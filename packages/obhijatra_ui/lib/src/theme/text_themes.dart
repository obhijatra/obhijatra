import 'package:flutter/material.dart';
import 'package:obhijatra_ui/src/tokens/typography.dart';

/// Maps the Aninda Studio type scale onto Material 3 text slots.
abstract final class ObhijatraTextThemes {
  /// English: Noto Serif headings, Noto Sans text.
  static TextTheme english(Color color) => TextTheme(
    displayLarge: ObhijatraType.display.toStyle(color: color),
    displayMedium: ObhijatraType.h1.toStyle(color: color),
    displaySmall: ObhijatraType.h2.toStyle(color: color),
    headlineLarge: ObhijatraType.h1.toStyle(color: color),
    headlineMedium: ObhijatraType.h2.toStyle(color: color),
    headlineSmall: ObhijatraType.h3.toStyle(color: color),
    titleLarge: ObhijatraType.h3.toStyle(color: color),
    titleMedium: ObhijatraType.h4.toStyle(color: color),
    titleSmall: ObhijatraType.label.toStyle(color: color),
    bodyLarge: ObhijatraType.bodyLg.toStyle(color: color),
    bodyMedium: ObhijatraType.body.toStyle(color: color),
    bodySmall: ObhijatraType.bodySm.toStyle(color: color),
    labelLarge: ObhijatraType.label.toStyle(color: color),
    labelMedium: ObhijatraType.label.toStyle(color: color),
    labelSmall: ObhijatraType.caption.toStyle(color: color),
  );

  /// Bangla: Noto Serif Bengali headings, Noto Sans Bengali text, one step
  /// larger than English with a line height of about 1.65.
  static TextTheme bangla(Color color) => TextTheme(
    displayLarge: ObhijatraType.bnH1.toStyle(color: color),
    displayMedium: ObhijatraType.bnH1.toStyle(color: color),
    displaySmall: ObhijatraType.bnH2.toStyle(color: color),
    headlineLarge: ObhijatraType.bnH1.toStyle(color: color),
    headlineMedium: ObhijatraType.bnH2.toStyle(color: color),
    headlineSmall: ObhijatraType.bnH3.toStyle(color: color),
    titleLarge: ObhijatraType.bnH3.toStyle(color: color),
    titleMedium: ObhijatraType.bnH4.toStyle(color: color),
    titleSmall: ObhijatraType.bnLabel.toStyle(color: color),
    bodyLarge: ObhijatraType.bnBodyLg.toStyle(color: color),
    bodyMedium: ObhijatraType.bnBody.toStyle(color: color),
    bodySmall: ObhijatraType.bnBodySm.toStyle(color: color),
    labelLarge: ObhijatraType.bnLabel.toStyle(color: color),
    labelMedium: ObhijatraType.bnLabel.toStyle(color: color),
    labelSmall: ObhijatraType.bnCaption.toStyle(color: color),
  );
}
