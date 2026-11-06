import 'dart:async';
import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart' show immutable, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obhijatra_manager/src/data/manager_api.dart';
import 'package:obhijatra_manager/src/data/models.dart';
import 'package:obhijatra_manager/src/data/pocketbase_api.dart';
import 'package:obhijatra_manager/src/data/problem.dart';
import 'package:obhijatra_manager/src/device/device_http.dart';
import 'package:obhijatra_manager/src/device/identity_store.dart';
import 'package:obhijatra_manager/src/device/platform.dart';
import 'package:obhijatra_manager/src/state/preferences.dart';
import 'package:obhijatra_manager/src/xform/form_definition.dart';
import 'package:obhijatra_manager/src/xform/instance_parser.dart';

/// Failed requests are not retried behind the person's back: the screen shows
/// the problem and one "Try again" button instead.
Duration? noAutomaticRetry(int retryCount, Object error) => null;

// ---------------------------------------------------------------- language

/// The language the app starts in. Replaced in `main` with the saved choice.
final initialLocaleProvider = Provider<Locale>((ref) => const Locale('en'));

/// The language shown. English is the default; the choice is remembered.
class LocaleNotifier extends Notifier<Locale> {
  @override
  Locale build() => ref.watch(initialLocaleProvider);

  /// Shows the app in [locale] and remembers the choice.
  void select(Locale locale) {
    if (locale.languageCode == state.languageCode) return;
    state = Locale(locale.languageCode);
    unawaited(Preferences.saveLanguage(locale.languageCode));
  }
}

/// Holds the current [Locale].
final localeProvider = NotifierProvider<LocaleNotifier, Locale>(
  LocaleNotifier.new,
);

// -------------------------------------------------------------- connection

/// The server address the app starts with. Replaced in `main` on desktop.
final initialServerUrlProvider = Provider<String>((ref) => '');

/// The server address. On the web it is the address of the page itself.
class ServerUrlNotifier extends Notifier<String> {
  static const String _override = String.fromEnvironment('OBHIJATRA_SERVER');

  @override
  String build() {
    if (kIsWeb) return _override.isNotEmpty ? _override : Uri.base.origin;
    return ref.watch(initialServerUrlProvider);
  }

  /// Uses [url] from now on and remembers it (desktop only).
  void set(String url) {
    if (url != state) state = url;
    unawaited(Preferences.saveServer(url));
  }

  /// Uses [url] without remembering it, so the sign-in screen can ask a
  /// newly typed server which ways to sign in it offers (desktop only).
  void preview(String url) {
    if (url != state) state = url;
  }
}

/// Holds the server address.
final serverUrlProvider = NotifierProvider<ServerUrlNotifier, String>(
  ServerUrlNotifier.new,
);

/// Where this device's keys are kept, for the server in use: the
/// operating system's protected storage on the desktop, non-extractable
/// WebCrypto keys in the browser. Tests replace it.
final deviceIdentityStoreProvider = Provider<DeviceIdentityStore>(
  (ref) => platformIdentityStore(ref.watch(serverUrlProvider)),
);

/// Signs every request to the server in use with this device's keys
/// (docs/decisions/0008-device-trust.md).
final deviceSignerProvider = Provider<DeviceSigner>((ref) {
  ref.watch(serverUrlProvider);
  return DeviceSigner();
});

/// The server connection. Tests replace it with a fake.
final apiProvider = Provider<ManagerApi>(
  (ref) => PocketBaseApi(
    ref.watch(serverUrlProvider),
    signer: ref.watch(deviceSignerProvider),
  ),
);

/// Asks for this device to be checked with the server again: counts up
/// each time the server refuses a request because of the device (switched
/// off, approval run out, waiting, wrong clock). The device check watches
/// it and shows what to do.
class DeviceRecheckNotifier extends Notifier<int> {
  @override
  int build() => 0;

  /// Asks for another check.
  void request() => state++;
}

/// Holds the number of device checks asked for.
final deviceRecheckProvider = NotifierProvider<DeviceRecheckNotifier, int>(
  DeviceRecheckNotifier.new,
);

