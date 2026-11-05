import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// [base] in a fixed-width font, for addresses, message bodies and other
/// text people copy from a technical guide.
///
/// Windows and macOS use their own fixed-width fonts. The web app cannot
/// use the computer's fonts and no fixed-width font is bundled, so there
/// the text keeps the Noto font, with figures of equal width.
TextStyle codeStyle(TextStyle base) {
  if (kIsWeb) {
    return base.copyWith(
      fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
    );
  }
  final family = switch (defaultTargetPlatform) {
    TargetPlatform.macOS || TargetPlatform.iOS => 'Menlo',
    TargetPlatform.windows => 'Consolas',
    _ => 'monospace',
  };
  return base.copyWith(
    fontFamily: family,
    fontFamilyFallback: const <String>[
      'Courier New',
      'monospace',
      'packages/obhijatra_ui/Noto Sans',
      'packages/obhijatra_ui/Noto Sans Bengali',
    ],
  );
}
