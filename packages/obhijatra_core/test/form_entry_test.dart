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

  group('position and total', () {
    test('count every relevant question and follow skip logic', () {
      // Date, outcome, "why not met" (relevant until the outcome is
      // "met") and notes.
      expect((session.position, session.total), (0, 4));
      answerByLabel(session, 'Date of visit', '2026-11-01');
      session.next();
      expect((session.position, session.total), (1, 4));
      answerByLabel(session, 'What happened', 'met');
      // Recomputed at once: head, size and children instead of the reason.
      expect((session.position, session.total), (1, 6));
      session.next();
      expect(currentLabel(session), 'Name of the household head');
      expect((session.position, session.total), (2, 6));
      answerByLabel(session, 'Name of the household head', 'Rahima Begum');
      session.next();
      session.back();
      expect((session.position, session.total), (2, 6));
      // Changing the outcome on the way back shrinks the total again.
      session.back();
      answerByLabel(session, 'What happened', 'not_home');
      expect((session.position, session.total), (1, 4));
    });

    test('at the end of the form, position equals total', () async {
      final s = await FormEntrySession.start(xformXml: householdVisitXForm);
      addTearDown(s.close);
      answerByLabel(s, 'Date of visit', '2026-11-01');
      s.next();
      answerByLabel(s, 'What happened', 'declined');
      s.next();
      answerByLabel(s, 'Why could', 'Busy.');
      s.next();
      expect((s.position, s.total), (3, 4));
      s.next();
      expect(s.screen, isA<EndOfFormScreen>());
      expect((s.position, s.total), (4, 4));
    });
  });

  group('validateAll and jumpTo', () {
    test('lists every failing question in form order without moving', () {
      final failed = session.validateAll();
      expect(failed.map((f) => f.question.label), [
        'Date of visit',
        'What happened at the visit?',
        'Why could the visit not go ahead?',
      ]);
      expect(
        failed.map((f) => f.issue),
        everyElement(ValidationIssue.required),
      );
      expect(failed.first.message.questionKey, failed.first.question.key);
      expect(currentLabel(session), 'Date of visit');
      expect(session.position, 0);
    });

    test('finds a broken cross-question rule and the form message', () {
      _goToHousehold(session);
      answerByLabel(session, 'How many people', '5');
      session.next();
      answerByLabel(session, 'How many of them', '4');
      session.next();
      // Back on the household size, a smaller number breaks the children
      // rule further on.
      session.back();
      session.back();
      expect(answerByLabel(session, 'How many people', '3'), isNull);
      final failed = session.validateAll();
      expect(failed, hasLength(1));
      expect(
        failed.single.question.label,
        'How many of them are under five years old?',
      );
      expect(failed.single.issue, ValidationIssue.constraint);
      expect(
        failed.single.message.formMessage,
        'This cannot be more than the number of people in the household.',
      );
      // The answers were not changed by checking them.
      expect(failed.single.question.value, '4');
      expect(session.finalise(), isA<FinaliseBlocked>());
    });

    test('is empty exactly when finalise succeeds', () async {
      final s = await FormEntrySession.start(xformXml: householdVisitXForm);
      addTearDown(s.close);
      answerByLabel(s, 'Date of visit', '2026-11-01');
      s.next();
      answerByLabel(s, 'What happened', 'not_home');
      s.next();
      answerByLabel(s, 'Why could', 'Away.');
      expect(s.validateAll(), isEmpty);
      expect(s.finalise(), isA<Finalised>());
    });

    test('messages follow the form language', () {
      session.language = 'Bangla (bn)';
      expect(session.validateAll().first.question.label, 'পরিদর্শনের তারিখ');
    });

    test('jumpTo opens a failing question, backwards and forwards', () {
      final dateKey = (session.screen as QuestionScreen).questions.single.key;
      _goToHousehold(session);
      expect(currentLabel(session), 'How many people live in the household?');
      final failed = session.validateAll();
      expect(failed.map((f) => f.question.label), [
        'How many people live in the household?',
      ]);

      // Back to the first question...
      expect(session.jumpTo(dateKey), isTrue);
      expect(currentLabel(session), 'Date of visit');
      expect(session.position, 0);

      // ...and forward to the failing one; nothing is checked on the way.
      expect(session.jumpTo(failed.single.question.key), isTrue);
      expect(currentLabel(session), 'How many people live in the household?');
      expect(session.position, 3);
      expect(session.validateScreen().single.issue, ValidationIssue.required);
    });

    test('jumpTo refuses a question that is not relevant or unknown', () {
      answerByLabel(session, 'Date of visit', '2026-11-01');
      session.next();
      answerByLabel(session, 'What happened', 'not_home');
      session.next();
      final reasonKey = (session.screen as QuestionScreen).questions.single.key;
      session.back();
      // Once the household was met, the reason question no longer applies.
      answerByLabel(session, 'What happened', 'met');
      expect(session.jumpTo(reasonKey), isFalse);
      expect(session.jumpTo('no such question'), isFalse);
      expect(session.jumpTo(''), isFalse);
      expect(currentLabel(session), 'What happened at the visit?');
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

    test('position, total and jumpTo across groups and repeats', () async {
      final s = await FormEntrySession.start(xformXml: xform);
      addTearDown(s.close);
      // Phone and village on one screen, one member, done.
      expect((s.position, s.total), (0, 4));
      answerByLabel(s, 'Village', 'Char Kukri');
      s.next();
      expect((s.position, s.total), (2, 4));
      answerByLabel(s, 'Member name', 'Amina');
      s.next();
      expect(s.screen, isA<RepeatPromptScreen>());
      expect(s.position, 3);
      s.addRepeat();
      expect((s.position, s.total), (3, 5));
      final karim = (s.screen as QuestionScreen).questions.single.key;
      s.next();
      s.next();
      expect(currentLabel(s), 'Done');
      expect((s.position, s.total), (4, 5));

      // A question in a field-list group opens the whole group.
      s.back();
      s.back();
      s.back();
      s.back();
      final village = (s.screen as QuestionScreen).questions.last.key;
      expect(s.jumpTo(karim), isTrue);
      expect(s.position, 3);
      expect(s.jumpTo(village), isTrue);
      final screen = s.screen as QuestionScreen;
      expect(screen.groupLabel, 'Contact');
      expect(screen.questions.map((q) => q.label), ['Phone', 'Village']);
      expect(s.position, 0);
      expect(s.validateAll(), isEmpty);
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
