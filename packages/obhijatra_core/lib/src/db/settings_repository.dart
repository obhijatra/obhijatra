import 'package:obhijatra_core/src/db/device_database.dart';
import 'package:pocketbase/pocketbase.dart';

/// Reads and writes the device's key-value settings.
final class SettingsRepository {
  /// Creates the repository on [db].
  SettingsRepository(this._db);

  final DeviceDatabase _db;

  /// The setting holding the signed-in session (token and user record).
  static const String sessionKey = 'auth.session';

  /// The setting holding the id of the field user whose submissions this
  /// database holds.
  static const String ownerKey = 'sync.owner_user_id';

  /// The setting holding the time of the last complete sync.
  static const String lastSyncedAtKey = 'sync.last_synced_at';

  /// The value of [key], or `null` if it is not set.
  Future<String?> read(String key) async {
    final row = await (_db.select(
      _db.deviceSettings,
    )..where((s) => s.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  /// Sets [key] to [value].
  Future<void> write(String key, String value) => _db
      .into(_db.deviceSettings)
      .insertOnConflictUpdate(
        DeviceSettingsCompanion.insert(key: key, value: value),
      );

  /// Removes [key].
  Future<void> delete(String key) =>
      (_db.delete(_db.deviceSettings)..where((s) => s.key.equals(key))).go();

  /// The time of the last sync that reached the server and handled every
  /// due submission, if any.
  Future<DateTime?> lastSyncedAt() async {
    final value = await read(lastSyncedAtKey);
    return value == null ? null : DateTime.tryParse(value);
  }

  /// Records [time] as the last complete sync.
  Future<void> setLastSyncedAt(DateTime time) =>
      write(lastSyncedAtKey, time.toUtc().toIso8601String());

  /// A session store for signing in while the device database is still
  /// closed (the app lock's online sign-in): [onSave] receives the data
  /// that [authStore] would have stored, or `null` when the session is
  /// cleared. Store it with [saveSession] once the database is open.
  ///
  /// [initial] is session data an earlier detached store gave, to carry on
  /// with that session (for example, to replace a one-time password).
  static AuthStore detachedAuthStore(
    void Function(String? data) onSave, {
    String? initial,
  }) => AsyncAuthStore(
    initial: initial,
    save: (data) async => onSave(data.isEmpty ? null : data),
    clear: () async => onSave(null),
  );

  /// Stores session [data] captured by [detachedAuthStore], replacing the
  /// saved session.
  Future<void> saveSession(String data) => write(sessionKey, data);

  /// A PocketBase session store that keeps the session in this (encrypted)
  /// database, so sync continues after the app restarts.
  Future<AuthStore> authStore() async => AsyncAuthStore(
    initial: await read(sessionKey),
    save: (data) => write(sessionKey, data),
    clear: () => delete(sessionKey),
  );
}
