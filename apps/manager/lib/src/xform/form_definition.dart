import 'package:xml/xml.dart';

/// Thrown when text is not a usable XForm.
class FormDefinitionException implements Exception {
  /// Creates the exception; [notXml] is true when the XML itself is broken.
  const FormDefinitionException({required this.notXml});

  /// True when the text is not well-formed XML, false when it is XML but not
  /// an XForm.
  final bool notXml;

  @override
  String toString() => 'FormDefinitionException(notXml: $notXml)';
}

/// A label that is either plain text or a reference into the form's
/// translations (`jr:itext('id')`).
class _Label {
  const _Label({this.text, this.itextId});
  final String? text;
  final String? itextId;
}

/// What the manager app reads from an XForm: identity, question labels,
/// answer choices and which answers are protected.
///
/// Only the facts the app needs are kept; this is not a form engine.
class FormDefinition {
  FormDefinition._({
    required this.formId,
    required this.version,
    required this.title,
    required this.rootName,
    required this.questionCount,
    required this.protectedPaths,
    required this.koboMatrixNames,
    required this.koboScoreNames,
    required this.koboRankNames,
    required this._labels,
    required this._choices,
    required this._translations,
    required this._translationLangs,
    required this._defaultLang,
  });

  /// Reads [xml]. Throws [FormDefinitionException] when it is not an XForm.
  ///
  /// Documents that declare a document type are refused.
  factory FormDefinition.parse(String xml) {
    final XmlDocument document;
    try {
      document = XmlDocument.parse(xml);
    } on XmlException {
      throw const FormDefinitionException(notXml: true);
    }
    if (document.doctypeElement != null) {
      throw const FormDefinitionException(notXml: true);
    }
    final html = document.rootElement;
    final head = _child(html, 'head');
    final model = head == null ? null : _child(head, 'model');
    final primary = model?.childElements
        .where((e) => e.localName == 'instance' && e.getAttribute('id') == null)
        .firstOrNull;
    final root = primary?.childElements.firstOrNull;
    if (html.localName != 'html' || model == null || root == null) {
      throw const FormDefinitionException(notXml: false);
    }

    final rootName = root.localName;
    final title = head == null
        ? ''
        : (_child(head, 'title')?.innerText.trim() ?? '');

    // Translations.
    final translations = <String, Map<String, String>>{};
    final langs = <String>[];
    String? defaultLang;
    final itext = _child(model, 'itext');
    for (final translation
        in itext?.childElements.where((e) => e.localName == 'translation') ??
            const <XmlElement>[]) {
      final lang = translation.getAttribute('lang') ?? '';
      langs.add(lang);
      if ((translation.getAttribute('default') ?? '').startsWith('true')) {
        defaultLang = lang;
      }
      final texts = <String, String>{};
      for (final text in translation.childElements.where(
        (e) => e.localName == 'text',
      )) {
        final id = text.getAttribute('id');
        if (id == null) continue;
        final value = text.childElements
            .where(
              (e) => e.localName == 'value' && e.getAttribute('form') == null,
            )
            .firstOrNull;
        if (value != null) texts[id] = value.innerText.trim();
      }
      translations[lang] = texts;
    }

    String absolute(String path) {
      final trimmed = path.trim();
      return trimmed.startsWith('/') ? trimmed : '/$rootName/$trimmed';
    }

    // Protected answers: bind elements carrying obhijatra:protect.
    final protectedPaths = <String>{};
    for (final bind in model.childElements.where(
      (e) => e.localName == 'bind',
    )) {
      final nodeset = bind.getAttribute('nodeset') ?? bind.getAttribute('ref');
      if (nodeset == null) continue;
      if (_hasProtect(bind)) protectedPaths.add(absolute(nodeset));
    }

    // Labels, choices, question count and Kobo-only constructs from the body.
    final labels = <String, _Label>{};
    final choices = <String, Map<String, _Label>>{};
    final matrix = <String>[];
    final score = <String>[];
    final rank = <String>[];
    var questionCount = 0;
    final body = _child(html, 'body');
    for (final element in body?.descendantElements ?? const <XmlElement>[]) {
      _collectKobo(element, matrix, score, rank);
      if (!_controls.contains(element.localName)) continue;
      final ref =
          element.getAttribute('ref') ?? element.getAttribute('nodeset');
      if (ref == null) continue;
      questionCount++;
      final path = absolute(ref);
      final label = _labelOf(element);
      if (label != null) labels[path] = label;
      final items = element.childElements.where((e) => e.localName == 'item');
      if (items.isNotEmpty) {
        final map = <String, _Label>{};
        for (final item in items) {
          final value = item.childElements
              .where((e) => e.localName == 'value')
              .firstOrNull
              ?.innerText
              .trim();
          final itemLabel = _labelOf(item);
          if (value != null && itemLabel != null) map[value] = itemLabel;
        }
        choices[path] = map;
      }
    }
    // Kobo constructs can also sit in the model or the instance.
    for (final element in model.descendantElements) {
      _collectKobo(element, matrix, score, rank);
    }

    return FormDefinition._(
      formId: root.getAttribute('id')?.trim() ?? '',
      version: _versionOf(root),
      title: title,
      rootName: rootName,
      questionCount: questionCount,
      labels: labels,
      choices: choices,
      protectedPaths: protectedPaths,
      translations: translations,
      translationLangs: langs,
      defaultLang: defaultLang,
      koboMatrixNames: matrix.toSet().toList(),
      koboScoreNames: score.toSet().toList(),
      koboRankNames: rank.toSet().toList(),
    );
  }

