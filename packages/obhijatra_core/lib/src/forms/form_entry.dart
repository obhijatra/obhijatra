import 'package:dartrosa/dartrosa.dart';
import 'package:obhijatra_core/src/forms/instance_xml.dart';
import 'package:obhijatra_core/src/forms/xform_info.dart';
import 'package:obhijatra_core/src/problem.dart';
import 'package:obhijatra_core/src/security/field_protector.dart';
import 'package:xml/xml.dart';

/// The kind of answer a question takes; the UI picks its widget from it.
enum QuestionKind {
  /// Free text.
  text,

  /// A whole number.
  integer,

  /// A decimal number.
  decimal,

  /// A calendar date (`yyyy-mm-dd`).
  date,

  /// A time of day.
  time,

  /// A date and time.
  dateTime,

  /// One choice from a list.
  selectOne,

  /// Any number of choices from a list (values separated by spaces).
  selectMultiple,

  /// A GPS point, trace or area.
  location,

  /// A photo, audio, video, signature or other file.
  media,

  /// A barcode or QR code.
  barcode,

  /// Read-only text shown to the user.
  note,

  /// An acknowledgement ("OK") the user ticks.
  acknowledge,

  /// Anything else; the UI shows a plain text field.
  other,
}

/// One option of a select question.
final class Choice {
  /// Creates an option.
  const Choice(this.value, this.label);

  /// The value stored in the instance.
  final String value;

  /// The label in the session's current language.
  final String label;
}

/// A question as it stands now. Read the screen again after any answer:
/// answers can change labels, choices and which questions are relevant.
final class Question {
  Question._(QuestionNode node)
    : _index = node.index,
      key = node.index.toPathString(),
      label = node.label.text,
      hint = node.hint,
      kind = _kindOf(node),
      isRequired = node.isRequired,
      isReadOnly = node.isReadonly,
      choices = [
        for (final choice in node.choices)
          Choice(choice.value, node.choiceLabel(choice) ?? choice.value),
      ],
      value = node.value?.uncast().string,
      displayValue = node.displayValue;

  final FormIndex _index;

  /// A key that identifies the question within this form.
  final String key;

  /// The label in the session's current language.
  final String? label;

  /// The hint, if any.
  final String? hint;

  /// What kind of answer the question takes.
  final QuestionKind kind;

  /// Whether an answer is required.
  final bool isRequired;

  /// Whether the question cannot be answered (a note or a calculation).
  final bool isReadOnly;

  /// The options of a select question (empty otherwise).
  final List<Choice> choices;

  /// The current answer in its XML text form, or `null` when unanswered.
  final String? value;

  /// The current answer as shown to the user (choice labels, for example).
  final String? displayValue;

  bool get _counts =>
      !isReadOnly &&
      kind != QuestionKind.note &&
      kind != QuestionKind.acknowledge;
}

/// What a question failed on.
enum ValidationIssue {
  /// A required question has no answer.
  required,

  /// The answer breaks the form's constraint.
  constraint,

  /// The text cannot be read as this kind of answer (for example letters
  /// for a number, or a value that is not one of the choices).
  invalidValue,
}

/// Why an answer was not accepted, for the UI to show next to the question.
final class ValidationMessage {
  /// Creates the message.
  const ValidationMessage({
    required this.questionKey,
    required this.issue,
    this.formMessage,
  });

  /// The [Question.key] of the question concerned.
  final String questionKey;

  /// What the question failed on; the UI translates it when the form gives
  /// no [formMessage].
  final ValidationIssue issue;

  /// The form's own message (`jr:constraintMsg` or `jr:requiredMsg`) in the
  /// current language, if it has one.
  final String? formMessage;
}

/// What the form shows now.
sealed class FormScreen {
  const FormScreen();
}

/// One question, or every question of a `field-list` group.
final class QuestionScreen extends FormScreen {
  /// Creates the screen.
  const QuestionScreen(this.questions, {this.groupLabel});

  /// The questions on the screen, in form order.
  final List<Question> questions;

  /// The label of the group the screen shows, if any.
  final String? groupLabel;
}

/// The point where the user may add another instance of a repeat.
final class RepeatPromptScreen extends FormScreen {
  /// Creates the screen.
  const RepeatPromptScreen(this.repeatLabel);

  /// The repeat's label, for "Add another …?".
  final String? repeatLabel;
}

/// After the last question: time to finalise.
final class EndOfFormScreen extends FormScreen {
  /// Creates the screen.
  const EndOfFormScreen();
}

