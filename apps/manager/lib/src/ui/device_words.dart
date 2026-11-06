import 'package:flutter/material.dart';
import 'package:obhijatra_manager/l10n/app_localizations.dart';
import 'package:obhijatra_manager/src/data/devices.dart';

/// A device platform in plain words, for example "Web browser".
String platformName(AppLocalizations l10n, String platform) =>
    switch (platform) {
      DevicePlatform.web => l10n.platformWeb,
      DevicePlatform.windows => l10n.platformWindows,
      DevicePlatform.macos => l10n.platformMac,
      DevicePlatform.linux => l10n.platformLinux,
      DevicePlatform.android => l10n.platformAndroid,
      DevicePlatform.ios => l10n.platformIos,
      _ => l10n.unknownValue,
    };

/// The icon of a device platform.
IconData platformIcon(String platform) => switch (platform) {
  DevicePlatform.web => Icons.language,
  DevicePlatform.windows => Icons.desktop_windows_outlined,
  DevicePlatform.macos => Icons.laptop_mac_outlined,
  DevicePlatform.android => Icons.phone_android_outlined,
  DevicePlatform.ios => Icons.phone_iphone_outlined,
  _ => Icons.computer_outlined,
};

/// A device's name, or its platform when it has none.
String deviceName(AppLocalizations l10n, DeviceRecord device) =>
    device.label.trim().isNotEmpty
    ? device.label.trim()
    : platformName(l10n, device.platform);

/// The person a device belongs to, or "Unknown".
String ownerName(AppLocalizations l10n, DeviceRecord device) =>
    device.ownerName.trim().isNotEmpty
    ? device.ownerName.trim()
    : l10n.unknownValue;

/// The device's name and its platform, "Mac · Web browser", or the name
/// alone when it already is the platform's name ("Windows computer").
String deviceAndPlatform(AppLocalizations l10n, DeviceRecord device) {
  final name = deviceName(l10n, device);
  final platform = platformName(l10n, device.platform);
  return name.toLowerCase() == platform.toLowerCase()
      ? name
      : '$name · $platform';
}
