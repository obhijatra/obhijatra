import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:obhijatra_core/obhijatra_core.dart';
import 'package:obhijatra_field/l10n/app_localizations.dart';
import 'package:obhijatra_field/l10n/app_localizations_bn.dart';
import 'package:obhijatra_field/l10n/app_localizations_en.dart';
import 'package:obhijatra_field/src/l10n/problem_text.dart';

Map<String, Object?> _arb(String lang) =>
    jsonDecode(File('lib/l10n/app_$lang.arb').readAsStringSync())
        as Map<String, Object?>;

bool _hasBangla(String text) => RegExp(r'[ঀ-৿]').hasMatch(text);

void main() {
  final en = AppLocalizationsEn();
  final bn = AppLocalizationsBn();

  test('Bangla is the default language', () {
    expect(AppLocalizations.supportedLocales.first.languageCode, 'bn');
  });

  test('every ProblemCode has a plain English and a Bangla sentence', () {
    for (final code in ProblemCode.values) {
      final english = problemText(en, code);
      final bangla = problemText(bn, code);
      expect(english.trim(), isNotEmpty, reason: '$code (en)');
      expect(bangla.trim(), isNotEmpty, reason: '$code (bn)');
      expect(_hasBangla(bangla), isTrue, reason: '$code (bn) is Bangla');
      expect(_hasBangla(english), isFalse, reason: '$code (en) is English');
      // Plain words only: no codes, class names or technical terms.
      for (final term in ['Exception', 'HTTP', 'null', code.name]) {
        expect(english.contains(term), isFalse, reason: '$code says "$term"');
      }
    }
  });

  test('English and Bangla files hold the same messages', () {
    final english = _arb('en').keys.where((k) => !k.startsWith('@')).toSet();
    final bangla = _arb('bn').keys.where((k) => !k.startsWith('@')).toSet();
    expect(bangla.difference(english), isEmpty);
    expect(english.difference(bangla), isEmpty);
  });

  test('the Bangla file is marked as a draft for the owner to check', () {
    final bangla = _arb('bn');
    expect(bangla['@@x-translation-status'], contains('DRAFT'));
    for (final code in ProblemCode.values) {
      final meta = bangla['@problem_${code.name}'] as Map<String, Object?>;
      expect(meta['x-translation-status'], contains('draft'));
    }
  });

  test(
    'every Bangla message is written in Bangla (except named exceptions)',
    () {
      const keepsEnglish = {
        'languageEnglish', // the English language, written in English
        'aboutMadeBy', // the credit line is plain English text on purpose
        'connectAddressHelp', // contains an example address
        'connectErrorShape',
        'validationItem', // only placeholders
      };
      final bangla = _arb('bn');
      for (final entry in bangla.entries) {
        if (entry.key.startsWith('@') || keepsEnglish.contains(entry.key)) {
          continue;
        }
        expect(_hasBangla(entry.value! as String), isTrue, reason: entry.key);
      }
    },
  );

  test('the owner\'s wording decisions are kept', () {
    expect(bn.appTitle, 'অভিযাত্রা');
    expect(en.appTitle, 'Obhijatra');
    expect(bn.savedBadge, 'সেভ হয়েছে');
    expect(bn.aboutMadeBy, 'Made by Aninda Studio');
    expect(en.aboutMadeBy, 'Made by Aninda Studio');
  });

  test('numbers are written in Bangla digits in Bangla', () {
    expect(bn.questionProgress(4, 12), 'প্রশ্ন ৪/১২');
    expect(en.questionProgress(4, 12), 'Question 4 of 12');
    expect(bn.formMetaDrafts(3), '৩টি খসড়া সেভ করা আছে');
    expect(en.formMetaDrafts(1), '1 draft saved');
    expect(en.formMetaDrafts(2), '2 drafts saved');
    expect(bn.summaryAnsweredValue(11, 12), '১২টির মধ্যে ১১টি');
    expect(en.validationTitle(1), 'One answer needs fixing');
    expect(en.validationTitle(3), '3 answers need fixing');
    expect(bn.validationTitle(1), 'একটি উত্তর ঠিক করতে হবে');
    expect(bn.validationTitle(3), '৩টি উত্তর ঠিক করতে হবে');
  });

  test('a wrong phone clock is explained as an action to take', () {
    expect(en.problem_clockSkew, contains('date and time'));
    expect(en.problem_clockSkew, contains('Settings'));
    expect(bn.problem_clockSkew, contains('তারিখ ও সময়'));
    final meta = _arb('bn')['@problem_clockSkew']! as Map<String, Object?>;
    expect(meta['x-translation-status'], contains('draft'));
  });

  test('no screen text mentions the device code or encryption yet', () {
    // The six-word device code and field-level protection come in the next
    // milestone; nothing may claim them now.
    final english = _arb('en');
    for (final entry in english.entries) {
      if (entry.key.startsWith('@')) continue;
      final text = (entry.value! as String).toLowerCase();
      expect(text.contains('six words'), isFalse, reason: entry.key);
      expect(text.contains('encrypt'), isFalse, reason: entry.key);
      expect(
        text.contains('only your organisation can read'),
        isFalse,
        reason: entry.key,
      );
    }
  });
}
