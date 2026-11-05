import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:obhijatra_manager/src/data/one_time_password.dart';
import 'package:obhijatra_manager/src/data/people.dart';
import 'package:obhijatra_manager/src/data/pocketbase_api.dart';
import 'package:obhijatra_manager/src/data/problem.dart';
import 'package:pocketbase/pocketbase.dart';

import 'support/people_fixtures.dart';

const String server = 'https://data.example.org';
const String token = 'eyJhbGciOiJIUzI1NiJ9.eyJleHAiOjk5OTk5OTk5OTl9.sig';

http.Response json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: <String, String>{'content-type': 'application/json'},
);

Map<String, Object?> listOf(
  List<Map<String, Object?>> items, {
  int page = 1,
  int total = -1,
}) => <String, Object?>{
  'page': page,
  'perPage': 50,
  'totalItems': total < 0 ? items.length : total,
  'totalPages': total < 0 ? 1 : (total / 50).ceil(),
  'items': items,
};

Map<String, Object?> personJson({
  String id = 'f1',
  String collection = 'field_users',
  String role = 'field_officer',
  bool mustChange = false,
}) => <String, Object?>{
  'id': id,
  'collectionName': collection,
  'name': 'Nasrin Sultana',
  'email': 'nasrin@example.org',
  'verified': true,
  'phone': '+8801712345678',
  'role': role,
  'location': mirpurBranch.id,
  'location_path': mirpurBranch.path,
  'active': true,
  'must_change_password': mustChange,
  'created': '2026-11-01 08:00:00.000Z',
};

/// A detailed refusal, as the server sends it.
http.Response refused(String field, String code, String message) =>
    json(<String, Object?>{
      'status': 400,
      'message': 'Failed to create record.',
      'data': <String, Object?>{
        field: <String, Object?>{'code': code, 'message': message},
      },
    }, 400);

Matcher problem(ProblemKind kind) =>
    throwsA(isA<AppProblem>().having((p) => p.kind, 'kind', kind));

/// A predictable source that records what it was asked for.
class RecordingRandom implements Random {
  RecordingRandom(this.values);

  final List<int> values;
  final List<int> asked = <int>[];
  int _next = 0;

  @override
  int nextInt(int max) {
    asked.add(max);
    return values[_next++ % values.length] % max;
  }

  @override
  bool nextBool() => throw UnimplementedError();

  @override
  double nextDouble() => throw UnimplementedError();
}

