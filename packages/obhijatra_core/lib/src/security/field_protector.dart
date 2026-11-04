/// The seam for field-level end-to-end encryption (Phase 3).
///
/// In Phase 3 an implementation backed by the injected `sodium` API will
/// encrypt every node the published form marks `obhijatra:protect`
/// (`protected` or `sealed`) inside the serialised instance XML, using the
/// per-record data key wrapped by the scope key, and add blind indexes.
///
/// Where it runs matters: the core calls [FieldProtector.protectInstance]
/// exactly once, when a finalised submission enters the outbox, and stores
/// the result. Encryption uses random nonces, so encrypting again on each
/// upload attempt would change the XML and the server, which recognises a
/// retry by the SHA-256 of the XML, would answer 409 instead of
/// "already received".
library;

/// Identifies the form version a submission was filled with.
final class FormVersionRef {
  /// Creates a reference to [version] of [formId].
  const FormVersionRef(this.formId, this.version);

  /// The XForm form id.
  final String formId;

  /// The XForm version string.
  final String version;

  @override
  bool operator ==(Object other) =>
      other is FormVersionRef &&
      other.formId == formId &&
      other.version == version;

  @override
  int get hashCode => Object.hash(formId, version);

  @override
  String toString() => '$formId@$version';
}

/// Turns a finalised instance into the bytes that leave the device.
abstract interface class FieldProtector {
  /// Returns [instanceXml] with every protected node encrypted.
  Future<String> protectInstance({
    required String instanceXml,
    required FormVersionRef form,
  });
}

/// Phase 1 behaviour: no field is encrypted; the XML is returned unchanged.
final class NoFieldProtection implements FieldProtector {
  /// Creates the pass-through protector.
  const NoFieldProtection();

  @override
  Future<String> protectInstance({
    required String instanceXml,
    required FormVersionRef form,
  }) async => instanceXml;
}
