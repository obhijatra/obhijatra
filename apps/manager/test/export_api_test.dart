// Downloading submissions (docs/decisions/0009-data-export.md): the
// request, its signature, streaming, refusals and "Confirm it's you".

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:obhijatra_manager/src/data/export.dart';
import 'package:obhijatra_manager/src/data/models.dart';
import 'package:obhijatra_manager/src/data/pocketbase_api.dart';
import 'package:obhijatra_manager/src/data/problem.dart';

import 'device_api_test.dart'
    show deviceId, expectSigned, json, problem, refusal, signedApi, testKeys;

const SubmissionExport november = SubmissionExport(
  formRecordId: 'form000000001',
  formId: 'household_survey',
);

/// A server that answers a download with [chunks] (or [answer]), and
/// records each request with its exact body.
MockClient exportServer(
  List<http.Request> seen, {
  List<List<int>> chunks = const <List<int>>[],
  http.Response Function(http.Request request)? answer,
  Stream<List<int>> Function()? stream,
}) => MockClient.streaming((request, body) async {
  final copy = http.Request(request.method, request.url)
    ..headers.addAll(request.headers)
    ..bodyBytes = await body.toBytes();
  seen.add(copy);
  final refused = answer?.call(copy);
  if (refused != null) {
    return http.StreamedResponse(
      Stream<List<int>>.value(refused.bodyBytes),
      refused.statusCode,
      headers: refused.headers,
    );
  }
  return http.StreamedResponse(
    stream?.call() ?? Stream<List<int>>.fromIterable(chunks),
    200,
    headers: <String, String>{
      'content-type': 'application/zip',
      'content-disposition':
          'attachment; filename="household_survey_2026-11-06.zip"',
    },
  );
});

Future<String?> download(
  PocketBaseApi api,
  List<List<int>> received, {
  SubmissionExport export = november,
  Future<void>? stop,
}) => api.downloadSubmissions(
  export,
  stop: stop,
  onChunk: (chunk) async => received.add(chunk),
);