/// The result of [FormEntrySession.next].
sealed class NavigationResult {
  const NavigationResult();
}

/// The session moved on to [screen].
final class Moved extends NavigationResult {
  /// Creates the result.
  const Moved(this.screen);

  /// The new screen.
  final FormScreen screen;
}

/// The session stayed: questions on the current screen need attention.
final class Blocked extends NavigationResult {
  /// Creates the result.
  const Blocked(this.messages);

  /// One message per question that failed.
  final List<ValidationMessage> messages;
}

/// A finalised instance, ready for the outbox.
final class FinalisedInstance {
  /// Creates the instance.
  const FinalisedInstance({
    required this.form,
    required this.instanceId,
    required this.xml,
    required this.attachmentNames,
  });

  /// The form version it was filled with.
  final FormVersionRef form;

  /// The `meta/instanceID` (`uuid:` prefix).
  final String instanceId;

  /// The submission XML (non-relevant answers left out).
  final String xml;

  /// The file names of media answers the XML refers to.
  final List<String> attachmentNames;
}

/// The result of [FormEntrySession.finalise].
sealed class FinaliseResult {
  const FinaliseResult();
}

/// The form is valid and was finalised.
final class Finalised extends FinaliseResult {
  /// Creates the result.
  const Finalised(this.instance);

  /// What to put in the outbox.
  final FinalisedInstance instance;
}

/// The form is not valid; the session now shows the question to fix.
final class FinaliseBlocked extends FinaliseResult {
  /// Creates the result.
  const FinaliseBlocked(this.message);

  /// Why the first failing question failed.
  final ValidationMessage message;
}

/// Filling in one instance of a form, headless: the UI reads [screen],
/// calls [answer], [next] and [back], saves [saveDraft] after every screen
/// and calls [finalise] at the end.
///
/// Runs ODK XForms through DartRosa: skip logic, constraints, required
/// questions, calculations, repeats and translations behave as in ODK
/// Collect.
final class FormEntrySession {
  FormEntrySession._(
    this._definition,
    this._session,
    this.form,
    this.instanceId,
  ) : _nav = _session.navigator;

  /// Starts a new instance of the XForm [xformXml], or continues the draft
  /// [draftXml] saved by [saveDraft].
  ///
  /// [instanceId] is the draft's id; pass it when continuing a draft of a
  /// form that has no `meta/instanceID` of its own. Throws an
  /// [ObhijatraException] with [ProblemCode.formInvalid] when the form or
  /// the draft cannot be loaded.
  static Future<FormEntrySession> start({
    required String xformXml,
    String? draftXml,
    String? instanceId,
    String? language,
    DartRosaConfig config = const DartRosaConfig(),
  }) async {
    final info = XFormInfo.read(xformXml);
    final FormDefinition definition;
    final FormSession session;
    try {
      definition = await FormDefinition.parse(xformXml, config: config);
      session = definition.createSession(
        existingInstance: draftXml,
        language: language,
      );
    } on Object catch (e) {
      throw ObhijatraException(ProblemCode.formInvalid, cause: e);
    }
    final id =
        _instanceIdIn(session.saveDraft()) ?? instanceId ?? newInstanceId();
    final entry = FormEntrySession._(
      definition,
      session,
      FormVersionRef(info.formId, info.version),
      id,
    );
    entry._settle(entry._nav.next(), forward: true);
    return entry;
  }

  final FormDefinition _definition;
  final FormSession _session;
  final FormNavigator _nav;

  /// The form version being filled.
  final FormVersionRef form;

  /// The instance id (from the form's `uid` preload, or generated).
  final String instanceId;

  /// The form title.
  String? get title => _definition.title;

  /// The form's languages (empty when it has no translations).
  List<String> get languages => _definition.languages;

  /// The current language.
  String? get language => _session.language;

  /// Changes the language of labels, hints, choices and messages.
  set language(String? value) => _session.language = value;

  /// What to show now.
  FormScreen get screen {
    switch (_nav.event) {
      case FormEntryEvent.promptNewRepeat:
        return RepeatPromptScreen(_nav.current.label.text);
      case FormEntryEvent.question:
        final node = _nav.current as QuestionNode;
        final group = node.ancestors.whereType<GroupNode>().lastOrNull;
        return QuestionScreen([
          Question._(node),
        ], groupLabel: group?.label.text);
      case FormEntryEvent.group:
        final group = _nav.current as GroupNode;
        return QuestionScreen([
          for (final q in _questionsIn(group)) Question._(q),
        ], groupLabel: group.label.text);
      case FormEntryEvent.beginningOfForm ||
          FormEntryEvent.endOfForm ||
          FormEntryEvent.repeat ||
          FormEntryEvent.repeatJuncture:
        return const EndOfFormScreen();
    }
  }

