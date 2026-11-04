import 'package:obhijatra_core/obhijatra_core.dart';
import 'package:obhijatra_core/src/forms/instance_xml.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';

void main() {
  const formId = 'household_visit';
  const version = '2026110401';
  const id = 'uuid:0f8fad5b-d9cb-469f-a165-70867728950e';

  ({String xml, String instanceId}) complete(String xml) => completeInstance(
    xml: xml,
    formId: formId,
    version: version,
    fallbackInstanceId: id,
  );

  test('newInstanceId is a uuid: prefixed version 4 UUID', () {
    final value = newInstanceId();
    expect(
      value,
      matches(
        RegExp(
          r'^uuid:[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
    expect(newInstanceId(), isNot(value));
    expect(instanceIdPattern.hasMatch(value), isTrue);
  });

  test('a complete instance is kept byte for byte', () {
    const xml =
        "<?xml version='1.0' encoding='UTF-8' ?><data id=\"$formId\" "
        'version="$version"><a>1</a><meta><instanceID>uuid:abc</instanceID>'
        '</meta></data>';
    final result = complete(xml);
    expect(result.xml, xml);
    expect(result.instanceId, 'uuid:abc');
  });

  test('the XML declaration the server needs is added when missing', () {
    const xml =
        '<data id="$formId" version="$version"><meta><instanceID>uuid:abc'
        '</instanceID></meta></data>';
    expect(complete(xml).xml, "<?xml version='1.0' encoding='UTF-8' ?>$xml");
  });

  test('meta and instanceID are added when the form has none', () {
    const xml = '<data id="$formId" version="$version"><a>1</a></data>';
    final result = complete(xml);
    expect(result.instanceId, id);
    expect(result.xml, startsWith('<?xml'));
    final root = XmlDocument.parse(result.xml).rootElement;
    expect(root.findElements('a').single.innerText, '1');
    expect(
      root
          .findElements('meta')
          .single
          .findElements('instanceID')
          .single
          .innerText,
      id,
    );
  });

  test('an empty instanceID is filled; orx:meta is recognised', () {
    const xml =
        '<data id="$formId" version="$version" '
        'xmlns:orx="http://openrosa.org/xforms"><orx:meta><orx:instanceID/>'
        '</orx:meta></data>';
    final result = complete(xml);
    expect(result.instanceId, id);
    final ids = XmlDocument.parse(result.xml).rootElement.descendantElements
        .where((e) => e.localName == 'instanceID');
    expect(ids.single.innerText, id);
  });

  test('orx:version is accepted as the version', () {
    const xml =
        '<data id="$formId" orx:version="$version" '
        'xmlns:orx="http://openrosa.org/xforms"><meta><instanceID>uuid:a'
        '</instanceID></meta></data>';
    expect(complete(xml).instanceId, 'uuid:a');
  });

  test('an instance of another form or version is refused', () {
    Matcher refused() => throwsA(
      isA<ObhijatraException>().having(
        (e) => e.code,
        'code',
        ProblemCode.formInvalid,
      ),
    );
    expect(() => complete('<data id="other" version="$version"/>'), refused());
    expect(() => complete('<data id="$formId" version="1"/>'), refused());
    expect(() => complete('not xml'), refused());
    expect(
      () => complete(
        '<data id="$formId" version="$version"><meta>'
        '<instanceID>../../etc</instanceID></meta></data>',
      ),
      refused(),
    );
  });

  group('XFormInfo', () {
    test('reads id, version and title', () {
      const xform =
          '<h:html xmlns="http://www.w3.org/2002/xforms" '
          'xmlns:h="http://www.w3.org/1999/xhtml"><h:head><h:title>T</h:title>'
          '<model><instance id="lookup"><x/></instance><instance>'
          '<data id="f" version="7"/></instance></model></h:head></h:html>';
      final info = XFormInfo.read(xform);
      expect(info.formId, 'f');
      expect(info.version, '7');
      expect(info.title, 'T');
    });

    test('refuses a document type declaration', () {
      expect(
        () => XFormInfo.read(
          '<!DOCTYPE html [<!ENTITY x "y">]><html><head><model><instance>'
          '<data id="f"/></instance></model></head></html>',
        ),
        throwsA(isA<ObhijatraException>()),
      );
    });
  });
}
