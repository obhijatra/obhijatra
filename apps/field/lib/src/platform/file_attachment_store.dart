import 'dart:io';
import 'dart:typed_data';

import 'package:obhijatra_core/obhijatra_core.dart';

/// Reads the files that go with submissions from the app's private folder,
/// and removes them once the server holds them.
///
/// A path may be relative to [root] or absolute, but it must lead to a file
/// inside [root]: the real path of the file (every `..` and symbolic link
/// resolved) must start with the real path of [root] followed by a path
/// separator. Anything else, including a symbolic link inside [root] that
/// points outside it, counts as missing and is never read or removed.
final class FileAttachmentStore implements AttachmentStore {
  /// Creates the store for files under [root].
  FileAttachmentStore(this.root);

  /// The folder that holds the attachments.
  final Directory root;

  @override
  Future<Uint8List> read(String path) async {
    final file = _contained(path);
    if (file == null) {
      throw const ObhijatraException(ProblemCode.attachmentMissing);
    }
    try {
      return await file.readAsBytes();
    } on FileSystemException catch (e) {
      throw ObhijatraException(ProblemCode.attachmentMissing, cause: e);
    }
  }

  @override
  Future<void> delete(String path) async {
    final file = _contained(path);
    if (file == null) return;
    try {
      await file.delete();
    } on PathNotFoundException {
      // Already gone.
    }
  }

  /// The file [path] names, by its real path, if it is a regular file inside
  /// [root]; otherwise `null`.
  File? _contained(String path) {
    try {
      final rootReal = root.resolveSymbolicLinksSync();
      final prefix = rootReal.endsWith(Platform.pathSeparator)
          ? rootReal
          : '$rootReal${Platform.pathSeparator}';
      final named = File(path).isAbsolute
          ? File(path)
          : File('$rootReal${Platform.pathSeparator}$path');
      final real = named.resolveSymbolicLinksSync();
      if (!real.startsWith(prefix)) return null;
      // Resolved, so this is the file itself, never a link.
      final type = FileSystemEntity.typeSync(real, followLinks: false);
      return type == FileSystemEntityType.file ? File(real) : null;
    } on FileSystemException {
      return null; // The root or the file does not exist.
    }
  }
}
