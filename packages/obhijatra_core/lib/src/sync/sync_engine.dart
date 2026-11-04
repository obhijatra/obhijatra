import 'dart:async';
import 'dart:math';

import 'package:clock/clock.dart';
import 'package:obhijatra_core/src/db/device_database.dart';
import 'package:obhijatra_core/src/db/settings_repository.dart';
import 'package:obhijatra_core/src/problem.dart';
import 'package:obhijatra_core/src/server/obhijatra_server.dart';
import 'package:obhijatra_core/src/server/server_models.dart';
import 'package:obhijatra_core/src/sync/backoff.dart';
import 'package:obhijatra_core/src/sync/outbox_repository.dart';

/// What the UI's SyncStatus component shows.
final class SyncStatus {
  /// Creates a status.
  const SyncStatus({
    this.queued = 0,
    this.problems = 0,
    this.isSending = false,
    this.isOffline = false,
    this.lastSyncedAt,
    this.blockedBy,
    this.nextAttemptAt,
  });

  /// Submissions not yet confirmed by the server.
  final int queued;

  /// Submissions the server refused; a person must act on each.
  final int problems;

  /// Whether a sync run is in progress.
  final bool isSending;

  /// Whether the last try could not reach the server.
  final bool isOffline;

  /// When the last sync that handled every due submission finished.
  final DateTime? lastSyncedAt;

  /// What stops all syncing until someone acts (sign in, update the app),
  /// or `null`.
  final ProblemCode? blockedBy;

  /// When the engine will try again by itself, if it will.
  final DateTime? nextAttemptAt;

  /// A copy with the given fields replaced; `clear…` flags set them to null.
  SyncStatus copyWith({
    int? queued,
    int? problems,
    bool? isSending,
    bool? isOffline,
    DateTime? lastSyncedAt,
    ProblemCode? blockedBy,
    bool clearBlockedBy = false,
    DateTime? nextAttemptAt,
    bool clearNextAttemptAt = false,
  }) => SyncStatus(
    queued: queued ?? this.queued,
    problems: problems ?? this.problems,
    isSending: isSending ?? this.isSending,
    isOffline: isOffline ?? this.isOffline,
    lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    blockedBy: clearBlockedBy ? null : (blockedBy ?? this.blockedBy),
    nextAttemptAt: clearNextAttemptAt
        ? null
        : (nextAttemptAt ?? this.nextAttemptAt),
  );

  @override
  bool operator ==(Object other) =>
      other is SyncStatus &&
      other.queued == queued &&
      other.problems == problems &&
      other.isSending == isSending &&
      other.isOffline == isOffline &&
      other.lastSyncedAt == lastSyncedAt &&
      other.blockedBy == blockedBy &&
      other.nextAttemptAt == nextAttemptAt;

  @override
  int get hashCode => Object.hash(
    queued,
    problems,
    isSending,
    isOffline,
    lastSyncedAt,
    blockedBy,
    nextAttemptAt,
  );

  @override
  String toString() =>
      'SyncStatus(queued: $queued, problems: $problems, '
      'sending: $isSending, offline: $isOffline, '
      'lastSyncedAt: $lastSyncedAt, blockedBy: ${blockedBy?.name}, '
      'next: $nextAttemptAt)';
}

/// What one sync run did.
final class SyncReport {
  /// Creates the report.
  const SyncReport({
    this.sent = 0,
    this.problems = 0,
    this.retrying = 0,
    this.stoppedBy,
  });

  /// Submissions the server confirmed in this run.
  final int sent;

  /// Submissions the server refused in this run.
  final int problems;

  /// Submissions that failed for a temporary reason and will be retried.
  final int retrying;

  /// Why the run stopped early, or `null` if it handled every due entry.
  final ProblemCode? stoppedBy;
}

/// Drains the outbox to the server.
///
/// - Checks `GET /meta` first and refuses to send (keeping every
///   submission) when the app is older than the server's
///   `min_client_version` or speaks another API version, or when the
///   phone's clock differs from the server's `Date` header by more than
///   [maxClockSkew] ([ProblemCode.clockSkew]).
/// - Sends due entries oldest first; a confirmation (`received` or
///   `already_received`) marks an entry sent; a 409 or other refusal marks
///   it as a problem with a plain-language code; a temporary failure
///   queues it again with exponential backoff and jitter.
/// - Never deletes a submission the server has not confirmed, and after a
///   crash re-sends entries left mid-send (the server recognises a retry).
///   Once the server confirms one, its XML and files are removed and a
///   receipt row stays.
/// - Publishes a [SyncStatus] stream for the UI.
///
/// Call [start] once, [syncNow] after queuing a submission, on app resume
/// and when the connection returns, and [dispose] before closing the
/// database.
final class SyncEngine {
  /// Creates an engine for [database] and [server]; [attachments] reads
  /// the files sent with submissions.
  SyncEngine({
    required DeviceDatabase database,
    required this._server,
    this._attachments,
    this._backoff = const Backoff(),
    Random? random,
    this._autoRetry = true,
    this._onUnexpectedError,
  }) : _outbox = OutboxRepository(database),
       _settings = SettingsRepository(database),
       _random = random ?? Random();