  /// Answers [question] with [text] (the XML text form: `2026-11-04`,
  /// `42`, a choice value, or choice values separated by spaces); `null`
  /// or blank clears the answer. Bangla digits are accepted in numbers and
  /// dates. Returns `null` when the answer was saved.
  ValidationMessage? answer(Question question, String? text) {
    var value = text?.trim();
    if (value != null && _numericKinds.contains(question.kind)) {
      value = _asciiDigits(value);
    }
    final result = _session.answer(
      question._index,
      (value == null || value.isEmpty) ? null : UncastValue(value),
    );
    return _messageFor(question.key, result);
  }

  /// Checks the questions on the current screen and, when they pass, moves
  /// to the next screen (skipping questions that are not relevant).
  NavigationResult next() {
    final messages = validateScreen();
    if (messages.isNotEmpty) return Blocked(messages);

    final here = _nav.position;
    final current = _nav.current;
    var event = _nav.next();
    if (current is GroupNode && current.isFieldList) {
      // Step over the group's own questions: they were on this screen.
      while (event != FormEntryEvent.endOfForm &&
          _nav.position.isInForm &&
          FormIndex.isSubElement(here, _nav.position)) {
        event = _nav.next();
      }
    }
    _settle(event, forward: true);
    return Moved(screen);
  }

  /// Moves to the previous screen (answers are kept, nothing is checked).
  FormScreen back() {
    final event = _nav.previous();
    if (event == FormEntryEvent.beginningOfForm) {
      _settle(_nav.next(), forward: true);
    } else {
      _settle(event, forward: false);
    }
    return screen;
  }

  /// At a [RepeatPromptScreen]: adds an instance of the repeat and moves to
  /// its first screen.
  FormScreen addRepeat() {
    if (_nav.event != FormEntryEvent.promptNewRepeat) {
      throw StateError('addRepeat() is only possible at a repeat prompt');
    }
    _nav.addRepeatAndEnter();
    _settle(_nav.next(), forward: true);
    return screen;
  }

  /// Checks every question on the current screen without moving.
  List<ValidationMessage> validateScreen() {
    final current = screen;
    if (current is! QuestionScreen) return const [];
    return [
      for (final q in current.questions)
        if (!q.isReadOnly) ?_revalidate(q),
    ];
  }

  /// Answered and total relevant questions that take an answer.
  ({int answered, int total}) get progress {
    var answered = 0;
    var total = 0;
    void visit(FormNode node) {
      switch (node) {
        case QuestionNode():
          final q = Question._(node);
          if (!q._counts) return;
          total++;
          if (q.value != null) answered++;
        case ContainerNode():
          node.visibleChildren.forEach(visit);
        case RepeatNode():
          node.instances.forEach(visit);
      }
    }

    visit(_session.root);
    return (answered: answered, total: total);
  }

  /// The whole instance as XML, non-relevant answers included, to store as
  /// a draft and continue later with [start].
  String saveDraft() => _session.saveDraft();

  /// Validates the whole form and, when valid, finalises it into the
  /// submission XML with its `meta/instanceID` and form version. When not
  /// valid, the session moves to the first question to fix.
  FinaliseResult finalise() {
    final FinalizeResult result;
    try {
      result = _session.finalize();
    } on Object catch (e) {
      throw ObhijatraException(ProblemCode.formInvalid, cause: e);
    }
    switch (result) {
      case FinalizeFailure(:final failure):
        _nav.jumpTo(failure.index);
        _settle(_nav.event, forward: false);
        return FinaliseBlocked(
          _messageFor(failure.index.toPathString(), failure.result) ??
              ValidationMessage(
                questionKey: failure.index.toPathString(),
                issue: ValidationIssue.required,
              ),
        );
      case FinalizeSuccess(:final submission):
        final complete = completeInstance(
          xml: submission.xml,
          formId: form.formId,
          version: form.version,
          fallbackInstanceId: instanceId,
        );
        return Finalised(
          FinalisedInstance(
            form: form,
            instanceId: complete.instanceId,
            xml: complete.xml,
            attachmentNames: List.unmodifiable(submission.attachments),
          ),
        );
    }
  }

  /// Releases the engine's resources; the session cannot be used after.
  Future<void> close() => _session.close();

