import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obhijatra_ui/obhijatra_ui.dart';

/// WCAG 2.x relative luminance of an sRGB colour.
double _luminance(Color c) {
  double lin(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b);
}

/// WCAG 2.x contrast ratio between two opaque colours.
double contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  const palettes = <String, ObhijatraPalette>{
    'light': ObhijatraPalette.light,
    'dark': ObhijatraPalette.dark,
  };

  group('theme builds', () {
    test('light, dark and Bangla variants', () {
      for (final theme in <ThemeData>[
        ObhijatraTheme.light(),
        ObhijatraTheme.dark(),
        ObhijatraTheme.light(locale: const Locale('bn')),
        ObhijatraTheme.dark(locale: const Locale('bn')),
      ]) {
        expect(theme.useMaterial3, isTrue);
        expect(theme.extension<ObhijatraColors>(), isNotNull);
      }
      expect(ObhijatraTheme.light().brightness, Brightness.light);
      expect(ObhijatraTheme.dark().brightness, Brightness.dark);
    });

    testWidgets('a MaterialApp renders with it', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ObhijatraTheme.light(),
          darkTheme: ObhijatraTheme.dark(),
          home: Builder(
            builder: (context) => Scaffold(
              body: Text('Hello', style: Theme.of(context).textTheme.bodyLarge),
            ),
          ),
        ),
      );
      expect(find.text('Hello'), findsOneWidget);
      final context = tester.element(find.text('Hello'));
      expect(context.palette.bg, ObhijatraPalette.light.bg);
    });

    test('colour scheme is taken from roles', () {
      final scheme = ObhijatraTheme.light().colorScheme;
      expect(scheme.primary, ObhijatraPalette.light.action);
      expect(scheme.surface, ObhijatraPalette.light.surface);
      expect(scheme.error, ObhijatraPalette.light.danger);
      expect(ObhijatraTheme.light().scaffoldBackgroundColor,
          ObhijatraPalette.light.bg);
    });
  });

  group('contrast (WCAG 2.x)', () {
    palettes.forEach((name, p) {
      test('$name: text on bg is at least 7:1', () {
        expect(contrast(p.text, p.bg), greaterThanOrEqualTo(7));
      });
      test('$name: text on bg-subtle, surface and sunken is at least 7:1', () {
        for (final ground in <Color>[p.bgSubtle, p.surface, p.surfaceSunken]) {
          expect(contrast(p.text, ground), greaterThanOrEqualTo(7));
        }
      });
      test('$name: muted text, links and danger are at least 4.5:1 on bg', () {
        for (final fg in <Color>[p.textMuted, p.textLink, p.danger]) {
          expect(contrast(fg, p.bg), greaterThanOrEqualTo(4.5));
          expect(contrast(fg, p.surface), greaterThanOrEqualTo(4.5));
        }
      });
      test('$name: text on action, brand and accent', () {
        expect(contrast(p.onAction, p.action), greaterThanOrEqualTo(4.5));
        expect(contrast(p.textOnBrand, p.surfaceBrand),
            greaterThanOrEqualTo(7));
        expect(contrast(p.onAccent, p.accent), greaterThanOrEqualTo(7));
      });
      test('$name: control borders are at least 3:1 on bg and surface', () {
        expect(contrast(p.borderStrong, p.bg), greaterThanOrEqualTo(3));
        expect(contrast(p.borderStrong, p.surface), greaterThanOrEqualTo(3));
      });
    });

    test('the Flutter theme text colour keeps 7:1 on the scaffold', () {
      for (final theme in <ThemeData>[
        ObhijatraTheme.light(),
        ObhijatraTheme.dark(),
        ObhijatraTheme.light(locale: const Locale('bn')),
        ObhijatraTheme.dark(locale: const Locale('bn')),
      ]) {
        final fg = theme.textTheme.bodyMedium!.color!;
        expect(contrast(fg, theme.scaffoldBackgroundColor),
            greaterThanOrEqualTo(7));
      }
    });
  });

  group('type scale', () {
    test('English sizes and line heights match the design system', () {
      const expected = <TextToken, (double, double)>{
        ObhijatraType.display: (48, 56),
        ObhijatraType.h1: (36, 44),
        ObhijatraType.h2: (28, 36),
        ObhijatraType.h3: (22, 30),
        ObhijatraType.h4: (18, 26),
        ObhijatraType.bodyLg: (18, 28),
        ObhijatraType.body: (16, 24),
        ObhijatraType.bodySm: (14, 20),
        ObhijatraType.label: (14, 20),
        ObhijatraType.caption: (12, 16),
        ObhijatraType.overline: (12, 16),
        ObhijatraType.bnH1: (36, 52),
        ObhijatraType.bnH2: (28, 42),
        ObhijatraType.bnH3: (22, 34),
        ObhijatraType.bnBodyLg: (20, 32),
        ObhijatraType.bnBody: (18, 30),
        ObhijatraType.bnBodySm: (16, 26),
        ObhijatraType.bnLabel: (16, 22),
        ObhijatraType.bnCaption: (14, 22),
      };
      expected.forEach((token, size) {
        expect(token.fontSize, size.$1);
        expect(token.lineHeight, size.$2);
      });
    });

    test('Bangla text is one step larger, with a line height near 1.65', () {
      expect(ObhijatraType.bnBody.fontSize,
          greaterThan(ObhijatraType.body.fontSize));
      for (final t in <TextToken>[
        ObhijatraType.bnBodyLg,
        ObhijatraType.bnBody,
        ObhijatraType.bnBodySm,
      ]) {
        expect(t.height, inInclusiveRange(1.6, 1.7));
      }
      // One-line Bangla labels need at least 1.3.
      expect(ObhijatraType.bnLabel.height, greaterThanOrEqualTo(1.3));
    });

    test('Bangla is never letter-spaced; smallest sizes are respected', () {
      final theme = ObhijatraTheme.light(locale: const Locale('bn'));
      for (final style in <TextStyle?>[
        theme.textTheme.displayLarge,
        theme.textTheme.bodyMedium,
        theme.textTheme.labelLarge,
        theme.textTheme.labelSmall,
      ]) {
        expect(style!.letterSpacing, 0);
        expect(style.fontSize, greaterThanOrEqualTo(14));
      }
      final en = ObhijatraTheme.light().textTheme;
      expect(en.labelSmall!.fontSize, greaterThanOrEqualTo(12));
    });

    test('headings use serif, text uses sans, Bangla uses Bengali families',
        () {
      final en = ObhijatraTheme.light().textTheme;
      expect(en.headlineMedium!.fontFamily, contains('Noto Serif'));
      expect(en.bodyMedium!.fontFamily, contains('Noto Sans'));
      final bn = ObhijatraTheme.light(locale: const Locale('bn')).textTheme;
      expect(bn.headlineMedium!.fontFamily, contains('Noto Serif Bengali'));
      expect(bn.bodyMedium!.fontFamily, contains('Noto Sans Bengali'));
      expect(en.headlineMedium!.fontWeight, FontWeight.w600);
    });
  });

  group('spacing and radius scales', () {
    test('every spacing step is a multiple of 4 px', () {
      for (final s in Spacing.scale) {
        expect(s % 4, 0);
      }
    });
    test('radius scale is ascending', () {
      final r = <double>[Radii.xs, Radii.sm, Radii.md, Radii.lg, Radii.xl];
      expect(r, orderedEquals(<double>[4, 8, 12, 16, 24]));
    });
    test('touch target is at least 48 dp', () {
      expect(Sizes.touch, greaterThanOrEqualTo(48));
      final theme = ObhijatraTheme.light();
      final min = theme.filledButtonTheme.style!.minimumSize!.resolve(
        <WidgetState>{},
      );
      expect(min!.height, greaterThanOrEqualTo(48));
    });
  });

  group('bundled fonts', () {
    const files = <String>[
      'NotoSans-Regular',
      'NotoSans-Medium',
      'NotoSans-SemiBold',
      'NotoSans-Bold',
      'NotoSansBengali-Regular',
      'NotoSansBengali-Medium',
      'NotoSansBengali-SemiBold',
      'NotoSansBengali-Bold',
      'NotoSerif-Regular',
      'NotoSerif-SemiBold',
      'NotoSerifBengali-Regular',
      'NotoSerifBengali-SemiBold',
    ];
    for (final f in files) {
      test('$f.ttf is bundled', () async {
        TestWidgetsFlutterBinding.ensureInitialized();
        final data = await rootBundle
            .load('packages/obhijatra_ui/assets/fonts/$f.ttf');
        expect(data.lengthInBytes, greaterThan(50000));
      });
    }
  });
}
