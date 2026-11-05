import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart' show XFile;

import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:obhijatra_manager/l10n/app_localizations.dart';
import 'package:obhijatra_manager/src/data/people.dart';
import 'package:obhijatra_manager/src/data/places.dart';
import 'package:obhijatra_manager/src/data/pocketbase_api.dart';
import 'package:obhijatra_manager/src/data/problem.dart';
import 'package:obhijatra_manager/src/state/file_picker.dart';
import 'package:obhijatra_manager/src/ui/places_import_screen.dart';

import 'support/people_fixtures.dart';

const String server = 'https://data.example.org';

http.Response json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: <String, String>{'content-type': 'application/json'},
);

/// A detailed refusal, as the server sends it.
http.Response refused(String field, String code, String message) =>
    json(<String, Object?>{
      'status': 400,
      'message': 'Failed to update record.',
      'data': <String, Object?>{
        field: <String, Object?>{'code': code, 'message': message},
      },
    }, 400);

Map<String, Object?> placeJson(Place place) => <String, Object?>{
  'id': place.id,
  'name': place.name,
  'code': place.code,
  'parent': place.parentId,
  'path': place.path,
  'closed': place.closed,
};

/// What the client sent, as JSON.
Map<String, dynamic> bodyOf(http.Request request) =>
    jsonDecode(request.body) as Map<String, dynamic>;

Future<AppProblem> problemOf(Future<Object?> Function() call) async {
  try {
    await call();
  } on AppProblem catch (problem) {
    return problem;
  }
  fail('no problem');
}