  /// The `id` of the primary instance's root element; may be empty.
  final String formId;

  /// The version; may be empty.
  final String version;

  /// The form title; may be empty.
  final String title;

  /// The local name of the primary instance's root element.
  final String rootName;

  /// How many questions the form body holds.
  final int questionCount;

  /// Absolute paths of answers marked `obhijatra:protect`.
  final Set<String> protectedPaths;

  /// Names of Kobo "question matrix" groups.
  final List<String> koboMatrixNames;

  /// Names of Kobo "rating" questions.
  final List<String> koboScoreNames;

  /// Names of Kobo "ranking" questions.
  final List<String> koboRankNames;

  final Map<String, _Label> _labels;
  final Map<String, Map<String, _Label>> _choices;
  final Map<String, Map<String, String>> _translations;
  final List<String> _translationLangs;
  final String? _defaultLang;

  static const String _orxNamespace = 'http://openrosa.org/xforms';
  static const Set<String> _controls = <String>{
    'input',
    'select',
    'select1',
    'upload',
    'range',
    'rank',
    'trigger',
  };

  /// Whether [path] (or any group above it) is marked protected.
  bool isProtected(String path) {
    for (final protectedPath in protectedPaths) {
      if (path == protectedPath || path.startsWith('$protectedPath/')) {
        return true;
      }
    }
    return false;
  }

  /// The label of the question at [path] in the language [lang] (`en` or
  /// `bn`), or null when the form has none.
  String? labelFor(String path, String lang) {
    final label = _labels[path];
    return label == null ? null : _resolve(label, lang);
  }

  /// The label of the choice [value] of the question at [path].
  String? choiceLabel(String path, String value, String lang) {
    final label = _choices[path]?[value];
    return label == null ? null : _resolve(label, lang);
  }

  /// How many questions lack a label in at least one translation. Zero when
  /// the form has fewer than two translations.
  int questionsMissingALanguage() {
    if (_translationLangs.length < 2) return 0;
    var missing = 0;
    for (final label in _labels.values) {
      final id = label.itextId;
      if (id == null) continue;
      final lacking = _translationLangs.any(
        (lang) => (_translations[lang]?[id] ?? '').isEmpty,
      );
      if (lacking) missing++;
    }
    return missing;
  }

  /// How many translations the form has.
  int get translationCount => _translationLangs.length;

