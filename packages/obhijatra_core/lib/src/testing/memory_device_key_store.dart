import 'package:obhijatra_core/src/security/device_identity.dart';

/// A [DeviceKeyStore] in memory, for tests: what an app keeps in the
/// platform's protected storage, per person, as text, so a test can look at
/// it, damage it or carry it from one "start of the app" to the next.
final class MemoryDeviceKeyStore implements DeviceKeyStore {
  /// The person whose keys sign now.
  String? currentAccount;

  /// The stored seeds by person, as [DeviceKeySeeds.toText] writes them.
  final Map<String, String> seeds = {};

  /// The stored enrolments by person, as [DeviceEnrolment.encode] writes
  /// them.
  final Map<String, String> enrolments = {};

  /// How many times new seeds were stored.
  int seedWrites = 0;

  /// The current person's stored seeds, if any.
  String? get seedsText => seeds[currentAccount];

  /// The current person's stored enrolment, if any.
  String? get enrolmentText => enrolments[currentAccount];

  /// Replaces (or, with `null`, removes) the current person's stored
  /// enrolment.
  set enrolmentText(String? text) {
    final account = currentAccount;
    if (account == null) throw StateError('Nobody has keys yet');
    if (text == null) {
      enrolments.remove(account);
    } else {
      enrolments[account] = text;
    }
  }

  @override
  Future<String?> readCurrentAccount() async => currentAccount;

  @override
  Future<void> writeCurrentAccount(String account) async =>
      currentAccount = account;

  @override
  Future<DeviceKeySeeds?> readKeySeeds(String account) async =>
      DeviceKeySeeds.fromText(seeds[account]);

  @override
  Future<void> writeKeySeeds(String account, DeviceKeySeeds keySeeds) async {
    seedWrites++;
    seeds[account] = keySeeds.toText();
  }

  @override
  Future<DeviceEnrolment?> readEnrolment(String account) async =>
      DeviceEnrolment.decode(enrolments[account]);

  @override
  Future<void> writeEnrolment(
    String account,
    DeviceEnrolment enrolment,
  ) async => enrolments[account] = enrolment.encode();

  @override
  Future<void> clear(String account) async {
    seeds.remove(account);
    enrolments.remove(account);
  }

  @override
  Future<void> clearAll() async {
    seeds.clear();
    enrolments.clear();
    currentAccount = null;
  }
}
