import 'package:flutter/material.dart';

/// The package that bundles the Noto fonts; used so apps find them.
const String obhijatraUiPackage = 'obhijatra_ui';

/// The four bundled Noto families (SIL OFL 1.1).
enum ObhijatraFont {
  /// Noto Serif: English headings.
  display('Noto Serif', <String>['Noto Serif Bengali']),

  /// Noto Sans: all English text, buttons, labels and numbers.
  body('Noto Sans', <String>['Noto Sans Bengali']),

  /// Noto Serif Bengali: Bangla headings.
  displayBn('Noto Serif Bengali', <String>['Noto Serif']),

  /// Noto Sans Bengali: Bangla text, buttons and labels.
  bodyBn('Noto Sans Bengali', <String>['Noto Sans']);

  const ObhijatraFont(this.family, this.fallback);

  /// The family name as declared in `pubspec.yaml`.
  final String family;

  /// Families tried, in order, for characters this one lacks.
  final List<String> fallback;
}

/// One step of the type scale: size and line height in logical pixels
/// (the design system's px; Flutter scales them with the OS text size).
@immutable
class TextToken {
  const TextToken({
    required this.font,
    required this.fontSize,
    required this.lineHeight,
    required this.fontWeight,
    this.letterSpacingEm = 0,
    this.uppercase = false,
  });

  /// The family used.
  final ObhijatraFont font;

  /// Font size in logical pixels.
  final double fontSize;

  /// Line height in logical pixels.
  final double lineHeight;

  /// Weight (400 regular, 500 medium, 600 semibold, 700 bold).
  final FontWeight fontWeight;

  /// Letter spacing in em. Always 0 for Bangla (never letter-space Bangla).
  final double letterSpacingEm;

  /// Whether the style is meant for capitals only (the overline).
  final bool uppercase;

  /// Line height as a multiple of the font size, as Flutter wants it.
  double get height => lineHeight / fontSize;

  /// The Flutter style for this token.
  TextStyle toStyle({Color? color}) => TextStyle(
        inherit: false,
        package: obhijatraUiPackage,
        fontFamily: font.family,
        fontFamilyFallback: font.fallback,
        fontSize: fontSize,
        height: height,
        fontWeight: fontWeight,
        letterSpacing: letterSpacingEm * fontSize,
        color: color,
        textBaseline: TextBaseline.alphabetic,
        leadingDistribution: TextLeadingDistribution.even,
      );
}

/// The Aninda Studio 5.0 type scale (`04-typography.md`, `tokens.json`).
abstract final class ObhijatraType {
  // ---- English headings: Noto Serif SemiBold 600 ----

  /// Hero headline, 48/56. One per screen.
  static const TextToken display = TextToken(
    font: ObhijatraFont.display,
    fontSize: 48,
    lineHeight: 56,
    fontWeight: FontWeight.w600,
    letterSpacingEm: -0.01,
  );

  /// Page or screen title, 36/44.
  static const TextToken h1 = TextToken(
    font: ObhijatraFont.display,
    fontSize: 36,
    lineHeight: 44,
    fontWeight: FontWeight.w600,
    letterSpacingEm: -0.005,
  );

  /// Section heading, 28/36.
  static const TextToken h2 = TextToken(
    font: ObhijatraFont.display,
    fontSize: 28,
    lineHeight: 36,
    fontWeight: FontWeight.w600,
  );

  /// Card title, dialog title, 22/30.
  static const TextToken h3 = TextToken(
    font: ObhijatraFont.display,
    fontSize: 22,
    lineHeight: 30,
    fontWeight: FontWeight.w600,
  );

  /// Small heading, 18/26.
  static const TextToken h4 = TextToken(
    font: ObhijatraFont.display,
    fontSize: 18,
    lineHeight: 26,
    fontWeight: FontWeight.w600,
  );

  // ---- English text and interface: Noto Sans ----

  /// Lead paragraph, 18/28.
  static const TextToken bodyLg = TextToken(
    font: ObhijatraFont.body,
    fontSize: 18,
    lineHeight: 28,
    fontWeight: FontWeight.w400,
  );