void main() {
  group('the request', () {
    test('days are local midnights with the offset; "to" is the day after '
        'the last, so the last day is whole', () {
      final export = SubmissionExport(
        formRecordId: 'form000000001',
        formId: 'household_survey',
        firstDay: DateTime(2026, 11, 1, 15, 30),
        lastDay: DateTime(2026, 11, 30, 9),
        reviewStates: const <ReviewState>{
          ReviewState.rejected,
          ReviewState.approved,
        },
        includeMedia: false,
      );
      final body = export.toJson();
      expect(body['form'], 'form000000001');
      expect(body['from'], rfc3339WithOffset(DateTime(2026, 11)));
      expect(body['to'], rfc3339WithOffset(DateTime(2026, 12)));
      expect(body['review_states'], <String>['Approved', 'Rejected']);
      expect(body['include_media'], false);
      final pattern = RegExp(r'^\d{4}-\d\d-\d\dT00:00:00[+-]\d\d:\d\d$');
      expect(body['from'], matches(pattern));
      expect(body['to'], matches(pattern));
      // The same instants as the local midnights.
      expect(
        DateTime.parse(body['to']! as String)
            .isAtSameMomentAs(DateTime(2026, 12)),
        isTrue,
      );
    });

    test('every review state and no days: only the form and the files', () {
      expect(november.toJson(), <String, Object>{
        'form': 'form000000001',
        'include_media': true,
      });
    });

    test('the offset is written as the server reads it (RFC 3339)', () {
      final moment = DateTime(2026, 3, 9, 7, 5, 4);
      final text = rfc3339WithOffset(moment);
      expect(text, startsWith('2026-03-09T07:05:04'));
      expect(DateTime.parse(text).isAtSameMomentAs(moment), isTrue);
    });

    test('file names: as the server names them, and never a path', () {
      expect(
        suggestedExportName('household survey', DateTime(2026, 11, 6)),
        'household_survey_2026-11-06.zip',
      );
      expect(
        exportFileName('attachment; filename="household_2026-11-06.zip"'),
        'household_2026-11-06.zip',
      );
      expect(
        exportFileName('attachment; filename="../../evil.zip"'),
        isNot(contains('/')),
      );
      expect(exportFileName('attachment; filename="notes.exe"'), isNull);
      expect(exportFileName(null), isNull);
    });
  });

  group('downloading', () {
    test('posts the choices, signed by this device with the session, and '
        'hands over the file part by part', () async {
      final keys = await testKeys();
      final seen = <http.Request>[];
      final (api, _) = await signedApi(
        exportServer(
          seen,
          chunks: <List<int>>[
            <int>[0x50, 0x4B, 0x03, 0x04],
            <int>[1, 2, 3],
          ],
        ),
        keys,
      );
      final received = <List<int>>[];
      final export = SubmissionExport(
        formRecordId: 'form000000001',
        formId: 'household_survey',
        firstDay: DateTime(2026, 11),
        reviewStates: const <ReviewState>{ReviewState.approved},
      );
      final name = await download(api, received, export: export);

      expect(name, 'household_survey_2026-11-06.zip');
      expect(received, <List<int>>[
        <int>[0x50, 0x4B, 0x03, 0x04],
        <int>[1, 2, 3],
      ]);
      final request = seen.single;
      expect(request.method, 'POST');
      expect(request.url.path, exportSubmissionsPath);
      expect(request.headers['Authorization'], isNotEmpty);
      expect(request.headers['content-type'], startsWith('application/json'));
      expect(jsonDecode(utf8.decode(request.bodyBytes)), export.toJson());
      await expectSigned(request, keys, deviceId);
    });

    test('each refusal becomes its own plain problem, and nothing is '
        'written', () async {
      final keys = await testKeys();
      for (final (answer, kind) in <(http.Response, ProblemKind)>[
        (
          refusal(403, recentSignInRequiredReason),
          ProblemKind.recentSignInRequired,
        ),
        (
          json(<String, Object?>{'message': 'No.'}, 403),
          ProblemKind.notAllowed,
        ),
        (
          json(<String, Object?>{'message': 'Sign in.'}, 401),
          ProblemKind.signInRequired,
        ),
        (refusal(403, 'device_revoked'), ProblemKind.deviceRevoked),
        (
          json(<String, Object?>{
            'data': <String, Object?>{
              'form': <String, Object?>{'code': 'validation_form_not_found'},
            },
          }, 400),
          ProblemKind.formUnavailable,
        ),
        (
          json(<String, Object?>{
            'data': <String, Object?>{
              'form': <String, Object?>{
                'code': 'validation_form_has_no_version',
              },
            },
          }, 400),
          ProblemKind.exportNoVersion,
        ),
        (
          json(<String, Object?>{
            'data': <String, Object?>{
              'to': <String, Object?>{'code': 'validation_period_empty'},
            },
          }, 400),
          ProblemKind.detailsInvalid,
        ),
        (json(<String, Object?>{}, 500), ProblemKind.serverError),
      ]) {
        final received = <List<int>>[];
        final (api, _) = await signedApi(
          exportServer(<http.Request>[], answer: (_) => answer),
          keys,
        );
        await expectLater(download(api, received), problem(kind));
        expect(received, isEmpty, reason: kind.name);
      }
    });

    test('a connection that breaks off part way is "offline"', () async {
      final keys = await testKeys();
      final (api, _) = await signedApi(
        exportServer(
          <http.Request>[],
          stream: () async* {
            yield <int>[1, 2];
            throw http.ClientException('Connection reset');
          },
        ),
        keys,
      );
      await expectLater(
        download(api, <List<int>>[]),
        problem(ProblemKind.offline),
      );
    });

    test('a file that cannot be written stops the download', () async {
      final keys = await testKeys();
      final (api, _) = await signedApi(
        exportServer(
          <http.Request>[],
          chunks: <List<int>>[
            <int>[1],
          ],
        ),
        keys,
      );
      await expectLater(
        api.downloadSubmissions(
          november,
          onChunk: (_) async => throw const AppProblem(ProblemKind.saveFailed),
        ),
        problem(ProblemKind.saveFailed),
      );
    });

    test('"Stop" ends the download part way', () async {
      final keys = await testKeys();
      final parts = StreamController<List<int>>();
      final (api, _) = await signedApi(
        exportServer(<http.Request>[], stream: () => parts.stream),
        keys,
      );
      final stop = Completer<void>();
      final received = <List<int>>[];
      final result = download(api, received, stop: stop.future);
      parts.add(<int>[1]);
      await pumpEventQueue();
      stop.complete();
      await pumpEventQueue();
      parts.add(<int>[2]);
      await expectLater(result, throwsA(isA<DownloadStopped>()));
      expect(received, <List<int>>[
        <int>[1],
      ]);
      await parts.close();
    });

    test('"recent sign-in required", then signing in again with the '
        'password: the download goes through on the new session, signed by '
        'the same device', () async {
      final keys = await testKeys();
      final seen = <http.Request>[];
      var signedInAgain = false;
      final client = MockClient.streaming((request, body) async {
        final copy = http.Request(request.method, request.url)
          ..headers.addAll(request.headers)
          ..bodyBytes = await body.toBytes();
        seen.add(copy);
        if (request.url.path.endsWith('/auth-with-password')) {
          signedInAgain = true;
          final answer = json(<String, Object?>{
            'token': 'fresh-session-token',
            'record': <String, Object?>{
              'id': 'u1',
              'collectionName': 'staff_users',
              'email': 'tania@example.org',
              'role': 'org_admin',
              'active': true,
            },
          });
          return http.StreamedResponse(
            Stream<List<int>>.value(answer.bodyBytes),
            200,
            headers: answer.headers,
          );
        }
        if (!signedInAgain) {
          final answer = refusal(403, recentSignInRequiredReason);
          return http.StreamedResponse(
            Stream<List<int>>.value(answer.bodyBytes),
            403,
            headers: answer.headers,
          );
        }
        return http.StreamedResponse(
          Stream<List<int>>.value(<int>[0x50, 0x4B]),
          200,
        );
      });
      final (api, _) = await signedApi(client, keys);

      await expectLater(
        download(api, <List<int>>[]),
        problem(ProblemKind.recentSignInRequired),
      );
      final oldToken = seen.single.headers['Authorization'];

      final user = await api.signIn('tania@example.org', 'correct horse');
      expect(user.id, 'u1');
      final received = <List<int>>[];
      await download(api, received);
      expect(received, <List<int>>[
        <int>[0x50, 0x4B],
      ]);

      expect(seen, hasLength(3));
      final signIn = seen[1];
      final retry = seen[2];
      // The sign-in is signed by this device, so the new session is its own.
      await expectSigned(signIn, keys, deviceId);
      await expectSigned(retry, keys, deviceId);
      expect(retry.headers['Authorization'], 'fresh-session-token');
      expect(retry.headers['Authorization'], isNot(oldToken));
      // The password went only to the sign-in.
      expect(utf8.decode(retry.bodyBytes), isNot(contains('correct horse')));
    });
  });
}
