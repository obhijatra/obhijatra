import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The only things the app remembers on this computer.
///
/// On the web that is the language choice and nothing else: the session
/// lives in memory and the server address is the address of the page. On
/// Windows and macOS the server address is remembered too, so it does not
/// have to be typed every day.
abstract final class Preferences {
  static const String _languageKey = 'language';
  static const String _serverKey = 'server_url';

  /// The saved language code (`en` or `bn`), or null.
  static Future<String?> loadLanguage() async {
    try {
      final value = (await SharedPreferences.getInstance()).getString(
        _languageKey,
      );
      return value == 'bn' || value == 'en' ? value : null;
    } on Object {
      return null; // Blocked or cleared storage: start in English.
    }
  }

  /// Remembers the language code.
  static Future<void> saveLanguage(String code) async {
    try {
      await (await SharedPreferences.getInstance()).setString(
        _languageKey,
        code,
      );
    } on Object {
      // Storage may be blocked (private window): the choice just won't stick.
    }
  }

  /// The saved server address. Always null on the web.
  static Future<String?> loadServer() async {
    if (kIsWeb) return null;
    try {
      return (await SharedPreferences.getInstance()).getString(_serverKey);
    } on Object {
      return null;
    }
  }

  /// Remembers the server address. Does nothing on the web.
  static Future<void> saveServer(String url) async {
    if (kIsWeb) return;
    try {
      await (await SharedPreferences.getInstance()).setString(_serverKey, url);
    } on Object {
      // Not remembered; the person types it again next time.
    }
  }
}
