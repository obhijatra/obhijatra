import 'package:flutter/services.dart';
import 'package:obhijatra_core/obhijatra_core.dart';
import 'package:url_launcher/url_launcher.dart';

/// Shows Google's sign-in page in a secure browser tab, never inside the
/// app: Google refuses sign-in in an app's own web view, and a browser tab
/// keeps the Google password away from the app.
abstract interface class SignInBrowser {
  /// Opens [url]; throws an [ObhijatraException] with
  /// [ProblemCode.browserUnavailable] when the phone cannot open it.
  Future<void> open(Uri url);

  /// Closes the tab [open] opened, where the phone allows an app to (iOS);
  /// on Android the person closes it.
  Future<void> close();
}

/// [SignInBrowser] with Chrome Custom Tabs on Android and
/// `SFSafariViewController` on iOS, or the phone's browser app when there
/// is no such tab (an embedded web view would be refused by Google).
class SecureBrowserTab implements SignInBrowser {
  /// Creates the browser.
  SecureBrowserTab();

  LaunchMode? _mode;

  @override
  Future<void> open(Uri url) async {
    var opened = false;
    try {
      final mode = await supportsLaunchMode(LaunchMode.inAppBrowserView)
          ? LaunchMode.inAppBrowserView
          : LaunchMode.externalApplication;
      opened = await launchUrl(url, mode: mode);
      if (opened) _mode = mode;
    } on PlatformException catch (e) {
      throw ObhijatraException(ProblemCode.browserUnavailable, cause: e);
    }
    if (!opened) {
      throw const ObhijatraException(ProblemCode.browserUnavailable);
    }
  }

  @override
  Future<void> close() async {
    final mode = _mode;
    _mode = null;
    if (mode == null) return;
    try {
      if (await supportsCloseForLaunchMode(mode)) await closeInAppWebView();
    } on PlatformException {
      // Nothing to close, or the phone does not allow it: the person can.
    }
  }
}

/// Signs in on [server] with Google in [browser]; [cancellation] stops
/// waiting. The browser tab is closed afterwards where the phone allows it,
/// so the person sees the app's answer.
Future<SignedInUser> signInWithGoogleIn(
  ObhijatraServer server,
  SignInBrowser browser,
  SignInCancellation cancellation,
) async {
  try {
    return await server.signInWithGoogle(
      browser.open,
      cancellation: cancellation,
    );
  } finally {
    await browser.close();
  }
}
