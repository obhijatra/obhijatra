import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show immutable;
import 'package:obhijatra_manager/src/data/csv.dart';
import 'package:obhijatra_manager/src/data/people.dart';

/// The most rows one spreadsheet import may hold (the server's limit).
const int maxImportRows = 5000;

/// The most levels one row may hold (the server's limit).
const int maxImportLevels = 10;

/// The longest place name the server keeps, in characters.
const int maxPlaceName = 200;

/// The longest place code the server keeps, in characters.
const int maxPlaceCode = 50;

/// The largest spreadsheet file read, in bytes: far more than 5,000 rows
/// of names need, and small enough to read at once in a browser.
const int maxImportBytes = 5 * 1024 * 1024;

/// One row of a spreadsheet import: the names from the top level down
/// (under the chosen place) and an optional code for the last one.
@immutable
class PlaceImportRow {
  /// Creates a row.
  const PlaceImportRow({
    required this.line,
    required this.path,
    this.code = '',
  });

  /// The row's line in the file, for messages.
  final int line;

  /// The names, from the top level down.
  final List<String> path;

  /// The code of the last place, or empty.
  final String code;

  /// The row as the server reads it.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'line': line,
    'path': path,
    'code': code,
  };
}

/// What the server found wrong with one row (see
/// server/internal/places/import.go): a code to word it in the person's
/// language, with the place and the value it is about, and the server's
/// own English sentence for codes the app does not know.
@immutable
class PlaceImportProblem {
  /// Creates a problem.
  const PlaceImportProblem({
    required this.line,
    required this.message,
    this.code = '',
    this.name = '',
    this.value = '',
  });

  /// The row's line in the file.
  final int line;

  /// Which problem, for example `place_closed`; empty from an older server.
  final String code;

  /// What is wrong, in the server's plain English.
  final String message;

  /// The place it is about, or empty.
  final String name;

  /// The code or limit it is about, or empty.
  final String value;
}

/// The server's answer to an import or a check of one.
@immutable
class PlaceImportResult {
  /// Creates a result.
  const PlaceImportResult({
    required this.created,
    required this.existing,
    required this.problems,
    required this.saved,
  });

  /// Reads the server's answer.
  factory PlaceImportResult.fromJson(Map<String, dynamic> json) =>
      PlaceImportResult(
        created: (json['created'] as num?)?.toInt() ?? 0,
        existing: (json['existing'] as num?)?.toInt() ?? 0,
        problems: <PlaceImportProblem>[
          if (json['problems'] case final List<dynamic> list)
            for (final item in list)
              if (item case {
                'line': final num line,
                'message': final String message,
              })
                PlaceImportProblem(
                  line: line.toInt(),
                  message: message,
                  code: _text(item['code']),
                  name: _text(item['name']),
                  value: _text(item['value']),
                ),
        ],
        saved: json['saved'] == true,
      );

  /// How many places the import makes.
  final int created;

  /// How many places in the file are already there.
  final int existing;

  /// What must be fixed first; nothing is saved while there is any.
  final List<PlaceImportProblem> problems;

  /// Whether the places were saved.
  final bool saved;
}

String _text(Object? value) => value is String ? value : '';

// ------------------------------------------------------------ the file

/// Why a spreadsheet file cannot be used at all.
enum PlaceSheetError {
  /// The file is bigger than [maxImportBytes].
  tooBig,

  /// The file is an Excel workbook, not CSV.
  excel,

  /// The file is not UTF-8 text.
  notUtf8,

  /// A quoted cell is never closed.
  unclosedQuote,

  /// The file has no rows.
  empty,

  /// The file has column names and nothing under them.
  onlyHeader,

  /// The file has more than [maxImportRows] rows of places.
  tooManyRows,
}

/// A file that cannot be used at all, with what to tell the admin.
class PlaceSheetException implements Exception {
  /// Creates the problem.
  const PlaceSheetException(this.error, {this.line = 0, this.count = 0});

