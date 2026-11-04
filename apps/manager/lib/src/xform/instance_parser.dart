import 'package:obhijatra_manager/src/data/models.dart';
import 'package:obhijatra_manager/src/xform/form_definition.dart';
import 'package:xml/xml.dart';

/// Reads the answers out of a submission's instance XML.
///
/// SAFETY RULE: the text of an answer that the form marks as protected is
/// never copied anywhere. Such an answer becomes [Answer.protected], which
/// has no field for a value, and the parser does not even look inside it.
/// The rule is the same on every platform; nothing here asks which one runs.
///
/// Throws [FormatException] when [instanceXml] is not usable XML.
List<Answer> parseAnswers(
  String instanceXml,
  FormDefinition definition, {
  String lang = 'en',
}) {
  final XmlDocument document;
  try {
    document = XmlDocument.parse(instanceXml);
  } on XmlException catch (e) {
    throw FormatException(e.message);
  }
  if (document.doctypeElement != null) {
    throw const FormatException('Document types are not allowed.');
  }
  final root = document.rootElement;
  final answers = <Answer>[];

  String labelOf(String path, String name) =>
      definition.labelFor(path, lang) ?? name;

  void walk(XmlElement element, String path, {required bool isRoot}) {
    for (final child in element.childElements) {
      final childPath = '$path/${child.localName}';
      if (isRoot && child.localName == 'meta') continue;
      if (definition.isProtected(childPath)) {
        answers.add(
          Answer.protected(label: labelOf(childPath, child.localName)),
        );
        continue;
      }
      if (child.childElements.isNotEmpty) {
        walk(child, childPath, isRoot: false);
        continue;
      }
      final raw = child.innerText.trim();
      if (raw.isEmpty) continue;
      answers.add(
        Answer.shown(
          label: labelOf(childPath, child.localName),
          value: _display(definition, childPath, raw, lang),
        ),
      );
    }
  }

  walk(root, '/${root.localName}', isRoot: true);
  return answers;
}

String _display(
  FormDefinition definition,
  String path,
  String raw,
  String lang,
) {
  final parts = raw.split(RegExp(r'\s+'));
  final labelled = parts
      .map((part) => definition.choiceLabel(path, part, lang))
      .toList();
  if (labelled.every((label) => label != null) && labelled.isNotEmpty) {
    return labelled.join(', ');
  }
  return raw;
}