  final OutboxRepository _outbox;
  final SettingsRepository _settings;
  final ObhijatraServer _server;
  final AttachmentStore? _attachments;
  final Backoff _backoff;
  final Random _random;
  final bool _autoRetry;
  final void Function(Object, StackTrace)? _onUnexpectedError;

  final _statusController = StreamController<SyncStatus>.broadcast();
  StreamSubscription<OutboxCounts>? _countsSubscription;
  SyncStatus _status = const SyncStatus();
  Future<SyncReport>? _running;
  Timer? _timer;
  int _unreachableRuns = 0;
  DateTime? _engineRetryAt;
  bool _started = false;
  bool _disposed = false;

  /// The status now.
  SyncStatus get status => _status;

  /// The status now, then every change.
  Stream<SyncStatus> watchStatus() => Stream.multi((listener) {
    listener.add(_status);
    final subscription = _statusController.stream.listen(
      listener.add,
      onDone: listener.close,
    );
    listener.onCancel = subscription.cancel;
  });

  /// Recovers entries left mid-send, starts watching the outbox and
  /// schedules the next retry. Safe to call more than once.
  Future<void> start() async {
    if (_started || _disposed) return;
    _started = true;
    await _outbox.recoverInterrupted();
    _update(_status.copyWith(lastSyncedAt: await _settings.lastSyncedAt()));
    _countsSubscription = _outbox.watchCounts().listen(
      (counts) => _update(
        _status.copyWith(queued: counts.pending, problems: counts.problem),
      ),
    );
    await _scheduleNext();
  }

  /// Sends every due submission now; when a run is already going, returns
  /// that run. With [ignoreBackoff], queued entries are tried even if
  /// their backoff has not passed (for a "Sync now" button).
  ///
  /// Never throws: problems are recorded on the entries and in [status].
  Future<SyncReport> syncNow({bool ignoreBackoff = false}) {
    if (_disposed) return Future.value(const SyncReport());
    final running = _running;
    if (running != null) return running;
    final run = _run(ignoreBackoff: ignoreBackoff);
    _running = run;
    return run.whenComplete(() => _running = null);
  }

