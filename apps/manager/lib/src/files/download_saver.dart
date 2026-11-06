import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obhijatra_manager/src/files/download_platform.dart';

/// Where one download goes, chosen before it starts.
abstract interface class DownloadTarget {
  /// Writes the next part of the file.
  Future<void> add(List<int> chunk);

  /// Finishes the file and returns its name, for the success message.
  /// [serverName] is the name the server gave, when known: a browser
  /// saves the file under it.
  Future<String> finish({String? serverName});

  /// Removes what was written, after a failure or when the person stops.
  Future<void> discard();
}

/// Saves downloaded files: on Windows and macOS straight to a file the
/// person chooses, part by part; in a browser through its own download,
/// which needs the whole file in memory first.
abstract interface class DownloadSaver {
  /// Whether the whole file is held in memory until it is saved (a web
  /// browser).
  bool get holdsInMemory;

  /// Asks where to save a file called [suggestedName] (desktop), or gets
  /// the browser's download ready. Null when the person cancels.
  Future<DownloadTarget?> choose(String suggestedName);
}

/// Saves downloads for the platform the app runs on. Tests replace it.
final downloadSaverProvider = Provider<DownloadSaver>(
  (ref) => platformDownloadSaver(),
);
