import 'package:flutter_test/flutter_test.dart';
import 'package:obhijatra_manager/src/data/models.dart';
import 'package:obhijatra_manager/src/xform/form_definition.dart';
import 'package:obhijatra_manager/src/xform/instance_parser.dart';
import 'package:obhijatra_manager/src/xform/publish_checks.dart';

import 'support/fixtures.dart';

PublishCheck? find(PublishReport r, CheckCode code) =>
    r.checks.where((c) => c.code == code).firstOrNull;

void main() {
  group('publish checks', () {
    test('a good form passes and lists the protected answers', () {
      final report = checkXForm(householdXForm());
      expect(report.canPublish, isTrue);
      expect(report.formId, 'household_visit');
      expect(report.version, '3');
      expect(report.questionCount, 4);
      expect(find(report, CheckCode.wellFormed)!.kind, CheckKind.passed);
      final protectedList = find(report, CheckCode.protectedList)!;
      expect(protectedList.kind, CheckKind.protectedAnswers);
      expect(protectedList.items, <String>[
        'Household head’s name',
        'Mobile number',
      ]);
      expect(find(report, CheckCode.languagesOk), isNotNull);
    });

    test('protected labels follow the language', () {
      final report = checkXForm(householdXForm(), lang: 'bn');
      expect(find(report, CheckCode.protectedList)!.items, <String>[
        'খানা প্রধানের নাম',
        'মোবাইল নম্বর',
      ]);
    });

    test('text that is not XML is a problem and stops the checks', () {
      final report = checkXForm('this is not xml <');
      expect(report.canPublish, isFalse);
      expect(report.checks.single.code, CheckCode.unreadable);
    });

    test('XML that is not an XForm is a problem', () {
      final report = checkXForm('<hello/>');
      expect(report.checks.single.code, CheckCode.notXForm);
    });

    test('a document type declaration is refused', () {
      final report = checkXForm(
        '<!DOCTYPE html [<!ENTITY x "y">]>${householdXForm()}',
      );
      expect(report.canPublish, isFalse);
    });

    test('a missing version and a missing form id are problems', () {
      final noVersion = checkXForm(householdXForm(version: ''));
      expect(
        find(noVersion, CheckCode.versionMissing)!.kind,
        CheckKind.problem,
      );
      final noId = checkXForm(householdXForm(formId: ''));
      expect(find(noId, CheckCode.formIdMissing)!.kind, CheckKind.problem);
      expect(noVersion.canPublish, isFalse);
      expect(noId.canPublish, isFalse);
    });

    test('a version that already exists is a problem', () {
      final report = checkXForm(
        householdXForm(),
        existingVersions: <String>['3'],
      );
      expect(find(report, CheckCode.versionExists)!.value, '3');
      expect(report.canPublish, isFalse);
    });

    test('Kobo-only question types are found by name', () {
      final xml = householdXForm(
        extraNamespaces: ' xmlns:kobo="http://kobotoolbox.org/xforms"',
        extraBody: '''
<group ref="/data/water_sources" appearance="field-list" kobo--matrix_list="water_list"><label>Sources</label></group>
<select ref="/data/rate" kobo--score-choices="s"><label>Rate</label></select>
<select ref="/data/order" kobo--rank-items="r"><label>Order</label></select>''',
      );
      final report = checkXForm(xml);
      expect(report.canPublish, isFalse);
      expect(find(report, CheckCode.koboMatrix)!.items, <String>[
        'water_sources',
      ]);
      expect(find(report, CheckCode.koboScore)!.items, <String>['rate']);
      expect(find(report, CheckCode.koboRank)!.items, <String>['order']);
      expect(report.problemCount, 3);
      // Problems come first.
      expect(report.checks.first.kind, CheckKind.problem);
    });

    test('a single-language form gets a note, not a problem', () {
      final report = checkXForm(householdXForm(bothLanguages: false));
      expect(report.canPublish, isTrue);
      expect(find(report, CheckCode.singleLanguage)!.kind, CheckKind.note);
    });
  });

  group('reading answers', () {
    test('a protected answer has no value anywhere', () {
      final definition = FormDefinition.parse(householdXForm());
      final answers = parseAnswers(householdInstance, definition);
      expect(answers.map((a) => a.label), <String>[
        'Household head’s name',
        'Mobile number',
        'Drinking water',
        'Household members',
      ]);
      expect(answers[0].isProtected, isTrue);
      expect(answers[0].value, isNull);
      expect(answers[1].isProtected, isTrue);
      expect(answers[1].value, isNull);
      expect(answers[2].value, 'Tube well'); // choice label, not the code
      expect(answers[3].value, '0');
      // Nothing about the secrets survives in any field of any answer.
      final dump = answers
          .map((a) => '${a.label}|${a.value}|${a.isProtected}')
          .join('\n');
      expect(dump, isNot(contains('SECRET')));
    });

    test('labels follow the language', () {
      final definition = FormDefinition.parse(householdXForm());
      final answers = parseAnswers(householdInstance, definition, lang: 'bn');
      expect(answers[2].label, 'খাবার পানি');
      expect(answers[2].value, 'নলকূপ');
    });

    test('protection covers a whole group', () {
      final xml = householdXForm(
        extraBinds: '<bind nodeset="/data/grp" obhijatra:protect="protected"/>',
      );
      final definition = FormDefinition.parse(xml);
      const instance =
          '<data id="household_visit"><grp><a>SECRET-A</a><b>SECRET-B</b></grp><members>2</members></data>';
      final answers = parseAnswers(instance, definition);
      expect(answers.where((a) => a.isProtected), hasLength(1));
      expect(answers.map((a) => a.value), isNot(contains('SECRET-A')));
    });

    test('a bind that says protect=false does not protect', () {
      final xml = householdXForm(
        extraBinds: '<bind nodeset="/data/open" obhijatra:protect="false"/>',
      );
      expect(
        FormDefinition.parse(xml).protectedPaths,
        isNot(contains('/data/open')),
      );
    });

    test('unlabelled answers fall back to the element name; empty ones are skipped', () {
      final definition = FormDefinition.parse(householdXForm());
      final answers = parseAnswers(
        '<data id="x"><mystery>42</mystery><empty/></data>',
        definition,
      );
      expect(answers.single.label, 'mystery');
      expect(answers.single.value, '42');
    });

    test(
      'broken instance XML is a FormatException, never a partial answer list',
      () {
        final definition = FormDefinition.parse(householdXForm());
        expect(
          () => parseAnswers('<data><a>', definition),
          throwsFormatException,
        );
      },
    );

    test('Answer.protected has nowhere to keep a value', () {
      const answer = Answer.protected(label: 'x');
      expect(answer.value, isNull);
    });
  });
}
