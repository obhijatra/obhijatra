import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:obhijatra_manager/src/data/models.dart';
import 'package:obhijatra_manager/src/data/phone_number.dart';
import 'package:obhijatra_manager/src/data/pocketbase_api.dart';
import 'package:obhijatra_manager/src/data/problem.dart';
import 'package:pocketbase/pocketbase.dart';

const String server = 'https://data.example.org';
const String signIn = '/api/obhijatra/v1/signin';

http.Response json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: <String, String>{'content-type': 'application/json'},
);

Matcher problem(ProblemKind kind) =>
    throwsA(isA<AppProblem>().having((p) => p.kind, 'kind', kind));

Map<String, Object?> staffRecord({String role = 'supervisor'}) =>
    <String, Object?>{
      'id': 'u2',
      'collectionName': 'staff_users',
      'name': 'Nasrin Sultana',
      'email': '',
      'phone': '+8801712345678',
      'role': role,
    };

const String token = 'eyJhbGciOiJIUzI1NiJ9.eyJleHAiOjk5OTk5OTk5OTl9.sig';

void main() {
  group('mobile numbers', () {
    test('what people type becomes the international form', () {
      for (final typed in <String>[
        '01712345678',
        '1712345678',
        '01712-345678',
        '+880 1712-345678',
        '+880 01712345678',
        '8801712345678',
        '008801712345678',
        '(017) 1234 5678',
        '০১৭১২৩৪৫৬৭৮',
      ]) {
        expect(normalisePhone(typed), '+8801712345678', reason: typed);
      }
      expect(normalisePhone('+44 7700 900123'), '+447700900123');
    });

    test('anything that is not a mobile number is refused', () {
      for (final typed in <String>[
        '',
        'abc',
        '0171234567', // one digit short
        '017123456789', // one digit long
        '0212345678', // a Dhaka landline cannot receive SMS
        '+1',
        '+0123456789',
        '12-34-ab',
      ]) {
        expect(normalisePhone(typed), isNull, reason: typed);
      }
    });

    test('numbers are spaced for reading', () {
      expect(displayPhone('+8801712345678'), '+880 1712-345678');
      expect(displayPhone('+447700900123'), '+447700900123');
      expect(hasOwnCountryCode('01712'), isFalse);
      expect(hasOwnCountryCode('+44'), isTrue);
      expect(hasOwnCountryCode('0044'), isTrue);
    });
  });

  group('sign-in methods', () {
    test('reads what the server offers', () async {
      late Uri url;
      final api = PocketBaseApi(
        server,
        httpClient: MockClient((request) async {
          url = request.url;
          return json(<String, Object?>{
            'password': true,
            'google': true,
            'phone': false,
          });
        }),
      );
      final methods = await api.signInMethods();
      expect(url.path, '$signIn/methods');
      expect(methods.google, isTrue);
      expect(methods.phone, isFalse);
    });

    test(
      'an older server without the route offers email and password',
      () async {
        final api = PocketBaseApi(
          server,
          httpClient: MockClient(
            (request) async =>
                json(<String, Object?>{'message': 'Not found.'}, 404),
          ),
        );
        expect(await api.signInMethods(), SignInMethods.passwordOnly);
      },
    );
  });

  group('SMS codes', () {
    test('asks for a code for a staff account', () async {
      late http.Request seen;
      final api = PocketBaseApi(
        server,
        httpClient: MockClient((request) async {
          seen = request;
          return json(<String, Object?>{
            'code_id': 'c1',
            'expires_in': 300,
            'resend_after': 60,
          });
        }),
      );
      final request = await api.requestPhoneCode('+8801712345678');
      expect(seen.method, 'POST');
      expect(seen.url.path, '$signIn/phone/code');
      expect(jsonDecode(seen.body), <String, Object?>{
        'collection': 'staff_users',
        'phone': '+8801712345678',
      });
      expect(request.codeId, 'c1');
      expect(request.expiresIn, const Duration(minutes: 5));
      expect(request.resendAfter, const Duration(minutes: 1));
    });

    test('refusals to send a code are plain problems', () async {
      Future<void> expectKind(http.Response answer, ProblemKind kind) async {
        final api = PocketBaseApi(
          server,
          httpClient: MockClient((request) async => answer),
        );
        await expectLater(
          api.requestPhoneCode('+8801712345678'),
          problem(kind),
        );
      }

      await expectKind(
        json(<String, Object?>{
          'message': 'Enter the mobile number in international form.',
          'data': <String, Object?>{
            'phone': <String, Object?>{
              'code': 'validation_invalid_phone',
              'message': 'Enter the mobile number in international form.',
            },
          },
        }, 400),
        ProblemKind.phoneInvalid,
      );
      await expectKind(
        json(<String, Object?>{'message': 'Off.'}, 403),
        ProblemKind.smsOff,
      );
      await expectKind(
        json(<String, Object?>{'message': 'Too many.'}, 429),
        ProblemKind.tooManyCodes,
      );
    });

    test('the right code signs in and keeps the session in memory', () async {
      late http.Request seen;
      final api = PocketBaseApi(
        server,
        httpClient: MockClient((request) async {
          seen = request;
          return json(<String, Object?>{
            'token': token,
            'record': staffRecord(),
          });
        }),
      );
      final user = await api.signInWithPhoneCode('c1', '123456');
      expect(seen.url.path, '$signIn/phone/verify');
      expect(jsonDecode(seen.body), <String, Object?>{
        'code_id': 'c1',
        'code': '123456',
      });
      expect(user.displayName, 'Nasrin Sultana');
      expect(user.phone, '+8801712345678');
      expect(api.currentUser?.id, 'u2');
    });

    test('a wrong code and too many tries are plain problems', () async {
      var status = 400;
      final api = PocketBaseApi(
        server,
        httpClient: MockClient(
          (request) async => json(<String, Object?>{'message': 'No.'}, status),
        ),
      );
      await expectLater(
        api.signInWithPhoneCode('c1', '000000'),
        problem(ProblemKind.codeWrong),
      );
      status = 429;
      await expectLater(
        api.signInWithPhoneCode('c1', '000000'),
        problem(ProblemKind.tooManyTries),
      );
      expect(api.currentUser, isNull);
    });
  });

  group('Google', () {
    /// A server that answers PocketBase's OAuth2 routes and keeps the live
    /// (server-sent events) connection open so the test can push to it.
    MockClient googleServer({
      required StreamController<List<int>> live,
      required List<http.Request> seen,
      http.Response Function()? exchange,
      String authUrl = 'https://accounts.example.com/o/oauth2/auth?client_id=abc&redirect_uri=',
      Future<void>? exchangeGate,
    }) => MockClient.streaming((request, body) async {
      final bytes = await body.toBytes();
      final copy = http.Request(request.method, request.url)
        ..headers.addAll(request.headers)
        ..bodyBytes = bytes;
      seen.add(copy);
      http.StreamedResponse reply(http.Response r) => http.StreamedResponse(
        Stream<List<int>>.value(r.bodyBytes),
        r.statusCode,
        headers: r.headers,
      );
      final path = request.url.path;
      if (path.endsWith('/auth-methods')) {
        return reply(
          json(<String, Object?>{
            'password': <String, Object?>{
              'enabled': true,
              'identityFields': <String>['email'],
            },
            'oauth2': <String, Object?>{
              'enabled': true,
              'providers': <Object?>[
                <String, Object?>{
                  'name': 'google',
                  'displayName': 'Google',
                  'state': 'ignored',
                  'authURL': authUrl,
                  'codeVerifier': 'verifier-1',
                  'codeChallenge': 'challenge',
                  'codeChallengeMethod': 'S256',
                },
              ],
            },
            'mfa': <String, Object?>{'enabled': false, 'duration': 0},
            'otp': <String, Object?>{'enabled': false, 'duration': 0},
          }),
        );
      }
      if (path == '/api/realtime' && request.method == 'GET') {
        return http.StreamedResponse(live.stream, 200);
      }
      if (path == '/api/realtime') return reply(http.Response('', 204));
      if (path.endsWith('/auth-with-oauth2')) {
        if (exchangeGate != null) await exchangeGate;
        return reply(
          exchange?.call() ??
              json(<String, Object?>{'token': token, 'record': staffRecord()}),
        );
      }
      return reply(json(<String, Object?>{}, 404));
    });

    void push(StreamController<List<int>> live, String event, Object data) =>
        live.add(
          utf8.encode(
            'id:client-1\nevent:$event\ndata:${jsonEncode(data)}\n\n',
          ),
        );

    test('opens Google with the server’s state and signs in when the browser '
        'comes back', () async {
      final live = StreamController<List<int>>();
      final seen = <http.Request>[];
      final api = PocketBaseApi(
        server,
        httpClient: googleServer(live: live, seen: seen),
      );
      push(live, 'PB_CONNECT', <String, Object?>{'clientId': 'client-1'});
      Uri? opened;
      final user = await api.signInWithGoogle(
        openUrl: (url) {
          opened = url;
          push(live, '@oauth2', <String, Object?>{
            'state': 'client-1',
            'code': 'google-code',
          });
        },
        cancelled: Completer<void>().future,
      );
      expect(user?.id, 'u2');
      expect(api.currentUser?.id, 'u2');
      expect(opened!.host, 'accounts.example.com');
      expect(opened!.queryParameters['state'], 'client-1');
      expect(
        opened!.queryParameters['redirect_uri'],
        '$server/api/oauth2-redirect',
      );
      final exchange = seen.lastWhere(
        (r) => r.url.path.endsWith('/auth-with-oauth2'),
      );
      expect(
        exchange.url.path,
        '/api/collections/staff_users/auth-with-oauth2',
      );
      expect(jsonDecode(exchange.body), containsPair('code', 'google-code'));
      expect(
        jsonDecode(exchange.body),
        containsPair('codeVerifier', 'verifier-1'),
      );
      await live.close();
    });

    test('cancelling stops waiting and signs nobody in', () async {
      final live = StreamController<List<int>>();
      final api = PocketBaseApi(
        server,
        httpClient: googleServer(live: live, seen: <http.Request>[]),
      );
      push(live, 'PB_CONNECT', <String, Object?>{'clientId': 'client-1'});
      final cancel = Completer<void>();
      final user = await api.signInWithGoogle(
        openUrl: (_) => cancel.complete(),
        cancelled: cancel.future,
      );
      expect(user, isNull);
      expect(api.currentUser, isNull);
      await live.close();
    });

    test('only a secure (https) Google address is ever opened', () async {
      for (final address in <String>[
        'http://accounts.example.com/o/oauth2/auth?redirect_uri=',
        'javascript:alert(1)//',
        'file:///etc/passwd?redirect_uri=',
        '/o/oauth2/auth?redirect_uri=',
        'https:///no-host?redirect_uri=',
      ]) {
        final live = StreamController<List<int>>();
        final seen = <http.Request>[];
        final api = PocketBaseApi(
          server,
          httpClient: googleServer(live: live, seen: seen, authUrl: address),
        );
        push(live, 'PB_CONNECT', <String, Object?>{'clientId': 'client-1'});
        var opened = false;
        await expectLater(
          api.signInWithGoogle(
            openUrl: (_) => opened = true,
            cancelled: Completer<void>().future,
          ),
          problem(ProblemKind.googleFailed),
          reason: address,
        );
        expect(opened, isFalse, reason: address);
        // Refused before any live connection is made.
        expect(
          seen.where((r) => r.url.path == '/api/realtime'),
          isEmpty,
          reason: address,
        );
        // Nobody listened, so closing would wait for ever: do not wait.
        unawaited(live.close());
      }
    });

    test('cancelled while the code is exchanged: nobody is signed in, not '
        'even for a moment', () async {
      final live = StreamController<List<int>>();
      final gate = Completer<void>();
      final store = AuthStore();
      final tokens = <String>[];
      final watch = store.onChange.listen((event) => tokens.add(event.token));
      addTearDown(watch.cancel);
      final api = PocketBaseApi(
        server,
        authStore: store,
        httpClient: googleServer(
          live: live,
          seen: <http.Request>[],
          exchangeGate: gate.future,
        ),
      );
      push(live, 'PB_CONNECT', <String, Object?>{'clientId': 'client-1'});
      final cancel = Completer<void>();
      final user = api.signInWithGoogle(
        openUrl: (_) => push(live, '@oauth2', <String, Object?>{
          'state': 'client-1',
          'code': 'google-code',
        }),
        cancelled: cancel.future,
      );
      // Let the browser's answer arrive and the exchange start.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      cancel.complete();
      expect(await user, isNull);
      // Google finishes after the person cancelled.
      gate.complete();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(api.currentUser, isNull);
      expect(store.token, isEmpty);
      expect(tokens.where((t) => t.isNotEmpty), isEmpty);
      await live.close();
    });

    test('the code is exchanged without the current session token', () async {
      final live = StreamController<List<int>>();
      final seen = <http.Request>[];
      final store = AuthStore()
        ..save(
          'eyJhbGciOiJIUzI1NiJ9.eyJleHAiOjk5OTk5OTk5OTksImlkIjoidTkifQ.old',
          RecordModel.fromJson(staffRecord()),
        );
      final api = PocketBaseApi(
        server,
        authStore: store,
        httpClient: googleServer(live: live, seen: seen),
      );
      push(live, 'PB_CONNECT', <String, Object?>{'clientId': 'client-1'});
      final user = await api.signInWithGoogle(
        openUrl: (_) => push(live, '@oauth2', <String, Object?>{
          'state': 'client-1',
          'code': 'google-code',
        }),
        cancelled: Completer<void>().future,
      );
      expect(user?.id, 'u2');
      final exchange = seen.lastWhere(
        (r) => r.url.path.endsWith('/auth-with-oauth2'),
      );
      expect(
        exchange.headers.keys.map((k) => k.toLowerCase()),
        isNot(contains('authorization')),
      );
      // The new session replaces the old one only after the exchange.
      expect(store.token, token);
      await live.close();
    });

    test('a refusal from the server becomes its own plain problem', () async {
      // The server sends a reason code in data.reason.code; the English
      // sentence is not relied on.
      final cases = <String?, ProblemKind>{
        'google_no_account': ProblemKind.googleNoAccount,
        'google_email_unconfirmed': ProblemKind.googleUnconfirmed,
        'account_not_allowed': ProblemKind.googleNotAllowed,
        'google_no_email': ProblemKind.googleNoEmail,
        'google_email_not_managed': ProblemKind.googleUnmanaged,
        'something_new': ProblemKind.googleFailed,
        null: ProblemKind.googleFailed,
      };
      for (final entry in cases.entries) {
        final live = StreamController<List<int>>();
        final api = PocketBaseApi(
          server,
          httpClient: googleServer(
            live: live,
            seen: <http.Request>[],
            exchange: () => json(<String, Object?>{
              'message': 'Any wording.',
              'data': entry.key == null
                  ? <String, Object?>{}
                  : <String, Object?>{
                      'reason': <String, Object?>{
                        'code': entry.key,
                        'message': 'Any wording.',
                      },
                    },
            }, 400),
          ),
        );
        push(live, 'PB_CONNECT', <String, Object?>{'clientId': 'client-1'});
        await expectLater(
          api.signInWithGoogle(
            openUrl: (_) => push(live, '@oauth2', <String, Object?>{
              'state': 'client-1',
              'code': 'google-code',
            }),
            cancelled: Completer<void>().future,
          ),
          problem(entry.value),
          reason: '${entry.key}',
        );
        expect(api.currentUser, isNull);
        await live.close();
      }
    });

    test('turning Google down is the same as cancelling', () async {
      final live = StreamController<List<int>>();
      final api = PocketBaseApi(
        server,
        httpClient: googleServer(live: live, seen: <http.Request>[]),
      );
      push(live, 'PB_CONNECT', <String, Object?>{'clientId': 'client-1'});
      final user = await api.signInWithGoogle(
        openUrl: (_) => push(live, '@oauth2', <String, Object?>{
          'state': 'client-1',
          'error': 'access_denied',
        }),
        cancelled: Completer<void>().future,
      );
      expect(user, isNull);
      await live.close();
    });

    test('a server without Google sign-in says so', () async {
      final api = PocketBaseApi(
        server,
        httpClient: MockClient(
          (request) async => json(<String, Object?>{
            'oauth2': <String, Object?>{
              'enabled': false,
              'providers': <Object?>[],
            },
          }),
        ),
      );
      await expectLater(
        api.signInWithGoogle(
          openUrl: (_) {},
          cancelled: Completer<void>().future,
        ),
        problem(ProblemKind.googleUnavailable),
      );
    });
  });

  group('sign-in settings', () {
    Map<String, Object?> view() => <String, Object?>{
      'google': <String, Object?>{
        'enabled': true,
        'client_id': '123-abc.apps.googleusercontent.com',
        'client_secret_set': true,
        'redirect_url': '$server/api/oauth2-redirect',
      },
      'phone': <String, Object?>{
        'enabled': false,
        'sms': <String, Object?>{
          'method': 'GET',
          'url': 'https://sms.example.com/send?to={phone_digits}',
          'content_type': '',
          'body': '',
          'headers': <Object?>[
            <String, Object?>{
              'name': 'Authorization',
              'value': 'Bearer {secret}',
            },
          ],
          'secret_set': true,
          'success_text': 'OK',
        },
        'last_send': <String, Object?>{
          'at': '2026-11-05T08:32:00Z',
          'ok': false,
          'status': 401,
          'reply': 'Unauthorised',
        },
        'code_lifetime_seconds': 300,
      },
    };

    test('reads every setting, without secrets', () async {
      final api = PocketBaseApi(
        server,
        httpClient: MockClient((request) async => json(view())),
      );
      final settings = await api.loadSignInSettings();
      expect(settings.google.enabled, isTrue);
      expect(settings.google.clientSecretSet, isTrue);
      expect(settings.google.redirectUrlUsable, isTrue);
      expect(settings.phone.sms.method, SmsMethod.get);
      expect(settings.phone.sms.headers.single.name, 'Authorization');
      expect(settings.phone.sms.secretSet, isTrue);
      expect(settings.phone.lastSend!.status, 401);
      expect(settings.phone.lastSend!.ok, isFalse);
    });

    test('a redirect address Google refuses is spotted', () {
      for (final address in <String>[
        'http://data.example.org/api/oauth2-redirect',
        'https://203.0.113.5/api/oauth2-redirect',
        '/api/oauth2-redirect',
        '',
      ]) {
        expect(
          GoogleSignInSettings(redirectUrl: address).redirectUrlUsable,
          isFalse,
          reason: address,
        );
      }
    });

    test('only an org admin may read them', () async {
      final api = PocketBaseApi(
        server,
        httpClient: MockClient(
          (request) async => json(<String, Object?>{'message': 'No.'}, 403),
        ),
      );
      await expectLater(
        api.loadSignInSettings(),
        problem(ProblemKind.notAllowed),
      );
    });

    test('saves with PUT; empty secrets keep the saved ones', () async {
      late http.Request seen;
      final api = PocketBaseApi(
        server,
        httpClient: MockClient((request) async {
          seen = request;
          return json(view());
        }),
      );
      await api.saveSignInSettings(
        const SignInSettingsUpdate(
          googleEnabled: true,
          googleClientId: '123-abc.apps.googleusercontent.com',
          googleClientSecret: '',
          phoneEnabled: true,
          sms: SmsProviderDraft(
            method: SmsMethod.post,
            url: 'https://api.example-sms.com/v1/send',
            bodyFormat: SmsBodyFormat.json,
            body: '{"to": "{phone_digits}", "text": "{message}"}',
            headers: <SmsHeader>[
              SmsHeader(name: 'Authorization', value: 'Bearer {secret}'),
            ],
            secret: '',
            successText: 'SUCCESS',
          ),
        ),
      );
      expect(seen.method, 'PUT');
      expect(seen.url.path, '$signIn/settings');
      expect(jsonDecode(seen.body), <String, Object?>{
        'google': <String, Object?>{
          'enabled': true,
          'client_id': '123-abc.apps.googleusercontent.com',
          'client_secret': '',
        },
        'phone': <String, Object?>{
          'enabled': true,
          'sms': <String, Object?>{
            'method': 'POST',
            'url': 'https://api.example-sms.com/v1/send',
            'content_type': 'json',
            'body': '{"to": "{phone_digits}", "text": "{message}"}',
            'headers': <Object?>[
              <String, Object?>{
                'name': 'Authorization',
                'value': 'Bearer {secret}',
              },
            ],
            'secret': '',
            'success_text': 'SUCCESS',
          },
        },
      });
    });

    test('refused fields come back one by one', () async {
      final api = PocketBaseApi(
        server,
        httpClient: MockClient(
          (request) async => json(<String, Object?>{
            'message': 'Some sign-in settings need attention.',
            'data': <String, Object?>{
              'phone.sms.url': <String, Object?>{
                'code': 'validation_invalid_value',
                'message': 'The address must start with https://',
              },
              'google.client_id': <String, Object?>{
                'code': 'validation_invalid_value',
                'message': 'This does not look like a Google client ID.',
              },
            },
          }, 400),
        ),
      );
      await expectLater(
        api.saveSignInSettings(
          const SignInSettingsUpdate(
            googleEnabled: false,
            googleClientId: 'x',
            googleClientSecret: '',
            phoneEnabled: false,
            sms: SmsProviderDraft(
              method: SmsMethod.get,
              url: 'http://x',
              bodyFormat: SmsBodyFormat.json,
              body: 'ignored for GET',
              headers: <SmsHeader>[],
              secret: '',
              successText: '',
            ),
          ),
        ),
        throwsA(
          isA<AppProblem>()
              .having((p) => p.kind, 'kind', ProblemKind.settingsInvalid)
              .having((p) => p.fields, 'fields', <String, String>{
                'phone.sms.url': 'The address must start with https://',
                'google.client_id':
                    'This does not look like a Google client ID.',
              }),
        ),
      );
    });

    test(
      'a test SMS sends the unsaved settings and reports the result',
      () async {
        late http.Request seen;
        var status = 200;
        final api = PocketBaseApi(
          server,
          httpClient: MockClient((request) async {
            seen = request;
            return status == 200
                ? json(<String, Object?>{
                    'at': '2026-11-05T08:32:00Z',
                    'ok': true,
                    'status': 200,
                    'reply': '{"status":"SUCCESS"}',
                  })
                : json(<String, Object?>{'message': 'Too many.'}, status);
          }),
        );
        const draft = SmsProviderDraft(
          method: SmsMethod.get,
          url: 'https://sms.example.com/send?to={phone}&text={message}',
          bodyFormat: SmsBodyFormat.json,
          body: '',
          headers: <SmsHeader>[],
          secret: 'new-key',
          successText: '',
        );
        final result = await api.sendTestSms('+8801712345678', draft);
        expect(seen.url.path, '$signIn/test-sms');
        final body = jsonDecode(seen.body) as Map<String, dynamic>;
        expect(body['phone'], '+8801712345678');
        expect(body['sms'], containsPair('method', 'GET'));
        expect(body['sms'], containsPair('content_type', ''));
        expect(body['sms'], containsPair('secret', 'new-key'));
        expect(result.ok, isTrue);
        expect(result.status, 200);

        status = 429;
        await expectLater(
          api.sendTestSms('+8801712345678', draft),
          problem(ProblemKind.tooManyTests),
        );
      },
    );
  });
}