  /// What is wrong.
  final PlaceSheetError error;

  /// The line it is on, for [PlaceSheetError.unclosedQuote].
  final int line;

  /// How many rows there are, for [PlaceSheetError.tooManyRows].
  final int count;

  @override
  String toString() => 'PlaceSheetException(${error.name})';
}

/// What is wrong with one row before anything is sent.
enum PlaceRowError {
  /// The row has a code but no place name.
  noName,

  /// A cell between two names is empty.
  gap,

  /// More than [maxImportLevels] names.
  tooDeep,

  /// A name is longer than [maxPlaceName] characters.
  nameTooLong,

  /// The code is longer than [maxPlaceCode] characters.
  codeTooLong,
}

/// A row that cannot be sent, with the line it is on.
@immutable
class PlaceRowProblem {
  /// Creates the problem.
  const PlaceRowProblem(this.line, this.error, {this.column = 0});

  /// The row's line in the file.
  final int line;

  /// What is wrong.
  final PlaceRowError error;

  /// For [PlaceRowError.gap]: the empty cell's column, counting from 0.
  final int column;
}

/// The places read from a spreadsheet file.
@immutable
class PlaceSheet {
  /// Creates the result of reading a file.
  const PlaceSheet({
    required this.rows,
    required this.problems,
    required this.hasHeader,
    required this.codeColumn,
    this.columnNames = const <String>[],
  });

  /// The rows to send, in the order of the file.
  final List<PlaceImportRow> rows;

  /// Rows that cannot be sent as they are.
  final List<PlaceRowProblem> problems;

  /// Whether the first row was read as column names.
  final bool hasHeader;

  /// The column names, when [hasHeader], without empty ones.
  final List<String> columnNames;

  /// The name of the column read as codes, as written in the file, or
  /// null when there is none.
  final String? codeColumn;
}

/// Column names that mark the code column, ignoring capitals.
const Set<String> _codeNames = <String>{'code', 'কোড'};

/// Words people use as column names for levels of an organisation. A
/// first row with one of them is column names, not places.
const Set<String> _levelWords = <String>{
  'region',
  'regions',
  'area',
  'areas',
  'branch',
  'branches',
  'zone',
  'zones',
  'division',
  'divisions',
  'district',
  'districts',
  'upazila',
  'upazilas',
  'union',
  'unions',
  'unit',
  'units',
  'office',
  'offices',
  'cluster',
  'clusters',
  'ward',
  'wards',
  'village',
  'villages',
  'level',
  'name',
  'place',
  'places',
  'country',
  'state',
  'province',
  'county',
  'city',
  'hub',
  'team',
  'অঞ্চল',
  'এলাকা',
  'শাখা',
  'বিভাগ',
  'জেলা',
  'উপজেলা',
  'ইউনিয়ন',
  'অফিস',
  'স্তর',
  'নাম',
  'স্থান',
  'ওয়ার্ড',
  'গ্রাম',
  'জোন',
};

/// Whether the first of [records] holds column names rather than a place.
///
/// The instructions ask for column names first, so that is assumed unless
/// the first row's top-level name appears again in a later row, as the
/// top level of a tree usually does and a column name never does. A column
/// named "code", or a familiar level word, settles it.
bool looksLikeHeader(List<CsvRecord> records) {
  if (records.isEmpty) return false;
  final first = <String>[
    for (final field in records.first.fields) field.trim().toLowerCase(),
  ];
  if (first.any(_codeNames.contains)) return true;
  final numberedLevel = RegExp(r'^(level|স্তর)\s*[\d০-৯]+$');
  if (first.any(
    (cell) => _levelWords.contains(cell) || numberedLevel.hasMatch(cell),
  )) {
    return true;
  }
  final top = first.isEmpty ? '' : first.first;
  if (top.isEmpty) return true;
  for (final record in records.skip(1)) {
    if (record.fields.isNotEmpty &&
        record.fields.first.trim().toLowerCase() == top) {
      return false;
    }
  }
  return true;
}

