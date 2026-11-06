// The download saver for the platform the app is built for. Desktop builds
// never import the web code, and the web build never imports dart:io.
export 'package:obhijatra_manager/src/files/download_saver_io.dart'
    if (dart.library.js_interop) 'package:obhijatra_manager/src/files/download_saver_web.dart'
    show platformDownloadSaver;