/// Whether the last request reached the server.
class OnlineNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  /// Records whether the server could be reached.
  void report({required bool online}) => state = online;
}

/// Holds whether the server can be reached.
final onlineProvider = NotifierProvider<OnlineNotifier, bool>(
  OnlineNotifier.new,
);

/// Runs [call] from a provider, remembering whether the server could be
/// reached.
Future<T> tracked<T>(Ref ref, Future<T> Function() call) => _track(
  ref.read(onlineProvider.notifier),
  ref.read(sessionProvider.notifier),
  ref.read(deviceRecheckProvider.notifier),
  call,
);

/// Runs [call] from a screen, remembering whether the server could be
/// reached.
Future<T> trackedUi<T>(WidgetRef ref, Future<T> Function() call) => _track(
  ref.read(onlineProvider.notifier),
  ref.read(sessionProvider.notifier),
  ref.read(deviceRecheckProvider.notifier),
  call,
);

/// Runs [call] for the device check itself: like [tracked], but a refusal
/// of the device does not ask for yet another device check.
Future<T> trackedDeviceCheck<T>(Ref ref, Future<T> Function() call) => _track(
  ref.read(onlineProvider.notifier),
  ref.read(sessionProvider.notifier),
  null,
  call,
);

Future<T> _track<T>(
  OnlineNotifier online,
  SessionNotifier session,
  DeviceRecheckNotifier? recheck,
  Future<T> Function() call,
) async {
  try {
    final result = await call();
    online.report(online: true);
    return result;
  } on Object catch (error) {
    final problem = problemFrom(error);
    // A refusal from the server still proves the server is there.
    online.report(online: problem.kind != ProblemKind.offline);
    // The server refuses everything until a one-time password is replaced:
    // the app shows the "choose your own password" step instead.
    if (problem.kind == ProblemKind.passwordChangeRequired) {
      session.requirePasswordChange();
    }
    // The device was switched off, ran out or waits: the device check
    // finds out which and shows what to do.
    if (recheck != null && isDeviceRefusal(problem.kind)) recheck.request();
    throw problem;
  }
}

// ----------------------------------------------------------------- session

/// The signed-in staff user, or null.
class SessionNotifier extends Notifier<StaffUser?> {
  @override
  StaffUser? build() => ref.watch(apiProvider).currentUser;

  /// [tracked] for the session itself, which cannot read its own provider.
  Future<T> _tracked<T>(Future<T> Function() call) => _track(
    ref.read(onlineProvider.notifier),
    this,
    ref.read(deviceRecheckProvider.notifier),
    call,
  );

  /// Signs a sign-in with the keys of whoever last used this device with
  /// this server, so the new session is tied to the device at once. When
  /// someone else signs in, the server ignores that signature and the
  /// device check ties the session instead.
  Future<void> _prepareDevice() async {
    final signer = ref.read(deviceSignerProvider)..clear();
    try {
      final store = ref.read(deviceIdentityStoreProvider);
      if (await store.support() != KeyStoreSupport.supported) return;
      final last = await store.lastAccount();
      final identity = last == null ? null : await store.load(last);
      if (identity?.deviceId != null) signer.use(identity!);
    } on Object {
      // Signed in without a signature; the device check ties the session.
    }
  }

  /// Signs in. Throws an [AppProblem] when the server says no.
  Future<void> signIn(String email, String password) async {
    await _prepareDevice();
    final user = await _tracked(
      () => ref.read(apiProvider).signIn(email, password),
    );
    // Kept in memory for a moment, so the person does not type their
    // one-time password twice.
    ref
        .read(typedOneTimePasswordProvider.notifier)
        .keep(user.mustChangePassword ? password : null);
    state = user;
  }

  /// Shows the "choose your own password" step: the server refused a
  /// request until the person replaces their one-time password.
  void requirePasswordChange() {
    final user = state;
    if (user == null || user.mustChangePassword) return;
    state = user.copyWith(mustChangePassword: true);
  }

