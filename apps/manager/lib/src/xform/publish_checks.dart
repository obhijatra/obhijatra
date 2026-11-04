import 'package:obhijatra_manager/src/xform/form_definition.dart';

/// How a check result is shown.
enum CheckKind {
  /// Must be fixed before the form can be published (red).
  problem,

  /// Answers that will be protected (green, shield).
  protectedAnswers,

  /// A check that passed (green).
  passed,

  /// Worth knowing, does not block publishing (blue).
  note,
}

/// Which check a result belongs to. The screen turns each into a plain
/// sentence in the chosen language.
enum CheckCode {
  /// The text is not well-formed XML.
  unreadable,

  /// The XML is not an XForm.
  notXForm,

  /// The XML is readable.
  wellFormed,

  /// The form has no version.
  versionMissing,

  /// The form has a version.
  versionOk,

  /// The form has no form id.
  formIdMissing,

  /// The form has a form id.
  formIdOk,

  /// This version was already uploaded.
  versionExists,

  /// Kobo question matrix.
  koboMatrix,

  /// Kobo rating question.
  koboScore,

  /// Kobo ranking question.
  koboRank,

  /// The list of protected answers.
  protectedList,

  /// Every question has labels in all languages.
  languagesOk,

  /// Some questions lack a label in one language.
  languagesPartial,

  /// The form has a single language.
  singleLanguage,
}

/// One line of the publish check.
class PublishCheck {
  /// Creates a check result.
  const PublishCheck(
    this.kind,
    this.code, {
    this.items = const <String>[],
    this.value = '',
    this.count = 0,
  });

  /// How it is shown.
  final CheckKind kind;

  /// Which check it is.
  final CheckCode code;

  /// Question names or labels the result is about.
  final List<String> items;

  /// A version or form id the sentence quotes.
  final String value;

  /// A number the sentence quotes.
  final int count;
}

/// The result of checking one XForm.
class PublishReport {
  /// Creates a report.
  const PublishReport({
    required this.checks,
    required this.questionCount,
    required this.formId,
    required this.version,
    required this.title,
  });

  /// Results, problems first.
  final List<PublishCheck> checks;

  /// Number of questions found.
  final int questionCount;

  /// Form id, empty when unreadable or missing.
  final String formId;

  /// Version, empty when unreadable or missing.
  final String version;

  /// Title, empty when none.
  final String title;

  /// How many things must be fixed.
  int get problemCount =>
      checks.where((c) => c.kind == CheckKind.problem).length;

  /// Whether nothing blocks publishing.
  bool get canPublish => problemCount == 0;
}

/// Checks the XForm in [xml] and describes the result.
///
/// [existingVersions] are the versions of this form that were already
/// uploaded; [lang] (`en` or `bn`) picks the language of question labels
/// quoted in the result.
PublishReport checkXForm(
  String xml, {
  Iterable<String> existingVersions = const <String>[],
  String lang = 'en',
}) {
  final FormDefinition definition;
  try {
    definition = FormDefinition.parse(xml);
  } on FormDefinitionException catch (e) {
    return PublishReport(
      checks: <PublishCheck>[
        PublishCheck(
          CheckKind.problem,
          e.notXml ? CheckCode.unreadable : CheckCode.notXForm,
        ),
      ],
      questionCount: 0,
      formId: '',
      version: '',
      title: '',
    );
  }

  final problems = <PublishCheck>[];
  final others = <PublishCheck>[];

  others.add(const PublishCheck(CheckKind.passed, CheckCode.wellFormed));

  if (definition.formId.isEmpty) {
    problems.add(
      const PublishCheck(CheckKind.problem, CheckCode.formIdMissing),
    );
  } else {
    others.add(
      PublishCheck(
        CheckKind.passed,
        CheckCode.formIdOk,
        value: definition.formId,
      ),
    );
  }

  if (definition.version.isEmpty) {
    problems.add(
      const PublishCheck(CheckKind.problem, CheckCode.versionMissing),
    );
  } else if (existingVersions.contains(definition.version)) {
    problems.add(
      PublishCheck(
        CheckKind.problem,
        CheckCode.versionExists,
        value: definition.version,
      ),
    );
  } else {
    others.add(
      PublishCheck(
        CheckKind.passed,
        CheckCode.versionOk,
        value: definition.version,
      ),
    );
  }

  void kobo(CheckCode code, List<String> names) {
    if (names.isEmpty) return;
    problems.add(
      PublishCheck(CheckKind.problem, code, items: names, count: names.length),
    );
  }

  kobo(CheckCode.koboMatrix, definition.koboMatrixNames);
  kobo(CheckCode.koboScore, definition.koboScoreNames);
  kobo(CheckCode.koboRank, definition.koboRankNames);

  if (definition.protectedPaths.isNotEmpty) {
    final names = definition.protectedPaths
        .map((path) => definition.labelFor(path, lang) ?? path.split('/').last)
        .toList();
    others.add(
      PublishCheck(
        CheckKind.protectedAnswers,
        CheckCode.protectedList,
        items: names,
        count: names.length,
      ),
    );
  }

  if (definition.translationCount < 2) {
    others.add(const PublishCheck(CheckKind.note, CheckCode.singleLanguage));
  } else {
    final missing = definition.questionsMissingALanguage();
    others.add(
      missing == 0
          ? const PublishCheck(CheckKind.passed, CheckCode.languagesOk)
          : PublishCheck(
              CheckKind.note,
              CheckCode.languagesPartial,
              count: missing,
            ),
    );
  }

  // Order as in the design: things to fix, protected answers, then passed.
  final protectedFirst = <PublishCheck>[
    ...others.where((c) => c.kind == CheckKind.protectedAnswers),
    ...others.where((c) => c.kind == CheckKind.note),
    ...others.where((c) => c.kind == CheckKind.passed),
  ];

  return PublishReport(
    checks: <PublishCheck>[...problems, ...protectedFirst],
    questionCount: definition.questionCount,
    formId: definition.formId,
    version: definition.version,
    title: definition.title,
  );
}
