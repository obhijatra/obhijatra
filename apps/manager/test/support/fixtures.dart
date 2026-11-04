import 'package:obhijatra_manager/src/data/models.dart';

/// A secret that must never appear on screen.
const String secretName = 'Rahima Begum SECRET';
const String secretPhone = '01712345678-SECRET';

/// An XForm with two languages, one choice question and two protected
/// answers (declared with the obhijatra:protect attribute).
String householdXForm({
  String version = '3',
  String formId = 'household_visit',
  String extraBody = '',
  String extraBinds = '',
  String extraNamespaces = '',
  bool bothLanguages = true,
}) =>
    '''<?xml version="1.0"?>
<h:html xmlns="http://www.w3.org/2002/xforms"
    xmlns:h="http://www.w3.org/1999/xhtml"
    xmlns:jr="http://openrosa.org/javarosa"
    xmlns:obhijatra="https://obhijatra.org/xforms"$extraNamespaces>
  <h:head>
    <h:title>Household visit</h:title>
    <model>
      <itext>
        <translation lang="English (en)" default="true()">
          <text id="/data/head:label"><value>Household head’s name</value></text>
          <text id="/data/phone:label"><value>Mobile number</value></text>
          <text id="/data/water:label"><value>Drinking water</value></text>
          <text id="/data/water/tube:label"><value>Tube well</value></text>
          <text id="/data/members:label"><value>Household members</value></text>
        </translation>
        ${bothLanguages ? '''<translation lang="Bangla (bn)">
          <text id="/data/head:label"><value>খানা প্রধানের নাম</value></text>
          <text id="/data/phone:label"><value>মোবাইল নম্বর</value></text>
          <text id="/data/water:label"><value>খাবার পানি</value></text>
          <text id="/data/water/tube:label"><value>নলকূপ</value></text>
          <text id="/data/members:label"><value>খানার সদস্য</value></text>
        </translation>''' : ''}
      </itext>
      <instance>
        <data id="$formId" version="$version">
          <head/><phone/><water/><members/>
          <meta><instanceID/></meta>
        </data>
      </instance>
      <bind nodeset="/data/head" type="string" obhijatra:protect="protected"/>
      <bind nodeset="/data/phone" type="string" obhijatra:protect="sealed"/>
      <bind nodeset="/data/water" type="string"/>
      <bind nodeset="/data/members" type="int"/>$extraBinds
    </model>
  </h:head>
  <h:body>
    <input ref="/data/head"><label ref="jr:itext('/data/head:label')"/></input>
    <input ref="/data/phone"><label ref="jr:itext('/data/phone:label')"/></input>
    <select1 ref="/data/water">
      <label ref="jr:itext('/data/water:label')"/>
      <item><label ref="jr:itext('/data/water/tube:label')"/><value>tube</value></item>
    </select1>
    <input ref="/data/members"><label ref="jr:itext('/data/members:label')"/></input>$extraBody
  </h:body>
</h:html>''';

/// The matching submission, with real-looking secret values.
const String householdInstance =
    '''<?xml version="1.0"?>
<data id="household_visit" version="3">
  <head>$secretName</head>
  <phone>$secretPhone</phone>
  <water>tube</water>
  <members>0</members>
  <meta><instanceID>uuid:1</instanceID></meta>
</data>''';

FormVersion version(
  String id, {
  String number = '3',
  bool published = false,
  String formRecordId = 'f1',
  DateTime? created,
}) => FormVersion(
  id: id,
  formRecordId: formRecordId,
  version: number,
  published: published,
  created: created ?? DateTime.now(),
  publishedAt: published ? DateTime(2026, 10, 12) : null,
  xformFile: '$id.xml',
);

SubmissionRow row(
  int i, {
  ReviewState state = ReviewState.received,
  String comment = '',
  bool commentSupported = true,
  String id = '',
  String versionId = 'v2',
}) => SubmissionRow(
  id: id.isEmpty ? 's$i' : id,
  instanceId: 'uuid:$i',
  formRecordId: 'f1',
  formVersionId: versionId,
  formTitle: 'Household visit',
  collector: 'Nasrin Sultana',
  locationPath: '/loc00000000000a/',
  receivedAt: DateTime.now().subtract(Duration(minutes: 20 * i)),
  state: state,
  comment: comment,
  commentSupported: commentSupported,
);