  String? _resolve(_Label label, String lang) {
    final text = label.text;
    if (text != null) return text.isEmpty ? null : text;
    final id = label.itextId;
    if (id == null) return null;
    final chosen = _pickLang(lang);
    final value = chosen == null ? null : _translations[chosen]?[id];
    if (value != null && value.isNotEmpty) return value;
    for (final other in _translationLangs) {
      final fallback = _translations[other]?[id];
      if (fallback != null && fallback.isNotEmpty) return fallback;
    }
    return null;
  }

  String? _pickLang(String lang) {
    bool matches(String name) {
      final n = name.toLowerCase();
      if (lang == 'bn') {
        return n.contains('(bn)') ||
            n == 'bn' ||
            n.startsWith('bn-') ||
            n.contains('bangla') ||
            n.contains('bengali') ||
            n.contains('বাংলা');
      }
      return n.contains('(en)') ||
          n == 'en' ||
          n.startsWith('en-') ||
          n.contains('english');
    }

    for (final name in _translationLangs) {
      if (matches(name)) return name;
    }
    return _defaultLang ??
        (_translationLangs.isEmpty ? null : _translationLangs.first);
  }

  static XmlElement? _child(XmlElement parent, String localName) =>
      parent.childElements.where((e) => e.localName == localName).firstOrNull;

  static String _versionOf(XmlElement root) {
    final plain = root.getAttribute('version');
    if (plain != null) return plain.trim();
    return root.getAttribute('version', namespaceUri: _orxNamespace)?.trim() ??
        '';
  }

  static bool _hasProtect(XmlElement element) {
    for (final attribute in element.attributes) {
      final name = attribute.name;
      if (name.local != 'protect') continue;
      final ns = (name.namespaceUri ?? '').toLowerCase();
      if (name.prefix == 'obhijatra' || ns.contains('obhijatra')) {
        final value = attribute.value.trim().toLowerCase();
        return value != 'false' &&
            value != 'no' &&
            value != '0' &&
            value != 'none';
      }
    }
    return false;
  }

  static _Label? _labelOf(XmlElement element) {
    final label = element.childElements
        .where((e) => e.localName == 'label')
        .firstOrNull;
    if (label == null) return null;
    final ref = label.getAttribute('ref');
    if (ref != null) {
      final match = RegExp('''jr:itext\\(\\s*['"](.+?)['"]\\s*\\)''')
          .firstMatch(ref);
      if (match != null) return _Label(itextId: match.group(1));
    }
    return _Label(text: label.innerText.trim());
  }

  static final RegExp _matrixPattern = RegExp(
    r'kobo--matrix|kobomatrix|begin_kobomatrix',
    caseSensitive: false,
  );
  static final RegExp _scorePattern = RegExp(
    r'kobo--score|begin_score',
    caseSensitive: false,
  );
  static final RegExp _rankPattern = RegExp(
    r'kobo--rank|begin_rank',
    caseSensitive: false,
  );

  static void _collectKobo(
    XmlElement element,
    List<String> matrix,
    List<String> score,
    List<String> rank,
  ) {
    var isMatrix = false;
    var isScore = false;
    var isRank = false;
    for (final attribute in element.attributes) {
      final text = '${attribute.name.qualified}=${attribute.value}';
      if (_matrixPattern.hasMatch(text)) isMatrix = true;
      if (_scorePattern.hasMatch(text)) isScore = true;
      if (_rankPattern.hasMatch(text)) isRank = true;
    }
    if (!isMatrix && !isScore && !isRank) return;
    final name = _questionName(element);
    if (isMatrix) matrix.add(name);
    if (isScore) score.add(name);
    if (isRank) rank.add(name);
  }

  static String _questionName(XmlElement element) {
    XmlElement? current = element;
    while (current != null) {
      final ref =
          current.getAttribute('ref') ?? current.getAttribute('nodeset');
      if (ref != null && ref.isNotEmpty) return ref.split('/').last;
      current = current.parentElement;
    }
    return element.localName;
  }
}