void main() {
  group('one-time passwords', () {
    test('12 characters in three groups, from the injected source', () {
      final random = RecordingRandom(<int>[
        0,
        1,
        2,
        3,
        4,
        5,
        6,
        7,
        8,
        9,
        10,
        30,
      ]);
      final password = newOneTimePassword(random);
      expect(password, 'abcd-efgh-jkm9');
      expect(password.length, 14);
      expect(random.asked, List<int>.filled(12, 31));
    });

    test('only unambiguous lower-case letters and digits', () {
      expect(oneTimePasswordAlphabet.length, 31);
      for (final confusing in <String>['0', 'o', '1', 'l', 'i']) {
        expect(oneTimePasswordAlphabet, isNot(contains(confusing)));
      }
      final shape = RegExp(
        '^[$oneTimePasswordAlphabet]{4}-[$oneTimePasswordAlphabet]{4}-'
        '[$oneTimePasswordAlphabet]{4}\$',
      );
      final random = Random(7);
      final seen = <String>{};
      for (var i = 0; i < 500; i++) {
        final password = newOneTimePassword(random);
        expect(password, matches(shape));
        seen.add(password);
      }
      expect(seen.length, 500, reason: 'no repeats in 500');
    });

    test('works with the secure source the app uses', () {
      final password = newOneTimePassword(Random.secure());
      expect(password.length, 14);
      expect(newOneTimePassword(Random.secure()), isNot(password));
    });

    test('a hidden password is long and never the one-time shape', () {
      final hidden = newHiddenPassword(Random.secure());
      expect(hidden.length, 48);
      expect(hidden, isNot(contains('-')));
    });
  });

  group('places', () {
    test('are listed as a tree, by name, with the names above them', () {
      final directory = PlaceDirectory(samplePlaces);
      expect(directory.ordered.map((p) => p.name), <String>[
        'Head office',
        'North region',
        'Mirpur branch',
        'South region',
      ]);
      expect(directory.depthOf(mirpurBranch), 2);
      expect(directory.trail(mirpurBranch), <String>[
        'Head office',
        'North region',
        'Mirpur branch',
      ]);
      expect(directory.nameAt(southRegion.path), 'South region');
      expect(directory.byId(northRegion.id), northRegion);
    });

    test('are read from the server', () async {
      late Uri url;
      final api = PocketBaseApi(
        server,
        httpClient: MockClient((request) async {
          url = request.url;
          return json(
            listOf(<Map<String, Object?>>[
              <String, Object?>{
                'id': mirpurBranch.id,
                'name': 'Mirpur branch',
                'code': 'N-MIR',
                'parent': northRegion.id,
                'path': mirpurBranch.path,
              },
            ]),
          );
        }),
      );
      final places = await api.listPlaces();
      expect(url.path, '/api/collections/locations/records');
      expect(places.single.parentId, northRegion.id);
      expect(places.single.path, mirpurBranch.path);
    });
  });

  group('listing people', () {
    test('asks for one page of one kind, with every filter', () async {
      final seen = <Uri>[];
      final api = PocketBaseApi(
        server,
        httpClient: MockClient((request) async {
          seen.add(request.url);
          return json(
            listOf(<Map<String, Object?>>[personJson()], page: 2, total: 51),
          );
        }),
      );
      final page = await api.listPeople(
        PeopleQuery(
          kind: PersonKind.field,
          search: '01712 345678',
          status: PeopleStatus.active,
          placePath: northRegion.path,
          sort: PeopleSort.name,
          page: 2,
        ),
      );
      final url = seen.single;
      expect(url.path, '/api/collections/field_users/records');
      expect(url.queryParameters['page'], '2');
      expect(url.queryParameters['perPage'], '50');
      expect(url.queryParameters['sort'], 'name,-created');
      final filter = url.queryParameters['filter']!;
      // The digits typed are looked for in the stored +880 numbers.
      expect(filter, contains('name ~ "01712 345678"'));
      expect(filter, contains('phone ~ "01712345678"'));
      expect(filter, contains('active = true'));
      expect(filter, contains('location_path ~ "${northRegion.path}"'));
      expect(page.totalItems, 51);
      expect(page.totalPages, 2);
      final nasrin = page.items.single;
      expect(nasrin.kind, PersonKind.field);
      expect(nasrin.verified, isTrue);
      expect(nasrin.locationPath, mirpurBranch.path);
    });

    test('newest first and no filter by default', () async {
      late Uri url;
      final api = PocketBaseApi(
        server,
        httpClient: MockClient((request) async {
          url = request.url;
          return json(listOf(<Map<String, Object?>>[]));
        }),
      );
      await api.listPeople(const PeopleQuery());
      expect(url.path, '/api/collections/staff_users/records');
      expect(url.queryParameters['sort'], '-created');
      expect(url.queryParameters.containsKey('filter'), isFalse);
    });

    test('"Locked" asks for the locks in force first', () async {
      final seen = <Uri>[];
      final api = PocketBaseApi(
        server,
        httpClient: MockClient((request) async {
          seen.add(request.url);
          if (request.url.path.contains('login_locks')) {
            return json(
              listOf(<Map<String, Object?>>[
                <String, Object?>{'id': 'l1', 'account_id': 's2'},
                <String, Object?>{'id': 'l2', 'account_id': 's2'},
                <String, Object?>{'id': 'l3', 'account_id': 's9'},
              ]),
            );
          }
          return json(listOf(<Map<String, Object?>>[]));
        }),
      );
      await api.listPeople(const PeopleQuery(status: PeopleStatus.locked));
      final locks = seen.first.queryParameters['filter']!;
      expect(locks, contains('account_collection = "staff_users"'));
      expect(locks, contains('unlocked = false'));
      // The server's clock decides, not this computer's.
      expect(locks, contains('locked_until > @now'));
      final people = seen.last.queryParameters['filter']!;
      expect(people, contains('(id = "s2" || id = "s9")'));
    });

    test('"Locked" with nobody locked asks for nobody', () async {
      final seen = <Uri>[];
      final api = PocketBaseApi(
        server,
        httpClient: MockClient((request) async {
          seen.add(request.url);
          return json(listOf(<Map<String, Object?>>[]));
        }),
      );
      final page = await api.listPeople(
        const PeopleQuery(status: PeopleStatus.locked),
      );
      expect(seen, hasLength(1));
      expect(page.items, isEmpty);
    });

    test('locks for a set of accounts', () async {
      late Uri url;
      final api = PocketBaseApi(
        server,
        httpClient: MockClient((request) async {
          url = request.url;
          return json(
            listOf(<Map<String, Object?>>[
              <String, Object?>{
                'id': 'l1',
                'account_collection': 'staff_users',
                'account_id': 's2',
                'ip': '',
                'failed_attempts': 30,
                'locked_until': '2026-11-06 10:15:00.000Z',
              },
            ]),
          );
        }),
      );
      expect(await api.activeLocks(PersonKind.staff, <String>[]), isEmpty);
      final locks = await api.activeLocks(PersonKind.staff, <String>[
        's2',
        's3',
      ]);
      expect(url.path, '/api/collections/login_locks/records');
      expect(
        url.queryParameters['filter'],
        allOf(
          contains('locked_until > @now'),
          contains('(account_id = "s2" || account_id = "s3")'),
        ),
      );
      expect(locks.single.accountId, 's2');
      expect(locks.single.ip, isEmpty);
      expect(locks.single.failedAttempts, 30);
      expect(
        locks.single.lockedUntil.toUtc(),
        DateTime.utc(2026, 11, 6, 10, 15),
      );
    });

    test('unlocking sends only "unlocked"', () async {
      late http.Request seen;
      final api = PocketBaseApi(
        server,
        httpClient: MockClient((request) async {
          seen = request;
          return json(<String, Object?>{'id': 'l1', 'unlocked': true});
        }),
      );
      await api.unlockSignIn(karimLock);
      expect(seen.method, 'PATCH');
      expect(seen.url.path, '/api/collections/login_locks/records/lock1');
      expect(jsonDecode(seen.body), <String, Object?>{'unlocked': true});
    });

    test('counts the active organisation admins', () async {
      late Uri url;
      final api = PocketBaseApi(
        server,
        httpClient: MockClient((request) async {
          url = request.url;
          return json(listOf(<Map<String, Object?>>[], total: 1));
        }),
      );
      expect(await api.countActiveOrgAdmins(), 1);
      expect(
        url.queryParameters['filter'],
        'role = "org_admin" && active = true',
      );
    });
  });

  group('changing people', () {
    test('adds a person with a one-time password', () async {
      late http.Request seen;
      final api = PocketBaseApi(
        server,
        httpClient: MockClient((request) async {
          seen = request;
          return json(personJson(mustChange: true));
        }),
      );
      final person = await api.createPerson(
        PersonKind.field,
        PersonDraft(
          name: 'Nasrin Sultana',
          role: fieldOfficerRole,
          locationId: mirpurBranch.id,
          email: 'nasrin@example.org',
          verified: true,
          phone: '+8801712345678',
        ),
        password: 'kfmw-tqzp-hrvx',
        oneTimePassword: true,
      );
      expect(seen.method, 'POST');
      expect(seen.url.path, '/api/collections/field_users/records');
      expect(jsonDecode(seen.body), <String, Object?>{
        'name': 'Nasrin Sultana',
        'role': 'field_officer',
        'location': mirpurBranch.id,
        'email': 'nasrin@example.org',
        'verified': true,
        'phone': '+8801712345678',
        'active': true,
        'password': 'kfmw-tqzp-hrvx',
        'passwordConfirm': 'kfmw-tqzp-hrvx',
        'must_change_password': true,
      });
      expect(person.mustChangePassword, isTrue);
    });

    test('an address nobody typed is never marked confirmed', () {
      final draft = PersonDraft(
        name: 'Karim',
        role: 'supervisor',
        locationId: mirpurBranch.id,
        email: '',
        verified: true,
        phone: '+8801711111111',
      );
      expect(draft.toJson()['verified'], isFalse);
    });

    test('saving sends only what changed', () async {
      late http.Request seen;
      final api = PocketBaseApi(
        server,
        httpClient: MockClient((request) async {
          seen = request;
          return json(personJson(id: 's2', collection: 'staff_users'));
        }),
      );
      await api.updatePerson(
        karim,
        PersonDraft(
          name: karim.name,
          role: 'branch_manager',
          locationId: karim.locationId,
          email: karim.email,
          verified: false,
          phone: '',
        ),
      );
      expect(seen.method, 'PATCH');
      expect(seen.url.path, '/api/collections/staff_users/records/s2');
      expect(jsonDecode(seen.body), <String, Object?>{
        'role': 'branch_manager',
        'phone': '',
      });
    });

    test('switching off and a new one-time password', () async {
      final bodies = <Object?>[];
      final api = PocketBaseApi(
        server,
        httpClient: MockClient((request) async {
          bodies.add(jsonDecode(request.body));
          return json(personJson(id: 's2', collection: 'staff_users'));
        }),
      );
      await api.setPersonActive(karim, active: false);
      await api.resetOneTimePassword(karim, 'abcd-efgh-jkmn');
      expect(bodies, <Object?>[
        <String, Object?>{'active': false},
        <String, Object?>{
          'password': 'abcd-efgh-jkmn',
          'passwordConfirm': 'abcd-efgh-jkmn',
          'must_change_password': true,
        },
      ]);
    });

    test('refused fields keep the server\'s codes and messages', () async {
      final api = PocketBaseApi(
        server,
        httpClient: MockClient(
          (request) async => refused(
            'role',
            'validation_last_org_admin',
            'This is the only active organisation admin. Make someone else '
                'an organisation admin first.',
          ),
        ),
      );
      try {
        await api.setPersonActive(tania, active: false);
        fail('no problem');
      } on AppProblem catch (problem) {
        expect(problem.kind, ProblemKind.detailsInvalid);
        expect(problem.codes, <String, String>{
          'role': 'validation_last_org_admin',
        });
        expect(problem.fields['role'], startsWith('This is the only'));
      }
    });

    test('a 400 without fields is an ordinary refusal', () async {
      final api = PocketBaseApi(
        server,
        httpClient: MockClient(
          (request) async =>
              json(<String, Object?>{'message': 'Failed.', 'data': {}}, 400),
        ),
      );
      expect(
        api.updatePerson(karim, PersonDraft.of(karim).copyWithName('Karim H')),
        problem(ProblemKind.rejected),
      );
    });
  });

  test(
    'a change someone else made meanwhile (409) asks for a reload',
    () async {
      final api = PocketBaseApi(
        server,
        httpClient: MockClient(
          (request) async => json(<String, Object?>{
            'status': 409,
            'message':
                'Someone changed this person a moment ago. Reload, then make '
                'your change again.',
            'data': <String, Object?>{},
          }, 409),
        ),
      );
      final draft = PersonDraft.of(karim);
      for (final change in <Future<Object?> Function()>[
        () => api.createPerson(
          PersonKind.staff,
          draft,
          password: 'kfmw-tqzp-hrvx',
          oneTimePassword: true,
        ),
        () => api.updatePerson(karim, draft.copyWithName('Karim H')),
        () => api.resetOneTimePassword(karim, 'kfmw-tqzp-hrvx'),
        () => api.setPersonActive(karim, active: false),
      ]) {
        try {
          await change();
          fail('no problem');
        } on AppProblem catch (problem) {
          expect(problem.kind, ProblemKind.personChanged);
          expect(problem.action, ProblemAction.reload);
        }
      }
    },
  );

  group('one-time password gate', () {
    test('403 with the reason opens the "choose a password" step', () {
      final gate = problemFrom(
        ClientException(
          statusCode: 403,
          response: <String, dynamic>{
            'data': <String, dynamic>{
              'reason': <String, dynamic>{
                'code': 'password_change_required',
                'message': 'Choose a new password before you continue.',
              },
            },
          },
        ),
      );
      expect(gate.kind, ProblemKind.passwordChangeRequired);
      expect(
        problemFrom(ClientException(statusCode: 403)).kind,
        ProblemKind.notAllowed,
      );
    });

    PocketBaseApi signedIn(
      Future<http.Response> Function(http.Request request) handler,
    ) => PocketBaseApi(
      server,
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/auth-with-password')) {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          if (body['password'] == 'kfmw-tqzp-hrvx' ||
              body['password'] == 'three green mangoes') {
            return json(<String, Object?>{
              'token': token,
              'record': <String, Object?>{
                'id': 'u7',
                'collectionName': 'staff_users',
                'name': 'Shila Das',
                'email': 'shila@example.org',
                'role': 'supervisor',
                'active': true,
                'must_change_password': body['password'] == 'kfmw-tqzp-hrvx',
              },
            });
          }
          return json(<String, Object?>{'message': 'Sign-in failed.'}, 400);
        }
        return handler(request);
      }),
    );

    test('sign-in says when a one-time password must be replaced', () async {
      final api = signedIn((request) async => json(<String, Object?>{}));
      final user = await api.signIn('shila@example.org', 'kfmw-tqzp-hrvx');
      expect(user.mustChangePassword, isTrue);
      expect(user.canManagePeople, isFalse);
    });

    test('choosing a password changes only the password, then signs in '
        'again with it', () async {
      final seen = <http.Request>[];
      final api = signedIn((request) async {
        seen.add(request);
        return json(<String, Object?>{
          'id': 'u7',
          'collectionName': 'staff_users',
          'email': 'shila@example.org',
          'must_change_password': false,
        });
      });
      await api.signIn('shila@example.org', 'kfmw-tqzp-hrvx');
      final user = await api.chooseNewPassword(
        currentPassword: 'kfmw-tqzp-hrvx',
        newPassword: 'three green mangoes',
      );
      final change = seen.single;
      expect(change.method, 'PATCH');
      expect(change.url.path, '/api/collections/staff_users/records/u7');
      expect(jsonDecode(change.body), <String, Object?>{
        'oldPassword': 'kfmw-tqzp-hrvx',
        'password': 'three green mangoes',
        'passwordConfirm': 'three green mangoes',
      });
      expect(user.mustChangePassword, isFalse);
      expect(api.currentUser?.mustChangePassword, isFalse);
    });

    test('a wrong one-time password is a field problem', () async {
      final api = signedIn(
        (request) async => refused(
          'oldPassword',
          'validation_invalid_old_password',
          'Missing or invalid old password.',
        ),
      );
      await api.signIn('shila@example.org', 'kfmw-tqzp-hrvx');
      try {
        await api.chooseNewPassword(
          currentPassword: 'wrong-wrong-wrong',
          newPassword: 'three green mangoes',
        );
        fail('no problem');
      } on AppProblem catch (problem) {
        expect(problem.kind, ProblemKind.detailsInvalid);
        expect(problem.codes['oldPassword'], 'validation_invalid_old_password');
      }
      expect(api.currentUser, isNotNull);
    });

    test('when signing in again fails, the session is gone', () async {
      final api = PocketBaseApi(
        server,
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/auth-with-password')) {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            if (body['password'] != 'kfmw-tqzp-hrvx') {
              return json(<String, Object?>{'message': 'Busy.'}, 503);
            }
            return json(<String, Object?>{
              'token': token,
              'record': <String, Object?>{
                'id': 'u7',
                'collectionName': 'staff_users',
                'email': 'shila@example.org',
                'role': 'supervisor',
                'must_change_password': true,
              },
            });
          }
          return json(<String, Object?>{'id': 'u7'});
        }),
      );
      await api.signIn('shila@example.org', 'kfmw-tqzp-hrvx');
      await expectLater(
        api.chooseNewPassword(
          currentPassword: 'kfmw-tqzp-hrvx',
          newPassword: 'three green mangoes',
        ),
        problem(ProblemKind.passwordSavedSignIn),
      );
      expect(api.currentUser, isNull);
    });
  });
}

extension on PersonDraft {
  PersonDraft copyWithName(String name) => PersonDraft(
    name: name,
    role: role,
    locationId: locationId,
    email: email,
    verified: verified,
    phone: phone,
  );
}