  /// Stops the engine, waiting for a run in progress to finish.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _timer?.cancel();
    await _running;
    await _countsSubscription?.cancel();
    await _statusController.close();
  }

  // -------------------------------------------------------------------

  Future<SyncReport> _run({required bool ignoreBackoff}) async {
    _timer?.cancel();
    _update(_status.copyWith(isSending: true, clearNextAttemptAt: true));
    var report = const SyncReport();
    try {
      report = await _drain(ignoreBackoff: ignoreBackoff);
    } on Object catch (error, stack) {
      // A database or programming error: the entry being sent stays in
      // `sending` and is recovered by the next run.
      _onUnexpectedError?.call(error, stack);
      report = const SyncReport(stoppedBy: ProblemCode.unknown);
    } finally {
      _update(_status.copyWith(isSending: false));
      if (!_disposed) await _scheduleNext(stoppedBy: report.stoppedBy);
    }
    return report;
  }

  Future<SyncReport> _drain({required bool ignoreBackoff}) async {
    // Nothing is in flight (runs never overlap), so `sending` rows are
    // left over from a stopped app.
    await _outbox.recoverInterrupted();

    final stop = await _handshake();
    if (stop != null) return SyncReport(stoppedBy: stop);

    var sent = 0;
    var problems = 0;
    var retrying = 0;
    ProblemCode? stoppedBy;
    final due = await _outbox.due(clock.now(), ignoreBackoff: ignoreBackoff);
    for (final entry in due) {
      if (_disposed) break;
      final id = entry.instanceId;
      if (!await _outbox.markSending(id)) continue;
      final attachmentPaths = OutboxRepository.attachmentPathsOf(entry);
      try {
        final receipt = await _server.submit(
          instanceXml: entry.instanceXml,
          attachmentPaths: attachmentPaths,
          attachments: _attachments,
        );
        if (await _outbox.markSent(id, serverId: receipt.serverId)) {
          await _removeSentFiles(attachmentPaths);
        }
        sent++;
      } on ObhijatraException catch (e) {
        if (e.code.blocksSync) {
          await _outbox.release(id, problem: e.code);
          stoppedBy = e.code;
          break;
        }
        if (e.code.isTransient) {
          await _outbox.markRetry(
            id,
            problem: e.code,
            serverMessage: e.serverMessage,
            nextAttemptAt: clock.now().add(
              _backoff.delay(entry.attempts + 1, _random),
            ),
          );
          retrying++;
          if (_serverWide(e.code)) {
            stoppedBy = e.code;
            break;
          }
          continue;
        }
        await _outbox.markProblem(
          id,
          problem: e.code,
          serverMessage: e.serverMessage,
        );
        problems++;
      } on Object catch (error, stack) {
        // Not a known problem (a bug, or an app-supplied component that
        // threw): keep the entry and retry it later.
        _onUnexpectedError?.call(error, stack);
        await _outbox.markRetry(
          id,
          problem: ProblemCode.unknown,
          nextAttemptAt: clock.now().add(
            _backoff.delay(entry.attempts + 1, _random),
          ),
        );
        retrying++;
      }
    }

    final unreachable = stoppedBy != null && _serverWide(stoppedBy);
    if (stoppedBy == null && !_disposed) {
      final now = clock.now();
      await _settings.setLastSyncedAt(now);
      _update(_status.copyWith(lastSyncedAt: now.toUtc()));
    }
    _update(
      _status.copyWith(
        isOffline: unreachable && _offlineCodes.contains(stoppedBy),
        blockedBy: stoppedBy != null && stoppedBy.blocksSync ? stoppedBy : null,
        clearBlockedBy: stoppedBy == null || !stoppedBy.blocksSync,
      ),
    );
    return SyncReport(
      sent: sent,
      problems: problems,
      retrying: retrying,
      stoppedBy: stoppedBy,
    );
  }

  /// Removes the files of a submission the server now holds. The receipt is
  /// already stored, so a file that cannot be removed is reported and left;
  /// it is never sent again.
  Future<void> _removeSentFiles(List<String> paths) async {
    final store = _attachments;
    if (store == null) return;
    for (final path in paths) {
      try {
        await store.delete(path);
      } on Object catch (error, stack) {
        _onUnexpectedError?.call(error, stack);
      }
    }
  }

  /// Checks the server, the phone's clock and the session; returns why not
  /// to send, if so.
  Future<ProblemCode?> _handshake() async {
    final ProblemCode? blocker;
    try {
      final meta = await _server.fetchMeta();
      blocker =
          meta.syncBlocker(_server.appVersion) ??
          // Before the session check: a wrong clock also makes a valid
          // session look expired.
          (meta.clockSkewed(clock.now()) ? ProblemCode.clockSkew : null);
    } on ObhijatraException catch (e) {
      _update(
        _status.copyWith(
          isOffline: _offlineCodes.contains(e.code),
          clearBlockedBy: true,
        ),
      );
      return e.code;
    }
    final stop =
        blocker ??
        (_server.hasValidSession
            ? await _checkOwner()
            : ProblemCode.signInRequired);
    _update(
      _status.copyWith(
        isOffline: false,
        blockedBy: stop,
        clearBlockedBy: stop == null,
      ),
    );
    return stop;
  }

  /// Makes sure submissions are sent only under the account that made
  /// them: the database belongs to the first user who syncs from it, and
  /// passes to another user only once nothing of the first is left unsent.
  Future<ProblemCode?> _checkOwner() async {
    final user = _server.currentUser!.id;
    final owner = await _settings.read(SettingsRepository.ownerKey);
    if (owner == user) return null;
    if (owner != null) {
      final counts = await _outbox.watchCounts().first;
      if (counts.pending > 0 || counts.problem > 0) {
        return ProblemCode.differentUser;
      }
    }
    await _settings.write(SettingsRepository.ownerKey, user);
    return null;
  }

  /// Plans the next automatic run: after a temporary failure of the whole
  /// run (no connection, server error), after an engine-level backoff;
  /// otherwise at the earliest entry backoff. Nothing is planned while
  /// syncing is blocked (sign-in or app update needed).
  Future<void> _scheduleNext({ProblemCode? stoppedBy}) async {
    _timer?.cancel();
    if (!_autoRetry || _disposed) return;

    if (stoppedBy != null && stoppedBy.isTransient) {
      _unreachableRuns++;
      _engineRetryAt = clock.now().add(
        _backoff.delay(_unreachableRuns, _random),
      );
    } else if (stoppedBy == null) {
      _unreachableRuns = 0;
      _engineRetryAt = null;
    }

    DateTime? next;
    if (_status.blockedBy == null) {
      next = _engineRetryAt ?? await _outbox.nextAttemptTime();
    }
    if (next == null) {
      _update(_status.copyWith(clearNextAttemptAt: true));
      return;
    }
    _update(_status.copyWith(nextAttemptAt: next.toUtc()));
    final wait = next.difference(clock.now());
    _timer = Timer(wait.isNegative ? Duration.zero : wait, () {
      unawaited(syncNow());
    });
  }

  void _update(SyncStatus next) {
    if (next == _status) return;
    _status = next;
    if (!_statusController.isClosed) _statusController.add(next);
  }

  static const _offlineCodes = {ProblemCode.offline, ProblemCode.timeout};

  /// Problems that would fail every other entry too, so the run stops.
  static bool _serverWide(ProblemCode code) =>
      _offlineCodes.contains(code) ||
      code == ProblemCode.serverError ||
      code == ProblemCode.serverBusy ||
      code == ProblemCode.redirected;
}
