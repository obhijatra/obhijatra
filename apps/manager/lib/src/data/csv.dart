/// A reader for comma-separated values (RFC 4180), as Excel, Google Sheets
/// and LibreOffice save them.
///
/// It reads what those programs write and what people type by hand:
/// fields in double quotes may hold the separator, line breaks and doubled
/// quotes (`""` is one `"`); lines end in CRLF, LF or a lone CR; a byte
/// order mark at the start is dropped; empty lines at the end are ignored.
/// A quote inside a field that does not start with one is kept as it is.
library;

import 'package:flutter/foundation.dart' show immutable, listEquals;

/// One row of a CSV file.
@immutable
class CsvRecord {
  /// Creates a row.
  const CsvRecord(this.line, this.fields);

  /// The line of the file the row starts on, counting from 1. A row with a
  /// line break inside quotes covers more than one line.
  final int line;

  /// The fields, as written (no spaces trimmed).
  final List<String> fields;

  /// Whether every field is empty or only spaces.
  bool get isBlank => fields.every((field) => field.trim().isEmpty);

  @override
  bool operator ==(Object other) =>
      other is CsvRecord &&
      other.line == line &&
      listEquals(other.fields, fields);

  @override
  int get hashCode => Object.hash(line, Object.hashAll(fields));

  @override
  String toString() => 'CsvRecord($line, $fields)';
}

/// A CSV file that cannot be read: a quoted field is never closed.
class CsvFormatException implements Exception {
  /// Creates the problem for the quoted field that starts on [line].
  const CsvFormatException(this.line);

  /// The line the unclosed quoted field starts on, counting from 1.
  final int line;

  @override
  String toString() => 'CsvFormatException: unclosed quote from line $line';
}

/// The separator a file most likely uses: a comma, unless its first line
/// has none outside quotes but has semicolons (Excel in some languages) or
/// tabs.
String guessSeparator(String text) {
  var commas = 0;
  var semicolons = 0;
  var tabs = 0;
  var quoted = false;
  for (var i = 0; i < text.length; i++) {
    final char = text[i];
    if (char == '"') {
      quoted = !quoted;
    } else if (!quoted) {
      if (char == '\n' || char == '\r') break;
      if (char == ',') commas++;
      if (char == ';') semicolons++;
      if (char == '\t') tabs++;
    }
  }
  if (commas > 0) return ',';
  if (semicolons > 0) return ';';
  if (tabs > 0) return '\t';
  return ',';
}

/// Reads every row of [text]. Throws [CsvFormatException] when a quoted
/// field is never closed.
List<CsvRecord> parseCsv(String text, {String separator = ','}) {
  assert(separator.length == 1, 'The separator is one character.');
  final records = <CsvRecord>[];
  var input = text;
  if (input.startsWith('\uFEFF')) input = input.substring(1);

  var fields = <String>[];
  final field = StringBuffer();
  var line = 1; // The line being read.
  var recordLine = 1; // The line the current row started on.
  var i = 0;
  // Whether anything (even an empty field before a separator) belongs to
  // the row being read, so an empty last line is not counted as a row.
  var started = false;

  void endField() {
    fields.add(field.toString());
    field.clear();
  }

  void endRecord() {
    endField();
    records.add(CsvRecord(recordLine, fields));
    fields = <String>[];
    started = false;
  }

  /// Steps over a line ending at [i]; returns its length (0 if none).
  int lineEnding(int at) {
    if (at >= input.length) return 0;
    final char = input[at];
    if (char == '\r') {
      return at + 1 < input.length && input[at + 1] == '\n' ? 2 : 1;
    }
    return char == '\n' ? 1 : 0;
  }

  while (i < input.length) {
    final char = input[i];
    if (!started) recordLine = line;

    if (char == '"' && field.isEmpty && _atFieldStart(input, i, separator)) {
      // A quoted field: read to the closing quote.
      started = true;
      final opened = line;
      i++;
      var closed = false;
      while (i < input.length) {
        final c = input[i];
        if (c == '"') {
          if (i + 1 < input.length && input[i + 1] == '"') {
            field.write('"');
            i += 2;
            continue;
          }
          closed = true;
          i++;
          break;
        }
        final ending = lineEnding(i);
        if (ending > 0) {
          // A line break inside quotes is kept as a plain newline.
          field.write('\n');
          line++;
          i += ending;
          continue;
        }
        field.write(c);
        i++;
      }
      if (!closed) throw CsvFormatException(opened);
      continue;
    }

    if (char == separator) {
      started = true;
      endField();
      i++;
      continue;
    }

    final ending = lineEnding(i);
    if (ending > 0) {
      if (started || field.isNotEmpty) {
        endRecord();
      } else {
        // An empty line: a row with one empty field.
        records.add(CsvRecord(line, const <String>['']));
      }
      line++;
      i += ending;
      continue;
    }

    started = true;
    field.write(char);
    i++;
  }
  if (started || field.isNotEmpty) endRecord();

  // Empty lines at the end are not rows.
  while (records.isNotEmpty && records.last.isBlank) {
    if (records.last.fields.length > 1) break; // ",,," is a row of blanks.
    records.removeLast();
  }
  return records;
}

/// Whether position [i] of [text] is the start of a field.
bool _atFieldStart(String text, int i, String separator) {
  if (i == 0) return true;
  final before = text[i - 1];
  return before == separator || before == '\n' || before == '\r';
}
