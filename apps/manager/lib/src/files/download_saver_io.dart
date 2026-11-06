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
    return FileTarget(location.path);
  }
}

/// The file at a path the person chose in the Save dialog.
///
/// Nothing touches it until the first part of the download arrives: a
/// file the person chose to replace keeps its contents if the download
/// fails before then. After a failure it is deleted only if this download
/// had already created or emptied it. It is written exactly where the
/// person chose: on macOS the app may write only that file, not one beside
/// it.
class FileTarget implements DownloadTarget {
  /// The target for the file at [path].
  FileTarget(String path) : _file = File(path);

  final File _file;
  RandomAccessFile? _open;

  /// Whether this download has created or emptied the file.
  bool _written = false;

  Future<RandomAccessFile> _opened() async {
    final open = _open;
    if (open != null) return open;
    try {
      final opened = await _file.open(mode: FileMode.write);
      _written = true;
      return _open = opened;
    } on FileSystemException {
      throw const AppProblem(ProblemKind.saveFailed);
    }
  }

  @override
  Future<void> add(List<int> chunk) async {
    final open = await _opened();
    try {
      await open.writeFrom(chunk);
    } on FileSystemException {
      throw const AppProblem(ProblemKind.saveFailed);
    }
  }

  @override
  Future<String> finish({String? serverName}) async {
    final open = await _opened();
    try {
      await open.flush();
      await open.close();
    } on FileSystemException {
      throw const AppProblem(ProblemKind.saveFailed);
    }
    _open = null;
    return _file.uri.pathSegments.lastWhere(
      (segment) => segment.isNotEmpty,
      orElse: () => _file.path,
    );
  }

  @override
  Future<void> discard() async {
    final open = _open;
    _open = null;
    if (open != null) {
      try {
        await open.close();
      } on Object {
        // Already closed.
      }
    }
    if (!_written) return; // Never touched: left as it was.
    try {
      if (_file.existsSync()) await _file.delete();
    } on Object {
      // Nothing more can be done; the person sees the failure.
    }
  }
}
