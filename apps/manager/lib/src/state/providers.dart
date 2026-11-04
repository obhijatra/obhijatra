import 'dart:async';
import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart' show immutable, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obhijatra_manager/src/data/manager_api.dart';
import 'package:obhijatra_manager/src/data/models.dart';
import 'package:obhijatra_manager/src/data/pocketbase_api.dart';
import 'package:obhijatra_manager/src/data/problem.dart';
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
    state = url;
    unawaited(Preferences.saveServer(url));
  }
}

/// Holds the server address.
final serverUrlProvider = NotifierProvider<ServerUrlNotifier, String>(
  ServerUrlNotifier.new,
);

/// The server connection. Tests replace it with a fake.
final apiProvider = Provider<ManagerApi>(
  (ref) => PocketBaseApi(ref.watch(serverUrlProvider)),
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
Future<T> tracked<T>(Ref ref, Future<T> Function() call) =>
    _track(ref.read(onlineProvider.notifier), call);

/// Runs [call] from a screen, remembering whether the server could be
/// reached.
Future<T> trackedUi<T>(WidgetRef ref, Future<T> Function() call) =>
    _track(ref.read(onlineProvider.notifier), call);

Future<T> _track<T>(OnlineNotifier online, Future<T> Function() call) async {
  try {
    final result = await call();
    online.report(online: true);
    return result;
  } on Object catch (error) {
    final problem = problemFrom(error);
    // A refusal from the server still proves the server is there.
    online.report(online: problem.kind != ProblemKind.offline);
    throw problem;
  }
}

// ----------------------------------------------------------------- session

/// The signed-in staff user, or null.
class SessionNotifier extends Notifier<StaffUser?> {
  @override
  StaffUser? build() => ref.watch(apiProvider).currentUser;

  /// Signs in. Throws an [AppProblem] when the server says no.
  Future<void> signIn(String email, String password) async {
    final user = await tracked(
      ref,
      () => ref.read(apiProvider).signIn(email, password),
    );
    state = user;
  }

  /// Ends the session and forgets everything loaded for it.
  void signOut() {
    ref.read(apiProvider).signOut();
    state = null;
  }
}

/// Holds the signed-in user.
final sessionProvider = NotifierProvider<SessionNotifier, StaffUser?>(
  SessionNotifier.new,
);

String? _userId(Ref ref) => ref.watch(sessionProvider.select((u) => u?.id));

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
