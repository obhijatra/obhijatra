import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:obhijatra_manager/src/data/models.dart';
import 'package:obhijatra_manager/src/data/pocketbase_api.dart';
import 'package:obhijatra_manager/src/data/problem.dart';
import 'package:pocketbase/pocketbase.dart';

import 'support/fixtures.dart';

http.Response json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: <String, String>{'content-type': 'application/json'},
);

Map<String, Object?> submissionJson({bool withComment = true}) =>
    <String, Object?>{
      'id': 's1',
      'collectionName': 'submissions',
      'instance_id': 'uuid:1',
      'form': 'f1',
      'form_version': 'v2',
      'location_path': '/loc00000000000a/',
      'received_at': '2026-11-04 10:32:00.000Z',
      'review_state': 'HasIssues',
      if (withComment) 'review_comment': 'Check household members',
      'expand': <String, Object?>{
        'form': <String, Object?>{
          'id': 'f1',
          'title': 'Household visit',
          'form_id': 'household_visit',
        },
        'submitted_by': <String, Object?>{
          'id': 'fu1',
          'name': 'Nasrin Sultana',
          'email': 'n@example.org',
        },
      },
    };

void main() {
  group('problem mapping', () {
    AppProblem map(
      int status, [
      Map<String, dynamic> response = const <String, dynamic>{},
    ]) => problemFrom(ClientException(statusCode: status, response: response));

    test('every status has a plain kind and one action', () {
      expect(map(0).kind, ProblemKind.offline);
      expect(map(401).kind, ProblemKind.signInRequired);
      expect(map(401).action, ProblemAction.signInAgain);
      expect(map(403).kind, ProblemKind.notAllowed);
      expect(map(404).kind, ProblemKind.notFound);
      expect(map(413).kind, ProblemKind.tooLarge);
      expect(map(429).kind, ProblemKind.serverBusy);
      expect(map(400).kind, ProblemKind.rejected);
      expect(map(500).kind, ProblemKind.serverError);
      expect(map(503).kind, ProblemKind.serverError);
      expect(map(418).kind, ProblemKind.unknown);
      expect(
        map(400, <String, dynamic>{
          'data': <String, dynamic>{
            'version': <String, dynamic>{'code': 'validation_not_unique'},
          },
        }).kind,
        ProblemKind.versionExists,
      );
    });

    test('time-outs, aborts and odd errors are mapped too', () {
      expect(problemFrom(TimeoutException('slow')).kind, ProblemKind.timeout);
      expect(
        problemFrom(ClientException(isAbort: true)).kind,
        ProblemKind.offline,
      );
      expect(
        problemFrom(const FormatException('x')).kind,
        ProblemKind.unreadableFile,
      );
      expect(problemFrom(StateError('x')).kind, ProblemKind.unknown);
    });

    test('every kind has an action', () {
      for (final kind in ProblemKind.values) {
        expect(AppProblem(kind).action, isA<ProblemAction>());
      }
    });
  });

  group('PocketBaseApi', () {
    test('signs in a staff user and keeps the session in memory', () async {
      late http.Request seen;
      final api = PocketBaseApi(
        'https://data.example.org',
        httpClient: MockClient((request) async {
          seen = request;
          return json(<String, Object?>{
            'token': 'eyJhbGciOiJIUzI1NiJ9.eyJleHAiOjk5OTk5OTk5OTl9.sig',
            'record': <String, Object?>{
              'id': 'u1',
              'collectionName': 'staff_users',
              'name': 'Tania Rahman',
              'email': 'tania@example.org',
              'role': 'org_admin',
            },
          });
        }),
      );
      final user = await api.signIn(' tania@example.org ', 'a-long-password');
      expect(seen.url.path, '/api/collections/staff_users/auth-with-password');
      expect(
        jsonDecode(seen.body),
        containsPair('identity', 'tania@example.org'),
      );
      expect(user.isOrgAdmin, isTrue);
      expect(api.currentUser?.displayName, 'Tania Rahman');
      api.signOut();
      expect(api.currentUser, isNull);
    });

    test('a refused sign-in is one plain problem', () async {
      final api = PocketBaseApi(
        'https://data.example.org',
        httpClient: MockClient(
          (request) async => json(<String, Object?>{
            'message': 'Failed to authenticate.',
          }, 400),
        ),
      );
      await expectLater(
        api.signIn('a@b.c', 'x'),
        throwsA(
          isA<AppProblem>().having(
            (p) => p.kind,
            'kind',
            ProblemKind.signInFailed,
          ),
        ),
      );
    });

    test('a network failure is "offline"', () async {
      final api = PocketBaseApi(
        'https://data.example.org',
        httpClient: MockClient(
          (request) async => throw http.ClientException('no route'),
        ),
      );
      await expectLater(
        api.listForms(),
        throwsA(
          isA<AppProblem>().having((p) => p.kind, 'kind', ProblemKind.offline),
        ),
      );
    });

    test(
      'submissions are asked for 50 at a time, newest first, with every filter',
      () async {
        late Uri url;
        final api = PocketBaseApi(
          'https://data.example.org',
          httpClient: MockClient((request) async {
            url = request.url;
            return json(<String, Object?>{
              'page': 3,
              'perPage': 50,
              'totalItems': 120,
              'totalPages': 3,
              'items': <Object?>[submissionJson()],
            });
          }),
        );
        final page = await api.listSubmissions(
          SubmissionQuery(
            formRecordId: 'f1',
            from: DateTime.utc(2026, 11),
            to: DateTime.utc(2026, 11, 5),
            state: ReviewState.hasIssues,
            page: 3,
          ),
        );
        final q = url.queryParameters;
        expect(url.path, '/api/collections/submissions/records');
        expect(q['page'], '3');
        expect(q['perPage'], '50');
        expect(q['sort'], '-received_at');
        expect(q['expand'], 'form,submitted_by');
        expect(q['filter'], contains('form = "f1"'));
        expect(q['filter'], contains('received_at >= '));
        expect(q['filter'], contains('received_at < '));
        expect(q['filter'], contains('review_state = "HasIssues"'));
        expect(page.totalItems, 120);
        final row = page.items.single;
        expect(row.formTitle, 'Household visit');
        expect(row.collector, 'Nasrin Sultana');
        expect(row.state, ReviewState.hasIssues);
        expect(row.comment, 'Check household members');
        expect(row.commentSupported, isTrue);
      },
    );

    test('filter values are bound, not pasted into the query', () async {
      late Uri url;
      final api = PocketBaseApi(
        'https://data.example.org',
        httpClient: MockClient((request) async {
          url = request.url;
          return json(<String, Object?>{
            'page': 1,
            'perPage': 50,
            'totalItems': 0,
            'totalPages': 0,
            'items': <Object?>[],
          });
        }),
      );
      await api.listSubmissions(
        const SubmissionQuery(formRecordId: 'x" || 1=1 || "'),
      );
      expect(url.queryParameters['filter'], contains(r'"x\" || 1=1 || \""'));
    });

    test('review: sends the state and the note, and reports a server that cannot keep notes', () async {
      late http.Request seen;
      var withComment = true;
      final api = PocketBaseApi(
        'https://data.example.org',
        httpClient: MockClient((request) async {
          seen = request;
          return json(submissionJson(withComment: withComment));
        }),
      );
      final saved = await api.setReview(
        row(1),
        ReviewState.hasIssues,
        comment: 'Check household members',
      );
      expect(seen.method, 'PATCH');
      expect(jsonDecode(seen.body), <String, Object?>{
        'review_state': 'HasIssues',
        'review_comment': 'Check household members',
      });
      expect(saved.state, ReviewState.hasIssues);

      withComment = false;
      await expectLater(
        api.setReview(
          row(1, commentSupported: false),
          ReviewState.rejected,
          comment: 'Duplicate',
        ),
        throwsA(
          isA<AppProblem>().having(
            (p) => p.kind,
            'kind',
            ProblemKind.commentNotSaved,
          ),
        ),
      );
    });

    test('approving sends only the state to a server without notes', () async {
      late http.Request seen;
      final api = PocketBaseApi(
        'https://data.example.org',
        httpClient: MockClient((request) async {
          seen = request;
          return json(submissionJson(withComment: false));
        }),
      );
      await api.setReview(
        row(1, commentSupported: false),
        ReviewState.approved,
      );
      expect(jsonDecode(seen.body), <String, Object?>{
        'review_state': 'Approved',
      });
    });

    test('forms and versions are joined', () async {
      final api = PocketBaseApi(
        'https://data.example.org',
        httpClient: MockClient((request) async {
          final isForms = request.url.path.endsWith('/forms/records');
          return json(<String, Object?>{
            'page': 1,
            'perPage': 500,
            'totalItems': 1,
            'totalPages': 1,
            'items': isForms
                ? <Object?>[
                    <String, Object?>{
                      'id': 'f1',
                      'form_id': 'household_visit',
                      'title': 'Household visit',
                    },
                  ]
                : <Object?>[
                    <String, Object?>{
                      'id': 'v2',
                      'form': 'f1',
                      'version': '2',
                      'published': true,
                      'created': '2026-10-12 08:00:00.000Z',
                      'published_at': '2026-10-12 09:00:00.000Z',
                      'xform': 'x.xml',
                    },
                  ],
          });
        }),
      );
      final forms = await api.listForms();
      expect(forms.single.displayTitle, 'Household visit');
      expect(forms.single.latestPublished!.version, '2');
    });
  });
}
