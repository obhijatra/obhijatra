import 'dart:async';
import 'dart:math' show min;
import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obhijatra_core/obhijatra_core.dart';
import 'package:obhijatra_field/src/providers/locale_provider.dart';
import 'package:obhijatra_field/src/providers/platform_providers.dart';

/// Which form to fill: a new copy of the newest version of [formId], or the
/// draft [draftInstanceId].
@immutable
class FormEntryArgs {
  /// Creates the arguments.
  const FormEntryArgs({
    required this.formId,
    this.draftInstanceId,
    this.token = 0,
  });

  /// The XForm id.
  final String formId;

  /// The draft to continue, or `null` to start a new copy.
  final String? draftInstanceId;

  /// Tells two "start a new copy" requests apart, so each starts fresh.
  final int token;

  @override
  bool operator ==(Object other) =>
      other is FormEntryArgs &&
      other.formId == formId &&
      other.draftInstanceId == draftInstanceId &&
      other.token == token;

  @override
  int get hashCode => Object.hash(formId, draftInstanceId, token);
}

/// The form is not on the phone (it was never downloaded).
class FormNotOnPhone implements Exception {
  /// Creates the exception.
  const FormNotOnPhone();
}

/// What the form-filling screens show now.
@immutable
class FormEntryState {
  /// Creates the state.
  const FormEntryState({
    required this.title,
    required this.screen,
    required this.step,
    required this.total,
    required this.answered,
    required this.answerable,
    required this.canGoBack,
    required this.startedAt,
    required this.errors,
    required this.revision,
    this.savedAt,
  });

  /// The form title.
  final String? title;

  /// What to show.
  final FormScreen screen;

  /// The number of the first question on the screen among the [total]
  /// (1 is the first; at the end of the form it is [total]).
  final int step;

  /// How many questions apply to this person's answers now, notes
  /// included; it changes as answers turn questions on and off.
  final int total;

  /// How many of the questions that take an answer have one.
  final int answered;

  /// How many questions that apply take an answer (notes left out).
  final int answerable;

  /// Whether there is an earlier screen.
  final bool canGoBack;

  /// When this copy was started.
  final DateTime startedAt;

  /// Messages to show, by question key.
  final Map<String, ValidationMessage> errors;

  /// Changes with every update so listeners always notice.
  final int revision;

  /// When the answers were last saved on the phone.
  final DateTime? savedAt;
}

/// What [FormEntryController.finish] did.
sealed class FinishResult {
  const FinishResult();
}

/// The form is in the outbox under [instanceId].
final class FinishQueued extends FinishResult {
  /// Creates the result.
  const FinishQueued(this.instanceId);

  /// The queued submission.
  final String instanceId;
}

/// Questions must be fixed first; the form has not moved.
final class FinishBlocked extends FinishResult {
  /// Creates the result.
  const FinishBlocked(this.failures);

  /// Every question to fix, in form order; open one with
  /// [FormEntryController.jumpTo].
  final List<FailedQuestion> failures;
}

/// Chooses the form language that matches [locale], or `null` to keep the
/// form's own default.
String? pickFormLanguage(List<String> languages, Locale locale) {
  final code = locale.languageCode.toLowerCase();
  final names = switch (code) {
    'bn' => const ['bangla', 'bengali', 'বাংলা'],
    'en' => const ['english'],
    _ => const <String>[],
  };
  for (final language in languages) {
    final low = language.toLowerCase();
    if (low == code ||
        low.contains('($code)') ||
        low.startsWith('$code-') ||
        low.startsWith('${code}_') ||
        names.any(low.contains)) {
      return language;
    }
  }
  return null;
}

/// The form being filled.
final formEntryProvider = AsyncNotifierProvider.autoDispose
    .family<FormEntryController, FormEntryState, FormEntryArgs>(
      FormEntryController.new,
    );

/// Runs one form-filling session: answers, moving between questions,
/// saving drafts and finishing into the outbox.
class FormEntryController extends AsyncNotifier<FormEntryState> {
  /// Creates the controller for [args].
  FormEntryController(this.args);

  /// Which form this controller fills.
  final FormEntryArgs args;

  late FormEntrySession _session;
  late DeviceDatabase _db;
  late DateTime _startedAt;
  final Map<String, ValidationMessage> _errors = <String, ValidationMessage>{};
  DateTime? _savedAt;
  int _revision = 0;
  Timer? _saveTimer;
  bool _dirty = false;
  bool _completed = false;
  bool _closed = false;

