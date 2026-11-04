import 'package:flutter/material.dart';
import 'package:obhijatra_ui/src/theme/text_themes.dart';
import 'package:obhijatra_ui/src/tokens/palette.dart';
import 'package:obhijatra_ui/src/tokens/spacing.dart';

/// Carries the full colour roles (including ones Material 3 has no slot for,
/// such as success, warning and the brand arc) inside [ThemeData].
///
/// Read with `Theme.of(context).extension<ObhijatraColors>()!.palette` or the
/// [ObhijatraThemeContext] shortcut `context.palette`.
@immutable
class ObhijatraColors extends ThemeExtension<ObhijatraColors> {
  const ObhijatraColors(this.palette);

  /// The roles of the active theme.
  final ObhijatraPalette palette;

  @override
  ObhijatraColors copyWith({ObhijatraPalette? palette}) =>
      ObhijatraColors(palette ?? this.palette);

  // Palettes are two fixed sets; switching is a step, not a blend.
  @override
  ObhijatraColors lerp(ThemeExtension<ObhijatraColors>? other, double t) {
    if (other is! ObhijatraColors) return this;
    return t < 0.5 ? this : other;
  }
}

/// Shortcut to the Aninda Studio colour roles.
extension ObhijatraThemeContext on BuildContext {
  /// The colour roles of the current theme.
  ObhijatraPalette get palette =>
      Theme.of(this).extension<ObhijatraColors>()!.palette;
}

/// Builds Material 3 [ThemeData] strictly from the Aninda Studio 5.0 colour
/// roles, 4 px spacing scale, radius scale and type scale.
abstract final class ObhijatraTheme {
  /// The default, light theme. Pass a Bangla [locale] for Bangla type.
  static ThemeData light({Locale? locale}) =>
      _build(ObhijatraPalette.light, locale);

  /// The optional dark theme. Pass a Bangla [locale] for Bangla type.
  static ThemeData dark({Locale? locale}) =>
      _build(ObhijatraPalette.dark, locale);

  /// Whether [locale] selects the Bangla type scale.
  static bool isBangla(Locale? locale) => locale?.languageCode == 'bn';

