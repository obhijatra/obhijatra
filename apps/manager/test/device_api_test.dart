import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:obhijatra_device/obhijatra_device.dart';
import 'package:obhijatra_manager/src/data/devices.dart';
import 'package:obhijatra_manager/src/data/models.dart';
import 'package:obhijatra_manager/src/data/people.dart';
import 'package:obhijatra_manager/src/data/pocketbase_api.dart';
import 'package:obhijatra_manager/src/data/problem.dart';
import 'package:obhijatra_manager/src/device/device_http.dart';
import 'package:obhijatra_manager/src/device/identity_store.dart';
import 'package:pocketbase/pocketbase.dart';

const String server = 'https://data.example.org';
const String deviceId = 'thisdevice00001';
const String token = 'eyJhbGciOiJIUzI1NiJ9.eyJleHAiOjk5OTk5OTk5OTl9.sig';

http.Response json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: <String, String>{'content-type': 'application/json'},
);

http.Response refusal(int status, String reason) => json(<String, Object?>{
  'status': status,
  'message': 'Refused.',
  'data': <String, Object?>{
    'reason': <String, Object?>{'code': reason, 'message': 'Refused.'},
  },
}, status);

Matcher problem(ProblemKind kind) =>
    throwsA(isA<AppProblem>().having((p) => p.kind, 'kind', kind));

/// Keys made from fixed seeds. Ed25519 signatures are deterministic
/// (RFC 8032), so a signature is valid exactly when signing the message
/// the server rebuilds gives the same bytes.
Future<SoftwareDeviceKeys> testKeys([int seed = 7]) =>
    SoftwareDeviceKeys.fromSeeds(
      List<int>.filled(32, seed),
      List<int>.filled(32, seed + 1),
    );

/// Checks that [request] carries a valid signature by [keys] as [device],
/// over the method, target, time, nonce and exact body, as the server
/// rebuilds them (docs/decisions/0008-device-trust.md).
Future<void> expectSigned(
  http.Request request,
  DeviceKeys keys,
  String device,
) async {
  final headers = request.headers;
  expect(headers[DeviceHeaders.device], device, reason: '${request.url}');
  final time = headers[DeviceHeaders.time]!;
  final nonce = headers[DeviceHeaders.nonce]!;
  expect(
    (int.parse(time) - DateTime.now().millisecondsSinceEpoch ~/ 1000).abs(),
    lessThan(5),
  );
  expect(nonce, matches(RegExp(r'^[A-Za-z0-9_-]{22}$')));
  final message = requestMessage(
    method: request.method,
    target: requestTarget(request.url),
    unixTime: time,
    nonce: nonce,
    body: request.bodyBytes,
  );
  expect(
    headers[DeviceHeaders.signature],
    base64UrlNoPadding(await keys.sign(message)),
    reason: '${request.method} ${request.url}',
  );
}

void expectUnsigned(http.Request request) {
  for (final header in <String>[
    DeviceHeaders.device,
    DeviceHeaders.time,
    DeviceHeaders.nonce,
    DeviceHeaders.signature,
  ]) {
    expect(request.headers.containsKey(header), isFalse, reason: header);
  }
}

/// A server that records every request (with its exact body bytes) and
/// answers with [answer].
MockClient recording(
  List<http.Request> seen,
  FutureOr<http.Response> Function(http.Request request) answer,
) => MockClient.streaming((request, body) async {
  final bytes = await body.toBytes();
  final copy = http.Request(request.method, request.url)
    ..headers.addAll(request.headers)
    ..bodyBytes = bytes;
  seen.add(copy);
  final response = await answer(copy);
  return http.StreamedResponse(
    Stream<List<int>>.value(response.bodyBytes),
    response.statusCode,
    headers: response.headers,
  );
});

/// The API signing with [keys] as [deviceId], signed in.
Future<(PocketBaseApi, DeviceSigner)> signedApi(
  http.Client client,
  DeviceKeys keys, {
  String? id = deviceId,
}) async {
  final signer = DeviceSigner()..use(DeviceIdentity(keys: keys, deviceId: id));
  final store = AuthStore()
    ..save(
      token,
      RecordModel.fromJson(<String, dynamic>{
        'id': 'u1',
        'collectionName': 'staff_users',
        'email': 'tania@example.org',
        'role': 'org_admin',
        'active': true,
      }),
    );
  return (
    PocketBaseApi(server, httpClient: client, signer: signer, authStore: store),
    signer,
  );
}

