import 'package:obhijatra_core/src/forms/xform_info.dart';
import 'package:obhijatra_core/src/problem.dart';
import 'package:uuid/uuid.dart';
import 'package:xml/xml.dart';

/// The shape the server accepts for `meta/instanceID`.
final RegExp instanceIdPattern = RegExp(r'^[A-Za-z0-9][A-Za-z0-9:._-]{0,127}$');

/// A new instance id: `uuid:` and a random (version 4) UUID, as ODK uses.
String newInstanceId() => 'uuid:${const Uuid().v4()}';

/// The XML declaration ODK clients put first; the server's file-type check
/// recognises XML only when the document starts with it.
const String xmlDeclaration = "<?xml version='1.0' encoding='UTF-8' ?>";

/// Makes a finalised instance acceptable to the server.
///
/// Checks that the root element carries [formId] and [version], that
/// `meta/instanceID` holds a valid id (adding `meta` and `instanceID`, with
/// [fallbackInstanceId], when the form has none) and that the document
/// starts with an XML declaration. Returns [xml] unchanged when nothing is
/// missing, so the engine's own serialisation is kept byte for byte.
///
/// Throws an [ObhijatraException] with [ProblemCode.formInvalid] when the
/// instance belongs to another form or version.
({String xml, String instanceId}) completeInstance({
  required String xml,
  required String formId,
  required String version,
  required String fallbackInstanceId,
}) {
  final XmlDocument document;
  try {
    document = XmlDocument.parse(xml);
  } on XmlException catch (e) {
    throw ObhijatraException(ProblemCode.formInvalid, cause: e);
  }
  final root = document.rootElement;
  if (root.getAttribute('id') != formId ||
      XFormInfo.versionOf(root) != version) {
    throw const ObhijatraException(ProblemCode.formInvalid);
  }

  var changed = false;
  var meta = root.childElements.where((e) => e.localName == 'meta').firstOrNull;
  if (meta == null) {
    meta = XmlElement(const XmlName.parts('meta'));
    root.children.add(meta);
    changed = true;
  }
  var idElement = meta.childElements
      .where((e) => e.localName == 'instanceID')
      .firstOrNull;
  if (idElement == null) {
    idElement = XmlElement(const XmlName.parts('instanceID'));
    meta.children.add(idElement);
    changed = true;
  }
  var instanceId = idElement.innerText.trim();
  if (instanceId.isEmpty) {
    instanceId = fallbackInstanceId;
    idElement.innerText = instanceId;
    changed = true;
  }
  if (!instanceIdPattern.hasMatch(instanceId)) {
    throw const ObhijatraException(ProblemCode.formInvalid);
  }

  if (!changed) {
    return (
      xml: xml.trimLeft().startsWith('<?xml') ? xml : '$xmlDeclaration$xml',
      instanceId: instanceId,
    );
  }
  for (final node in document.children.whereType<XmlDeclaration>().toList()) {
    document.children.remove(node);
  }
  return (
    xml: '$xmlDeclaration${document.toXmlString()}',
    instanceId: instanceId,
  );
}
