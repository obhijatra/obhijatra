import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:obhijatra_manager/src/data/problem.dart';
import 'package:obhijatra_manager/src/files/download_saver.dart';

/// The desktop saver: asks where to save, then writes each part to that
/// file as it arrives, so a large download never sits in memory.
DownloadSaver platformDownloadSaver() => const FileDownloadSaver();

/// Saves to a file the person chooses with the system's Save dialog.
class FileDownloadSaver implements DownloadSaver {
  /// Creates the saver.
  const FileDownloadSaver();

  @override
  bool get holdsInMemory => false;

  @override
  Future<DownloadTarget?> choose(String suggestedName) async {
    const zip = XTypeGroup(
      label: 'Zip',
      extensions: <String>['zip'],
      uniformTypeIdentifiers: <String>['public.zip-archive'],
    );
    final location = await getSaveLocation(
      suggestedName: suggestedName,
      acceptedTypeGroups: <XTypeGroup>[zip],
    );
    if (location == null) return null;
    // Written exactly where the person chose: on macOS the app may write
    // only that file, not one beside it.
    final file = File(location.path);
    try {
      return _FileTarget(file, await file.open(mode: FileMode.write));
    } on FileSystemException {
      throw const AppProblem(ProblemKind.saveFailed);
    }
  }
}

class _FileTarget implements DownloadTarget {
  _FileTarget(this._file, this._open);

  final File _file;
  final RandomAccessFile _open;

  @override
  Future<void> add(List<int> chunk) async {
    try {
      await _open.writeFrom(chunk);
    } on FileSystemException {
      throw const AppProblem(ProblemKind.saveFailed);
    }
  }

  @override
  Future<String> finish({String? serverName}) async {
    try {
      await _open.flush();
      await _open.close();
    } on FileSystemException {
      throw const AppProblem(ProblemKind.saveFailed);
    }
    return _file.uri.pathSegments.lastWhere(
      (segment) => segment.isNotEmpty,
      orElse: () => _file.path,
    );
  }

  @override
  Future<void> discard() async {
    try {
      await _open.close();
    } on Object {
      // Already closed.
    }
    try {
      if (_file.existsSync()) await _file.delete();
    } on Object {
      // Nothing more can be done; the person sees the failure.
    }
  }
}
