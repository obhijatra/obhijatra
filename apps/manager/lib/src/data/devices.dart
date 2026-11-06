import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:obhijatra_device/obhijatra_device.dart';
import 'package:obhijatra_manager/src/data/models.dart';
import 'package:obhijatra_manager/src/data/people.dart';

// Device trust (docs/decisions/0008-device-trust.md): every computer,
// browser and phone is enrolled with its own keys and approved by a person.

/// Where a device stands with the server.
enum DeviceStatus {
  /// Enrolled, waiting for approval (or for a second org admin's approval).
  pending,

  /// Approved. The approval lasts a year; see [DeviceView.approvalExpired].
  active,

  /// Switched off. It stays off; the person enrols it again as a new device.
  revoked,

  /// A status this app does not know (a newer server).
  unknown;

  /// The status the server calls [wire].
  static DeviceStatus fromWire(String wire) => switch (wire) {
    'pending' => DeviceStatus.pending,
    'active' => DeviceStatus.active,
    'revoked' => DeviceStatus.revoked,
    _ => DeviceStatus.unknown,
  };
}

/// The platforms a device can report, as the server names them.
abstract final class DevicePlatform {
  /// A web browser (the manager app's web build).
  static const String web = 'web';

  /// The manager app on Windows.
  static const String windows = 'windows';

  /// The manager app on macOS.
  static const String macos = 'macos';

  /// The manager app on Linux.
  static const String linux = 'linux';

  /// The field app on Android.
  static const String android = 'android';

  /// The field app on iOS.
  static const String ios = 'ios';
}

/// The longest device label the server accepts, in characters.
const int maxDeviceLabel = 100;

/// A device as the device routes describe it (enrol, status, approve,
/// switch off). The check code is never part of it: the device and the
/// approver each work it out from the keys.
@immutable
class DeviceView {
  /// Creates the description.
  const DeviceView({
    required this.id,
    required this.status,
    required this.label,
    required this.platform,
    this.expires,
    this.approvedAt,
    this.needsSecondApproval = false,
    this.approvalExpired = false,
  });

  /// Reads the server's answer.
  factory DeviceView.fromJson(Map<String, dynamic> json) => DeviceView(
    id: json['id'] as String? ?? '',
    status: DeviceStatus.fromWire(json['status'] as String? ?? ''),
    label: json['label'] as String? ?? '',
    platform: json['platform'] as String? ?? '',
    expires: parseServerDate(json['expires'] as String? ?? ''),
    approvedAt: parseServerDate(json['approved_at'] as String? ?? ''),
    needsSecondApproval: json['needs_second_approval'] == true,
    approvalExpired: json['approval_expired'] == true,
  );

  /// The device's record id.
  final String id;

  /// Waiting, approved or switched off.
  final DeviceStatus status;

  /// The device's name, for example "Web browser (Chrome on Windows)".
  final String label;

  /// One of [DevicePlatform].
  final String platform;

  /// When the approval runs out, or null before approval.
  final DateTime? expires;

  /// When it was last approved, or null.
  final DateTime? approvedAt;

  /// An org admin's device approved once, waiting for a second org admin.
  final bool needsSecondApproval;

  /// Approved once, but the approval has run out (renewal needed).
  final bool approvalExpired;

  /// Whether the device may be used now.
  bool get usable => status == DeviceStatus.active && !approvalExpired;
}

/// A device in the list an approver sees (the `devices` collection), with
/// the name of the person it belongs to.
@immutable
class DeviceRecord {
  /// Creates the record.
  const DeviceRecord({
    required this.id,
    required this.ownerKind,
    required this.ownerId,
    required this.ownerName,
    required this.ownerRole,
    this.ownerContact = '',
    required this.label,
    required this.platform,
    required this.status,
    required this.signPublicKey,
    required this.encPublicKey,
    this.expires,
    this.approvedAt,
    this.created,
    this.firstApprovedBy = '',
  });

  /// Record id.
  final String id;

  /// Office staff (this app) or field staff (a phone).
  final PersonKind ownerKind;

  /// The person's record id.
  final String ownerId;

  /// The person's name, email or number; empty if the server did not say.
  final String ownerName;

  /// The person's email or phone number, for the approver to reach them;
  /// empty when [ownerName] already is it, or the server did not say.
  final String ownerContact;

