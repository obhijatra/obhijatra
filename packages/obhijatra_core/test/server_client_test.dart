import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:obhijatra_core/obhijatra_core.dart';
import 'package:obhijatra_core/src/server/semver.dart';
import 'package:obhijatra_core/testing.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:test/test.dart';

import 'support/test_support.dart';

void main() {
  late FakeObhijatraServer fake;
  late ObhijatraServer server;

  ObhijatraServer connect({RequestSigner signer = const UnsignedRequests()}) =>
      ObhijatraServer(
        baseUrl: FakeObhijatraServer.baseUrl,
        appVersion: '0.1.0',
        signer: signer,
        httpClientFactory: fake.client,
      );

  setUp(() {
    fake = FakeObhijatraServer(xform: householdVisitXForm);
    server = connect();
  });
  tearDown(() => server.close());

  Matcher problem(ProblemCode code) =>
      throwsA(isA<ObhijatraException>().having((e) => e.code, 'code', code));

  group('handshake', () {
    test('reads the meta route', () async {
      final meta = await server.fetchMeta();
      expect(meta.apiVersion, '1');
      expect(meta.schemaVersion, 3);
      expect(meta.minClientVersion, '0.1.0');
      expect(meta.syncBlocker('0.1.0'), isNull);
    });

    test('an app older than min_client_version must update', () {
      const meta = ServerMeta(
        serverVersion: '0.3.0',
        schemaVersion: 2,
        apiVersion: '1',
        minClientVersion: '0.2.0',
      );
      expect(meta.syncBlocker('0.1.9'), ProblemCode.appUpdateRequired);
      expect(meta.syncBlocker('0.2.0-beta.1'), ProblemCode.appUpdateRequired);
      expect(meta.syncBlocker('0.2.0'), isNull);
      expect(meta.syncBlocker('1.0.0'), isNull);
    });

    test('another API version or an unset-up server blocks sync', () {
      ServerMeta meta({String api = '1', int schema = 1}) => ServerMeta(
        serverVersion: 'x',
        schemaVersion: schema,
        apiVersion: api,
        minClientVersion: '0.1.0',
      );
      expect(
        meta(api: '2').syncBlocker('0.1.0'),
        ProblemCode.serverIncompatible,
      );
      expect(meta(schema: 0).syncBlocker('0.1.0'), ProblemCode.serverNotSetUp);
    });

    test('a malformed meta answer is an unexpected response', () async {
      fake.meta = {'hello': 'world'};
      await expectLater(
        server.fetchMeta(),
        problem(ProblemCode.unexpectedResponse),
      );
    });

    test('no connection is reported as offline', () async {
      fake.metaGlitches.add(const NoConnection());
      await expectLater(server.fetchMeta(), problem(ProblemCode.offline));
    });

    test('an error answer to the meta route keeps its plain meaning', () async {
      fake.metaGlitches.addAll(const [
        ErrorStatus(503),
        ErrorStatus(429),
        ErrorStatus(404),
        ErrorStatus(400),
      ]);
      await expectLater(server.fetchMeta(), problem(ProblemCode.serverError));
      await expectLater(server.fetchMeta(), problem(ProblemCode.serverBusy));
      await expectLater(
        server.fetchMeta(),
        problem(ProblemCode.serverIncompatible),
      );
      await expectLater(
        server.fetchMeta(),
        problem(ProblemCode.unexpectedResponse),
      );
    });

    test('reads the server\'s clock from the Date header', () async {
      fake.clockOffset = const Duration(hours: 2);
      final meta = await server.fetchMeta();
      final now = DateTime.now();
      expect(meta.serverTime!.isUtc, isTrue);
      expect(
        meta.serverTime!.difference(now.add(const Duration(hours: 2))).abs(),
        lessThan(const Duration(seconds: 5)),
      );
      expect(meta.clockSkewed(now), isTrue);
    });

    test('a clock more than 10 minutes off is skewed, ahead or behind', () {
      final serverAt = DateTime.utc(2026, 11, 4, 10);
      ServerMeta meta(DateTime? at) => ServerMeta(
        serverVersion: 'x',
        schemaVersion: 3,
        apiVersion: '1',
        minClientVersion: '0.1.0',
        serverTime: at,
      );
      expect(maxClockSkew, const Duration(minutes: 10));
      final at = meta(serverAt);
      expect(at.clockSkewed(serverAt), isFalse);
      expect(at.clockSkewed(serverAt.add(maxClockSkew)), isFalse);
      expect(at.clockSkewed(serverAt.subtract(maxClockSkew)), isFalse);
      expect(
        at.clockSkewed(serverAt.add(maxClockSkew + const Duration(seconds: 1))),
        isTrue,
      );
      expect(
        at.clockSkewed(serverAt.subtract(const Duration(days: 365))),
        isTrue,
      );
      // A local time is compared as the same instant.
      expect(at.clockSkewed(serverAt.toLocal()), isFalse);
      // No Date header: nothing to compare.
      expect(meta(null).clockSkewed(DateTime(1999)), isFalse);
    });

    test('semantic versions compare as SemVer 2.0.0 says', () {
      expect(compareVersions('0.1.0', '0.1.0'), 0);
      expect(compareVersions('0.1.0', '0.10.0'), lessThan(0));
      expect(compareVersions('1.0.0-alpha', '1.0.0'), lessThan(0));
      expect(compareVersions('1.0.0-alpha.2', '1.0.0-alpha.10'), lessThan(0));
      expect(compareVersions('1.0.0-beta', '1.0.0-alpha.1'), greaterThan(0));
      expect(compareVersions('1.0.0+build.5', '1.0.0'), 0);
      expect(() => compareVersions('1.0', '1.0.0'), throwsFormatException);
    });
  });

  group('sign-in', () {
    test('a field user signs in and the session is kept', () async {
      expect(server.hasValidSession, isFalse);
      final user = await server.signIn(
        email: ' field1@example.org ',
        password: fakePassword,
      );
      expect(user.id, 'fielduser1abcde');
      expect(user.locationPath, '/aaaaaaaaaaaaaaa/');
      expect(server.hasValidSession, isTrue);
      expect(server.currentUser!.email, 'field1@example.org');
      server.signOut();
      expect(server.hasValidSession, isFalse);
    });

    test('a wrong password is signInFailed', () async {
      await expectLater(
        server.signIn(email: 'field1@example.org', password: 'wrong-password'),
        problem(ProblemCode.signInFailed),
      );
    });

    test('the session survives a restart through the settings table', () async {
      final db = memoryDatabase();
      addTearDown(db.close);
      final settings = SettingsRepository(db);
      final first = ObhijatraServer(
        baseUrl: FakeObhijatraServer.baseUrl,
        appVersion: '0.1.0',
        authStore: await settings.authStore(),
        httpClientFactory: fake.client,
      );
      await first.signIn(email: 'field1@example.org', password: fakePassword);
      first.close();
      await pumpEventQueue();

      final second = ObhijatraServer(
        baseUrl: FakeObhijatraServer.baseUrl,
        appVersion: '0.1.0',
        authStore: await settings.authStore(),
        httpClientFactory: fake.client,
      );
      addTearDown(second.close);
      expect(second.hasValidSession, isTrue);
      expect(second.currentUser!.id, 'fielduser1abcde');
    });

    test('an expired session is not valid', () {
      final store = AuthStore()
        ..save(
          fakeToken('u', inHours: -1),
          RecordModel({'id': 'u', 'collectionName': 'field_users'}),
        );
      final expired = ObhijatraServer(
        baseUrl: FakeObhijatraServer.baseUrl,
        appVersion: '0.1.0',
        authStore: store,
        httpClientFactory: fake.client,
      );
      addTearDown(expired.close);
      expect(expired.hasValidSession, isFalse);
      expect(
        expired.submit(instanceXml: '<x/>'),
        problem(ProblemCode.signInRequired),
      );
    });
  });

  group('forms', () {
    test('lists published versions and downloads the XForm', () async {
      await server.signIn(email: 'field1@example.org', password: fakePassword);
      final versions = await server.listPublishedFormVersions();
      expect(versions.single.formId, sampleFormId);
      expect(versions.single.version, sampleFormVersion);
      expect(versions.single.title, 'Household visit');
      expect(versions.single.publishedAt, DateTime.utc(2026, 11, 4, 8));
      expect(await server.downloadXForm(versions.single), householdVisitXForm);
    });

    test('the form repository caches each version once', () async {
      await server.signIn(email: 'field1@example.org', password: fakePassword);
      final db = memoryDatabase();
      addTearDown(db.close);
      final forms = FormRepository(db);

      final first = await forms.refreshFromServer(server);
      expect(first.added.single.formId, sampleFormId);
      expect(first.added.single.title, 'Household visit');
      final second = await forms.refreshFromServer(server);
      expect(second.added, isEmpty);
      expect(second.alreadyCached, 1);
      expect(
        (await forms.latestVersion(sampleFormId))!.xformXml,
        householdVisitXForm,
      );
      expect((await forms.forms()).single.title, 'Household visit');
    });

    test('a published version is never replaced by different XML', () async {
      final db = memoryDatabase();
      addTearDown(db.close);
      final forms = FormRepository(db);
      await forms.storeFormVersion(xformXml: householdVisitXForm);
      await expectLater(
        forms.storeFormVersion(
          xformXml: householdVisitXForm.replaceFirst(
            'Date of visit',
            'Visit date',
          ),
        ),
        problem(ProblemCode.formInvalid),
      );
      await expectLater(
        forms.storeFormVersion(
          xformXml: householdVisitXForm,
          expected: (formId: sampleFormId, version: '1'),
        ),
        problem(ProblemCode.formInvalid),
      );
    });
  });

  group('submissions', () {
    late FinalisedInstance instance;

    setUp(() async {
      await server.signIn(email: 'field1@example.org', password: fakePassword);
      instance = await fillHouseholdVisit();
    });

    test('are sent as the multipart body the server expects', () async {
      final store = MemoryAttachments({
        '/phone/media/photo-1.jpg': [0xff, 0xd8, 0xff, 0xe0, 1, 2, 3],
      });
      final receipt = await server.submit(
        instanceXml: instance.xml,
        attachmentPaths: ['/phone/media/photo-1.jpg'],
        attachments: store,
      );
      expect(receipt.status, ReceiptStatus.received);
      expect(receipt.instanceId, instance.instanceId);

      final stored = fake.submissions[instance.instanceId]!;
      expect(stored.xml, instance.xml);
      final xmlPart = stored.parts.firstWhere(
        (p) => p.name == 'xml_submission_file',
      );
      expect(xmlPart.filename, 'submission.xml');
      expect(xmlPart.contentType, startsWith('text/xml'));
      final photo = stored.parts.firstWhere((p) => p.name == 'photo-1.jpg');
      expect(photo.filename, 'photo-1.jpg');
      expect(photo.bytes, [0xff, 0xd8, 0xff, 0xe0, 1, 2, 3]);
      expect(stored.parts, hasLength(2));
      expect(fake.lastSubmissionHeaders['authorization'], isNotEmpty);
    });

    test('a retry of the same bytes is already received', () async {
      final first = await server.submit(instanceXml: instance.xml);
      final again = await server.submit(instanceXml: instance.xml);
      expect(first.status, ReceiptStatus.received);
      expect(again.status, ReceiptStatus.alreadyReceived);
      expect(again.serverId, first.serverId);
      expect(fake.submissions, hasLength(1));
    });

    test('different XML under the same instance ID is a 409', () async {
      await server.submit(instanceXml: instance.xml);
      await expectLater(
        server.submit(
          instanceXml: instance.xml.replaceFirst('Rahima', 'Rokeya'),
        ),
        throwsA(
          isA<ObhijatraException>()
              .having((e) => e.code, 'code', ProblemCode.duplicateInstance)
              .having((e) => e.statusCode, 'status', 409)
              .having(
                (e) => e.serverMessage,
                'message',
                contains('instance ID'),
              ),
        ),
      );
    });

    test('HTTP statuses map to plain-language problem codes', () async {
      final expected = {
        400: ProblemCode.submissionInvalid,
        401: ProblemCode.signInRequired,
        403: ProblemCode.accountNotPermitted,
        404: ProblemCode.serverIncompatible,
        413: ProblemCode.submissionTooLarge,
        422: ProblemCode.formNotOnServer,
        429: ProblemCode.serverBusy,
        500: ProblemCode.serverError,
        503: ProblemCode.serverError,
        418: ProblemCode.unexpectedResponse,
      };
      for (final MapEntry(key: status, value: code) in expected.entries) {
        fake.submissionGlitches.add(ErrorStatus(status));
        await expectLater(
          server.submit(instanceXml: instance.xml),
          problem(code),
          reason: 'HTTP $status',
        );
      }
    });

    test('an unpublished form version is formNotOnServer (422)', () async {
      await expectLater(
        server.submit(
          instanceXml: instance.xml.replaceAll(sampleFormVersion, '1999'),
        ),
        problem(ProblemCode.formNotOnServer),
      );
    });

    test('a dropped connection is offline; a slow server is timeout', () async {
      fake.submissionGlitches.add(const NoConnection());
      await expectLater(
        server.submit(instanceXml: instance.xml),
        problem(ProblemCode.offline),
      );

      final slow = ObhijatraServer(
        baseUrl: FakeObhijatraServer.baseUrl,
        appVersion: '0.1.0',
        authStore: AuthStore()
          ..save(
            fakeToken('u'),
            RecordModel({'id': 'u', 'collectionName': 'field_users'}),
          ),
        httpClientFactory: () => MockClient((request) async {
          await Future<void>.delayed(const Duration(milliseconds: 200));
          return http.Response('', 200);
        }),
        timeout: const Duration(milliseconds: 20),
      );
      addTearDown(slow.close);
      await expectLater(
        slow.submit(instanceXml: instance.xml),
        problem(ProblemCode.timeout),
      );
      await expectLater(slow.fetchMeta(), problem(ProblemCode.timeout));
    });

    test('a missing attachment is reported, not thrown raw', () async {
      await expectLater(
        server.submit(
          instanceXml: instance.xml,
          attachmentPaths: ['/gone.jpg'],
          attachments: MemoryAttachments(),
        ),
        problem(ProblemCode.attachmentMissing),
      );
    });

    test('every request passes through the request signer', () async {
      final signer = _RecordingSigner();
      final signed = connect(signer: signer);
      addTearDown(signed.close);
      await signed.signIn(email: 'field1@example.org', password: fakePassword);
      await signed.submit(instanceXml: instance.xml);

      expect(signer.requests.map((r) => '${r.method} ${r.url.path}'), [
        'POST /api/collections/field_users/auth-with-password',
        'POST /api/obhijatra/v1/submissions',
      ]);
      // The signer saw exactly the bytes the server received.
      final body = signer.requests.last.body;
      expect(latin1.decode(body), contains(instance.instanceId));
      expect(fake.lastSubmissionHeaders['x-test-signature'], '${body.length}');
    });
  });
}

final class _RecordingSigner implements RequestSigner {
  final requests = <SignableRequest>[];

  @override
  Future<Map<String, String>> signatureHeaders(SignableRequest request) async {
    requests.add(request);
    return {'X-Test-Signature': '${request.body.length}'};
  }
}
