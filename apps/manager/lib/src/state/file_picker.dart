import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A file the person chose.
class PickedFile {
  /// Creates a picked file.
  const PickedFile({required this.name, required this.bytes});

  /// File name without folders.
  final String name;

  /// The whole file.
  final Uint8List bytes;
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
  /// Opens the system file chooser; null when the person cancels.
  Future<PickedFile?> pickCsvFile();
}

/// The real chooser (web, Windows and macOS).
class SystemCsvFilePicker implements CsvFilePicker {
  /// Creates the chooser.
  const SystemCsvFilePicker();

  @override
  Future<PickedFile?> pickCsvFile() async {
    const group = XTypeGroup(
      label: 'CSV',
      extensions: <String>['csv'],
      mimeTypes: <String>['text/csv'],
      uniformTypeIdentifiers: <String>['public.comma-separated-values-text'],
    );
    final file = await openFile(acceptedTypeGroups: <XTypeGroup>[group]);
    if (file == null) return null;
    return PickedFile(name: file.name, bytes: await file.readAsBytes());
  }
}

/// The file chooser used by the spreadsheet import of places.
final csvFilePickerProvider = Provider<CsvFilePicker>(
  (ref) => const SystemCsvFilePicker(),
);
