import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obhijatra_ui/obhijatra_ui.dart';

/// The words each widget is tested with, in both languages.
const Map<String, Map<String, String>> _words = <String, Map<String, String>>{
  'en': <String, String>{
    'label': 'Where does the drinking water come from?',
    'a': 'Tube well',
    'b': 'Pond or river',
    'required': 'Required',
    'button': 'Next',
    'offline': "You're offline.",
    'offlineBody': 'Your work is safe on this phone.',
    'protected': 'Protected on this phone',
    'problem': 'One answer needs fixing',
    'fix': 'Fix it, then send again.',
    'item': 'Age: Please answer this question.',
    'sync': 'Waiting to send',
  },
  'bn': <String, String>{
    'label': 'খাবার পানি কোথা থেকে আসে?',
    'a': 'নলকূপ',
    'b': 'পুকুর বা নদী',
    'required': 'আবশ্যক',
    'button': 'পরের প্রশ্ন',
    'offline': 'আপনি অফলাইনে আছেন।',
    'offlineBody': 'আপনার কাজ এই ফোনে নিরাপদ আছে।',
    'protected': 'এই ফোনে সুরক্ষিত',
    'problem': 'একটি উত্তর ঠিক করতে হবে',
    'fix': 'ঠিক করুন, তারপর আবার পাঠান।',
    'item': 'বয়স: এই প্রশ্নের উত্তর দিন।',
    'sync': 'পাঠানোর অপেক্ষায়',
  },
};

Future<void> _show(
  WidgetTester tester,
  Widget child, {
  required String language,
  required double scale,
}) async {
  tester.view
    ..physicalSize = const Size(360 * 3, 800 * 3)
    ..devicePixelRatio = 3;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });
  final locale = Locale(language);
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      theme: ObhijatraTheme.light(locale: locale),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    ),
  );
  await tester.pump();
}

/// Runs [body] for both languages at the normal and the largest text size.
void _matrix(
  String name,
  Future<void> Function(WidgetTester tester, Map<String, String> w, String language, double scale) body,
) {
  for (final language in <String>['bn', 'en']) {
    for (final scale in <double>[1.0, 2.0]) {
      testWidgets('$name [$language, text x$scale]', (tester) async {
        final handle = tester.ensureSemantics();
        await body(tester, _words[language]!, language, scale);
        // Nothing overflowed (the framework reports overflow as an error).
        expect(tester.takeException(), isNull);
        handle.dispose();
      });
    }
  }
}