/// Reads a spreadsheet saved as CSV UTF-8. [hasHeader] overrides the guess
/// of whether the first row holds column names. Throws
/// [PlaceSheetException] when the file cannot be used at all.
PlaceSheet readPlaceSheet(Uint8List bytes, {bool? hasHeader}) {
  if (bytes.length > maxImportBytes) {
    throw const PlaceSheetException(PlaceSheetError.tooBig);
  }
  // An .xlsx workbook is a zip file; an old .xls starts with D0 CF 11 E0.
  if (_startsWith(bytes, const <int>[0x50, 0x4B, 0x03, 0x04]) ||
      _startsWith(bytes, const <int>[0xD0, 0xCF, 0x11, 0xE0])) {
    throw const PlaceSheetException(PlaceSheetError.excel);
  }
  final String text;
  try {
    text = utf8.decode(bytes);
  } on FormatException {
    throw const PlaceSheetException(PlaceSheetError.notUtf8);
  }
  if (text.contains('\u0000')) {
    // UTF-16 text decodes as UTF-8 only when it is plain English, and then
    // it is full of zero characters.
    throw const PlaceSheetException(PlaceSheetError.notUtf8);
  }
  final List<CsvRecord> records;
  try {
    records = parseCsv(text, separator: guessSeparator(text));
  } on CsvFormatException catch (e) {
    throw PlaceSheetException(PlaceSheetError.unclosedQuote, line: e.line);
  }
  final filled = records.where((record) => !record.isBlank).toList();
  if (filled.isEmpty) throw const PlaceSheetException(PlaceSheetError.empty);

  final header = hasHeader ?? looksLikeHeader(filled);
  var codeIndex = -1;
  String? codeColumn;
  if (header) {
    final names = filled.first.fields;
    for (var i = names.length - 1; i >= 0; i--) {
      if (_codeNames.contains(names[i].trim().toLowerCase())) {
        codeIndex = i;
        codeColumn = names[i].trim();
        break;
      }
    }
  }
  final body = header ? filled.skip(1).toList() : filled;
  if (body.isEmpty) {
    throw PlaceSheetException(
      header ? PlaceSheetError.onlyHeader : PlaceSheetError.empty,
    );
  }
  if (body.length > maxImportRows) {
    throw PlaceSheetException(PlaceSheetError.tooManyRows, count: body.length);
  }

  final rows = <PlaceImportRow>[];
  final problems = <PlaceRowProblem>[];
  for (final record in body) {
    final code = codeIndex >= 0 && codeIndex < record.fields.length
        ? record.fields[codeIndex].trim()
        : '';
    // The names with their columns, without the code and without the
    // empty cells at the end of the row.
    final cells = <(int, String)>[
      for (var i = 0; i < record.fields.length; i++)
        if (i != codeIndex) (i, record.fields[i].trim()),
    ];
    while (cells.isNotEmpty && cells.last.$2.isEmpty) {
      cells.removeLast();
    }
    final PlaceRowProblem? problem;
    final gap = cells.where((cell) => cell.$2.isEmpty).firstOrNull;
    if (cells.isEmpty) {
      problem = PlaceRowProblem(record.line, PlaceRowError.noName);
    } else if (gap != null) {
      problem = PlaceRowProblem(record.line, PlaceRowError.gap, column: gap.$1);
    } else if (cells.length > maxImportLevels) {
      problem = PlaceRowProblem(record.line, PlaceRowError.tooDeep);
    } else if (cells.any((cell) => cell.$2.runes.length > maxPlaceName)) {
      problem = PlaceRowProblem(record.line, PlaceRowError.nameTooLong);
    } else if (code.runes.length > maxPlaceCode) {
      problem = PlaceRowProblem(record.line, PlaceRowError.codeTooLong);
    } else {
      problem = null;
    }
    if (problem != null) {
      problems.add(problem);
      continue;
    }
    rows.add(
      PlaceImportRow(
        line: record.line,
        path: <String>[for (final cell in cells) cell.$2],
        code: code,
      ),
    );
  }
  return PlaceSheet(
    rows: rows,
    problems: problems,
    hasHeader: header,
    codeColumn: codeColumn,
    columnNames: header
        ? <String>[
            for (final name in filled.first.fields)
              if (name.trim().isNotEmpty) name.trim(),
          ]
        : const <String>[],
  );
}