  /// Replaces the one-time password and carries on signed in with the new
  /// password. Throws an [AppProblem] when the server says no; after
  /// [ProblemKind.passwordSavedSignIn] the person must sign in again.
  Future<void> chooseNewPassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = await _tracked(
      () => ref
          .read(apiProvider)
          .chooseNewPassword(
            currentPassword: currentPassword,
            newPassword: newPassword,
          ),
    );
    ref.read(typedOneTimePasswordProvider.notifier).keep(null);
    state = user;
  }

  /// Signs in with the code from an SMS. Throws an [AppProblem] when the
  /// server says no.
  Future<void> signInWithPhoneCode(String codeId, String code) async {
    await _prepareDevice();
    final user = await _tracked(
      () => ref.read(apiProvider).signInWithPhoneCode(codeId, code),
    );
    state = user;
  }

  /// Signs in with Google in the web browser. Returns false when the
  /// person cancelled or turned Google down.
  Future<bool> signInWithGoogle({
    required FutureOr<void> Function(Uri url) openUrl,
    required Future<void> cancelled,
  }) async {
    await _prepareDevice();
    final user = await _tracked(
      () => ref
          .read(apiProvider)
          .signInWithGoogle(openUrl: openUrl, cancelled: cancelled),
    );
    if (user == null) return false;
    state = user;
    return true;
  }

  // "Confirm it's you": some actions need a sign-in within the last 15
  // minutes (downloading data, docs/decisions/0009-data-export.md). The
  // person signs in again while signed in; the new session replaces the
  // old one. Unlike a sign-in from the sign-in screen, the device signer is
  // kept as it is, so the new session is this device's at once. On a
  // refusal the old session stays. Each returns the person signed in now
  // (null when they cancelled), who is the same person unless they chose
  // another Google account.

  /// Confirms with the signed-in person's password. Nothing keeps it.
  Future<StaffUser> confirmWithPassword(String password) async {
    final email = state?.email ?? '';
    if (email.isEmpty) throw const AppProblem(ProblemKind.signInRequired);
    final user = await _tracked(
      () => ref.read(apiProvider).signIn(email, password),
    );
    return state = user;
  }

  /// Confirms with the code from an SMS sent to the person's own number.
  Future<StaffUser> confirmWithPhoneCode(String codeId, String code) async {
    final user = await _tracked(
      () => ref.read(apiProvider).signInWithPhoneCode(codeId, code),
    );
    return state = user;
  }

  /// Confirms with Google in the web browser.
  Future<StaffUser?> confirmWithGoogle({
    required FutureOr<void> Function(Uri url) openUrl,
    required Future<void> cancelled,
  }) async {
    final user = await _tracked(
      () => ref
          .read(apiProvider)
          .signInWithGoogle(openUrl: openUrl, cancelled: cancelled),
    );
    if (user != null) state = user;
    return user;
  }

  /// Ends the session and forgets everything loaded for it. The device's
  /// keys stay, for the next sign-in.
  void signOut() {
    ref.read(apiProvider).signOut();
    ref.read(deviceSignerProvider).clear();
    ref.read(typedOneTimePasswordProvider.notifier).keep(null);
    state = null;
  }
}

/// Holds the signed-in user.
final sessionProvider = NotifierProvider<SessionNotifier, StaffUser?>(
  SessionNotifier.new,
);

/// The one-time password the person has just typed to sign in, kept in
/// memory only until they have chosen their own.
class TypedOneTimePasswordNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  /// Keeps [password], or forgets it with null.
  void keep(String? password) => state = password;
}

/// Holds the one-time password just typed, or null.
final typedOneTimePasswordProvider =
    NotifierProvider<TypedOneTimePasswordNotifier, String?>(
      TypedOneTimePasswordNotifier.new,
    );

String? _userId(Ref ref) => ref.watch(sessionProvider.select((u) => u?.id));

