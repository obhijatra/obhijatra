// One-time passwords: an organisation admin gives a field user a password
// they must replace before anything else works. The client reads the flag
// at sign-in, turns the server's refusal into its own problem code (from
// every call, sync too), chooses the new password and signs in again with
// it, and says plainly what went wrong when it cannot.
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:obhijatra_core/obhijatra_core.dart';
import 'package:obhijatra_core/testing.dart';
import 'package:pocketbase/pocketbase.dart' show AuthStore;
import 'package:test/test.dart';

import 'support/test_support.dart';

/// The one-time password the admin gives in these tests.
const String _oneTime = 'kfmw-tqzp-hrvx';

/// The password the person chooses.
const String _ownPassword = 'river tea mango kite';

void main() {
  late FakeObhijatraServer fake;
  late DeviceDatabase db;
  late ObhijatraServer server;

  Matcher problem(ProblemCode code) =>
      throwsA(isA<ObhijatraException>().having((e) => e.code, 'code', code));

  setUp(() async {
    fake = FakeObhijatraServer(xform: householdVisitXForm);
    db = memoryDatabase();
    server = ObhijatraServer(
      baseUrl: FakeObhijatraServer.baseUrl,
      appVersion: '0.1.0',
      authStore: await SettingsRepository(db).authStore(),
      httpClientFactory: fake.client,
    );
  });

  tearDown(() async {
    server.close();
    await db.close();
  });

  /// Signs in with the one-time password the admin gave.
  Future<SignedInUser> signInOneTime() {
    fake.giveOneTimePassword(fakeEmail, _oneTime);
    return server.signIn(email: fakeEmail, password: _oneTime);
  }

  group('the flag', () {
    test('a normal sign-in does not ask for a new password', () async {
      final user = await server.signIn(
        email: fakeEmail,
        password: fakePassword,
      );
      expect(user.mustChangePassword, isFalse);
      expect(server.currentUser!.mustChangePassword, isFalse);
    });

    test('a one-time password is read from the sign-in answer, and kept '
        'with the saved session', () async {
      final user = await signInOneTime();
      expect(user.mustChangePassword, isTrue);
      expect(server.hasValidSession, isTrue);

      // The app restarts: the saved session still says so.
      final again = ObhijatraServer(
        baseUrl: FakeObhijatraServer.baseUrl,
        appVersion: '0.1.0',
        authStore: await SettingsRepository(db).authStore(),
        httpClientFactory: fake.client,
      );
      addTearDown(again.close);
      expect(again.currentUser!.mustChangePassword, isTrue);
    });

    test('SMS-code and Google sign-ins read it too', () async {
      fake
        ..offersPhone = true
        ..giveOneTimePassword(fakeEmail, _oneTime);
      final request = await server.requestPhoneCode(fakePhone);
      final user = await server.signInWithPhoneCode(
        codeId: request.codeId,
        code: fake.sentSms.single.code,
      );
      expect(user.mustChangePassword, isTrue);
    });
  });

  group('everything else is refused with its own problem', () {
    test('forms, form downloads and submissions', () async {
      await signInOneTime();
      await expectLater(
        server.listPublishedFormVersions(),
        problem(ProblemCode.passwordChangeRequired),
      );
      const version = RemoteFormVersion(
        serverId: 'fv0000000000001',
        formServerId: 'formrecord00001',
        formId: sampleFormId,
        title: null,
        version: sampleFormVersion,
        xformFileName: 'household_visit_abc123.xml',
        publishedAt: null,
      );
      await expectLater(
        server.downloadXForm(version),
        problem(ProblemCode.passwordChangeRequired),
      );
      final instance = await fillHouseholdVisit();
      await expectLater(
        server.submit(instanceXml: instance.xml),
        problem(ProblemCode.passwordChangeRequired),
      );
      expect(fake.submissions, isEmpty);
      // The public checks still answer.
      expect((await server.fetchMeta()).apiVersion, '1');
      expect((await server.fetchSignInMethods()).password, isTrue);
    });

    test('the problem stops sync and is not tried again by itself', () {
      expect(ProblemCode.passwordChangeRequired.blocksSync, isTrue);
      expect(ProblemCode.passwordChangeRequired.isTransient, isFalse);
      for (final code in [
        ProblemCode.currentPasswordWrong,
        ProblemCode.newPasswordInvalid,
        ProblemCode.passwordChangedSignInAgain,
      ]) {
        expect(code.blocksSync, isFalse, reason: code.name);
        expect(code.isTransient, isFalse, reason: code.name);
      }
    });

    test('a plain 403 is still "not permitted"', () async {
      await server.signIn(email: fakeEmail, password: fakePassword);
      fake.submissionGlitches.add(const ErrorStatus(403));
      final instance = await fillHouseholdVisit();
      await expectLater(
        server.submit(instanceXml: instance.xml),
        problem(ProblemCode.accountNotPermitted),
      );
    });
  });

  group('choosing a new password', () {
    test('changes it, ends the old session and signs in with the new '
        'password', () async {
      await signInOneTime();
      final oldToken = (await savedSession(db))['token']! as String;
      fake.log.clear();

      final user = await server.changePassword(
        currentPassword: _oneTime,
        newPassword: _ownPassword,
      );
      expect(user.mustChangePassword, isFalse);
      expect(user.email, fakeEmail);
      expect(server.currentUser!.mustChangePassword, isFalse);
      expect(server.hasValidSession, isTrue);
      expect(fake.log, [
        'PATCH /api/collections/field_users/records/fielduser1abcde',
        'POST /api/collections/field_users/auth-with-password',
      ]);
      expect(fake.mustChangePassword(fakeEmail), isFalse);
      expect(fake.passwordOf(fakeEmail), _ownPassword);

      // The new session is the saved one, and it works.
      final saved = await savedSession(db);
      expect(saved['token'], isNot(oldToken));
      final record = saved['model']! as Map<String, Object?>;
      expect(record['must_change_password'], isFalse);
      expect(await server.listPublishedFormVersions(), hasLength(1));
      // The old session ended on the server.
      final stale = ObhijatraServer(
        baseUrl: FakeObhijatraServer.baseUrl,
        appVersion: '0.1.0',
        authStore: AuthStoreFor.token(oldToken),
        httpClientFactory: fake.client,
      );
      addTearDown(stale.close);
      await expectLater(
        stale.listPublishedFormVersions(),
        problem(ProblemCode.signInRequired),
      );
    });

    test('a Bangla password counts its letters, not its bytes', () async {
      await signInOneTime();
      // 12 letters, 36 bytes.
      const bangla = 'নদীচাআমঘুড়িবই';
      expect(bangla.runes.length, greaterThanOrEqualTo(minPasswordLength));
      final user = await server.changePassword(
        currentPassword: _oneTime,
        newPassword: bangla,
      );
      expect(user.mustChangePassword, isFalse);
      expect(fake.passwordOf(fakeEmail), bangla);
    });

    test('a wrong one-time password changes nothing', () async {
      await signInOneTime();
      await expectLater(
        server.changePassword(
          currentPassword: 'not-the-one-time',
          newPassword: _ownPassword,
        ),
        problem(ProblemCode.currentPasswordWrong),
      );
      await expectLater(
        server.changePassword(currentPassword: '', newPassword: _ownPassword),
        problem(ProblemCode.currentPasswordWrong),
      );
      expect(fake.mustChangePassword(fakeEmail), isTrue);
      expect(fake.passwordOf(fakeEmail), _oneTime);
      // The one-time session goes on, to try again.
      expect(server.hasValidSession, isTrue);
      expect(server.currentUser!.mustChangePassword, isTrue);
    });

    test('too short or too long is refused before anything is sent', () async {
      await signInOneTime();
      fake.log.clear();
      for (final password in ['short pass', 'x' * (maxPasswordLength + 1)]) {
        await expectLater(
          server.changePassword(
            currentPassword: _oneTime,
            newPassword: password,
          ),
          problem(ProblemCode.newPasswordInvalid),
        );
      }
      expect(fake.log, isEmpty);
      expect('a' * minPasswordLength, hasLength(12));
    });

    test('offline changes nothing and can be tried again', () async {
      await signInOneTime();
      fake.passwordChangeGlitches.add(const NoConnection());
      await expectLater(
        server.changePassword(
          currentPassword: _oneTime,
          newPassword: _ownPassword,
        ),
        problem(ProblemCode.offline),
      );
      expect(fake.mustChangePassword(fakeEmail), isTrue);
      expect(server.hasValidSession, isTrue);
      final user = await server.changePassword(
        currentPassword: _oneTime,
        newPassword: _ownPassword,
      );
      expect(user.mustChangePassword, isFalse);
    });

    test('saved, but the sign-in after it fails: no session is left, and '
        'the new password signs in', () async {
      await signInOneTime();
      fake.signInGlitches.add(const NoConnection());
      await expectLater(
        server.changePassword(
          currentPassword: _oneTime,
          newPassword: _ownPassword,
        ),
        problem(ProblemCode.passwordChangedSignInAgain),
      );
      expect(fake.passwordOf(fakeEmail), _ownPassword);
      expect(server.hasValidSession, isFalse);
      expect(server.currentUser, isNull);
      expect(
        await SettingsRepository(db).read(SettingsRepository.sessionKey),
        isNull,
      );
      final user = await server.signIn(
        email: fakeEmail,
        password: _ownPassword,
      );
      expect(user.mustChangePassword, isFalse);
    });

    test('without a session there is nothing to change', () async {
      await expectLater(
        server.changePassword(
          currentPassword: _oneTime,
          newPassword: _ownPassword,
        ),
        problem(ProblemCode.signInRequired),
      );
      // A session the server has ended (the admin reset the password).
      await server.signIn(email: fakeEmail, password: fakePassword);
      fake.expireSessions();
      await expectLater(
        server.changePassword(
          currentPassword: fakePassword,
          newPassword: _ownPassword,
        ),
        problem(ProblemCode.signInRequired),
      );
    });

    test('the server\'s answers, read plainly', () async {
      // Answers of the real server, as PocketBase writes them.
      Future<ObhijatraException> refusal(int status, Object body) async {
        final scripted = MockClient((request) async {
          if (request.url.path.endsWith('/auth-with-password')) {
            return http.Response(
              jsonEncode({
                'token': fakeToken('fielduser1abcde'),
                'record': AuthStoreFor.record,
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response(
            jsonEncode(body),
            status,
            headers: {'content-type': 'application/json'},
          );
        });
        final client = ObhijatraServer(
          baseUrl: FakeObhijatraServer.baseUrl,
          appVersion: '0.1.0',
          httpClientFactory: () => scripted,
        );
        addTearDown(client.close);
        await client.signIn(email: fakeEmail, password: fakePassword);
        try {
          await client.changePassword(
            currentPassword: fakePassword,
            newPassword: _ownPassword,
          );
        } on ObhijatraException catch (e) {
          return e;
        }
        fail('the change was not refused');
      }

      Map<String, Object?> fieldError(String field, String code) => {
        'status': 400,
        'message': 'Failed to update record.',
        'data': {
          field: {'code': code, 'message': 'x'},
        },
      };
      final cases = <(int, Object), ProblemCode>{
        (400, fieldError('oldPassword', 'validation_invalid_old_password')):
            ProblemCode.currentPasswordWrong,
        (400, fieldError('password', 'validation_min_text_constraint')):
            ProblemCode.newPasswordInvalid,
        (400, fieldError('passwordConfirm', 'validation_values_mismatch')):
            ProblemCode.newPasswordInvalid,
        (400, fieldError('name', 'validation_required')):
            ProblemCode.unexpectedResponse,
        (
          403,
          {
            'status': 403,
            'message': 'Choose a new password before you continue.',
            'data': {
              'reason': {
                'code': 'password_change_required',
                'message': 'Choose a new password before you continue.',
              },
            },
          },
        ): ProblemCode.passwordChangeRequired,
        (403, {'status': 403, 'message': 'No.', 'data': <String, Object?>{}}):
            ProblemCode.accountNotPermitted,
        (404, {'status': 404, 'message': 'Not found.'}):
            ProblemCode.accountNotPermitted,
        (401, {'status': 401, 'message': 'Sign in.'}):
            ProblemCode.signInRequired,
        (429, {'status': 429, 'message': 'Too many requests.'}):
            ProblemCode.serverBusy,
      };
      for (final MapEntry(key: (status, body), value: code) in cases.entries) {
        final e = await refusal(status, body);
        expect(e.code, code, reason: '$status $body');
        expect(e.statusCode, status);
      }
    });
  });

  group('sync', () {
    late OutboxRepository outbox;
    late SyncEngine engine;

    setUp(() {
      outbox = OutboxRepository(db);
      engine = SyncEngine(database: db, server: server, autoRetry: false);
    });
    tearDown(() => engine.dispose());

    test('the server refuses a submission: sync stops, the form stays '
        'queued', () async {
      await server.signIn(email: fakeEmail, password: fakePassword);
      final id = (await outbox.enqueue(await fillHouseholdVisit())).instanceId;
      // The admin asks for a new password while the phone holds a session.
      fake.requirePasswordChange(fakeEmail);
      await engine.start();

      final report = await engine.syncNow();
      expect(report.stoppedBy, ProblemCode.passwordChangeRequired);
      expect(engine.status.blockedBy, ProblemCode.passwordChangeRequired);
      final entry = (await outbox.find(id))!;
      expect(entry.state, OutboxState.queued);
      expect(entry.attempts, 0);
      expect(fake.submissions, isEmpty);

      // The person chooses a new password; the form goes.
      await server.changePassword(
        currentPassword: fakePassword,
        newPassword: _ownPassword,
      );
      final after = await engine.syncNow();
      expect(after.sent, 1);
      expect(engine.status.blockedBy, isNull);
      expect((await outbox.find(id))!.state, OutboxState.sent);
    });

    test('a session that says so is not used to send at all', () async {
      await signInOneTime();
      await outbox.enqueue(await fillHouseholdVisit());
      await engine.start();
      fake.log.clear();

      final report = await engine.syncNow();
      expect(report.stoppedBy, ProblemCode.passwordChangeRequired);
      expect(fake.log, ['GET /api/obhijatra/v1/meta']);
    });

    test('updating forms stops with the same problem', () async {
      await server.signIn(email: fakeEmail, password: fakePassword);
      fake.requirePasswordChange(fakeEmail);
      await expectLater(
        FormRepository(db).refreshFromServer(server),
        problem(ProblemCode.passwordChangeRequired),
      );
    });
  });

  test('a detached session store can carry on with an earlier session', () {
    String? first;
    final store = SettingsRepository.detachedAuthStore((d) => first = d);
    final token = fakeToken('fielduser1abcde');
    store.save(token, null);
    return Future<void>.delayed(Duration.zero, () {
      String? second;
      final resumed = SettingsRepository.detachedAuthStore(
        (d) => second = d,
        initial: first,
      );
      expect(resumed.token, token);
      resumed.clear();
      return Future<void>.delayed(Duration.zero, () => expect(second, isNull));
    });
  });
}

/// A session store holding only [token], as a phone that kept an old one.
abstract final class AuthStoreFor {
  /// The store.
  static AuthStore token(String token) =>
      SettingsRepository.detachedAuthStore((_) {}, initial: _session(token));

  /// The fake's first user's record.
  static const Map<String, Object?> record = {
    'id': 'fielduser1abcde',
    'collectionId': 'pbc_field_users',
    'collectionName': 'field_users',
    'email': fakeEmail,
  };

  static String _session(String token) =>
      jsonEncode({'token': token, 'model': record});
}

/// The session saved in [db]'s settings.
Future<Map<String, Object?>> savedSession(DeviceDatabase db) async =>
    jsonDecode(
      (await SettingsRepository(db).read(SettingsRepository.sessionKey))!,
    ) as Map<String, Object?>;
