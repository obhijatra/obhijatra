import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:obhijatra_manager/src/data/csv.dart';
import 'package:obhijatra_manager/src/data/people.dart';
import 'package:obhijatra_manager/src/data/places.dart';

import 'support/people_fixtures.dart';

/// The fields of every row.
List<List<String>> fieldsOf(String text, {String separator = ','}) =>
    parseCsv(text, separator: separator).map((r) => r.fields).toList();

Uint8List bytesOf(String text) => Uint8List.fromList(utf8.encode(text));

Matcher sheetError(PlaceSheetError error) =>
    throwsA(isA<PlaceSheetException>().having((e) => e.error, 'error', error));

void main() {
  group('CSV reader (RFC 4180)', () {
    test('plain rows and fields', () {
      expect(fieldsOf('a,b,c\n1,2,3\n'), <List<String>>[
        <String>['a', 'b', 'c'],
        <String>['1', '2', '3'],
      ]);
    });

    test('CRLF, LF and lone CR all end a row', () {
      expect(fieldsOf('a,b\r\nc,d\re,f\ng,h'), <List<String>>[
        <String>['a', 'b'],
        <String>['c', 'd'],
        <String>['e', 'f'],
        <String>['g', 'h'],
      ]);
    });

    test('quoted fields keep commas, line breaks and doubled quotes', () {
      final records = parseCsv(
        'name,note\r\n'
        '"Mirpur, Dhaka","Line one\r\nline two"\r\n'
        '"The ""Best"" branch",""\r\n'
        'last,"x"\r\n',
      );
      expect(records.map((r) => r.fields).toList(), <List<String>>[
        <String>['name', 'note'],
        <String>['Mirpur, Dhaka', 'Line one\nline two'],
        <String>['The "Best" branch', ''],
        <String>['last', 'x'],
      ]);
      // A row with a line break inside quotes still has the line it
      // started on; the next row's line counts both lines.
      expect(records.map((r) => r.line), <int>[1, 2, 4, 5]);
    });

    test('a quote inside an unquoted field is kept as it is', () {
      expect(fieldsOf('5" pipe,a"b\n'), <List<String>>[
        <String>['5" pipe', 'a"b'],
      ]);
    });

    test('text after a closing quote is kept (lenient)', () {
      expect(fieldsOf('"abc"def,x'), <List<String>>[
        <String>['abcdef', 'x'],
      ]);
    });

    test('a byte order mark at the start is dropped', () {
      expect(fieldsOf('\uFEFFRegion,code\nDhaka,D'), <List<String>>[
        <String>['Region', 'code'],
        <String>['Dhaka', 'D'],
      ]);
    });

    test('empty lines at the end are not rows; empty fields are', () {
      expect(fieldsOf('a,,c\n,,\n\n\r\n\n'), <List<String>>[
        <String>['a', '', 'c'],
        <String>['', '', ''],
      ]);
      expect(fieldsOf(''), isEmpty);
      expect(fieldsOf('\n\n'), isEmpty);
    });

    test('an empty line in the middle is a blank row on its own line', () {
      final records = parseCsv('a\n\nb\n');
      expect(records.map((r) => r.fields).toList(), <List<String>>[
        <String>['a'],
        <String>[''],
        <String>['b'],
      ]);
      expect(records.map((r) => r.line), <int>[1, 2, 3]);
      expect(records[1].isBlank, isTrue);
    });

    test('a separator at the end of a row makes an empty last field', () {
      expect(fieldsOf('a,b,\n'), <List<String>>[
        <String>['a', 'b', ''],
      ]);
    });

    test('Bangla text, quoted and not', () {
      expect(
        fieldsOf('ঢাকা অঞ্চল,"মিরপুর, এলাকা",মিরপুর-১০ শাখা\n'),
        <List<String>>[
          <String>['ঢাকা অঞ্চল', 'মিরপুর, এলাকা', 'মিরপুর-১০ শাখা'],
        ],
      );
    });

    test('a quoted field never closed is refused with its line', () {
      expect(
        () => parseCsv('a,b\nc,"never closed\nmore'),
        throwsA(isA<CsvFormatException>().having((e) => e.line, 'line', 2)),
      );
    });

    test('semicolons and tabs are found when there are no commas', () {
      expect(guessSeparator('Region;Area;code\nx;y;z'), ';');
      expect(guessSeparator('Region\tArea\nx\ty'), '\t');
      expect(guessSeparator('"a;b",c\n'), ',');
      expect(guessSeparator('Region\n'), ',');
      expect(fieldsOf('a;"b;c"\n', separator: ';'), <List<String>>[
        <String>['a', 'b;c'],
      ]);
    });
  });

  group('reading a spreadsheet of places', () {
    test('column names first, a code column, ragged rows', () {
      final sheet = readPlaceSheet(
        bytesOf(
          '\uFEFFRegion,Area,Branch,Code\r\n'
          'Dhaka region,Mirpur area,Mirpur-10 branch,MRP10\r\n'
          'Dhaka region,Mirpur area,Pallabi branch,PLB\r\n'
          'Khulna region,Sonadanga area\r\n'
          ',,,\r\n'
          '  Khulna region , Daulatpur area ,,\r\n',
        ),
      );
      expect(sheet.hasHeader, isTrue);
      expect(sheet.codeColumn, 'Code');
      expect(sheet.columnNames, <String>['Region', 'Area', 'Branch', 'Code']);
      expect(sheet.problems, isEmpty);
      expect(sheet.rows.map((r) => r.line), <int>[2, 3, 4, 6]);
      expect(sheet.rows.map((r) => r.path).toList(), <List<String>>[
        <String>['Dhaka region', 'Mirpur area', 'Mirpur-10 branch'],
        <String>['Dhaka region', 'Mirpur area', 'Pallabi branch'],
        <String>['Khulna region', 'Sonadanga area'],
        <String>['Khulna region', 'Daulatpur area'],
      ]);
      expect(sheet.rows.map((r) => r.code), <String>['MRP10', 'PLB', '', '']);
      expect(sheet.rows.first.toJson(), <String, dynamic>{
        'line': 2,
        'path': <String>['Dhaka region', 'Mirpur area', 'Mirpur-10 branch'],
        'code': 'MRP10',
      });
    });

    test('the code column may be anywhere and in any capitals', () {
      final sheet = readPlaceSheet(
        bytesOf('CODE,Region,Branch\nD1,Dhaka,Mirpur\n'),
      );
      expect(sheet.codeColumn, 'CODE');
      expect(sheet.rows.single.path, <String>['Dhaka', 'Mirpur']);
      expect(sheet.rows.single.code, 'D1');
    });

    test('a header is recognised by its words, in Bangla too', () {
      expect(
        readPlaceSheet(bytesOf('অঞ্চল,এলাকা\nঢাকা,মিরপুর\nঢাকা,পল্লবী\n'))
            .hasHeader,
        isTrue,
      );
      expect(
        readPlaceSheet(bytesOf('Level 1,Level 2\nA,B\nA,C\n')).hasHeader,
        isTrue,
      );
    });

    test('a first row whose top name comes again is a place, not a header', () {
      final sheet = readPlaceSheet(
        bytesOf('Dhaka region,Mirpur area\nDhaka region,Uttara area\n'),
      );
      expect(sheet.hasHeader, isFalse);
      expect(sheet.codeColumn, isNull);
      expect(sheet.rows.map((r) => r.line), <int>[1, 2]);
    });

    test('the admin can say whether the first row has column names', () {
      final bytes = bytesOf('Dhaka region\nKhulna region\n');
      expect(readPlaceSheet(bytes).rows.single.path, <String>['Khulna region']);
      expect(
        readPlaceSheet(bytes, hasHeader: false).rows.map((r) => r.path.first),
        <String>['Dhaka region', 'Khulna region'],
      );
    });

    test('Bangla names stay as written', () {
      final sheet = readPlaceSheet(
        bytesOf('অঞ্চল,শাখা,code\nঢাকা অঞ্চল,মিরপুর-১০ শাখা,MRP10\n'),
      );
      expect(sheet.rows.single.path, <String>['ঢাকা অঞ্চল', 'মিরপুর-১০ শাখা']);
    });

    test('rows with a gap, no name, too many levels or long text are '
        'problems, by line', () {
      final long = 'x' * 201;
      final sheet = readPlaceSheet(
        bytesOf(
          'Region,Area,Branch,code\n'
          'Dhaka,,Mirpur,M\n'
          ',,,ONLYCODE\n'
          '${List<String>.filled(12, 'L').join(',')}\n'
          'Dhaka,$long\n'
          'Dhaka,Mirpur,Pallabi,${'C' * 51}\n'
          'Dhaka,Mirpur\n',
        ),
      );
      expect(
        sheet.problems.map((p) => (p.line, p.error)).toList(),
        <(int, PlaceRowError)>[
          (2, PlaceRowError.gap),
          (3, PlaceRowError.noName),
          (4, PlaceRowError.tooDeep),
          (5, PlaceRowError.nameTooLong),
          (6, PlaceRowError.codeTooLong),
        ],
      );
      expect(sheet.problems.first.column, 1);
      expect(columnLetter(sheet.problems.first.column), 'B');
      expect(sheet.rows.single.line, 7);
    });

    test('files that cannot be used are refused plainly', () {
      // Not UTF-8 (Windows-1252 "Café").
      expect(
        () => readPlaceSheet(
          Uint8List.fromList(<int>[0x43, 0x61, 0x66, 0xE9, 0x0A]),
        ),
        sheetError(PlaceSheetError.notUtf8),
      );
      // UTF-16 with its byte order mark.
      expect(
        () => readPlaceSheet(Uint8List.fromList(<int>[0xFF, 0xFE, 0x41, 0])),
        sheetError(PlaceSheetError.notUtf8),
      );
      // An Excel workbook.
      expect(
        () => readPlaceSheet(
          Uint8List.fromList(<int>[0x50, 0x4B, 0x03, 0x04, 1, 2, 3]),
        ),
        sheetError(PlaceSheetError.excel),
      );
      expect(
        () => readPlaceSheet(bytesOf('\n\n,,\n')),
        sheetError(PlaceSheetError.empty),
      );
      expect(
        () => readPlaceSheet(bytesOf('Region,Area,code\n')),
        sheetError(PlaceSheetError.onlyHeader),
      );
      expect(
        () => readPlaceSheet(bytesOf('Region\n"Dhaka\n')),
        throwsA(
          isA<PlaceSheetException>()
              .having((e) => e.error, 'error', PlaceSheetError.unclosedQuote)
              .having((e) => e.line, 'line', 2),
        ),
      );
      expect(
        () => readPlaceSheet(Uint8List(maxImportBytes + 1)),
        sheetError(PlaceSheetError.tooBig),
      );
    });

    test('at most 5,000 rows', () {
      String file(int rows) => <String>[
        'Region,Branch',
        for (var i = 0; i < rows; i++) 'Region,Branch $i',
      ].join('\n');
      expect(
        readPlaceSheet(bytesOf(file(maxImportRows))).rows,
        hasLength(maxImportRows),
      );
      expect(
        () => readPlaceSheet(bytesOf(file(maxImportRows + 1))),
        throwsA(
          isA<PlaceSheetException>()
              .having((e) => e.error, 'error', PlaceSheetError.tooManyRows)
              .having((e) => e.count, 'count', maxImportRows + 1),
        ),
      );
    });
  });

  group('preview of an import', () {
    test('places already there are reused, ignoring capitals and spaces', () {
      final directory = PlaceDirectory(samplePlaces);
      final preview = previewImport(
        directory,
        headOffice,
        const <PlaceImportRow>[
          PlaceImportRow(
            line: 2,
            path: <String>[' north REGION ', 'Mirpur branch', 'Ward 1'],
            code: 'W1',
          ),
          PlaceImportRow(line: 3, path: <String>['North region', 'Uttara']),
          PlaceImportRow(line: 4, path: <String>['East region']),
        ],
      );
      expect(
        preview.map((n) => (n.name, n.depth, n.isNew, n.code)).toList(),
        <(String, int, bool, String)>[
          ('North region', 0, false, 'N'),
          ('Mirpur branch', 1, false, 'N-MIR'),
          ('Ward 1', 2, true, 'W1'),
          ('Uttara', 1, true, ''),
          ('East region', 0, true, ''),
        ],
      );
    });

    test('names are cleaned and compared as the server does', () {
      final directory = PlaceDirectory(samplePlaces);
      final preview = previewImport(
        directory,
        headOffice,
        const <PlaceImportRow>[
          // No-break spaces, a line break, a zero-width space and a soft
          // hyphen: still North region.
          PlaceImportRow(
            line: 2,
            path: <String>[
              'North\u00A0 \nREGION\u200B',
              'Mir\u00ADpur  branch',
            ],
          ),
          // A name that is only invisible characters is left out.
          PlaceImportRow(line: 3, path: <String>['\u2060\uFEFF', 'Banani']),
        ],
      );
      expect(
        preview.map((n) => (n.name, n.depth, n.isNew)).toList(),
        <(String, int, bool)>[
          ('North region', 0, false),
          ('Mirpur branch', 1, false),
          ('Banani', 0, true),
        ],
      );
    });
  });

  group('place names, as the server cleans and compares them', () {
    test('invisible characters go, spaces collapse, ends are trimmed', () {
      expect(
        cleanPlaceName('  Mirpur\u00A0\u00A0 -10\t\r\nbranch\u200B  '),
        'Mirpur -10 branch',
      );
      expect(cleanPlaceName('\uFEFFDha\u00ADka\u2060'), 'Dhaka');
      expect(cleanPlaceName('\u200B \u3000'), isEmpty);
      // Bangla joiners choose letter shapes, so they stay.
      expect(cleanPlaceName('র\u200D্য'), 'র\u200D্য');
      expect(cleanPlaceName('মিরপুর\u2028শাখা'), 'মিরপুর শাখা');
    });

    test('capitals are ignored letter by letter, as Go folds them', () {
      expect(placeNameKey(' NORTH  Region '), placeNameKey('north region'));
      expect(placeNameKey('ΟΔΟΣ'), placeNameKey('οδος'));
      expect(placeNameKey('ſ'), placeNameKey('S'));
      expect(placeNameKey('\u212A'), placeNameKey('k'), reason: 'Kelvin');
      expect(placeNameKey('Straße'), isNot(placeNameKey('Strasse')));
      expect(placeNameKey('ঢাকা অঞ্চল'), 'ঢাকা অঞ্চল');
    });

    test('control and direction-changing characters are unsafe, and shown '
        'as a visible mark', () {
      for (final rune in <int>[0x00, 0x09, 0x0A, 0x7F, 0x85, 0x202E, 0x2066]) {
        expect(isUnsafeTextRune(rune), isTrue, reason: rune.toRadixString(16));
      }
      for (final rune in <int>[0x20, 0x41, 0x200D, 0x09A2, 0x2028]) {
        expect(isUnsafeTextRune(rune), isFalse, reason: rune.toRadixString(16));
      }
      expect(showUnsafeText('Dhaka\u202Eregion\n'), 'Dhaka\uFFFDregion\uFFFD');
    });

    test(
      'a spreadsheet\'s names are cleaned before they are checked or sent',
      () {
        final sheet = readPlaceSheet(
          bytesOf(
            'Region,Area\n'
            '"North\u00A0region\n",\u200B\n'
            '\u200B,Mirpur area\n',
          ),
        );
        expect(sheet.rows.single.path, <String>['North region']);
        expect(sheet.problems.single.error, PlaceRowError.gap);
        expect(sheet.problems.single.line, 4);
      },
    );
  });
}