/// The ways to sign in the server offers. If the server cannot be asked,
/// email and password are shown on their own; they report any problem
/// themselves.
final signInMethodsProvider = FutureProvider.autoDispose<SignInMethods>((
  ref,
) async {
  final api = ref.watch(apiProvider);
  if (api.serverUrl.trim().isEmpty) return SignInMethods.passwordOnly;
  try {
    return await api.signInMethods();
  } on Object {
    return SignInMethods.passwordOnly;
  }
});

/// The organisation's name for the top bar.
final organisationNameProvider = FutureProvider<String>((ref) {
  _userId(ref);
  return tracked(ref, () => ref.read(apiProvider).organisationName());
});

// ------------------------------------------------------------------- forms

/// Forms and their versions.
final formsProvider = FutureProvider<List<FormSummary>>((ref) {
  _userId(ref);
  return tracked(ref, () => ref.read(apiProvider).listForms());
});

/// The form chosen in the list (record id).
class SelectedFormNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  /// Chooses a form (or none).
  void select(String? id) => state = id;
}

/// Holds the chosen form.
final selectedFormProvider = NotifierProvider<SelectedFormNotifier, String?>(
  SelectedFormNotifier.new,
);

/// The version chosen in the list (record id).
class SelectedVersionNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  /// Chooses a version (or none).
  void select(String? id) => state = id;
}

/// Holds the chosen version.
final selectedVersionProvider =
    NotifierProvider<SelectedVersionNotifier, String?>(
      SelectedVersionNotifier.new,
    );

/// The XForm text of a version.
final xformTextProvider = FutureProvider.family<String, FormVersion>((
  ref,
  version,
) {
  _userId(ref);
  return tracked(ref, () => ref.read(apiProvider).downloadXForm(version));
});

// ------------------------------------------------------------- submissions

/// How far back the date filter looks.
enum DatePreset {
  /// The last 7 days, including today.
  last7,

  /// The last 30 days, including today.
  last30,

  /// No date limit.
  allTime,

  /// A range chosen on the calendar.
  custom,
}

/// The submissions filters.
@immutable
class SubmissionFilter {
  /// Creates a filter state.
  const SubmissionFilter({required this.preset, required this.query});

  /// Which date choice is selected.
  final DatePreset preset;

  /// What is sent to the server.
  final SubmissionQuery query;
}

/// Holds the submissions filters and the current page.
class SubmissionFilterNotifier extends Notifier<SubmissionFilter> {
  @override
  SubmissionFilter build() => SubmissionFilter(
    preset: DatePreset.last7,
    query: _forPreset(const SubmissionQuery(), DatePreset.last7),
  );

  static SubmissionQuery _forPreset(SubmissionQuery base, DatePreset preset) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return switch (preset) {
      DatePreset.last7 => base.copyWith(
        from: today.subtract(const Duration(days: 6)),
        page: 1,
      ),
      DatePreset.last30 => base.copyWith(
        from: today.subtract(const Duration(days: 29)),
        page: 1,
      ),
      DatePreset.allTime ||
      DatePreset.custom => base.copyWith(clearDates: true, page: 1),
    };
  }

  /// Chooses a form (or all forms).
  void setForm(String? formRecordId) => state = SubmissionFilter(
    preset: state.preset,
    query: formRecordId == null
        ? state.query.copyWith(clearForm: true, page: 1)
        : state.query.copyWith(formRecordId: formRecordId, page: 1),
  );

  /// Chooses a date preset (not [DatePreset.custom]).
  void setPreset(DatePreset preset) => state = SubmissionFilter(
    preset: preset,
    query: _forPreset(state.query, preset),
  );

  /// Chooses a custom range of days, both included.
  void setRange(DateTime firstDay, DateTime lastDay) =>
      state = SubmissionFilter(
        preset: DatePreset.custom,
        query: state.query.copyWith(
          from: DateTime(firstDay.year, firstDay.month, firstDay.day),
          to: DateTime(lastDay.year, lastDay.month, lastDay.day + 1),
          page: 1,
        ),
      );

  /// Chooses a review state (or all).
  void setState(ReviewState? reviewState) => state = SubmissionFilter(
    preset: state.preset,
    query: reviewState == null
        ? state.query.copyWith(clearState: true, page: 1)
        : state.query.copyWith(state: reviewState, page: 1),
  );

  /// Goes to [page].
  void setPage(int page) => state = SubmissionFilter(
    preset: state.preset,
    query: state.query.copyWith(page: page),
  );

  /// Starts again from today's date for a relative preset.
  void refreshDates() {
    if (state.preset == DatePreset.last7 || state.preset == DatePreset.last30) {
      setPreset(state.preset);
    }
  }
}

