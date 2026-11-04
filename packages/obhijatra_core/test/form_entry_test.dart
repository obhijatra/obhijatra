import 'package:obhijatra_core/obhijatra_core.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';

import 'support/test_support.dart';

void main() {
  late FormEntrySession session;

  setUp(() async {
    session = await FormEntrySession.start(xformXml: householdVisitXForm);
  });
  tearDown(() => session.close());

  group('loading', () {
    test('starts on the first question with form metadata', () {
      expect(
        session.form,
        const FormVersionRef(sampleFormId, sampleFormVersion),
      );
      expect(session.title, 'Household visit');
      expect(session.languages, ['English (en)', 'Bangla (bn)']);
      expect(session.instanceId, matches(RegExp(r'^uuid:[0-9a-f-]{36}$')));

      final screen = session.screen as QuestionScreen;
      final q = screen.questions.single;
      expect(q.label, 'Date of visit');
      expect(q.kind, QuestionKind.date);
      expect(q.isRequired, isTrue);
      expect(q.value, isNull);
    });

    test('switches labels and messages to Bangla', () {
      session.language = 'Bangla (bn)';
      expect(currentLabel(session), 'পরিদর্শনের তারিখ');
      final problem = answerByLabel(session, '', '2099-01-01');
      expect(problem!.formMessage, 'পরিদর্শনের তারিখ ভবিষ্যতের হতে পারে না।');
    });

    test('rejects XML that is not an XForm', () async {
      await expectLater(
        FormEntrySession.start(xformXml: '<data id="x"/>'),
        throwsA(
          isA<ObhijatraException>().having(
            (e) => e.code,
            'code',
            ProblemCode.formInvalid,
          ),
        ),
      );
    });
  });

  group('validation', () {
    test('a required question blocks next()', () {
      final result = session.next();
      expect(result, isA<Blocked>());
      final message = (result as Blocked).messages.single;
      expect(message.issue, ValidationIssue.required);
      expect(currentLabel(session), 'Date of visit');
    });

    test('a date constraint gives the form message', () {
      final problem = answerByLabel(session, 'Date of visit', '2099-01-01');
      expect(problem!.issue, ValidationIssue.constraint);
      expect(problem.formMessage, 'The visit date cannot be in the future.');
      expect(answerByLabel(session, 'Date of visit', '2026-11-01'), isNull);
    });

    test('text that does not fit the type is an invalid value', () {
      expect(
        answerByLabel(session, 'Date of visit', 'yesterday')!.issue,
        ValidationIssue.invalidValue,
      );
      session.next();
    });

    test('select_one accepts only offered choices', () {
      answerByLabel(session, 'Date of visit', '2026-11-01');
      session.next();
      final q = (session.screen as QuestionScreen).questions.single;
      expect(q.kind, QuestionKind.selectOne);
      expect(q.choices.map((c) => c.value), ['met', 'not_home', 'declined']);
      expect(q.choices.first.label, 'Met the household');
      expect(session.answer(q, 'maybe')!.issue, ValidationIssue.invalidValue);
      expect(session.answer(q, 'met'), isNull);
    });

    test('integer constraint, Bangla digits and a cross-question rule', () {
      _goToHousehold(session);
      expect(
        answerByLabel(session, 'How many people', '40')!.formMessage,
        'Enter a number from 1 to 30.',
      );
      expect(answerByLabel(session, 'How many people', '৪'), isNull);
      final size = (session.screen as QuestionScreen).questions.single;
      expect(size.value, '4');
      expect(size.hint, 'Count everyone who usually eats and sleeps here.');
      expect(session.next(), isA<Moved>());

      expect(
        answerByLabel(session, 'How many of them', '5')!.issue,
        ValidationIssue.constraint,
      );
      expect(answerByLabel(session, 'How many of them', '4'), isNull);
    });
  });

  group('navigation and skip logic', () {
    test('a household that was not met skips the household questions', () {
      answerByLabel(session, 'Date of visit', '2026-11-01');
      session.next();
      answerByLabel(session, 'What happened', 'not_home');
      session.next();
      expect(currentLabel(session), 'Why could the visit not go ahead?');
      // Required while relevant.
      expect(session.next(), isA<Blocked>());
      answerByLabel(session, 'Why could', 'The family was at the market.');
      session.next();
      expect(currentLabel(session), 'Notes (optional)');
      session.next();
      expect(session.screen, isA<EndOfFormScreen>());
    });

    test('a household that was met skips the reason question', () {
      _goToHousehold(session);
      expect(currentLabel(session), 'How many people live in the household?');
      session.back();
      expect(currentLabel(session), 'Name of the household head');
      session.back();
      session.back();
      expect(currentLabel(session), 'Date of visit');
      // Back from the first screen stays there.
      session.back();
      expect(currentLabel(session), 'Date of visit');
    });

    test('progress counts relevant questions only', () {
      // Before the outcome is known, the reason question is relevant and
      // the three household questions are not.
      expect(session.progress, (answered: 0, total: 4));
      answerByLabel(session, 'Date of visit', '2026-11-01');
      session.next();
      answerByLabel(session, 'What happened', 'met');
      // Now the household questions count and the reason does not.
      expect(session.progress, (answered: 2, total: 6));
    });
  });

  group('drafts', () {
    test('a saved draft resumes with its answers and instance id', () async {
      _goToHousehold(session);
      final draft = session.saveDraft();
      final id = session.instanceId;

      final resumed = await FormEntrySession.start(
        xformXml: householdVisitXForm,
        draftXml: draft,
      );
      addTearDown(resumed.close);
      expect(resumed.instanceId, id);
      expect(resumed.progress.answered, 3);
      expect(currentLabel(resumed), 'Date of visit');
      expect(
        (resumed.screen as QuestionScreen).questions.single.value,
        '2026-11-01',
      );
    });
  });

  group('finalising', () {
    test('is blocked by a missing required answer and shows it', () {
      _goToHousehold(session);
      final result = session.finalise();
      expect(result, isA<FinaliseBlocked>());
      expect(
        (result as FinaliseBlocked).message.issue,
        ValidationIssue.required,
      );
      expect(currentLabel(session), 'How many people live in the household?');
    });

    test('serialises the instance with id, version and instanceID', () async {
      final instance = await fillHouseholdVisit();
      expect(instance.form.formId, sampleFormId);
      expect(instance.form.version, sampleFormVersion);
      expect(instance.instanceId, matches(RegExp(r'^uuid:[0-9a-f-]{36}$')));
      expect(instance.xml, startsWith('<?xml'));
      expect(instance.attachmentNames, isEmpty);

      final root = XmlDocument.parse(instance.xml).rootElement;
      expect(root.name.local, 'data');
      expect(root.getAttribute('id'), sampleFormId);
      expect(root.getAttribute('version'), sampleFormVersion);
      expect(
        root
            .findElements('meta')
            .single
            .findElements('instanceID')
            .single
            .innerText,
        instance.instanceId,
      );
      expect(
        root.findElements('household_head').single.innerText,
        'Rahima Begum',
      );
      expect(root.findElements('household_size').single.innerText, '5');
      // Non-relevant questions are left out of the submission.
      expect(root.findElements('reason_not_met'), isEmpty);
    });
  });

  group('field-list groups and repeats', () {
    const xform = '''<?xml version="1.0"?>
<h:html xmlns="http://www.w3.org/2002/xforms" xmlns:h="http://www.w3.org/1999/xhtml">
  <h:head>
    <h:title>Members</h:title>
    <model>
      <instance>
        <data id="members" version="1">
          <contact><phone/><village/></contact>
          <member><name/></member>
          <done/>
        </data>
      </instance>
      <bind nodeset="/data/contact/phone" type="string"/>
      <bind nodeset="/data/contact/village" type="string" required="true()"/>
      <bind nodeset="/data/member/name" type="string"/>
      <bind nodeset="/data/done" type="string"/>
    </model>
  </h:head>
  <h:body>
    <group ref="/data/contact" appearance="field-list">
      <label>Contact</label>
      <input ref="/data/contact/phone"><label>Phone</label></input>
      <input ref="/data/contact/village"><label>Village</label></input>
    </group>
    <group ref="/data/member">
      <label>Member</label>
      <repeat nodeset="/data/member">
        <input ref="/data/member/name"><label>Member name</label></input>
      </repeat>
    </group>
    <input ref="/data/done"><label>Done</label></input>
  </h:body>
</h:html>''';

    test('show group questions together and offer to add repeats', () async {
      final s = await FormEntrySession.start(xformXml: xform);
      addTearDown(s.close);

      final contact = s.screen as QuestionScreen;
      expect(contact.groupLabel, 'Contact');
      expect(contact.questions.map((q) => q.label), ['Phone', 'Village']);
      expect(s.next(), isA<Blocked>()); // Village is required.
      answerByLabel(s, 'Village', 'Char Kukri');
      expect(s.next(), isA<Moved>());

      expect(currentLabel(s), 'Member name');
      answerByLabel(s, 'Member name', 'Amina');
      s.next();
      expect(s.screen, isA<RepeatPromptScreen>());
      s.addRepeat();
      expect(currentLabel(s), 'Member name');
      answerByLabel(s, 'Member name', 'Karim');
      s.next();
      expect(s.screen, isA<RepeatPromptScreen>());
      s.next();
      expect(currentLabel(s), 'Done');
      // Back over a repeat lands on the prompt, then on the last member.
      s.back();
      expect(s.screen, isA<RepeatPromptScreen>());
      s.back();
      expect(currentLabel(s), 'Member name');
      s.back();
      s.back();
      s.back();
      expect((s.screen as QuestionScreen).groupLabel, 'Contact');

      final result = s.finalise();
      expect(result, isA<Finalised>());
      final xml = (result as Finalised).instance.xml;
      expect('<name>'.allMatches(xml).length, 2);
    });

    test('a form without meta/instanceID gets one in the submission', () async {
      final s = await FormEntrySession.start(xformXml: xform);
      addTearDown(s.close);
      answerByLabel(s, 'Village', 'Char Kukri');
      final result = s.finalise() as Finalised;
      expect(result.instance.instanceId, s.instanceId);
      final meta = XmlDocument.parse(result.instance.xml).rootElement
          .findElements('meta')
          .single;
      expect(meta.findElements('instanceID').single.innerText, s.instanceId);

      // A draft of such a form keeps the id the app passes back.
      final resumed = await FormEntrySession.start(
        xformXml: xform,
        draftXml: s.saveDraft(),
        instanceId: s.instanceId,
      );
      addTearDown(resumed.close);
      expect(resumed.instanceId, s.instanceId);
    });
  });
}

/// Answers the first two questions so that the household questions show.
void _goToHousehold(FormEntrySession session) {
  answerByLabel(session, 'Date of visit', '2026-11-01');
  session.next();
  answerByLabel(session, 'What happened', 'met');
  session.next();
  answerByLabel(session, 'Name of the household head', 'Rahima Begum');
  session.next();
}