  /// The person's role, for example `org_admin` or `field_officer`.
  final String ownerRole;

  /// The device's name.
  final String label;

  /// One of [DevicePlatform].
  final String platform;

  /// Waiting, approved or switched off.
  final DeviceStatus status;

  /// The Ed25519 public key, standard base64.
  final String signPublicKey;

  /// The X25519 public key, standard base64.
  final String encPublicKey;

  /// When the approval runs out, or null.
  final DateTime? expires;

  /// When it was last approved, or null.
  final DateTime? approvedAt;

  /// When it was enrolled.
  final DateTime? created;

  /// The org admin who gave an org admin's device its first approval, while
  /// it waits for a second; empty otherwise.
  final String firstApprovedBy;

  /// Whether the device belongs to an organisation admin (two approvals).
  bool get ownerIsOrgAdmin =>
      ownerKind == PersonKind.staff && ownerRole == orgAdminRole;

  /// Approved, but the approval has run out by [now].
  bool approvalExpiredAt(DateTime now) {
    final end = expires;
    return status == DeviceStatus.active && (end == null || !end.isAfter(now));
  }

  /// Waiting for approval: new, or approved before and run out.
  bool waitingAt(DateTime now) =>
      status == DeviceStatus.pending || approvalExpiredAt(now);

  /// An org admin's device with one approval, waiting for a second.
  bool get needsSecondApproval =>
      status == DeviceStatus.pending && firstApprovedBy.isNotEmpty;

  /// Whether [user] owns it.
  bool isOwnedBy(StaffUser user) =>
      ownerKind == PersonKind.staff && ownerId == user.id;

  /// Whether both public keys can be read, so its numbers can be checked.
  bool get keysReadable =>
      _key(signPublicKey) != null && _key(encPublicKey) != null;
}

/// What came of comparing the numbers an approver typed with a device's
/// keys.
enum CodeCheck {
  /// Fewer or more than 18 digits.
  incomplete,

  /// 18 digits that do not belong to this device.
  mismatch,

  /// The numbers belong to this device.
  match,

  /// The device's keys cannot be read, so it must not be approved.
  unreadableKeys,
}

/// Compares what an approver [typed] (English or Bangla digits, spaces and
/// dashes) with the code worked out from [device]'s public keys.
///
/// The expected code is never returned, so no screen can show it: an
/// approver who could see it would not need to read it from the person's
/// own screen.
CodeCheck checkTypedCode(DeviceRecord device, String typed) {
  final digits = normaliseCheckCode(typed);
  if (digits.length != checkCodeDigits) return CodeCheck.incomplete;
  final sign = _key(device.signPublicKey);
  final enc = _key(device.encPublicKey);
  if (sign == null || enc == null) return CodeCheck.unreadableKeys;
  return deviceCheckCode(sign, enc) == digits
      ? CodeCheck.match
      : CodeCheck.mismatch;
}

List<int>? _key(String text) {
  try {
    final bytes = base64.decode(text);
    return bytes.length == 32 ? bytes : null;
  } on FormatException {
    return null;
  }
}

/// Whether [user] may approve [device] now, as the server decides it: org
/// admins approve anyone, branch managers field staff (the server lists
/// only those in their part of the tree), nobody their own device, and an
/// org admin's device needs a second, different org admin.
bool mayApproveDevice(StaffUser user, DeviceRecord device, DateTime now) {
  if (!user.canApproveDevices || device.isOwnedBy(user)) return false;
  if (!device.waitingAt(now)) return false;
  if (device.firstApprovedBy == user.id) return false;
  return user.isOrgAdmin || device.ownerKind == PersonKind.field;
}

/// Whether [user] may switch [device] off: their own, or as an org admin
/// any device, or as a branch manager the field staff devices the server
/// lists for them.
bool maySwitchOffDevice(StaffUser user, DeviceRecord device) {
  if (device.status == DeviceStatus.revoked) return false;
  if (device.isOwnedBy(user)) return true;
  if (!user.canApproveDevices) return false;
  return user.isOrgAdmin || device.ownerKind == PersonKind.field;
}

/// A date as PocketBase writes it ("2026-11-06 09:00:00.000Z"), in local
/// time, or null when empty or unreadable.
DateTime? parseServerDate(String text) => text.isEmpty
    ? null
    : DateTime.tryParse(text.replaceFirst(' ', 'T'))?.toLocal();
