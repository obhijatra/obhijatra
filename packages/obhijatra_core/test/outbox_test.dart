import 'package:clock/clock.dart';
import 'package:obhijatra_core/obhijatra_core.dart';
import 'package:test/test.dart';

import 'support/test_support.dart';

void main() {
  late DeviceDatabase db;
  late OutboxRepository outbox;

  setUp(() {
    db = memoryDatabase();
    outbox = OutboxRepository(db);
  });
  tearDown(() => db.close());

  group('state machine', () {
    test('allows exactly the documented moves', () {
      const s = OutboxState.values;
      final allowed = {
        for (final from in s)
          for (final to in s)
            if (canMoveOutbox(from, to)) '${from.name}->${to.name}',
      };
      expect(allowed, {
        'queued->sending',
        'sending->sent',
        'sending->queued',
        'sending->problem',
        'problem->queued',
      });
    });

    test('a queued entry is claimed once; sent is final', () async {
      final entry = await outbox.enqueue(await fillHouseholdVisit());
      final id = entry.instanceId;
      expect(entry.state, OutboxState.queued);
      expect(entry.attempts, 0);

      expect(await outbox.markSent(id, serverId: 'x'), isFalse); // not sending
      expect(await outbox.markSending(id), isTrue);
      expect(await outbox.markSending(id), isFalse); // already claimed
      expect((await outbox.find(id))!.attempts, 1);

      expect(await outbox.markSent(id, serverId: 'srv1'), isTrue);
      final sent = (await outbox.find(id))!;
      expect(sent.state, OutboxState.sent);
      expect(sent.serverId, 'srv1');
      expect(sent.sentAt, isNotNull);
      // Nothing moves a sent entry, and it is never deleted.
      expect(await outbox.markSending(id), isFalse);
      expect(await outbox.retry(id), isFalse);
      expect(await outbox.recoverInterrupted(), 0);
      expect((await outbox.find(id))!.instanceXml, entry.instanceXml);
    });

    test('a temporary failure queues again with a backoff time', () async {
      final id = (await outbox.enqueue(await fillHouseholdVisit())).instanceId;
      final now = DateTime.utc(2026, 11, 4, 10);
      await withClock(Clock.fixed(now), () async {
        await outbox.markSending(id);
        await outbox.markRetry(
          id,
          problem: ProblemCode.serverError,
          serverMessage: 'Something went wrong.',
          nextAttemptAt: now.add(const Duration(seconds: 30)),
        );
      });
      final entry = (await outbox.find(id))!;
      expect(entry.state, OutboxState.queued);
      expect(ProblemCode.fromName(entry.lastError), ProblemCode.serverError);
      expect(entry.lastErrorMessage, 'Something went wrong.');
      expect(entry.attempts, 1);

      expect(await outbox.due(now), isEmpty);
      expect(await outbox.due(now, ignoreBackoff: true), hasLength(1));
      expect(
        await outbox.due(now.add(const Duration(seconds: 30))),
        hasLength(1),
      );
      expect(
        await outbox.nextAttemptTime(),
        now.add(const Duration(seconds: 30)),
      );
    });

    test('a refusal becomes a problem a person can retry', () async {
      final id = (await outbox.enqueue(await fillHouseholdVisit())).instanceId;
      await outbox.markSending(id);
      await outbox.markProblem(
        id,
        problem: ProblemCode.duplicateInstance,
        serverMessage: 'A different submission with this instance ID…',
      );
      var entry = (await outbox.find(id))!;
      expect(entry.state, OutboxState.problem);
      expect(entry.lastError, 'duplicateInstance');
      expect(await outbox.due(DateTime.now()), isEmpty);

      expect(await outbox.retry(id), isTrue);
      entry = (await outbox.find(id))!;
      expect(entry.state, OutboxState.queued);
      expect(entry.attempts, 0);
    });

    test('a blocked try is released without counting it', () async {
      final id = (await outbox.enqueue(await fillHouseholdVisit())).instanceId;
      await outbox.markSending(id);
      await outbox.release(id, problem: ProblemCode.signInRequired);
      final entry = (await outbox.find(id))!;
      expect(entry.state, OutboxState.queued);
      expect(entry.attempts, 0);
      expect(entry.lastError, 'signInRequired');
    });

    test('entries left mid-send by a stopped app are recovered', () async {
      final a = (await outbox.enqueue(await fillHouseholdVisit())).instanceId;
      final b = (await outbox.enqueue(await fillHouseholdVisit())).instanceId;
      await outbox.markSending(a);
      await outbox.markSending(b);
      expect(await outbox.recoverInterrupted(), 2);
      expect(await outbox.entries(state: OutboxState.queued), hasLength(2));
      // The try that was cut off still counts towards backoff.
      expect((await outbox.find(a))!.attempts, 1);
    });
  });

  group('enqueue', () {
    test('moves a draft into the outbox in one transaction', () async {
      final session = await FormEntrySession.start(
        xformXml: householdVisitXForm,
      );
      addTearDown(session.close);
      final drafts = DraftRepository(db);
      await drafts.save(session);
      expect(await drafts.find(session.instanceId), isNotNull);

      answerByLabel(session, 'Date of visit', '2026-11-01');
      session.next();
      answerByLabel(session, 'What happened', 'declined');
      session.next();
      answerByLabel(session, 'Why could', 'They asked us to come next week.');
      final finalised = session.finalise() as Finalised;
      final entry = await outbox.enqueue(
        finalised.instance,
        attachmentPaths: ['/data/media/photo-1.jpg'],
      );

      expect(entry.instanceId, session.instanceId);
      expect(entry.formId, sampleFormId);
      expect(entry.formVersion, sampleFormVersion);
      expect(entry.instanceXml, finalised.instance.xml);
      expect(OutboxRepository.attachmentPathsOf(entry), [
        '/data/media/photo-1.jpg',
      ]);
      expect(await drafts.find(session.instanceId), isNull);
    });

    test('is idempotent for the same XML and refuses different XML', () async {
      final instance = await fillHouseholdVisit();
      final first = await outbox.enqueue(instance);
      final again = await outbox.enqueue(instance);
      expect(again.createdAt, first.createdAt);

      final altered = FinalisedInstance(
        form: instance.form,
        instanceId: instance.instanceId,
        xml: instance.xml.replaceFirst('Rahima', 'Rokeya'),
        attachmentNames: const [],
      );
      await expectLater(
        outbox.enqueue(altered),
        throwsA(
          isA<ObhijatraException>().having(
            (e) => e.code,
            'code',
            ProblemCode.duplicateInstance,
          ),
        ),
      );
      expect(
        (await outbox.find(instance.instanceId))!.instanceXml,
        instance.xml,
      );
    });

    test('runs the field protector once, before storing', () async {
      final protector = _CountingProtector();
      final protected = OutboxRepository(db, protector: protector);
      final entry = await protected.enqueue(await fillHouseholdVisit());
      expect(protector.calls, 1);
      expect(entry.instanceXml, contains('<!-- protected -->'));
    });
  });

  test('counts are watched as the outbox changes', () async {
    final counts = outbox.watchCounts();
    final seen = <OutboxCounts>[];
    final subscription = counts.listen(seen.add);
    addTearDown(subscription.cancel);

    final id = (await outbox.enqueue(await fillHouseholdVisit())).instanceId;
    await outbox.markSending(id);
    await outbox.markSent(id, serverId: 's');
    await pumpEventQueue();
    expect(seen.last, const OutboxCounts(sent: 1));
    expect(seen.last.pending, 0);
  });
}

final class _CountingProtector implements FieldProtector {
  int calls = 0;

  @override
  Future<String> protectInstance({
    required String instanceXml,
    required FormVersionRef form,
  }) async {
    calls++;
    return instanceXml.replaceFirst('<meta>', '<!-- protected --><meta>');
  }
}