  static ThemeData _build(ObhijatraPalette p, Locale? locale) {
    final bangla = isBangla(locale);
    final isLight = p.brightness == Brightness.light;
    final textTheme = bangla
        ? ObhijatraTextThemes.bangla(p.text)
        : ObhijatraTextThemes.english(p.text);
    final labelStyle = textTheme.labelLarge!;

    final scheme = ColorScheme(
      brightness: p.brightness,
      primary: p.action,
      onPrimary: p.onAction,
      primaryContainer: p.actionSubtle,
      onPrimaryContainer: p.text,
      secondary: p.secondary,
      onSecondary: p.onAccent,
      secondaryContainer: p.actionSubtle,
      onSecondaryContainer: p.text,
      tertiary: p.accent,
      onTertiary: p.onAccent,
      tertiaryContainer: p.accentSubtle,
      onTertiaryContainer: p.text,
      error: p.danger,
      onError: isLight ? p.onAction : p.bg,
      errorContainer: p.dangerSubtle,
      onErrorContainer: p.danger,
      surface: p.surface,
      onSurface: p.text,
      surfaceDim: p.bgSubtle,
      surfaceBright: p.surface,
      surfaceContainerLowest: p.surface,
      surfaceContainerLow: p.surface,
      surfaceContainer: p.surface,
      surfaceContainerHigh: p.surface,
      surfaceContainerHighest: p.surfaceSunken,
      onSurfaceVariant: p.textMuted,
      outline: p.borderStrong,
      outlineVariant: p.border,
      shadow: isLight ? p.surfaceBrand : const Color(0xFF000000),
      scrim: const Color(0xFF000000),
      inverseSurface: p.surfaceBrand,
      onInverseSurface: p.textOnBrand,
      inversePrimary: isLight
          ? ObhijatraPalette.dark.action
          : ObhijatraPalette.light.action,
      surfaceTint: const Color(0x00000000),
    );

    // Focus ring: 2 px solid in the focus colour on every interactive element.
    final focusRing = BorderSide(color: p.focus, width: 2);
    WidgetStateProperty<BorderSide?> ringOn(BorderSide? rest) =>
        WidgetStateProperty.resolveWith<BorderSide?>(
          (states) => states.contains(WidgetState.focused) ? focusRing : rest,
        );

    const buttonShape = RoundedRectangleBorder(borderRadius: Radii.smAll);
    const buttonPadding = EdgeInsets.symmetric(
      horizontal: Spacing.space5,
      vertical: Spacing.space2,
    );
    const buttonMin = Size(Sizes.touch, Sizes.control);

    return ThemeData(
      useMaterial3: true,
      brightness: p.brightness,
      colorScheme: scheme,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      scaffoldBackgroundColor: p.bg,
      canvasColor: p.bg,
      cardColor: p.surface,
      dividerColor: p.border,
      focusColor: p.focus.withValues(alpha: 0.12),
      hoverColor: p.actionSubtle,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      extensions: <ThemeExtension<dynamic>>[ObhijatraColors(p)],
      dividerTheme: DividerThemeData(color: p.border, space: 1, thickness: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: p.bg,
        foregroundColor: p.text,
        surfaceTintColor: const Color(0x00000000),
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: p.surface,
        surfaceTintColor: const Color(0x00000000),
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: Radii.mdAll,
          side: BorderSide(color: p.border),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: const Color(0x00000000),
        shape: const RoundedRectangleBorder(borderRadius: Radii.lgAll),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: const Color(0x00000000),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.lg)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.surfaceBrand,
        contentTextStyle: textTheme.bodyMedium!.copyWith(color: p.textOnBrand),
        actionTextColor: ObhijatraPalette.dark.action,
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: Radii.mdAll),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.surface,
        selectedColor: p.actionSubtle,
        side: BorderSide(color: p.borderStrong),
        shape: const RoundedRectangleBorder(borderRadius: Radii.smAll),
        labelStyle: labelStyle.copyWith(color: p.text),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Spacing.space4,
          vertical: Spacing.space3,
        ),
        hintStyle: textTheme.bodyMedium!.copyWith(color: p.textMuted),
        labelStyle: labelStyle.copyWith(color: p.textMuted),
        helperStyle: textTheme.labelSmall!.copyWith(color: p.textMuted),
        errorStyle: textTheme.labelSmall!.copyWith(color: p.danger),
        border: OutlineInputBorder(
          borderRadius: Radii.smAll,
          borderSide: BorderSide(color: p.borderStrong),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: Radii.smAll,
          borderSide: BorderSide(color: p.borderStrong),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: Radii.smAll,
          borderSide: BorderSide(color: p.focus, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: Radii.smAll,
          borderSide: BorderSide(color: p.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: Radii.smAll,
          borderSide: BorderSide(color: p.danger, width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: Radii.smAll,
          borderSide: BorderSide(color: p.border),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.action,
          foregroundColor: p.onAction,
          minimumSize: buttonMin,
          padding: buttonPadding,
          shape: buttonShape,
          textStyle: labelStyle,
        ).copyWith(side: ringOn(null)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.action,
          foregroundColor: p.onAction,
          elevation: 0,
          minimumSize: buttonMin,
          padding: buttonPadding,
          shape: buttonShape,
          textStyle: labelStyle,
        ).copyWith(side: ringOn(null)),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.textLink,
          minimumSize: buttonMin,
          padding: buttonPadding,
          shape: buttonShape,
          textStyle: labelStyle,
        ).copyWith(side: ringOn(BorderSide(color: p.borderStrong))),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.textLink,
          minimumSize: buttonMin,
          padding: buttonPadding,
          shape: buttonShape,
          textStyle: labelStyle,
        ).copyWith(side: ringOn(null)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color?>(
          (s) => s.contains(WidgetState.selected) ? p.onAction : p.borderStrong,
        ),
        trackColor: WidgetStateProperty.resolveWith<Color?>(
          (s) => s.contains(WidgetState.selected) ? p.action : p.surfaceSunken,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith<Color?>(
          (s) => s.contains(WidgetState.selected) ? p.action : p.borderStrong,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: const RoundedRectangleBorder(borderRadius: Radii.xsAll),
        fillColor: WidgetStateProperty.resolveWith<Color?>(
          (s) => s.contains(WidgetState.selected) ? p.action : null,
        ),
        checkColor: WidgetStatePropertyAll<Color>(p.onAction),
        side: BorderSide(color: p.borderStrong, width: 2),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: const Color(0x00000000),
        indicatorColor: p.actionSubtle,
        labelTextStyle: WidgetStatePropertyAll<TextStyle>(labelStyle),
      ),
      listTileTheme: ListTileThemeData(
        textColor: p.text,
        iconColor: p.textMuted,
        minVerticalPadding: Spacing.space2,
      ),
    );
  }
}
