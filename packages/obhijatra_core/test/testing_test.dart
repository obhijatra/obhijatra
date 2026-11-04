// The exported test server (package:obhijatra_core/testing.dart) behaves
// as its documentation says, so app tests can rely on it.
import 'package:clock/clock.dart';
import 'package:obhijatra_core/obhijatra_core.dart';
import 'package:obhijatra_core/testing.dart';
import 'package:test/test.dart';

import 'support/test_support.dart';

void main() {
  late FakeObhijatraServer fake;
  late ObhijatraServer server;

  setUp(() {
    fake = FakeObhijatraServer(xform: householdVisitXForm);
    server = ObhijatraServer(
      baseUrl: FakeObhijatraServer.baseUrl,
      appVersion: '0.1.0',
      httpClientFactory: fake.client,
    );
  });
  tearDown(() => server.close());

  Matcher problem(ProblemCode code) =>
      throwsA(isA<ObhijatraException>().having((e) => e.code, 'code', code));

  test(
    'queued glitches are used up one per request, before a lasting one',
    () async {
      fake
        ..metaGlitches.add(const ErrorStatus(503))
        ..metaGlitch = const NoConnection();
      await expectLater(server.fetchMeta(), problem(ProblemCode.serverError));
      await expectLater(server.fetchMeta(), problem(ProblemCode.offline));
      await expectLater(server.fetchMeta(), problem(ProblemCode.offline));
      fake.metaGlitch = null;
      expect((await server.fetchMeta()).apiVersion, '1');
    },
  );

  test('sign-in: glitches, unknown and inactive users', () async {
    fake.signInGlitch = const NoConnection();
    await expectLater(
      server.signIn(email: fakeEmail, password: fakePassword),
      problem(ProblemCode.offline),
    );
    fake
      ..signInGlitch = null
      ..users['gone@example.org'] = const FakeFieldUser(
        id: 'goneuser1abcdef',
        active: false,
      );
    await expectLater(
      server.signIn(email: 'gone@example.org', password: fakePassword),
      problem(ProblemCode.signInFailed),
    );
    final user = await server.signIn(email: fakeEmail, password: fakePassword);
    expect(user.name, 'Rahima Akter');
    expect(user.locationPath, '/aaaaaaaaaaaaaaa/');
  });

  test('downloads need a session and a file token', () async {
    await expectLater(
      server.listPublishedFormVersions(),
      problem(ProblemCode.signInRequired),
    );
    await server.signIn(email: fakeEmail, password: fakePassword);
    final versions = await server.listPublishedFormVersions();
    expect(versions.single.formId, sampleFormId);
    expect(await server.downloadXForm(versions.single), householdVisitXForm);
  });

  test('expired sessions and a lasting submission glitch', () async {
    await server.signIn(email: fakeEmail, password: fakePassword);
    final instance = await fillHouseholdVisit();
    fake.submissionGlitch = const ErrorStatus(422);
    await expectLater(
      server.submit(instanceXml: instance.xml),
      problem(ProblemCode.formNotOnServer),
    );
    await expectLater(
      server.submit(instanceXml: instance.xml),
      problem(ProblemCode.formNotOnServer),
    );
    fake
      ..submissionGlitch = null
      ..expireSessions();
    await expectLater(
      server.submit(instanceXml: instance.xml),
      problem(ProblemCode.signInRequired),
    );
    expect(fake.submissions, isEmpty);
  });

  test('a website answers instead of a server', () async {
    fake.isWebsite = true;
    await expectLater(
      server.fetchMeta(),
      problem(ProblemCode.unexpectedResponse),
    );
  });

  test('the Date header follows the test clock and the offset', () async {
    final phone = DateTime.utc(2030, 1, 2, 3, 4, 5);
    final meta = await withClock(Clock.fixed(phone), server.fetchMeta);
    expect(meta.serverTime, phone);
    fake.clockOffset = const Duration(minutes: -30);
    final behind = await withClock(Clock.fixed(phone), server.fetchMeta);
    expect(behind.serverTime, phone.subtract(const Duration(minutes: 30)));
    expect(behind.clockSkewed(phone), isTrue);
  });
}
