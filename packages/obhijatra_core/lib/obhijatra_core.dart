/// Pure-Dart core of Obhijatra.
///
/// This library must never import Flutter, `dart:html` or `package:js`, and
/// may import only `package:drift/drift.dart` from drift. The test suite
/// enforces these rules.
///
/// - Device database: [DeviceDatabase], opened with [openDeviceDatabase]
///   from an app-supplied [KeyStore] and [DeviceDatabaseOpener].
/// - Forms: [FormRepository], [FormEntrySession], [DraftRepository].
/// - Server: [ObhijatraServer] (handshake, sign-in by email and password,
///   SMS code or Google, replacing a one-time password, forms,
///   submissions); [parsePhoneNumber] reads a typed mobile number.
/// - Sync: [OutboxRepository] and [SyncEngine] with its [SyncStatus].
/// - Problems: every failure carries a plain-language [ProblemCode].
/// - App lock: [AppLock] (app PIN, wrong-PIN waits, offline limit) over an
///   app-supplied [SecureValueStore].
library;

export 'src/db/device_database.dart'
    show
        CachedForm,
        CachedFormVersion,
        DeviceDatabase,
        DeviceSetting,
        Draft,
        OutboxEntry,
        OutboxState;
export 'src/db/settings_repository.dart';
export 'src/forms/draft_repository.dart';
export 'src/forms/form_entry.dart';
export 'src/forms/form_repository.dart';
export 'src/forms/instance_xml.dart' show newInstanceId;
export 'src/forms/xform_info.dart';
export 'src/phone_number.dart';
export 'src/problem.dart';
export 'src/security/app_lock.dart';
export 'src/security/field_protector.dart';
export 'src/security/key_store.dart';
export 'src/server/obhijatra_server.dart';
export 'src/server/request_signer.dart';
export 'src/server/server_models.dart';
export 'src/sync/backoff.dart';
export 'src/sync/outbox_repository.dart';
export 'src/sync/sync_engine.dart';
export 'src/version.dart';