bool _startsWith(Uint8List bytes, List<int> start) {
  if (bytes.length < start.length) return false;
  for (var i = 0; i < start.length; i++) {
    if (bytes[i] != start[i]) return false;
  }
  return true;
}

/// A spreadsheet column's letter, as Excel shows it: 0 is A, 26 is AA.
String columnLetter(int index) {
  var n = index + 1;
  var letters = '';
  while (n > 0) {
    letters = String.fromCharCode(0x41 + (n - 1) % 26) + letters;
    n = (n - 1) ~/ 26;
  }
  return letters;
}

// ------------------------------------------------------------- preview

/// One line of the preview of an import: a place in the file, new or
/// already there.
@immutable
class PlacePreviewNode {
  /// Creates a line of the preview.
  const PlacePreviewNode({
    required this.name,
    required this.depth,
    required this.isNew,
    this.code = '',
    this.closed = false,
  });

  /// The place's name, as it is or will be saved.
  final String name;

  /// 0 for a place directly inside the chosen place.
  final int depth;

  /// Whether the import adds it.
  final bool isNew;

  /// The code the file gives it, or empty.
  final String code;

  /// Whether it is already there and closed.
  final bool closed;
}

class _Node {
  _Node(this.name, {this.place});

  final String name;
  final Place? place;
  String code = '';
  final Map<String, _Node> children = <String, _Node>{};
  bool loaded = false;
}

/// The places [rows] name, as they will sit inside [parent]: in the order
/// of the file, each followed by the places inside it. A name already
/// used at that level (ignoring capitals and spaces round it) is the same
/// place, as the server decides.
List<PlacePreviewNode> previewImport(
  PlaceDirectory directory,
  Place parent,
  List<PlaceImportRow> rows,
) {
  String key(String name) => name.trim().toLowerCase();
  void load(_Node node) {
    if (node.loaded) return;
    node.loaded = true;
    final place = node.place;
    if (place == null) return;
    for (final child in directory.childrenOf(place.id)) {
      node.children.putIfAbsent(
        key(child.name),
        () => _Node(child.name.trim(), place: child),
      );
    }
  }

  final top = _Node(parent.name, place: parent);
  final seen = <_Node>{};
  final order = <_Node, List<_Node>>{};
  for (final row in rows) {
    var current = top;
    for (var depth = 0; depth < row.path.length; depth++) {
      load(current);
      final name = row.path[depth].trim();
      final next = current.children.putIfAbsent(key(name), () => _Node(name));
      if (depth == row.path.length - 1 &&
          row.code.isNotEmpty &&
          next.code.isEmpty &&
          (next.place?.code ?? '').isEmpty) {
        next.code = row.code;
      }
      if (seen.add(next)) {
        order.putIfAbsent(current, () => <_Node>[]).add(next);
      }
      current = next;
    }
  }

  final out = <PlacePreviewNode>[];
  void visit(_Node node, int depth) {
    for (final child in order[node] ?? const <_Node>[]) {
      final place = child.place;
      out.add(
        PlacePreviewNode(
          name: place?.displayName ?? child.name,
          depth: depth,
          isNew: place == null,
          code: child.code.isNotEmpty ? child.code : (place?.code ?? ''),
          closed: place?.closed ?? false,
        ),
      );
      visit(child, depth + 1);
    }
  }

  visit(top, 0);
  return out;
}
