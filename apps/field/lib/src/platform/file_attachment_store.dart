import 'dart:io';
import 'dart:typed_data';

import 'package:obhijatra_core/obhijatra_core.dart';

/// Reads the files that go with submissions from the app's private folder.
///
/// A path may be relative to [root] or absolute, but it must lead to a file
/// inside [root]; anything else counts as missing.
final class FileAttachmentStore implements AttachmentStore {
  /// Creates the store for files under [root].
  FileAttachmentStore(this.root);

  /// The folder that holds the attachments.
  final Directory root;

  @override
  Future<Uint8List> read(String path) async {
    final rootPath = root.absolute.uri.normalizePath().toFilePath();
    final file = File(
      path.startsWith(Platform.pathSeparator) || path.contains(':')
          ? path
          : '${root.path}${Platform.pathSeparator}$path',
    );
    final resolved = file.absolute.uri.normalizePath().toFilePath();
    if (!resolved.startsWith(rootPath)) {
      throw const ObhijatraException(ProblemCode.attachmentMissing);
    }
    try {
      return await file.readAsBytes();
    } on FileSystemException catch (e) {
      throw ObhijatraException(ProblemCode.attachmentMissing, cause: e);
    }
  }
}
