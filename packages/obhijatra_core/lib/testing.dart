/// Test helpers for apps built on `obhijatra_core`: a [FakeObhijatraServer]
/// that stands in for `obhijatra-server` in widget and unit tests (device
/// trust included), and a [MemoryDeviceKeyStore] for a device's keys.
///
/// ```dart
/// import 'package:obhijatra_core/testing.dart';
/// ```
///
/// Import it from tests only. It is pure Dart, like the rest of the core.
library;

export 'src/testing/fake_obhijatra_server.dart';
export 'src/testing/memory_device_key_store.dart';
