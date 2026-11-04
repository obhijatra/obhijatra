import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:obhijatra_core/src/db/device_database.dart';
import 'package:obhijatra_core/src/forms/form_entry.dart';
import 'package:obhijatra_core/src/problem.dart';
import 'package:obhijatra_core/src/security/field_protector.dart';

/// The moves the outbox state machine allows.
///
/// `queued → sending` starts a try; `sending → sent` when the server
/// confirms; `sending → queued` after a temporary failure or when the app
/// stopped mid-send; `sending → problem` when a person must act;
/// `problem → queued` when a person retries. `sent` is final.
const Map<OutboxState, Set<OutboxState>> outboxTransitions = {
  OutboxState.queued: {OutboxState.sending},
  OutboxState.sending: {
    OutboxState.sent,
    OutboxState.queued,
    OutboxState.problem,
  },
  OutboxState.problem: {OutboxState.queued},
  OutboxState.sent: {},
};

/// Whether the outbox may move from [from] to [to].
bool canMoveOutbox(OutboxState from, OutboxState to) =>
    outboxTransitions[from]!.contains(to);

/// How many submissions are in each state.
final class OutboxCounts {
  /// Creates the counts.
  const OutboxCounts({
    this.queued = 0,
    this.sending = 0,
    this.sent = 0,
    this.problem = 0,
  });

  /// Waiting to be sent.
  final int queued;

  /// Being sent.
  final int sending;

  /// Confirmed by the server.
  final int sent;

  /// Refused; a person must act.
  final int problem;

  /// Not yet confirmed by the server (queued or sending).
  int get pending => queued + sending;

  @override
  bool operator ==(Object other) =>
      other is OutboxCounts &&
      other.queued == queued &&
      other.sending == sending &&
      other.sent == sent &&
      other.problem == problem;

  @override
  int get hashCode => Object.hash(queued, sending, sent, problem);

  @override
  String toString() =>
      'OutboxCounts(queued: $queued, sending: $sending, sent: $sent, '
      'problem: $problem)';
}

/// The queue of finalised submissions.
///
/// Every state change is a compare-and-set on the stored state, so two
/// sync runs (or a sync run and the user) can never both act on one row,
/// and no row is ever deleted before the server has confirmed it.
final class OutboxRepository {
  /// Creates the repository on [db]; [protector] encrypts protected fields
  /// once, as a submission enters the outbox (Phase 3).
  OutboxRepository(this._db, {this._protector = const NoFieldProtection()});

  final DeviceDatabase _db;
  final FieldProtector _protector;

  /// Puts a finalised [instance] in the outbox and deletes its draft, in
  /// one transaction. [attachmentPaths] are the local files to send.
  ///
  /// Queuing the same instance again with the same XML returns the stored
  /// entry; with different XML it throws an [ObhijatraException] with
  /// [ProblemCode.duplicateInstance] and changes nothing.
  Future<OutboxEntry> enqueue(
    FinalisedInstance instance, {
    List<String> attachmentPaths = const [],
  }) async {
    final xml = await _protector.protectInstance(
      instanceXml: instance.xml,
      form: instance.form,
    );
    final now = _now();
    return _db.transaction(() async {
      final existing = await find(instance.instanceId);
      if (existing != null) {
        // Never replace a queued or sent submission.
        if (existing.instanceXml == xml) return existing;
        throw const ObhijatraException(ProblemCode.duplicateInstance);
      }
      final entry = await _db
          .into(_db.outbox)
          .insertReturning(
            OutboxCompanion.insert(
              instanceId: instance.instanceId,
              formId: instance.form.formId,
              formVersion: instance.form.version,
              instanceXml: xml,
              attachments: Value(jsonEncode(attachmentPaths)),
              state: OutboxState.queued,
              createdAt: now,
              updatedAt: now,
            ),
          );
      await (_db.delete(
        _db.drafts,
      )..where((d) => d.instanceId.equals(instance.instanceId))).go();
      return entry;
    });
  }

  /// The entry for [instanceId], if any.
  Future<OutboxEntry?> find(String instanceId) => (_db.select(
    _db.outbox,
  )..where((o) => o.instanceId.equals(instanceId))).getSingleOrNull();

  /// Every entry, or those in [state], oldest first.
  Future<List<OutboxEntry>> entries({OutboxState? state}) {
    final query = _db.select(_db.outbox)
      ..orderBy([(o) => OrderingTerm.asc(o.createdAt)]);
    if (state != null) query.where((o) => o.state.equalsValue(state));
    return query.get();
  }

  /// Queued entries whose backoff has passed at [now] (all queued entries
  /// when [ignoreBackoff]), oldest first.
  Future<List<OutboxEntry>> due(DateTime now, {bool ignoreBackoff = false}) {
    final utc = now.toUtc();
    final query = _db.select(_db.outbox)
      ..where((o) => o.state.equalsValue(OutboxState.queued))
      ..orderBy([(o) => OrderingTerm.asc(o.createdAt)]);
    if (!ignoreBackoff) {
      query.where(
        (o) =>
            o.nextAttemptAt.isNull() |
            o.nextAttemptAt.isSmallerOrEqualValue(utc),
      );
    }
    return query.get();
  }

  /// The earliest time a queued entry is waiting for, if any.
  Future<DateTime?> nextAttemptTime() async {
    final next = _db.outbox.nextAttemptAt.min();
    final row =
        await (_db.selectOnly(_db.outbox)
              ..addColumns([next])
              ..where(_db.outbox.state.equalsValue(OutboxState.queued)))
            .getSingle();
    return row.read(next);
  }

