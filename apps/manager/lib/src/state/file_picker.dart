import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A file the person chose.
class PickedFile {
  /// Creates a picked file.
  const PickedFile({
    required this.name,
    required this.bytes,
    this.tooLarge = false,
  });

  /// A file that was not read because it is bigger than allowed.
  PickedFile.tooLarge(this.name) : bytes = Uint8List(0), tooLarge = true;

  /// File name without folders.
  final String name;

  /// The whole file; empty when [tooLarge].
  final Uint8List bytes;

  /// Whether the file is bigger than allowed and so was not read.
  final bool tooLarge;
}

/// Reads [file], unless it is bigger than [maxBytes]: its size is asked
/// first, so a huge file is never read into memory (a browser tab could
/// run out of it).
Future<PickedFile> readPickedFile(XFile file, {required int maxBytes}) async {
  if (await file.length() > maxBytes) return PickedFile.tooLarge(file.name);
  return PickedFile(name: file.name, bytes: await file.readAsBytes());
}

/// Asks the person for a form file. Tests replace it.
// ignore: one_member_abstracts
abstract interface class FormFilePicker {
  /// Opens the system file chooser; null when the person cancels.
  Future<PickedFile?> pickFormFile();
}

/// The real chooser (web, Windows and macOS).
class SystemFormFilePicker implements FormFilePicker {
  /// Creates the chooser.
  const SystemFormFilePicker();

  @override
  Future<PickedFile?> pickFormFile() async {
    const group = XTypeGroup(
      label: 'XForm',
      extensions: <String>['xml', 'xlsx'],
    );
    final file = await openFile(acceptedTypeGroups: <XTypeGroup>[group]);
    if (file == null) return null;
    return PickedFile(name: file.name, bytes: await file.readAsBytes());
  }
}

/// The file chooser used by the upload dialog.
final formFilePickerProvider = Provider<FormFilePicker>(
  (ref) => const SystemFormFilePicker(),
);

/// Asks the person for a spreadsheet saved as CSV. Tests replace it.
// ignore: one_member_abstracts
abstract interface class CsvFilePicker {
  /// Opens the system file chooser; null when the person cancels. A file
  /// bigger than [maxBytes] is not read: it comes back
  /// [PickedFile.tooLarge].
  Future<PickedFile?> pickCsvFile({required int maxBytes});
}

/// The real chooser (web, Windows and macOS).
class SystemCsvFilePicker implements CsvFilePicker {
  /// Creates the chooser.
  const SystemCsvFilePicker();

  @override
  Future<PickedFile?> pickCsvFile({required int maxBytes}) async {
    const group = XTypeGroup(
      label: 'CSV',
      extensions: <String>['csv'],
      mimeTypes: <String>['text/csv'],
      uniformTypeIdentifiers: <String>['public.comma-separated-values-text'],
    );
    final file = await openFile(acceptedTypeGroups: <XTypeGroup>[group]);
    if (file == null) return null;
    return readPickedFile(file, maxBytes: maxBytes);
  }
}

/// The file chooser used by the spreadsheet import of places.
final csvFilePickerProvider = Provider<CsvFilePicker>(
  (ref) => const SystemCsvFilePicker(),
);