void main() {
  group('PrimaryButton', () {
    _matrix('is at least 48 dp tall, labelled, and taps', (tester, w, language, scale) async {
      var taps = 0;
      await _show(
        tester,
        PrimaryButton(label: w['button']!, onPressed: () => taps++),
        language: language,
        scale: scale,
      );
      expect(tester.getSize(find.byType(PrimaryButton)).height, greaterThanOrEqualTo(48));
      expect(find.bySemanticsLabel(w['button']!), findsOneWidget);
      await tester.tap(find.text(w['button']!));
      expect(taps, 1);
    });

    _matrix('shows busy and cannot be tapped', (tester, w, language, scale) async {
      var taps = 0;
      await _show(
        tester,
        PrimaryButton(label: w['button']!, busy: true, onPressed: () => taps++),
        language: language,
        scale: scale,
      );
      await tester.tap(find.byType(PrimaryButton), warnIfMissed: false);
      expect(taps, 0);
    });

    _matrix('a disabled button does nothing', (tester, w, language, scale) async {
      await _show(
        tester,
        PrimaryButton(label: w['button']!, onPressed: null),
        language: language,
        scale: scale,
      );
      expect(find.text(w['button']!), findsOneWidget);
    });
  });

  group('QuestionChoice', () {
    _matrix('select one: tapping chooses, and only one stays chosen', (tester, w, language, scale) async {
      var selected = <String>{};
      late StateSetter set;
      await _show(
        tester,
        StatefulBuilder(
          builder: (context, setState) {
            set = setState;
            return QuestionChoice(
              label: w['label']!,
              number: '1',
              requiredLabel: w['required'],
              options: <ChoiceOption>[ChoiceOption('a', w['a']!), ChoiceOption('b', w['b']!)],
              selected: selected,
              onChanged: (v) => set(() => selected = v),
            );
          },
        ),
        language: language,
        scale: scale,
      );
      await tester.tap(find.text(w['a']!));
      await tester.pump();
      await tester.tap(find.text(w['b']!));
      await tester.pump();
      expect(selected, <String>{'b'});
      // A screen reader hears the state in words, not only the mark.
      expect(
        tester.getSemantics(find.bySemanticsLabel(w['b']!)),
        isSemantics(
          label: w['b'],
          isChecked: true,
          hasCheckedState: true,
          isInMutuallyExclusiveGroup: true,
          isButton: true,
          hasTapAction: true,
        ),
      );
    });

    _matrix('select many: each tap toggles', (tester, w, language, scale) async {
      var selected = <String>{};
      late StateSetter set;
      await _show(
        tester,
        StatefulBuilder(
          builder: (context, setState) {
            set = setState;
            return QuestionChoice(
              label: w['label']!,
              multiple: true,
              options: <ChoiceOption>[ChoiceOption('a', w['a']!), ChoiceOption('b', w['b']!)],
              selected: selected,
              onChanged: (v) => set(() => selected = v),
            );
          },
        ),
        language: language,
        scale: scale,
      );
      await tester.tap(find.text(w['a']!));
      await tester.pump();
      await tester.tap(find.text(w['b']!));
      await tester.pump();
      expect(selected, <String>{'a', 'b'});
      await tester.tap(find.text(w['a']!));
      await tester.pump();
      expect(selected, <String>{'b'});
    });

    _matrix('shows an error in words', (tester, w, language, scale) async {
      await _show(
        tester,
        QuestionChoice(
          label: w['label']!,
          options: <ChoiceOption>[ChoiceOption('a', w['a']!)],
          selected: const <String>{},
          onChanged: (_) {},
          errorText: w['item'],
        ),
        language: language,
        scale: scale,
      );
      expect(find.text(w['item']!), findsOneWidget);
    });
  });

  group('QuestionText', () {
    _matrix('whole numbers accept English and Bangla digits only', (tester, w, language, scale) async {
      String? last;
      await _show(
        tester,
        QuestionText(
          label: w['label']!,
          kind: QuestionTextKind.integer,
          onChanged: (v) => last = v,
        ),
        language: language,
        scale: scale,
      );
      await tester.enterText(find.byType(EditableText), 'a1২b3');
      expect(last, isNotNull);
      expect(last!.replaceAll(RegExp('[0-9০-৯]'), ''), isEmpty);
    });

    _matrix('plain text keeps what is typed', (tester, w, language, scale) async {
      String? last;
      await _show(
        tester,
        QuestionText(label: w['label']!, onChanged: (v) => last = v),
        language: language,
        scale: scale,
      );
      await tester.enterText(find.byType(EditableText), w['a']!);
      expect(last, w['a']);
    });
  });

  group('QuestionDate', () {
    _matrix('opens the date picker and reports the day chosen', (tester, w, language, scale) async {
      DateTime? picked;
      await _show(
        tester,
        QuestionDate(
          label: w['label']!,
          valueText: null,
          pickLabel: w['button']!,
          onChanged: (d) => picked = d,
        ),
        language: language,
        scale: scale,
      );
      await tester.tap(find.text(w['button']!));
      await tester.pumpAndSettle();
      final ok = MaterialLocalizations.of(tester.element(find.byType(DatePickerDialog))).okButtonLabel;
      await tester.tap(find.text(ok));
      await tester.pumpAndSettle();
      expect(picked, isNotNull);
    });
  });

  group('OfflineBanner', () {
    _matrix('shows title and message, announced as one line', (tester, w, language, scale) async {
      await _show(
        tester,
        OfflineBanner(title: w['offline']!, message: w['offlineBody']!),
        language: language,
        scale: scale,
      );
      expect(find.textContaining(w['offline']!), findsOneWidget);
      expect(find.bySemanticsLabel('${w['offline']} ${w['offlineBody']}'), findsOneWidget);
      // Fills the width it is given (the test page has 16 dp on each side).
      expect(tester.getSize(find.byType(OfflineBanner)).width, 328);
    });
  });

  group('ProtectedChip', () {
    _matrix('shows its words next to the icon', (tester, w, language, scale) async {
      await _show(tester, ProtectedChip(label: w['protected']!), language: language, scale: scale);
      expect(find.text(w['protected']!), findsOneWidget);
    });
  });

  group('SyncStatusBadge', () {
    _matrix('every state has words, never colour alone', (tester, w, language, scale) async {
      for (final state in SyncVisualState.values) {
        await _show(
          tester,
          SyncStatusBadge(state: state, label: '${w['sync']} ${state.name}'),
          language: language,
          scale: scale,
        );
        expect(find.text('${w['sync']} ${state.name}'), findsOneWidget);
        expect(find.byType(Icon), findsWidgets);
      }
    });
  });

  group('ValidationSummary', () {
    _matrix('lists each problem and taps through to it', (tester, w, language, scale) async {
      var taps = 0;
      await _show(
        tester,
        ValidationSummary(
          title: w['problem']!,
          message: w['fix']!,
          items: <ValidationSummaryItem>[ValidationSummaryItem(label: w['item']!, onTap: () => taps++)],
        ),
        language: language,
        scale: scale,
      );
      expect(find.text(w['problem']!), findsOneWidget);
      await tester.tap(find.text(w['item']!));
      expect(taps, 1);
      final target = tester.getSize(find.ancestor(of: find.text(w['item']!), matching: find.byType(InkWell)).first);
      expect(target.height, greaterThanOrEqualTo(48));
    });
  });

  group('Cards', () {
    _matrix('an action card is large, labelled and taps', (tester, w, language, scale) async {
      var taps = 0;
      await _show(
        tester,
        ActionCard(icon: Icons.edit, title: w['label']!, meta: w['a'], onTap: () => taps++),
        language: language,
        scale: scale,
      );
      expect(tester.getSize(find.byType(ActionCard)).height, greaterThanOrEqualTo(72));
      await tester.tap(find.text(w['label']!));
      expect(taps, 1);
    });

    _matrix('a stat card shows its number and words', (tester, w, language, scale) async {
      await _show(
        tester,
        StatCard(number: '3', label: w['sync']!, icon: Icons.cloud_upload, onTap: () {}),
        language: language,
        scale: scale,
      );
      expect(find.text('3'), findsOneWidget);
      expect(find.text(w['sync']!), findsOneWidget);
      expect(tester.getSize(find.byType(StatCard)).height, greaterThanOrEqualTo(96));
    });
  });
}