  /// Puts entries left in `sending` by a stopped app back in the queue.
  /// Call only when no upload is in progress. Returns how many moved.
  Future<int> recoverInterrupted() =>
      (_db.update(
        _db.outbox,
      )..where((o) => o.state.equalsValue(OutboxState.sending))).write(
        OutboxCompanion(
          state: const Value(OutboxState.queued),
          nextAttemptAt: const Value(null),
          updatedAt: Value(_now()),
        ),
      );

  /// Claims [instanceId] for an upload (`queued → sending`) and counts the
  /// try. Returns `false` if it was not queued.
  Future<bool> markSending(String instanceId) async {
    final changed = await _db.customUpdate(
      'UPDATE outbox SET state = ?, attempts = attempts + 1, updated_at = ? '
      'WHERE instance_id = ? AND state = ?',
      variables: [
        Variable.withString(OutboxState.sending.name),
        Variable.withDateTime(_now()),
        Variable.withString(instanceId),
        Variable.withString(OutboxState.queued.name),
      ],
      updates: {_db.outbox},
      updateKind: UpdateKind.update,
    );
    return changed == 1;
  }

  /// Records the server's confirmation (`sending → sent`).
  Future<bool> markSent(String instanceId, {required String serverId}) {
    final now = _now();
    return _move(
      instanceId,
      from: OutboxState.sending,
      to: OutboxCompanion(
        state: const Value(OutboxState.sent),
        serverId: Value(serverId),
        sentAt: Value(now),
        lastError: const Value(null),
        lastErrorMessage: const Value(null),
        nextAttemptAt: const Value(null),
        updatedAt: Value(now),
      ),
    );
  }

  /// Queues [instanceId] again after a temporary failure, not before
  /// [nextAttemptAt] (`sending → queued`).
  Future<bool> markRetry(
    String instanceId, {
    required ProblemCode problem,
    required DateTime nextAttemptAt,
    String? serverMessage,
  }) => _move(
    instanceId,
    from: OutboxState.sending,
    to: OutboxCompanion(
      state: const Value(OutboxState.queued),
      lastError: Value(problem.name),
      lastErrorMessage: Value(serverMessage),
      nextAttemptAt: Value(nextAttemptAt.toUtc()),
      updatedAt: Value(_now()),
    ),
  );

  /// Puts [instanceId] back in the queue without counting the try, when a
  /// problem that blocks all syncing (sign-in, app update) stopped it.
  Future<bool> release(String instanceId, {required ProblemCode problem}) =>
      _db.transaction(() async {
        final moved = await _move(
          instanceId,
          from: OutboxState.sending,
          to: OutboxCompanion(
            state: const Value(OutboxState.queued),
            lastError: Value(problem.name),
            nextAttemptAt: const Value(null),
            updatedAt: Value(_now()),
          ),
        );
        if (moved) {
          await _db.customUpdate(
            'UPDATE outbox SET attempts = MAX(attempts - 1, 0) '
            'WHERE instance_id = ?',
            variables: [Variable.withString(instanceId)],
            updates: {_db.outbox},
            updateKind: UpdateKind.update,
          );
        }
        return moved;
      });

  /// Records that the server refused [instanceId] and a person must act
  /// (`sending → problem`). The submission is kept.
  Future<bool> markProblem(
    String instanceId, {
    required ProblemCode problem,
    String? serverMessage,
  }) => _move(
    instanceId,
    from: OutboxState.sending,
    to: OutboxCompanion(
      state: const Value(OutboxState.problem),
      lastError: Value(problem.name),
      lastErrorMessage: Value(serverMessage),
      nextAttemptAt: const Value(null),
      updatedAt: Value(_now()),
    ),
  );

  /// Queues a submission with a problem again, as a person asked
  /// (`problem → queued`); its try count starts again.
  Future<bool> retry(String instanceId) => _move(
    instanceId,
    from: OutboxState.problem,
    to: OutboxCompanion(
      state: const Value(OutboxState.queued),
      attempts: const Value(0),
      nextAttemptAt: const Value(null),
      updatedAt: Value(_now()),
    ),
  );

  /// The number of entries in each state, updated as the outbox changes.
  Stream<OutboxCounts> watchCounts() {
    final count = _db.outbox.instanceId.count();
    final query = _db.selectOnly(_db.outbox)
      ..addColumns([_db.outbox.state, count])
      ..groupBy([_db.outbox.state]);
    return query.watch().map((rows) {
      final byState = <String, int>{
        for (final row in rows)
          row.read(_db.outbox.state)!: row.read(count) ?? 0,
      };
      int of(OutboxState s) => byState[s.name] ?? 0;
      return OutboxCounts(
        queued: of(OutboxState.queued),
        sending: of(OutboxState.sending),
        sent: of(OutboxState.sent),
        problem: of(OutboxState.problem),
      );
    });
  }

  /// Decoded [OutboxEntry.attachments].
  static List<String> attachmentPathsOf(OutboxEntry entry) {
    final decoded = jsonDecode(entry.attachments);
    if (decoded is! List<Object?>) return const [];
    return decoded.whereType<String>().toList();
  }

  /// Times are stored in UTC so that stored text sorts in time order.
  static DateTime _now() => clock.now().toUtc();

  Future<bool> _move(
    String instanceId, {
    required OutboxState from,
    required OutboxCompanion to,
  }) async {
    assert(canMoveOutbox(from, to.state.value), 'illegal outbox move');
    final changed =
        await (_db.update(_db.outbox)..where(
              (o) =>
                  o.instanceId.equals(instanceId) & o.state.equalsValue(from),
            ))
            .write(to);
    return changed == 1;
  }
}
