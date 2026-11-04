import 'package:obhijatra_core/src/problem.dart';
import 'package:xml/xml.dart';

/// The identity of an XForm: what the server and the outbox key on.
final class XFormInfo {
  /// Creates the description.
  const XFormInfo({
    required this.formId,
    required this.version,
    required this.title,
  });

  /// Reads the form id, version and title from XForm [xml]: the root
  /// element of the first `<instance>` without an `id` inside `<model>`.
  ///
  /// Throws an [ObhijatraException] with [ProblemCode.formInvalid] when the
  /// XML is not an XForm or declares a document type.
  factory XFormInfo.read(String xml) {
    final XmlDocument document;
    try {
      document = XmlDocument.parse(xml);
    } on XmlException catch (e) {
      throw ObhijatraException(ProblemCode.formInvalid, cause: e);
    }
    if (document.doctypeElement != null) {
      throw const ObhijatraException(ProblemCode.formInvalid);
    }
    final html = document.rootElement;
    final head = _child(html, 'head');
    final model = head == null ? null : _child(head, 'model');
    final instance = model?.childElements
        .where((e) => e.localName == 'instance' && e.getAttribute('id') == null)
        .firstOrNull;
    final root = instance?.childElements.firstOrNull;
    final formId = root?.getAttribute('id')?.trim() ?? '';
    if (html.localName != 'html' || root == null || formId.isEmpty) {
      throw const ObhijatraException(ProblemCode.formInvalid);
    }
    final title = head == null ? null : _child(head, 'title')?.innerText.trim();
    return XFormInfo(
      formId: formId,
      version: versionOf(root),
      title: (title == null || title.isEmpty) ? null : title,
    );
  }

  /// The form id.
  final String formId;

  /// The version string; empty when the form has none.
  final String version;

  /// The form title, if any.
  final String? title;

  /// The OpenRosa namespace, whose `version` attribute ODK also accepts.
  static const String orxNamespace = 'http://openrosa.org/xforms';

  /// The `version` (or `orx:version`) attribute of an instance root.
  static String versionOf(XmlElement root) {
    final plain = root.getAttribute('version');
    if (plain != null) return plain.trim();
    return root.getAttribute('version', namespaceUri: orxNamespace)?.trim() ??
        '';
  }

  static XmlElement? _child(XmlElement parent, String localName) =>
      parent.childElements.where((e) => e.localName == localName).firstOrNull;
}