void main() {
  test('every place is read, a page at a time, with closed places', () async {
    final pages = <String>[];
    final api = PocketBaseApi(
      server,
      httpClient: MockClient((request) async {
        final url = request.url;
        expect(url.path, '/api/collections/locations/records');
        expect(
          url.queryParameters['fields'],
          'id,name,code,parent,path,closed',
        );
        pages.add(url.queryParameters['page']!);
        final perPage = int.parse(url.queryParameters['perPage']!);
        final page = int.parse(url.queryParameters['page']!);
        // 1,001 places: the first page is full, the second has the rest.
        final items = <Map<String, Object?>>[
          if (page == 1)
            for (var i = 0; i < perPage; i++)
              placeJson(
                Place(
                  id: 'p${i.toString().padLeft(14, '0')}',
                  name: 'Branch $i',
                  code: '',
                  parentId: headOffice.id,
                  path: '/x/',
                ),
              )
          else
            placeJson(
              const Place(
                id: 'closedbranch001',
                name: 'Old branch',
                code: 'OLD',
                parentId: 'northregion0001',
                path: '/a/b/c/',
                closed: true,
              ),
            ),
        ];
        return json(<String, Object?>{
          'page': page,
          'perPage': perPage,
          'totalItems': perPage + 1,
          'totalPages': 2,
          'items': items,
        });
      }),
    );
    final places = await api.listPlaces();
    expect(pages, <String>['1', '2']);
    expect(places, hasLength(501));
    expect(places.last.closed, isTrue);
    expect(places.last.code, 'OLD');
    expect(places.first.closed, isFalse);
  });

  test('adding a place sends its name, code and the place above', () async {
    late http.Request sent;
    final api = PocketBaseApi(
      server,
      httpClient: MockClient((request) async {
        sent = request;
        return json(
          placeJson(
            const Place(
              id: 'uttarabranch01',
              name: 'Uttara branch',
              code: 'UTT',
              parentId: 'northregion0001',
              path: '/headoffice00001/northregion0001/uttarabranch01/',
            ),
          ),
        );
      }),
    );
    final place = await api.createPlace(
      parentId: northRegion.id,
      name: '  Uttara\u00A0 branch\u200B ',
      code: ' UTT ',
    );
    expect(sent.method, 'POST');
    expect(sent.url.path, '/api/collections/locations/records');
    expect(bodyOf(sent), <String, dynamic>{
      'name': 'Uttara branch',
      'code': 'UTT',
      'parent': northRegion.id,
    });
    // The server makes the id and refuses one sent.
    expect(bodyOf(sent).containsKey('id'), isFalse);
    expect(place.parentId, northRegion.id);
    expect(place.code, 'UTT');
  });

  test(
    'renaming sends only what changed; nothing changed sends nothing',
    () async {
      final sent = <http.Request>[];
      final api = PocketBaseApi(
        server,
        httpClient: MockClient((request) async {
          sent.add(request);
          return json(placeJson(mirpurBranch));
        }),
      );
      await api.updatePlace(
        mirpurBranch,
        name: 'Mirpur-10 branch',
        code: 'N-MIR',
      );
      expect(sent.single.method, 'PATCH');
      expect(
        sent.single.url.path,
        '/api/collections/locations/records/${mirpurBranch.id}',
      );
      expect(bodyOf(sent.single), <String, dynamic>{
        'name': 'Mirpur-10 branch',
      });
      await api.updatePlace(mirpurBranch, name: 'Mirpur branch', code: 'MIR10');
      expect(bodyOf(sent.last), <String, dynamic>{'code': 'MIR10'});
      final unchanged = await api.updatePlace(
        mirpurBranch,
        name: ' Mirpur branch ',
        code: 'N-MIR',
      );
      expect(sent, hasLength(2));
      expect(unchanged, mirpurBranch);
    },
  );

  test('a name or code already used keeps the server\'s codes', () async {
    for (final (field, code) in <(String, String)>[
      ('name', 'validation_place_name_taken'),
      ('code', 'validation_not_unique'),
    ]) {
      final api = PocketBaseApi(
        server,
        httpClient: MockClient(
          (request) async => refused(field, code, 'Not this one.'),
        ),
      );
      final problem = await problemOf(
        () => api.createPlace(
          parentId: northRegion.id,
          name: 'Mirpur branch',
          code: 'N',
        ),
      );
      // Not mistaken for a form version uploaded twice.
      expect(problem.kind, ProblemKind.detailsInvalid);
      expect(problem.codes, <String, String>{field: code});
      expect(problem.fields, <String, String>{field: 'Not this one.'});
    }
  });

  test('closing and reopening send only "closed"; refusals keep their '
      'reasons', () async {
    final sent = <http.Request>[];
    var answer = json(placeJson(mirpurBranch));
    final api = PocketBaseApi(
      server,
      httpClient: MockClient((request) async {
        sent.add(request);
        return answer;
      }),
    );
    await api.setPlaceClosed(mirpurBranch, closed: false);
    expect(bodyOf(sent.single), <String, dynamic>{'closed': false});

    answer = refused(
      'closed',
      'validation_place_has_people',
      '3 active person(s) work here. Move them to another place, or '
          'deactivate them, first.',
    );
    final problem = await problemOf(
      () => api.setPlaceClosed(mirpurBranch, closed: true),
    );
    expect(bodyOf(sent.last), <String, dynamic>{'closed': true});
    expect(problem.kind, ProblemKind.detailsInvalid);
    expect(problem.codes['closed'], 'validation_place_has_people');
    expect(problem.fields['closed'], startsWith('3 active'));
  });

  test('deleting a place in use is refused with "Close it instead"', () async {
    late http.Request sent;
    final api = PocketBaseApi(
      server,
      httpClient: MockClient((request) async {
        sent = request;
        return json(<String, Object?>{
          'status': 400,
          'message':
              'This place is in use, so it cannot be deleted. Close it '
              'instead.',
          'data': <String, Object?>{
            'id': <String, Object?>{
              'code': 'validation_place_in_use',
              'message':
                  'This place is used by 2 place(s), people or record(s), '
                  'so it cannot be deleted. Close it instead.',
            },
          },
        }, 400);
      }),
    );
    final problem = await problemOf(() => api.deletePlace(southRegion));
    expect(sent.method, 'DELETE');
    expect(
      sent.url.path,
      '/api/collections/locations/records/${southRegion.id}',
    );
    expect(problem.kind, ProblemKind.detailsInvalid);
    expect(problem.codes, <String, String>{'id': 'validation_place_in_use'});

    final ok = PocketBaseApi(
      server,
      httpClient: MockClient((request) async => http.Response('', 204)),
    );
    await ok.deletePlace(southRegion);
  });

  group('import', () {
    const rows = <PlaceImportRow>[
      PlaceImportRow(
        line: 2,
        path: <String>['Dhaka region', 'Mirpur area', 'Mirpur-10 branch'],
        code: 'MRP10',
      ),
      PlaceImportRow(line: 3, path: <String>['Khulna region']),
    ];

    test(
      'a check sends every row with its line, and reads the answer',
      () async {
        late http.Request sent;
        final api = PocketBaseApi(
          server,
          httpClient: MockClient((request) async {
            sent = request;
            return json(<String, Object?>{
              'created': 4,
              'existing': 1,
              'problems': <Object?>[],
              'saved': false,
            });
          }),
        );
        final result = await api.importPlaces(
          parentId: headOffice.id,
          rows: rows,
          dryRun: true,
        );
        expect(sent.method, 'POST');
        expect(sent.url.path, '/api/obhijatra/v1/places/import');
        expect(bodyOf(sent), <String, dynamic>{
          'parent': headOffice.id,
          'rows': <Map<String, dynamic>>[
            <String, dynamic>{
              'line': 2,
              'path': <String>[
                'Dhaka region',
                'Mirpur area',
                'Mirpur-10 branch',
              ],
              'code': 'MRP10',
            },
            <String, dynamic>{
              'line': 3,
              'path': <String>['Khulna region'],
              'code': '',
            },
          ],
          'dry_run': true,
        });
        expect(result.created, 4);
        expect(result.existing, 1);
        expect(result.problems, isEmpty);
        expect(result.saved, isFalse);
      },
    );

    test('problems come back as an answer, from a check (200) or a real '
        'import (400)', () async {
      for (final status in <int>[200, 400]) {
        final api = PocketBaseApi(
          server,
          httpClient: MockClient(
            (request) async => json(<String, Object?>{
              'created': 2,
              'existing': 0,
              'problems': <Object?>[
                <String, Object?>{
                  'line': 3,
                  'code': 'place_closed',
                  'message':
                      '"Khulna region" is closed. Reopen it first, '
                      'or remove this row.',
                  'name': 'Khulna region',
                },
                // An older server sends no code.
                <String, Object?>{'line': 4, 'message': 'Something else.'},
              ],
              'saved': false,
            }, status),
          ),
        );
        final result = await api.importPlaces(
          parentId: headOffice.id,
          rows: rows,
          dryRun: status == 200,
        );
        expect(result.saved, isFalse);
        final closed = result.problems.first;
        expect(closed.line, 3);
        expect(closed.code, 'place_closed');
        expect(closed.name, 'Khulna region');
        expect(closed.value, isEmpty);
        expect(closed.message, contains('is closed'));
        final older = result.problems.last;
        expect((older.line, older.code, older.name), (4, '', ''));
      }
    });

    test('a closed place to import into is a refusal under "parent"', () async {
      final api = PocketBaseApi(
        server,
        httpClient: MockClient(
          (request) async => json(<String, Object?>{
            'status': 400,
            'message': 'The import could not start.',
            'data': <String, Object?>{
              'parent': <String, Object?>{
                'code': 'validation_place_closed',
                'message': 'This place is closed. Choose an open place.',
              },
            },
          }, 400),
        ),
      );
      final problem = await problemOf(
        () => api.importPlaces(
          parentId: southRegion.id,
          rows: rows,
          dryRun: true,
        ),
      );
      expect(problem.kind, ProblemKind.detailsInvalid);
      expect(problem.codes, <String, String>{
        'parent': 'validation_place_closed',
      });
    });

    test('someone who is not an organisation admin is refused', () async {
      final api = PocketBaseApi(
        server,
        httpClient: MockClient(
          (request) async => json(<String, Object?>{
            'status': 403,
            'message': 'Only an organisation admin can add places.',
            'data': <String, Object?>{},
          }, 403),
        ),
      );
      final problem = await problemOf(
        () =>
            api.importPlaces(parentId: headOffice.id, rows: rows, dryRun: true),
      );
      expect(problem.kind, ProblemKind.notAllowed);
    });
  });

  test('problems with rows are worded by their code, using the place and '
      'value; unknown codes keep the server\'s sentence', () {
    PlaceImportProblem problem(
      String code, {
      String name = '',
      String value = '',
      String message = 'The server says so.',
    }) => PlaceImportProblem(
      line: 2,
      code: code,
      name: name,
      value: value,
      message: message,
    );
    for (final lang in <String>['en', 'bn']) {
      final l10n = lookupAppLocalizations(Locale(lang));
      final cases = <PlaceImportProblem, String>{
        problem('no_name'): l10n.importProblemNoName,
        problem('too_deep', value: '10'): l10n.importProblemTooDeep(10),
        problem('too_deep', value: 'many'): l10n.importRowTooDeep,
        problem('code_too_long', value: 'C' * 51): l10n.importRowCodeTooLong,
        problem('name_too_long', name: 'x' * 201): l10n.importRowNameTooLong,
        problem('place_closed', name: 'Old "Bazar" branch'): l10n
            .importServerClosed('Old "Bazar" branch'),
        problem('code_mismatch', name: 'Mirpur branch', value: 'N-MIR'): l10n
            .importServerCodeOther('Mirpur branch', 'N-MIR'),
        problem('code_repeated', value: 'ঢাকা-১'): l10n.importServerCodeTwice(
          'ঢাকা-১',
        ),
        problem('code_taken', value: 'N'): l10n.importServerCodeTaken('N'),
        problem('unsafe_text', name: 'Dhaka\u202Eregion'): l10n
            .importServerUnsafeName('Dhaka\uFFFDregion'),
        problem('unsafe_text', value: 'D\t1'): l10n.importServerUnsafeCode(
          'D\uFFFD1',
        ),
        problem('unsafe_text'): 'The server says so.',
        // Without the place or value it needs, or with a code the app does
        // not know, the server's own sentence.
        problem('place_closed'): 'The server says so.',
        problem('something_new'): 'The server says so.',
        problem(''): 'The server says so.',
        problem('something_new', message: ''): l10n.problemRejected,
      };
      for (final MapEntry(key: given, value: expected) in cases.entries) {
        expect(
          importProblemText(l10n, given),
          expected,
          reason: '$lang ${given.code}',
        );
      }
    }
  });

  test(
    'a spreadsheet bigger than allowed is refused without being read',
    () async {
      final big = await readPickedFile(
        _SizedFile(maxImportBytes + 1),
        maxBytes: maxImportBytes,
      );
      expect(big.tooLarge, isTrue);
      expect(big.bytes, isEmpty);
      expect(big.name, 'places.csv');
      final small = await readPickedFile(
        XFile.fromData(
          Uint8List.fromList(<int>[65, 10]),
          name: 'places.csv',
          path: 'places.csv',
        ),
        maxBytes: maxImportBytes,
      );
      expect(small.tooLarge, isFalse);
      expect(small.bytes, <int>[65, 10]);
    },
  );
}

/// A file that says how big it is and fails the test if it is read.
class _SizedFile extends XFile {
  _SizedFile(this.size)
    : super.fromData(Uint8List(0), name: 'places.csv', path: 'places.csv');

  final int size;

  @override
  Future<int> length() async => size;

  @override
  Future<Uint8List> readAsBytes() => fail('the file was read');
}