/// Holds the submissions filters.
final submissionFilterProvider =
    NotifierProvider<SubmissionFilterNotifier, SubmissionFilter>(
      SubmissionFilterNotifier.new,
    );

/// One page of submissions.
final submissionsProvider = FutureProvider.autoDispose
    .family<SubmissionPage, SubmissionQuery>((ref, query) {
      _userId(ref);
      return tracked(ref, () => ref.read(apiProvider).listSubmissions(query));
    });

/// How many submissions are in each review state, for the tab badges.
final submissionCountsProvider = FutureProvider.autoDispose
    .family<Map<ReviewState, int>, SubmissionQuery>((ref, query) {
      _userId(ref);
      return tracked(ref, () => ref.read(apiProvider).countByState(query));
    });

/// Location names by path.
final locationNamesProvider = FutureProvider<Map<String, String>>((ref) {
  _userId(ref);
  return tracked(ref, () => ref.read(apiProvider).locationNames());
});

/// The submission open in the side panel (record id).
class SelectedSubmissionNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  /// Opens a submission (or closes the panel).
  void select(String? id) => state = id;
}

/// Holds the open submission.
final selectedSubmissionProvider =
    NotifierProvider<SelectedSubmissionNotifier, String?>(
      SelectedSubmissionNotifier.new,
    );

/// The parsed form definition of a form version, used to read answers.
final formDefinitionProvider =
    FutureProvider.family<FormDefinition, FormVersion>((ref, version) async {
      final xml = await ref.watch(xformTextProvider(version).future);
      return FormDefinition.parse(xml);
    });

/// What is needed to show one submission's answers.
@immutable
class AnswersRequest {
  /// Creates a request.
  const AnswersRequest({
    required this.submissionId,
    required this.versionId,
    required this.formRecordId,
    required this.lang,
  });

  /// The submission.
  final String submissionId;

  /// The form version the phone used.
  final String versionId;

  /// The form it belongs to.
  final String formRecordId;

  /// `en` or `bn`.
  final String lang;

  @override
  bool operator ==(Object other) =>
      other is AnswersRequest &&
      other.submissionId == submissionId &&
      other.versionId == versionId &&
      other.formRecordId == formRecordId &&
      other.lang == lang;

  @override
  int get hashCode => Object.hash(submissionId, versionId, formRecordId, lang);
}

/// The answers of a submission, with protected answers carrying no value.
///
/// If the form definition cannot be loaded, this fails with
/// [ProblemKind.formUnavailable] and NO answer is shown: without the
/// definition there is no way to tell which answers are protected.
final answersProvider = FutureProvider.autoDispose
    .family<List<Answer>, AnswersRequest>((ref, request) async {
      _userId(ref);
      final FormDefinition definition;
      try {
        final forms = await ref.watch(formsProvider.future);
        final version = forms
            .expand((form) => form.versions)
            .where((v) => v.id == request.versionId)
            .firstOrNull;
        if (version == null) {
          throw const AppProblem(ProblemKind.formUnavailable);
        }
        definition = await ref.watch(formDefinitionProvider(version).future);
      } on Object catch (error) {
        final problem = problemFrom(error);
        throw problem.kind == ProblemKind.offline ||
                problem.kind == ProblemKind.signInRequired
            ? problem
            : const AppProblem(ProblemKind.formUnavailable);
      }
      final xml = await tracked(
        ref,
        () => ref.read(apiProvider).downloadInstance(request.submissionId),
      );
      try {
        return parseAnswers(xml, definition, lang: request.lang);
      } on FormatException {
        throw const AppProblem(ProblemKind.unreadableFile);
      }
    });