Map<String, Object?> listOf(List<Map<String, Object?>> items) =>
    <String, Object?>{
      'page': 1,
      'perPage': 500,
      'totalItems': items.length,
      'totalPages': 1,
      'items': items,
    };

Map<String, Object?> view({
  String status = 'pending',
  bool second = false,
  bool expired = false,
}) => <String, Object?>{
  'id': deviceId,
  'status': status,
  'label': 'Web browser (Chrome on Windows)',
  'platform': 'web',
  'expires': status == 'active' ? '2027-11-06 09:00:00.000Z' : '',
  'approved_at': status == 'active' ? '2026-11-06 09:00:00.000Z' : '',
  'needs_second_approval': second,
  'approval_expired': expired,
};

void main() {
  group('every request is signed by this device', () {
    test('the SDK’s requests, with the session token', () async {
      final keys = await testKeys();
      final seen = <http.Request>[];
      final (api, _) = await signedApi(
        recording(seen, (_) => json(listOf(const <Map<String, Object?>>[]))),
        keys,
      );
      await api.listForms();
      expect(seen, hasLength(2));
      for (final request in seen) {
        expect(request.headers['Authorization'], token);
        await expectSigned(request, keys, deviceId);
      }
    });

    test(
      'raw file downloads, with the file token in the signed target',
      () async {
        final keys = await testKeys();
        final seen = <http.Request>[];
        final (api, _) = await signedApi(
          recording(seen, (request) {
            if (request.url.path == '/api/files/token') {
              return json(<String, Object?>{'token': 'file-token-1'});
            }
            return http.Response('<h:html/>', 200);
          }),
          keys,
        );
        final xml = await api.downloadXForm(
          FormVersion(
            id: 'v1',
            formRecordId: 'f1',
            version: '1',
            published: true,
            created: DateTime(2026, 11, 6),
            xformFile: 'household_abc.xml',
          ),
        );
        expect(xml, '<h:html/>');
        final download = seen.last;
        expect(
          download.url.path,
          '/api/files/form_versions/v1/household_abc.xml',
        );
        expect(requestTarget(download.url), contains('token=file-token-1'));
        for (final request in seen) {
          await expectSigned(request, keys, deviceId);
        }
      },
    );

    test('multipart uploads, over the exact bytes sent', () async {
      final keys = await testKeys();
      final seen = <http.Request>[];
      final (api, _) = await signedApi(
        recording(seen, (request) {
          if (request.method == 'GET') {
            return json(listOf(const <Map<String, Object?>>[]));
          }
          return json(<String, Object?>{
            'id': request.url.path.contains('form_versions') ? 'v9' : 'f9',
            'form': 'f9',
            'version': '3',
            'published': false,
            'created': '2026-11-06 09:00:00.000Z',
            'xform': 'a.xml',
          });
        }),
        keys,
      );
      await api.uploadDraft(
        formId: 'household_visit',
        title: 'Household visit',
        version: '3',
        xmlBytes: Uint8List.fromList(utf8.encode('<data>রহিমা</data>')),
      );
      final upload = seen.last;
      expect(
        upload.headers['content-type'],
        startsWith('multipart/form-data; boundary='),
      );
      expect(utf8.decode(upload.bodyBytes), contains('<data>রহিমা</data>'));
      for (final request in seen) {
        await expectSigned(request, keys, deviceId);
      }
    });

    test('a sign-in, so the new session is the device’s at once', () async {
      final keys = await testKeys();
      final seen = <http.Request>[];
      final signer = DeviceSigner()
        ..use(DeviceIdentity(keys: keys, deviceId: deviceId));
      final api = PocketBaseApi(
        server,
        httpClient: recording(
          seen,
          (_) => json(<String, Object?>{
            'token': token,
            'record': <String, Object?>{
              'id': 'u1',
              'collectionName': 'staff_users',
              'email': 'tania@example.org',
              'role': 'supervisor',
            },
          }),
        ),
        signer: signer,
      );
      await api.signIn('tania@example.org', 'a-long-password');
      expect(
        seen.single.url.path,
        '/api/collections/staff_users/auth-with-password',
      );
      await expectSigned(seen.single, keys, deviceId);
    });

    test('the Google code exchange, on its own empty session', () async {
      final keys = await testKeys();
      final live = StreamController<List<int>>();
      final seen = <http.Request>[];
      final client = MockClient.streaming((request, body) async {
        final bytes = await body.toBytes();
        seen.add(
          http.Request(request.method, request.url)
            ..headers.addAll(request.headers)
            ..bodyBytes = bytes,
        );
        http.StreamedResponse reply(http.Response r) => http.StreamedResponse(
          Stream<List<int>>.value(r.bodyBytes),
          r.statusCode,
          headers: r.headers,
        );
        final path = request.url.path;
        if (path.endsWith('/auth-methods')) {
          return reply(
            json(<String, Object?>{
              'password': <String, Object?>{'enabled': true},
              'oauth2': <String, Object?>{
                'enabled': true,
                'providers': <Object?>[
                  <String, Object?>{
                    'name': 'google',
                    'displayName': 'Google',
                    'state': 'x',
                    'authURL': 'https://accounts.example.com/o/oauth2/auth?redirect_uri=',
                    'codeVerifier': 'verifier-1',
                    'codeChallenge': 'c',
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
        return reply(
          json(<String, Object?>{
            'token': token,
            'record': <String, Object?>{
              'id': 'u2',
              'collectionName': 'staff_users',
              'email': 'nasrin@example.org',
              'role': 'supervisor',
            },
          }),
        );
      });
      void push(String event, Object data) => live.add(
        utf8.encode('id:client-1\nevent:$event\ndata:${jsonEncode(data)}\n\n'),
      );
      final signer = DeviceSigner()
        ..use(DeviceIdentity(keys: keys, deviceId: deviceId));
      final api = PocketBaseApi(server, httpClient: client, signer: signer);
      push('PB_CONNECT', <String, Object?>{'clientId': 'client-1'});
      final user = await api.signInWithGoogle(
        openUrl: (_) => push('@oauth2', <String, Object?>{
          'state': 'client-1',
          'code': 'google-code',
        }),
        cancelled: Completer<void>().future,
      );
      expect(user?.id, 'u2');
      final exchange = seen.lastWhere(
        (r) => r.url.path.endsWith('/auth-with-oauth2'),
      );
      expect(exchange.headers.containsKey('Authorization'), isFalse);
      await expectSigned(exchange, keys, deviceId);
      // The live connection and its subscription are signed too.
      for (final request in seen.where((r) => r.url.path == '/api/realtime')) {
        await expectSigned(request, keys, deviceId);
      }
      await live.close();
    });

    test(
      'nothing is signed before the server has given the device an id',
      () async {
        final keys = await testKeys();
        final seen = <http.Request>[];
        final (api, _) = await signedApi(
          recording(seen, (_) => json(<String, Object?>{'items': <Object?>[]})),
          keys,
          id: null,
        );
        await api.organisationName();
        expectUnsigned(seen.single);
      },
    );
  });

  group('enrolment', () {
    test(
      'sends the public keys, signed as "enrol" with the keys it enrols',
      () async {
        final keys = await testKeys(3);
        final other = await testKeys(11);
        final seen = <http.Request>[];
        // The device signer holds other keys; enrolment must not use them.
        final (api, _) = await signedApi(
          recording(seen, (_) => json(view())),
          other,
          id: 'otherdevice0001',
        );
        final device = await api.enrolDevice(
          keys: keys,
          label: 'Web browser (Chrome on Windows)',
          platform: DevicePlatform.web,
        );
        final request = seen.single;
        expect(request.method, 'POST');
        expect(request.url.path, deviceEnrolPath);
        expect(request.headers['Authorization'], token);
        await expectSigned(request, keys, enrolDeviceId);
        final body = jsonDecode(utf8.decode(request.bodyBytes)) as Map;
        expect(body, <String, Object?>{
          'label': 'Web browser (Chrome on Windows)',
          'platform': 'web',
          'sign_public_key': base64.encode(keys.signPublicKey),
          'enc_public_key': base64.encode(keys.encPublicKey),
        });
        // Standard base64 with padding: 32 bytes are 44 characters.
        expect(body['sign_public_key'] as String, hasLength(44));
        expect((body['sign_public_key'] as String).endsWith('='), isTrue);
        expect(device.id, deviceId);
        expect(device.status, DeviceStatus.pending);
        expect(device.usable, isFalse);
      },
    );

    test('refusals: keys in use, too many waiting, an ended session', () async {
      final keys = await testKeys();
      for (final (answer, kind) in <(http.Response, ProblemKind)>[
        (
          json(<String, Object?>{'message': 'In use.'}, 409),
          ProblemKind.deviceKeyInUse,
        ),
        (
          json(<String, Object?>{'message': 'Too many.'}, 429),
          ProblemKind.tooManyWaitingDevices,
        ),
        (refusal(401, DeviceReason.sessionRevoked), ProblemKind.signInRequired),
        (
          refusal(401, DeviceReason.sessionOtherDevice),
          ProblemKind.sessionOtherDevice,
        ),
        (refusal(403, DeviceReason.clock), ProblemKind.deviceClock),
      ]) {
        final (api, _) = await signedApi(
          recording(<http.Request>[], (_) => answer),
          keys,
          id: null,
        );
        await expectLater(
          api.enrolDevice(keys: keys, label: 'Mac', platform: 'macos'),
          problem(kind),
        );
      }
    });
  });

  group('device status and refusals', () {
    test('reads this device’s status', () async {
      final keys = await testKeys();
      final seen = <http.Request>[];
      final (api, _) = await signedApi(
        recording(seen, (_) => json(view(status: 'active', expired: true))),
        keys,
      );
      final device = await api.myDevice();
      expect(seen.single.url.path, deviceMePath);
      await expectSigned(seen.single, keys, deviceId);
      expect(device.status, DeviceStatus.active);
      expect(device.approvalExpired, isTrue);
      expect(device.usable, isFalse);
      expect(device.expires, DateTime.utc(2027, 11, 6, 9).toLocal());
    });

    test('every reason code becomes its own plain problem', () async {
      final keys = await testKeys();
      for (final (answer, kind) in <(http.Response, ProblemKind)>[
        (refusal(403, DeviceReason.revoked), ProblemKind.deviceRevoked),
        (refusal(403, DeviceReason.expired), ProblemKind.deviceExpired),
        (refusal(403, DeviceReason.notApproved), ProblemKind.deviceNotApproved),
        (refusal(403, DeviceReason.clock), ProblemKind.deviceClock),
        (
          refusal(403, DeviceReason.signatureRequired),
          ProblemKind.deviceNotSetUp,
        ),
        (
          refusal(403, DeviceReason.signatureInvalid),
          ProblemKind.deviceCheckFailed,
        ),
        (refusal(403, DeviceReason.unknown), ProblemKind.deviceUnknown),
        (refusal(401, DeviceReason.sessionRevoked), ProblemKind.signInRequired),
        (
          refusal(401, DeviceReason.sessionOtherDevice),
          ProblemKind.sessionOtherDevice,
        ),
        (
          refusal(403, 'password_change_required'),
          ProblemKind.passwordChangeRequired,
        ),
        (
          json(<String, Object?>{'message': 'No.'}, 403),
          ProblemKind.notAllowed,
        ),
      ]) {
        final (api, _) = await signedApi(
          recording(<http.Request>[], (_) => answer),
          keys,
        );
        await expectLater(api.listForms(), problem(kind));
        await expectLater(api.myDevice(), problem(kind));
      }
    });

    test('a refused signature is sent once more, freshly signed', () async {
      final keys = await testKeys();
      final seen = <http.Request>[];
      final (api, _) = await signedApi(
        recording(
          seen,
          (_) => seen.length == 1
              ? refusal(403, DeviceReason.signatureInvalid)
              : json(view(status: 'active')),
        ),
        keys,
      );
      expect((await api.myDevice()).status, DeviceStatus.active);
      expect(seen, hasLength(2));
      expect(
        seen[0].headers[DeviceHeaders.nonce],
        isNot(seen[1].headers[DeviceHeaders.nonce]),
      );
      for (final request in seen) {
        await expectSigned(request, keys, deviceId);
      }
    });

    test('a second refusal is not sent a third time', () async {
      final keys = await testKeys();
      final seen = <http.Request>[];
      final (api, _) = await signedApi(
        recording(seen, (_) => refusal(403, DeviceReason.signatureInvalid)),
        keys,
      );
      await expectLater(api.myDevice(), problem(ProblemKind.deviceCheckFailed));
      expect(seen, hasLength(2));
      // Other refusals are never sent again.
      seen.clear();
      final (other, _) = await signedApi(
        recording(seen, (_) => refusal(403, DeviceReason.revoked)),
        keys,
      );
      await expectLater(other.myDevice(), problem(ProblemKind.deviceRevoked));
      expect(seen, hasLength(1));
    });

    test('a device the server does not know is not sent again: the device '
        'check enrols it instead', () async {
      final keys = await testKeys();
      final seen = <http.Request>[];
      final (api, _) = await signedApi(
        recording(seen, (_) => refusal(403, DeviceReason.unknown)),
        keys,
      );
      await expectLater(api.myDevice(), problem(ProblemKind.deviceUnknown));
      expect(seen, hasLength(1));
      seen.clear();
      await expectLater(api.listForms(), problem(ProblemKind.deviceUnknown));
      // Each of its requests is sent once, none again.
      final targets = seen.map((request) => request.url.toString()).toList();
      expect(targets.toSet(), hasLength(targets.length));
      expect(isDeviceRefusal(ProblemKind.deviceUnknown), isTrue);
    });

    test('a redirect is never followed, by the SDK or a download', () async {
      final keys = await testKeys();
      final seen = <http.Request>[];
      final (api, _) = await signedApi(
        recording(
          seen,
          (request) => request.url.path == '/api/files/token'
              ? json(<String, Object?>{'token': 'file-token-1'})
              : http.Response(
                  '',
                  302,
                  headers: <String, String>{
                    'location': 'https://wifi.example.com/',
                  },
                ),
        ),
        keys,
      );
      await expectLater(api.myDevice(), problem(ProblemKind.offline));
      await expectLater(
        api.downloadXForm(
          FormVersion(
            id: 'v1',
            formRecordId: 'f1',
            version: '1',
            published: true,
            created: DateTime(2026, 11, 6),
            xformFile: 'a.xml',
          ),
        ),
        problem(ProblemKind.offline),
      );
      expect(seen.last.url.path, '/api/files/form_versions/v1/a.xml');
      expect(seen.every((r) => r.url.host == 'data.example.org'), isTrue);
    });
  });

  group('approving and switching off', () {
    test('approval sends the numbers as typed; the answer says if a second '
        'admin is needed', () async {
      final keys = await testKeys();
      final seen = <http.Request>[];
      final (api, _) = await signedApi(
        recording(seen, (_) => json(view(second: true))),
        keys,
      );
      final answer = await api.approveDevice('fielddevice0001', '২২৫ ১৪২ ৭৫৩');
      final request = seen.single;
      expect(
        request.url.path,
        '/api/obhijatra/v1/devices/fielddevice0001/approve',
      );
      expect(jsonDecode(utf8.decode(request.bodyBytes)), <String, Object?>{
        'code': '২২৫ ১৪২ ৭৫৩',
      });
      await expectSigned(request, keys, deviceId);
      expect(answer.needsSecondApproval, isTrue);
    });

    test(
      'approval refusals: wrong numbers, not allowed, not waiting',
      () async {
        final keys = await testKeys();
        for (final (answer, kind) in <(http.Response, ProblemKind)>[
          (
            json(<String, Object?>{
              'message': 'Failed.',
              'data': <String, Object?>{
                'code': <String, Object?>{
                  'code': 'validation_device_code_mismatch',
                  'message': 'The numbers do not match.',
                },
              },
            }, 400),
            ProblemKind.deviceCodeMismatch,
          ),
          (
            json(<String, Object?>{'message': 'No.'}, 403),
            ProblemKind.notAllowed,
          ),
          (
            json(<String, Object?>{'message': 'Not waiting.'}, 409),
            ProblemKind.deviceNotWaiting,
          ),
          (refusal(403, DeviceReason.expired), ProblemKind.deviceExpired),
        ]) {
          final (api, _) = await signedApi(
            recording(<http.Request>[], (_) => answer),
            keys,
          );
          await expectLater(api.approveDevice('d1', '1' * 18), problem(kind));
        }
      },
    );

    test('switching off posts to the device’s route', () async {
      final keys = await testKeys();
      final seen = <http.Request>[];
      final (api, _) = await signedApi(
        recording(seen, (_) => json(view(status: 'revoked'))),
        keys,
      );
      final answer = await api.revokeDevice('fielddevice0001');
      expect(seen.single.method, 'POST');
      expect(
        seen.single.url.path,
        '/api/obhijatra/v1/devices/fielddevice0001/revoke',
      );
      await expectSigned(seen.single, keys, deviceId);
      expect(answer.status, DeviceStatus.revoked);
    });

    test(
      'the list reads the people’s names and roles, not their records',
      () async {
        final keys = await testKeys();
        final seen = <http.Request>[];
        final (api, _) = await signedApi(
          recording(
            seen,
            (_) => json(
              listOf(<Map<String, Object?>>[
                <String, Object?>{
                  'id': 'fielddevice0001',
                  'field_user': 'f1',
                  'staff_user': '',
                  'label': 'Android phone',
                  'platform': 'android',
                  'status': 'pending',
                  'expires': '',
                  'first_approved_by': '',
                  'sign_public_key': base64.encode(keys.signPublicKey),
                  'enc_public_key': base64.encode(keys.encPublicKey),
                  'created': '2026-11-06 09:00:00.000Z',
                  'expand': <String, Object?>{
                    'field_user': <String, Object?>{'name': 'Rokeya Akter'},
                  },
                },
                <String, Object?>{
                  'id': 'admindevice0001',
                  'field_user': '',
                  'staff_user': 'u7',
                  'label': 'Mac',
                  'platform': 'macos',
                  'status': 'pending',
                  'first_approved_by': 'u3',
                  'sign_public_key': '',
                  'enc_public_key': '',
                  'expand': <String, Object?>{
                    'staff_user': <String, Object?>{
                      'name': '',
                      'email': 'shila@example.org',
                      'role': 'org_admin',
                    },
                  },
                },
              ]),
            ),
          ),
          keys,
        );
        final devices = await api.listDevices();
        final query = seen.single.url.queryParameters;
        expect(seen.single.url.path, '/api/collections/devices/records');
        expect(query['expand'], 'field_user,staff_user');
        expect(query['sort'], '-created');
        expect(query['fields'], contains('expand.field_user.name'));
        expect(query['fields'], isNot(contains('password')));
        await expectSigned(seen.single, keys, deviceId);

        final phone = devices[0];
        expect(phone.ownerKind, PersonKind.field);
        expect(phone.ownerName, 'Rokeya Akter');
        expect(phone.ownerRole, fieldOfficerRole);
        expect(phone.keysReadable, isTrue);
        final admin = devices[1];
        expect(admin.ownerKind, PersonKind.staff);
        expect(admin.ownerName, 'shila@example.org');
        expect(admin.ownerIsOrgAdmin, isTrue);
        expect(admin.needsSecondApproval, isTrue);
        expect(admin.keysReadable, isFalse);
      },
    );
  });

  test('the signer and identities never show key material', () async {
    final keys = await testKeys();
    final identity = DeviceIdentity(keys: keys, deviceId: deviceId);
    final signer = DeviceSigner()..use(identity);
    for (final text in <String>['$identity', '$signer', '$keys']) {
      expect(text, contains('redacted'));
      expect(text, isNot(contains(base64.encode(keys.signSeed))));
      expect(text, isNot(contains(deviceId)));
    }
  });
}
