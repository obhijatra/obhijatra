import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obhijatra_core/obhijatra_core.dart';
import 'package:obhijatra_field/src/app_info.dart';
import 'package:obhijatra_field/src/providers/app_lock_provider.dart';
import 'package:obhijatra_field/src/providers/platform_providers.dart';

/// Reads and writes this device's settings.
final settingsRepositoryProvider = FutureProvider<SettingsRepository>(
  (ref) async =>
      SettingsRepository(await ref.watch(deviceDatabaseProvider.future)),
);

/// A server connection and the address it uses.
class ServerConnection {
  /// Creates the pair.
  const ServerConnection(this.server, this.address);

  /// The client for the server.
  final ObhijatraServer server;

  /// The address the person typed, for display.
  final Uri address;
}

/// The connection to the organisation's server; `null` until the person
/// has typed a server address.
final serverProvider = AsyncNotifierProvider<ServerNotifier, ServerConnection?>(
  ServerNotifier.new,
);

/// Holds the [ServerConnection] for the saved server address.
class ServerNotifier extends AsyncNotifier<ServerConnection?> {
  ServerConnection? _connection;

  @override
  Future<ServerConnection?> build() async {
    ref.onDispose(() => _connection?.server.close());
    final settings = await ref.watch(settingsRepositoryProvider.future);
    final address = await settings.read(serverUrlSettingKey);
    if (address == null) return null;
    final uri = Uri.parse(address);
    // The app lock needs the address to sign in before the database opens.
    await ref.read(appLockProvider.notifier).rememberServerAddress(uri);
    return _connection = await _create(uri, settings);
  }

  Future<ServerConnection> _create(
    Uri address,
    SettingsRepository settings,
  ) async {
    return ServerConnection(
      ObhijatraServer(
        baseUrl: address,
        appVersion: appReleaseVersion,
        authStore: await settings.authStore(),
        httpClientFactory: ref.read(httpClientFactoryProvider),
      ),
      address,
    );
  }

  /// Saves [address] as the organisation's server and connects to it.
  Future<void> setAddress(Uri address) async {
    final settings = await ref.read(settingsRepositoryProvider.future);
    await settings.write(serverUrlSettingKey, address.toString());
    await ref.read(appLockProvider.notifier).rememberServerAddress(address);
    final next = await _create(address, settings);
    _connection?.server.close();
    _connection = next;
    state = AsyncData<ServerConnection?>(next);
  }

  /// Forgets the server address, to type another one.
  Future<void> forgetAddress() async {
    final settings = await ref.read(settingsRepositoryProvider.future);
    await settings.delete(serverUrlSettingKey);
    _connection?.server.close();
    _connection = null;
    state = const AsyncData<ServerConnection?>(null);
  }
}

/// The field user signed in on this phone, or `null`.
///
/// A person whose session has run out is still "signed in" here, so they can
/// keep filling forms offline; only sending needs a valid session.
final sessionProvider = NotifierProvider<SessionNotifier, SignedInUser?>(
  SessionNotifier.new,
);

/// Holds the signed-in [SignedInUser].
class SessionNotifier extends Notifier<SignedInUser?> {
  @override
  SignedInUser? build() {
    final user = ref.watch(serverProvider).value?.server.currentUser;
    // A saved one-time-password session (the app closed before the person
    // chose their own password) is no sign-in: they sign in again.
    return user != null && user.mustChangePassword ? null : user;
  }

  /// Signs in with [email] and [password] (see [signInWith]).
  Future<void> signIn({required String email, required String password}) =>
      signInWith((server) => server.signIn(email: email, password: password));

  /// Signs in by [method] (email and password, SMS code or Google) on the
  /// saved server. Throws an [ObhijatraException] with a plain-language
  /// code. Every method ends the same way: the app lock records the online
  /// sign-in (and may ask for an app PIN).
  ///
  /// An account with a one-time password throws [PasswordChangeNeeded] and
  /// records nothing: the person chooses their own password with
  /// [changePassword] first.
  Future<void> signInWith(
    Future<SignedInUser> Function(ObhijatraServer server) method,
  ) async {
    final server = ref.read(serverProvider).requireValue!.server;
    final user = await method(server);
    if (user.mustChangePassword) throw PasswordChangeNeeded(user);
    state = user;
    await ref.read(appLockProvider.notifier).signedInOnline(user);
  }

  /// Chooses the person's own password in place of a one-time password,
  /// then carries on exactly as a sign-in does (see [signInWith]): the new
  /// password signs in again, because the change ends every session.
  /// Throws an [ObhijatraException]; after
  /// [ProblemCode.passwordChangedSignInAgain] no session is left.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) => signInWith(
    (server) => server.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    ),
  );

  /// Forgets the session on this phone. Unsent forms stay.
  void signOut() {
    ref.read(serverProvider).value?.server.signOut();
    state = null;
  }
}