  @override
  Future<FormEntryState> build() async {
    _db = await ref.watch(deviceDatabaseProvider.future);
    final forms = FormRepository(_db);
    final drafts = DraftRepository(_db);

    Draft? draft;
    CachedFormVersion? cached;
    if (args.draftInstanceId != null) {
      draft = await drafts.find(args.draftInstanceId!);
      if (draft == null) throw const FormNotOnPhone();
      cached = await forms.formVersion(draft.formId, draft.formVersion);
    } else {
      cached = await forms.latestVersion(args.formId);
    }
    if (cached == null) throw const FormNotOnPhone();

    final locale = ref.read(localeProvider);
    final session = await FormEntrySession.start(
      xformXml: cached.xformXml,
      draftXml: draft?.instanceXml,
      instanceId: draft?.instanceId,
      language: null,
    );
    session.language =
        pickFormLanguage(session.languages, locale) ?? session.language;
    _session = session;
    _startedAt = draft?.createdAt.toLocal() ?? ref.read(nowProvider)();

    ref.listen<Locale>(localeProvider, (previous, next) {
      final picked = pickFormLanguage(_session.languages, next);
      if (picked != null && !_closed) {
        _session.language = picked;
        _publish();
      }
    });
    ref.onDispose(() {
      _closed = true;
      _saveTimer?.cancel();
      unawaited(_flushAndClose());
    });

    return _snapshot();
  }

  Future<void> _flushAndClose() async {
    try {
      if (_dirty && !_completed) {
        await DraftRepository(_db).save(_session);
      }
      await _session.close();
    } on Object {
      // The app is closing; the last debounced save is best effort.
    }
  }

  FormEntryState _snapshot() {
    final progress = _session.progress;
    final position = _session.position;
    final total = _session.total;
    return FormEntryState(
      title: _session.title,
      screen: _session.screen,
      // "Question N of M": N counts from 1; at the end it stays at M.
      step: total == 0 ? 0 : min(position + 1, total),
      total: total,
      answered: progress.answered,
      answerable: progress.total,
      canGoBack: position > 0,
      startedAt: _startedAt,
      errors: Map<String, ValidationMessage>.unmodifiable(_errors),
      revision: ++_revision,
      savedAt: _savedAt,
    );
  }

  void _publish() {
    if (_closed) return;
    state = AsyncData<FormEntryState>(_snapshot());
  }

  /// Records the answer to [question] ([text] is the XML text form, `null`
  /// to clear). Messages are kept for when the person presses Next.
  void answer(Question question, String? text) {
    final message = _session.answer(question, text);
    if (message == null) {
      _errors.remove(question.key);
    } else {
      _errors[question.key] = message;
    }
    _dirty = true;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 900), () {
      unawaited(saveNow());
    });
    _publish();
  }

  /// Saves the answers so far as a draft (when there is any answer).
  Future<void> saveNow() async {
    _saveTimer?.cancel();
    if (_completed || _closed) return;
    if (_session.progress.answered == 0) return;
    await DraftRepository(_db).save(_session);
    _dirty = false;
    _savedAt = ref.read(nowProvider)();
    _publish();
  }

  /// Checks the screen and moves on. Returns `true` when it moved.
  Future<bool> next() async {
    final result = _session.next();
    switch (result) {
      case Blocked(:final messages):
        for (final message in messages) {
          final raw = _errors[message.questionKey];
          // An answer the form engine refused is more specific than the
          // "required" the stored (empty) answer produces.
          if (raw == null || message.issue != ValidationIssue.required) {
            _errors[message.questionKey] = message;
          }
        }
        _publish();
        return false;
      case Moved():
        _errors.clear();
        await saveNow();
        _publish();
        return true;
    }
  }

  /// Goes to the previous screen.
  Future<void> back() async {
    if (_session.position == 0) return;
    _errors.clear();
    _session.back();
    await saveNow();
    _publish();
  }

  /// At a repeat prompt: adds another copy of the repeated group.
  Future<void> addRepeat() async {
    _session.addRepeat();
    await saveNow();
    _publish();
  }

  /// Opens the screen with the question [questionKey] (from a
  /// [FinishBlocked] failure), keeping the messages to fix. Returns `false`
  /// when that question no longer applies.
  bool jumpTo(String questionKey) {
    final moved = _session.jumpTo(questionKey);
    if (moved) _publish();
    return moved;
  }

  /// Checks every question and, when all pass, puts the form in the outbox.
  /// When some fail, nothing moves: [FinishBlocked] lists them all and
  /// their messages wait on the questions.
  Future<FinishResult> finish() async {
    final failures = _session.validateAll();
    if (failures.isNotEmpty) return _blocked(failures);
    final result = _session.finalise();
    switch (result) {
      case FinaliseBlocked(:final message):
        // validateAll() found nothing, so this should not happen; the
        // engine now shows the question, and the person is sent to it.
        final screen = _session.screen;
        return _blocked(<FailedQuestion>[
          if (screen is QuestionScreen)
            for (final q in screen.questions)
              if (q.key == message.questionKey) FailedQuestion(q, message),
        ]);
      case Finalised(:final instance):
        _completed = true;
        _saveTimer?.cancel();
        await OutboxRepository(_db).enqueue(instance);
        return FinishQueued(instance.instanceId);
    }
  }

  FinishBlocked _blocked(List<FailedQuestion> failures) {
    _errors
      ..clear()
      ..addAll(<String, ValidationMessage>{
        for (final f in failures) f.question.key: f.message,
      });
    _publish();
    return FinishBlocked(failures);
  }
}
