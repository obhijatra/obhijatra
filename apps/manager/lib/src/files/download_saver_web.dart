import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:obhijatra_manager/src/files/download_saver.dart';
import 'package:web/web.dart' as web;

/// The web saver: the browser's own download, made from the whole file
/// once it has arrived (a page cannot write to the disk part by part).
DownloadSaver platformDownloadSaver() => const BrowserDownloadSaver();

/// Saves through the browser's downloads.
class BrowserDownloadSaver implements DownloadSaver {
  /// Creates the saver.
  const BrowserDownloadSaver();

  @override
  bool get holdsInMemory => true;

  @override
  Future<DownloadTarget?> choose(String suggestedName) async =>
      _BrowserTarget(suggestedName);
}

class _BrowserTarget implements DownloadTarget {
  _BrowserTarget(this._suggestedName);

  final String _suggestedName;
  final BytesBuilder _bytes = BytesBuilder(copy: false);

  @override
  Future<void> add(List<int> chunk) async => _bytes.add(chunk);

  @override
  Future<String> finish({String? serverName}) async {
    final name = serverName ?? _suggestedName;
    final blob = web.Blob(
      <JSAny>[_bytes.takeBytes().toJS].toJS,
      web.BlobPropertyBag(type: 'application/zip'),
    );
    final url = web.URL.createObjectURL(blob);
    final link = web.HTMLAnchorElement()
      ..href = url
      ..download = name
      ..style.display = 'none';
    web.document.body?.append(link);
    link.click();
    link.remove();
    // The browser reads the file after the click; let it go a little later.
    Timer(const Duration(minutes: 1), () => web.URL.revokeObjectURL(url));
    return name;
  }

  @override
  Future<void> discard() async => _bytes.clear();
}
