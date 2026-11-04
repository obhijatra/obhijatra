import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:obhijatra_core/obhijatra_core.dart';
import 'package:obhijatra_field/src/platform/file_attachment_store.dart';
import 'package:obhijatra_field/src/platform/multiple_ciphers_opener.dart';
import 'package:obhijatra_field/src/platform/secure_storage_key_store.dart';
import 'package:obhijatra_field/src/providers/app_lock_provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// Where the key to the device database is kept.
final keyStoreProvider = Provider<KeyStore>((ref) => SecureStorageKeyStore());

/// The app's private folder (not backed up, not visible to other apps).
final appSupportDirectoryProvider = FutureProvider<Directory>(
  (ref) => getApplicationSupportDirectory(),
);

/// How the device database file is opened.
final databaseOpenerProvider = FutureProvider<DeviceDatabaseOpener>((
  ref,
) async {
  final dir = await ref.watch(appSupportDirectoryProvider.future);
  return MultipleCiphersOpener(
    File('${dir.path}${Platform.pathSeparator}obhijatra.db'),
  );
});

/// The encrypted device database: opened only while the app lock allows it
/// ([AppLockState.opensData]), and closed again when the app locks.
///
/// While the app is locked it waits. Fails with an [ObhijatraException]
/// (never deletes anything) when the key or the file is not usable.
final deviceDatabaseProvider = FutureProvider<DeviceDatabase>((ref) async {
  final opens = ref.watch(
    appLockProvider.select((lock) => lock.value?.opensData ?? false),
  );
  if (!opens) return Completer<DeviceDatabase>().future;
  final opener = await ref.watch(databaseOpenerProvider.future);
  final db = await openDeviceDatabase(
    keyStore: ref.watch(keyStoreProvider),
    opener: opener,
  );
  ref.onDispose(() => unawaited(db.close()));
  // An online sign-in made while the database was closed brings a session.
  final session = ref.read(appLockProvider.notifier).takePendingSession();
  if (session != null) await SettingsRepository(db).saveSession(session);
  return db;
});

/// The files that go with submissions.
final attachmentStoreProvider = FutureProvider<AttachmentStore>((ref) async {
  final dir = await ref.watch(appSupportDirectoryProvider.future);
  return FileAttachmentStore(
    Directory('${dir.path}${Platform.pathSeparator}attachments'),
  );
});

/// Makes the HTTP client of the server connection; `null` uses the default.
/// Tests put a fake server here.
final httpClientFactoryProvider = Provider<http.Client Function()?>(
  (ref) => null,
);

/// The current time; tests fix it.
final nowProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Opens a web address outside the app; returns whether it opened.
final urlLauncherProvider = Provider<Future<bool> Function(Uri)>(
  (ref) =>
      (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);

/// Whether the phone has any network connection, now and when it changes.
///
/// "Connected" only means the phone is on a network; the sync engine still
/// has to reach the server.
final onlineProvider = StreamProvider<bool>((ref) async* {
  final connectivity = Connectivity();
  bool isOnline(List<ConnectivityResult> r) =>
      r.any((e) => e != ConnectivityResult.none);
  yield isOnline(await connectivity.checkConnectivity());
  yield* connectivity.onConnectivityChanged.map(isOnline);
});

/// Whether sync retries by itself on a timer (tests switch it off).
final syncAutoRetryProvider = Provider<bool>((ref) => true);
