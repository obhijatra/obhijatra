import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Switches for work that is built in the next milestone.
///
/// Everything behind a switch that is off is invisible: there is no menu item,
/// no button and no "coming soon" text. Turning a switch on is a code change
/// made together with the feature itself.
class FeatureFlags {
  /// Creates the flags; all are off by default.
  const FeatureFlags({
    this.deviceEnrolment = false,
    this.keyCeremony = false,
    this.decryptProtected = false,
  });

  /// Approving field officers' phones (the "Add a device" screens).
  final bool deviceEnrolment;

  /// Creating and backing up the organisation's keys.
  final bool keyCeremony;

  /// Reading protected answers in the desktop app. Never honoured on the web:
  /// see `AnswerList`.
  final bool decryptProtected;
}

/// The flags in force. Tests replace it.
final featureFlagsProvider = Provider<FeatureFlags>(
  (ref) => const FeatureFlags(),
);