  /// Default text, 16/24.
  static const TextToken body = TextToken(
    font: ObhijatraFont.body,
    fontSize: 16,
    lineHeight: 24,
    fontWeight: FontWeight.w400,
  );

  /// Secondary text, list details, table cells, 14/20.
  static const TextToken bodySm = TextToken(
    font: ObhijatraFont.body,
    fontSize: 14,
    lineHeight: 20,
    fontWeight: FontWeight.w400,
  );

  /// Buttons, tabs, chips and form labels, 14/20 SemiBold.
  static const TextToken label = TextToken(
    font: ObhijatraFont.body,
    fontSize: 14,
    lineHeight: 20,
    fontWeight: FontWeight.w600,
  );

  /// Help text and notes, 12/16. Never smaller.
  static const TextToken caption = TextToken(
    font: ObhijatraFont.body,
    fontSize: 12,
    lineHeight: 16,
    fontWeight: FontWeight.w400,
  );

  /// Eyebrow above a heading, 12/16 SemiBold, capitals, 0.08 em tracking.
  /// English only.
  static const TextToken overline = TextToken(
    font: ObhijatraFont.body,
    fontSize: 12,
    lineHeight: 16,
    fontWeight: FontWeight.w600,
    letterSpacingEm: 0.08,
    uppercase: true,
  );

  // ---- Bangla headings: Noto Serif Bengali SemiBold 600 ----

  /// Bangla heading 1, 36/52.
  static const TextToken bnH1 = TextToken(
    font: ObhijatraFont.displayBn,
    fontSize: 36,
    lineHeight: 52,
    fontWeight: FontWeight.w600,
  );

  /// Bangla heading 2, 28/42.
  static const TextToken bnH2 = TextToken(
    font: ObhijatraFont.displayBn,
    fontSize: 28,
    lineHeight: 42,
    fontWeight: FontWeight.w600,
  );

  /// Bangla heading 3, 22/34.
  static const TextToken bnH3 = TextToken(
    font: ObhijatraFont.displayBn,
    fontSize: 22,
    lineHeight: 34,
    fontWeight: FontWeight.w600,
  );

  /// Bangla heading 4, 20/33. DERIVED, not in the design system: the English
  /// h4 (18) one step larger at the 1.65 Bangla line height. Replace if the
  /// design system adds a `bn-h4`.
  static const TextToken bnH4 = TextToken(
    font: ObhijatraFont.displayBn,
    fontSize: 20,
    lineHeight: 33,
    fontWeight: FontWeight.w600,
  );

  // ---- Bangla text: Noto Sans Bengali, one step larger ----

  /// Bangla lead paragraph, 20/32.
  static const TextToken bnBodyLg = TextToken(
    font: ObhijatraFont.bodyBn,
    fontSize: 20,
    lineHeight: 32,
    fontWeight: FontWeight.w400,
  );

  /// Bangla default text, 18/30.
  static const TextToken bnBody = TextToken(
    font: ObhijatraFont.bodyBn,
    fontSize: 18,
    lineHeight: 30,
    fontWeight: FontWeight.w400,
  );

  /// Bangla secondary text, 16/26.
  static const TextToken bnBodySm = TextToken(
    font: ObhijatraFont.bodyBn,
    fontSize: 16,
    lineHeight: 26,
    fontWeight: FontWeight.w400,
  );

  /// Bangla buttons, tabs and labels, 16/22 SemiBold. Let them wrap or grow.
  static const TextToken bnLabel = TextToken(
    font: ObhijatraFont.bodyBn,
    fontSize: 16,
    lineHeight: 22,
    fontWeight: FontWeight.w600,
  );

  /// Bangla help text, 14/22. Never smaller.
  static const TextToken bnCaption = TextToken(
    font: ObhijatraFont.bodyBn,
    fontSize: 14,
    lineHeight: 22,
    fontWeight: FontWeight.w400,
  );
}
