import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// The keys of one device: an Ed25519 key that signs its requests and an
/// X25519 key for end-to-end encryption (registered now, used later).
///
/// The private keys never leave the device. Implementations keep them in
/// the platform's protected storage: [SoftwareDeviceKeys] for seeds kept in
/// the Android Keystore, the Apple Keychain, Windows DPAPI or the Linux
/// secret service; a web implementation keeps non-extractable WebCrypto
/// keys.
abstract interface class DeviceKeys {
  /// The Ed25519 public key (32 bytes).
  Uint8List get signPublicKey;

  /// The X25519 public key (32 bytes).
  Uint8List get encPublicKey;

  /// The Ed25519 signature (64 bytes) of [message].
  Future<Uint8List> sign(Uint8List message);
}

/// [DeviceKeys] made from two 32-byte seeds, in pure Dart.
///
/// Store [signSeed] and [encSeed] only in the platform's protected storage
/// (for example `flutter_secure_storage`), never in a plain file.
final class SoftwareDeviceKeys implements DeviceKeys {
  SoftwareDeviceKeys._(
    this._signSeed,
    this._encSeed,
    this._signPair,
    this.signPublicKey,
    this.encPublicKey,
  );

  /// Makes the keys from seeds stored earlier.
  static Future<SoftwareDeviceKeys> fromSeeds(
    List<int> signSeed,
    List<int> encSeed,
  ) async {
    if (signSeed.length != 32 || encSeed.length != 32) {
      throw ArgumentError('Device key seeds are 32 bytes each');
    }
    final signPair = await Ed25519().newKeyPairFromSeed(signSeed);
    final encPair = await X25519().newKeyPairFromSeed(encSeed);
    final signPublic = await signPair.extractPublicKey();
    final encPublic = await encPair.extractPublicKey();
    return SoftwareDeviceKeys._(
      Uint8List.fromList(signSeed),
      Uint8List.fromList(encSeed),
      signPair,
      Uint8List.fromList(signPublic.bytes),
      Uint8List.fromList(encPublic.bytes),
    );
  }

  /// Makes new keys from the platform's secure random generator.
  static Future<SoftwareDeviceKeys> generate([Random? random]) {
    final source = random ?? Random.secure();
    List<int> seed() => List<int>.generate(32, (_) => source.nextInt(256));
    return fromSeeds(seed(), seed());
  }

  final Uint8List _signSeed;
  final Uint8List _encSeed;
  final SimpleKeyPair _signPair;

  @override
  final Uint8List signPublicKey;

  @override
  final Uint8List encPublicKey;

  /// A copy of the Ed25519 seed, for protected storage only.
  Uint8List get signSeed => Uint8List.fromList(_signSeed);

  /// A copy of the X25519 seed, for protected storage only.
  Uint8List get encSeed => Uint8List.fromList(_encSeed);

  @override
  Future<Uint8List> sign(Uint8List message) async {
    final signature = await Ed25519().sign(message, keyPair: _signPair);
    return Uint8List.fromList(signature.bytes);
  }

  @override
  String toString() => 'SoftwareDeviceKeys(<redacted>)';
}