  // -------------------------------------------------------------------

  static const _numericKinds = {
    QuestionKind.integer,
    QuestionKind.decimal,
    QuestionKind.date,
    QuestionKind.time,
    QuestionKind.dateTime,
  };

  /// Rests the cursor on a screen: a question, a field-list group, a
  /// repeat prompt or the end, stepping in the given direction.
  void _settle(FormEntryEvent event, {required bool forward}) {
    var current = event;
    while (true) {
      switch (current) {
        case FormEntryEvent.endOfForm || FormEntryEvent.promptNewRepeat:
          return;
        case FormEntryEvent.beginningOfForm:
          current = _nav.next();
          forward = true;
        case FormEntryEvent.question:
          final fieldList = _nav.current.ancestors
              .whereType<GroupNode>()
              .where((g) => g.isFieldList)
              .firstOrNull;
          if (fieldList != null) _nav.jumpTo(fieldList.index);
          return;
        case FormEntryEvent.group:
          final group = _nav.current;
          if (group is GroupNode && group.isFieldList) return;
          current = forward ? _nav.next() : _nav.previous();
        case FormEntryEvent.repeat || FormEntryEvent.repeatJuncture:
          current = forward ? _nav.next() : _nav.previous();
      }
    }
  }

  /// Checks [q]'s stored answer by saving it again with validation.
  ValidationMessage? _revalidate(Question q) {
    final node = _session.nodeAt(q._index);
    final value = node is QuestionNode ? node.value : null;
    return _messageFor(q.key, _session.answer(q._index, value));
  }

  static ValidationMessage? _messageFor(String key, AnswerResult result) =>
      switch (result) {
        AnswerAccepted() => null,
        AnswerRequired(:final message) => ValidationMessage(
          questionKey: key,
          issue: ValidationIssue.required,
          formMessage: message,
        ),
        AnswerConstraintViolated(:final message) => ValidationMessage(
          questionKey: key,
          issue: ValidationIssue.constraint,
          formMessage: message,
        ),
        AnswerRejected() => ValidationMessage(
          questionKey: key,
          issue: ValidationIssue.invalidValue,
        ),
      };

  static Iterable<QuestionNode> _questionsIn(ContainerNode node) sync* {
    for (final child in node.visibleChildren) {
      switch (child) {
        case QuestionNode():
          yield child;
        case ContainerNode():
          yield* _questionsIn(child);
        case RepeatNode():
          for (final instance in child.instances) {
            yield* _questionsIn(instance);
          }
      }
    }
  }

  static String? _instanceIdIn(String xml) {
    try {
      final root = XmlDocument.parse(xml).rootElement;
      final meta = root.childElements
          .where((e) => e.localName == 'meta')
          .firstOrNull;
      final id = meta?.childElements
          .where((e) => e.localName == 'instanceID')
          .firstOrNull
          ?.innerText
          .trim();
      return (id == null || id.isEmpty) ? null : id;
    } on XmlException {
      return null;
    }
  }

  static String _asciiDigits(String text) => String.fromCharCodes([
    for (final c in text.runes)
      (c >= 0x09E6 && c <= 0x09EF) ? c - 0x09E6 + 0x30 : c,
  ]);
}

QuestionKind _kindOf(QuestionNode node) {
  if (node.isNote) return QuestionKind.note;
  switch (node.controlType) {
    case ControlType.selectOne:
      return QuestionKind.selectOne;
    case ControlType.selectMulti:
      return QuestionKind.selectMultiple;
    case ControlType.trigger:
      return QuestionKind.acknowledge;
    case ControlType.upload ||
        ControlType.imageChoose ||
        ControlType.audioCapture ||
        ControlType.videoCapture ||
        ControlType.fileCapture:
      return QuestionKind.media;
    default:
      break;
  }
  return switch (node.dataType) {
    DataType.text => QuestionKind.text,
    DataType.integer || DataType.long => QuestionKind.integer,
    DataType.decimal => QuestionKind.decimal,
    DataType.date => QuestionKind.date,
    DataType.time => QuestionKind.time,
    DataType.dateTime => QuestionKind.dateTime,
    DataType.choice => QuestionKind.selectOne,
    DataType.multipleItems => QuestionKind.selectMultiple,
    DataType.geopoint ||
    DataType.geotrace ||
    DataType.geoshape => QuestionKind.location,
    DataType.barcode => QuestionKind.barcode,
    DataType.binary => QuestionKind.media,
    _ => QuestionKind.other,
  };
}
