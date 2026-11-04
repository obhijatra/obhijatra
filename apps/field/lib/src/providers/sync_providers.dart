import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obhijatra_core/obhijatra_core.dart';
import 'package:obhijatra_field/src/providers/platform_providers.dart';
import 'package:obhijatra_field/src/providers/session_providers.dart';

/// The engine that sends finished forms; `null` before a server is chosen.
final syncEngineProvider = FutureProvider<SyncEngine?>((ref) async {
  final connection = await ref.watch(serverProvider.future);
  if (connection == null) return null;
  final db = await ref.watch(deviceDatabaseProvider.future);
  final attachments = await ref.watch(attachmentStoreProvider.future);
  final engine = SyncEngine(
    database: db,
    server: connection.server,
    attachments: attachments,
    autoRetry: ref.watch(syncAutoRetryProvider),
  );
  ref.onDispose(() => unawaited(engine.dispose()));
  await engine.start();
  return engine;
});

/// What the SyncStatus parts of the screens show, live.
final syncStatusProvider = StreamProvider<SyncStatus>((ref) async* {
  final engine = await ref.watch(syncEngineProvider.future);
  if (engine == null) {
    yield const SyncStatus();
    return;
  }
  yield* engine.watchStatus();
});

/// Sends waiting forms now. Never throws.
Future<SyncReport> syncNow(WidgetRef ref, {bool ignoreBackoff = false}) async {
  final engine = await ref.read(syncEngineProvider.future);
  return engine?.syncNow(ignoreBackoff: ignoreBackoff) ?? const SyncReport();
}

/// Where the last "update forms" stands.
@immutable
class FormsRefreshState {
  /// Creates the state.
  const FormsRefreshState({this.isRefreshing = false, this.problem});

  /// Whether forms are being downloaded now.
  final bool isRefreshing;

  /// Why the last update failed, or `null`.
  final ProblemCode? problem;
}

/// Downloads new published forms.
final formsRefreshProvider =
    NotifierProvider<FormsRefreshNotifier, FormsRefreshState>(
      FormsRefreshNotifier.new,
    );

/// Runs "update forms".
class FormsRefreshNotifier extends Notifier<FormsRefreshState> {
  @override
  FormsRefreshState build() => const FormsRefreshState();

  /// Downloads every published form version not yet on the phone.
  Future<void> refresh() async {
    if (state.isRefreshing) return;
    final server = ref.read(serverProvider).value?.server;
    if (server == null) return;
    state = const FormsRefreshState(isRefreshing: true);
    ProblemCode? problem;
    try {
      final db = await ref.read(deviceDatabaseProvider.future);
      await FormRepository(db).refreshFromServer(server);
    } on ObhijatraException catch (e) {
      problem = e.code;
    } on Object {
      problem = ProblemCode.unknown;
    }
    state = FormsRefreshState(problem: problem);
  }
}

/// Starts a sync, and an "update forms", when the app comes back to the
/// front and when the phone gets a connection again. Watch it once while the
/// person is signed in.
final syncTriggersProvider = Provider<void>((ref) {
  final observer = _ResumeObserver(() {
    unawaited(_syncAndRefresh(ref));
  });
  WidgetsBinding.instance.addObserver(observer);
  ref.onDispose(() => WidgetsBinding.instance.removeObserver(observer));

  ref.listen<AsyncValue<bool>>(onlineProvider, (previous, next) {
    final wasOnline = previous?.value ?? false;
    if (next.value == true && !wasOnline) {
      // Signal is back: try now, without waiting out an earlier back-off.
      unawaited(_syncAndRefresh(ref, ignoreBackoff: true));
    }
  });
});

Future<void> _syncAndRefresh(Ref ref, {bool ignoreBackoff = false}) async {
  try {
    final engine = await ref.read(syncEngineProvider.future);
    await engine?.syncNow(ignoreBackoff: ignoreBackoff);
    if (ref.read(sessionProvider) != null) {
      await ref.read(formsRefreshProvider.notifier).refresh();
    }
  } on Object {
    // Sync never throws; a failure here is only a missing provider while the
    // app closes.
  }
}

class _ResumeObserver with WidgetsBindingObserver {
  _ResumeObserver(this.onResume);

  final VoidCallback onResume;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) onResume();
  }
}
