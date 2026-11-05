import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens a web address in the person's browser; says whether it could.
typedef UrlOpener = Future<bool> Function(Uri url);

/// Opens addresses in a new browser tab (web) or the default browser
/// (Windows, macOS). Tests replace it.
final urlOpenerProvider = Provider<UrlOpener>((ref) => _launch);

Future<bool> _launch(Uri url) async {
  try {
    return await launchUrl(url, webOnlyWindowName: '_blank');
  } on Object {
    return false;
  }
}
