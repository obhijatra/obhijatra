import 'package:flutter/material.dart';

/// Colour ROLES of the Aninda Studio 5.0 design system, for one theme.
///
/// Values are copied from `project/tokens.json` (version 5). Widgets must use
/// roles, never raw brand colours, so that light and dark stay in step.
@immutable
class ObhijatraPalette {
  const ObhijatraPalette({
    required this.brightness,
    required this.bg,
    required this.bgSubtle,
    required this.surface,
    required this.surfaceSunken,
    required this.surfaceBrand,
    required this.text,
    required this.textMuted,
    required this.textOnBrand,
    required this.textLink,
    required this.border,
    required this.borderStrong,
    required this.action,
    required this.actionHover,
    required this.onAction,
    required this.actionSubtle,
    required this.focus,
    required this.secondary,
    required this.accent,
    required this.onAccent,
    required this.accentSubtle,
    required this.arcStart,
    required this.arcMid,
    required this.arcEnd,
    required this.success,
    required this.successSubtle,
    required this.warning,
    required this.warningSubtle,
    required this.danger,
    required this.dangerSubtle,
    required this.info,
    required this.infoSubtle,
  });

  /// Which theme these roles belong to.
  final Brightness brightness;

  /// Page background.
  final Color bg;

  /// Alternate page bands, table stripes, sidebars.
  final Color bgSubtle;

  /// Cards, sheets, dialogs, inputs.
  final Color surface;

  /// Wells, code blocks, read-only fields.
  final Color surfaceSunken;

  /// Brand moments: hero bands, cover blocks (text on it: [textOnBrand]).
  final Color surfaceBrand;

  /// Body copy and headings.
  final Color text;

  /// Secondary text, help text, captions, placeholders.
  final Color textMuted;

  /// Text on [surfaceBrand].
  final Color textOnBrand;

  /// Links and text buttons.
  final Color textLink;

  /// Decorative dividers and card outlines (no contrast duty).
  final Color border;

  /// Form-control borders (3:1 on surface and bg).
  final Color borderStrong;

  /// Primary buttons, selected states, switches on.
  final Color action;

  /// Hover and pressed state of [action].
  final Color actionHover;

  /// Text and icons on [action].
  final Color onAction;

  /// Selected rows, active tab background, secondary button hover.
  final Color actionSubtle;

  /// Focus ring colour (2 px solid, 2 px offset).
  final Color focus;

  /// Secondary fills, chart series and graphics. Never text on light grounds.
  final Color secondary;

  /// Straw: rewards and "new" labels. Never text; never a warning.
  final Color accent;

  /// Text and icons on [accent].
  final Color onAccent;

  /// Soft straw background for reward and "new" panels.
  final Color accentSubtle;

  /// Quarter-arc blend start (brand graphics only).
  final Color arcStart;

  /// Quarter-arc blend middle (brand graphics only).
  final Color arcMid;

  /// Quarter-arc blend end (brand graphics only).
  final Color arcEnd;

  /// Success text and icons (always with a word or icon).
  final Color success;

  /// Success banner background.
  final Color successSubtle;

  /// Warning text and icons (always with a word or icon).
  final Color warning;

  /// Warning banner background.
  final Color warningSubtle;

  /// Error text, destructive buttons, invalid-field borders.
  final Color danger;

  /// Error banner background.
  final Color dangerSubtle;

  /// Information text and icons.
  final Color info;

  /// Information banner background.
  final Color infoSubtle;

  /// The light theme (default).
  static const ObhijatraPalette light = ObhijatraPalette(
    brightness: Brightness.light,
    bg: Color(0xFFF5F8FB),
    bgSubtle: Color(0xFFE6EEF4),
    surface: Color(0xFFFFFFFF),
    surfaceSunken: Color(0xFFE6EEF4),
    surfaceBrand: Color(0xFF23384A),
    text: Color(0xFF18242E),
    textMuted: Color(0xFF4B5D6B),
    textOnBrand: Color(0xFFFFFFFF),
    textLink: Color(0xFF2A6A90),
    border: Color(0xFFDCEAF4),
    borderStrong: Color(0xFF687A89),
    action: Color(0xFF2A6A90),
    actionHover: Color(0xFF1E5271),
    onAction: Color(0xFFFFFFFF),
    actionSubtle: Color(0xFFDCEAF4),
    focus: Color(0xFF2A6A90),
    secondary: Color(0xFF5B8FB0),
    accent: Color(0xFFE3D3A3),
    onAccent: Color(0xFF18242E),
    accentSubtle: Color(0xFFFBF7E9),
    arcStart: Color(0xFF23384A),
    arcMid: Color(0xFF2A6A90),
    arcEnd: Color(0xFF5B9FC4),
    success: Color(0xFF00796B),
    successSubtle: Color(0xFFE0F2F1),
    warning: Color(0xFF5D4037),
    warningSubtle: Color(0xFFFFF8E1),
    danger: Color(0xFFC62828),
    dangerSubtle: Color(0xFFFFEBEE),
    info: Color(0xFF1565C0),
    infoSubtle: Color(0xFFE3F2FD),
  );

  /// The optional dark theme.
  static const ObhijatraPalette dark = ObhijatraPalette(
    brightness: Brightness.dark,
    bg: Color(0xFF16212B),
    bgSubtle: Color(0xFF213040),
    surface: Color(0xFF213040),
    surfaceSunken: Color(0xFF16212B),
    surfaceBrand: Color(0xFF23384A),
    text: Color(0xFFE6EEF4),
    textMuted: Color(0xFFA3B6C4),
    textOnBrand: Color(0xFFFFFFFF),
    textLink: Color(0xFF7FB8DA),
    border: Color(0xFF2A3D50),
    borderStrong: Color(0xFF8395A4),
    action: Color(0xFF7FB8DA),
    actionHover: Color(0xFFBFDDF0),
    onAction: Color(0xFF16212B),
    actionSubtle: Color(0xFF2A3D50),
    focus: Color(0xFF7FB8DA),
    secondary: Color(0xFFA3C8DF),
    accent: Color(0xFFE3D3A3),
    onAccent: Color(0xFF18242E),
    accentSubtle: Color(0xFF3C311E),
    arcStart: Color(0xFF3F7FA6),
    arcMid: Color(0xFF7FB8DA),
    arcEnd: Color(0xFFBFDDF0),
    success: Color(0xFF1DE9B6),
    successSubtle: Color(0xFF213040),
    warning: Color(0xFFFFD54F),
    warningSubtle: Color(0xFF213040),
    danger: Color(0xFFEF9A9A),
    dangerSubtle: Color(0xFF213040),
    info: Color(0xFF90CAF9),
    infoSubtle: Color(0xFF213040),
  );
}
