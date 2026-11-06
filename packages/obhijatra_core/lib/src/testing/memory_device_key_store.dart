import 'package:obhijatra_core/src/security/device_identity.dart';

/// A [DeviceKeyStore] in memory, for tests: what an app keeps in the
/// platform's protected storage, as text, so a test can look at it, damage
/// it or carry it from one "start of the app" to the next.
final class MemoryDeviceKeyStore implements DeviceKeyStore {
  /// The stored seeds, as [DeviceKeySeeds.toText] writes them.
  String? seedsText;

  /// The stored enrolment, as [DeviceEnrolment.encode] writes it.
  String? enrolmentText;

  /// How many times new seeds were stored.
  int seedWrites = 0;

  @override
  Future<DeviceKeySeeds?> readKeySeeds() async =>
      DeviceKeySeeds.fromText(seedsText);

  @override
  Future<void> writeKeySeeds(DeviceKeySeeds seeds) async {
    seedWrites++;
    seedsText = seeds.toText();
  }

  @override
  Future<DeviceEnrolment?> readEnrolment() async =>
      DeviceEnrolment.decode(enrolmentText);

  @override
  Future<void> writeEnrolment(DeviceEnrolment enrolment) async =>
      enrolmentText = enrolment.encode();

  @override
  Future<void> clear() async {
    seedsText = null;
    enrolmentText = null;
  }
}
