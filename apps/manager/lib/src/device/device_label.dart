import 'package:flutter/foundation.dart';
import 'package:obhijatra_manager/src/data/devices.dart';

/// The platform this app reports to the server: `web`, `windows`, `macos`
/// or `linux`.
String currentDevicePlatform() {
  if (kIsWeb) return DevicePlatform.web;
  return switch (defaultTargetPlatform) {
    TargetPlatform.windows => DevicePlatform.windows,
    TargetPlatform.macOS => DevicePlatform.macos,
    _ => DevicePlatform.linux,
  };
}

/// The name this device is enrolled with, chosen from fixed words only:
/// "Web browser (Chrome on Windows)", "Windows computer" or "Mac". Nothing
/// is copied from [userAgent], so no odd character reaches the server or an
/// approver's screen. At most [maxDeviceLabel] characters.
///
/// The name stays in English: it is stored once and read by every approver,
/// whatever language each of them uses. The apps translate the platform.
String deviceLabel(String platform, {String userAgent = ''}) {
  final label = switch (platform) {
    DevicePlatform.web => _browserLabel(userAgent),
    DevicePlatform.windows => 'Windows computer',
    DevicePlatform.macos => 'Mac',
    _ => 'Linux computer',
  };
  final runes = label.runes;
  return runes.length <= maxDeviceLabel
      ? label
      : String.fromCharCodes(runes.take(maxDeviceLabel));
}

String _browserLabel(String userAgent) {
  final browser = _browser(userAgent);
  final system = _system(userAgent);
  return switch ((browser, system)) {
    (final String b, final String s) => 'Web browser ($b on $s)',
    (final String b, null) => 'Web browser ($b)',
    (null, final String s) => 'Web browser ($s)',
    (null, null) => 'Web browser',
  };
}

// Order matters: Edge and Opera also say "Chrome", Chrome also says
// "Safari", and Android also says "Linux".
String? _browser(String ua) {
  if (ua.contains('Edg/') || ua.contains('EdgA/') || ua.contains('EdgiOS/')) {
    return 'Edge';
  }
  if (ua.contains('OPR/') || ua.contains('Opera')) return 'Opera';
  if (ua.contains('SamsungBrowser/')) return 'Samsung Internet';
  if (ua.contains('Firefox/') || ua.contains('FxiOS/')) return 'Firefox';
  if (ua.contains('Chrome/') ||
      ua.contains('CriOS/') ||
      ua.contains('Chromium/')) {
    return 'Chrome';
  }
  if (ua.contains('Safari/')) return 'Safari';
  return null;
}

String? _system(String ua) {
  if (ua.contains('Windows')) return 'Windows';
  if (ua.contains('Android')) return 'Android';
  if (ua.contains('iPhone')) return 'iPhone';
  if (ua.contains('iPad')) return 'iPad';
  if (ua.contains('CrOS')) return 'ChromeOS';
  if (ua.contains('Macintosh') || ua.contains('Mac OS X')) return 'Mac';
  if (ua.contains('Linux')) return 'Linux';
  return null;
}
