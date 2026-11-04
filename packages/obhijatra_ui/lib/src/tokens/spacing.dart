import 'package:flutter/material.dart';

/// The 4 px spacing scale (`space-N` tokens), in logical pixels.
abstract final class Spacing {
  /// No gap.
  static const double space0 = 0;

  /// Icon to label; tight chips.
  static const double space1 = 4;

  /// Inside buttons and badges; label to field.
  static const double space2 = 8;

  /// Between related items.
  static const double space3 = 12;

  /// Card padding on phones; screen side margin.
  static const double space4 = 16;

  /// Between groups.
  static const double space5 = 20;

  /// Card padding on large screens.
  static const double space6 = 24;

  /// Between sections on a screen.
  static const double space8 = 32;

  /// Large section gaps.
  static const double space10 = 40;

  /// Section padding on phones (web).
  static const double space12 = 48;

  /// Section padding on large screens.
  static const double space16 = 64;

  /// Hero padding.
  static const double space20 = 80;

  /// Every step of the scale, smallest first.
  static const List<double> scale = <double>[
    space0,
    space1,
    space2,
    space3,
    space4,
    space5,
    space6,
    space8,
    space10,
    space12,
    space16,
    space20,
  ];
}

/// The radius scale (`radius-*` tokens), in logical pixels.
abstract final class Radii {
  /// Badges, checkboxes.
  static const double xs = 4;

  /// Buttons, inputs, chips.
  static const double sm = 8;

  /// Cards, menus, snack bars.
  static const double md = 12;

  /// Dialogs, bottom sheets, large cards.
  static const double lg = 16;

  /// Hero panels, image frames.
  static const double xl = 24;

  /// Fully rounded ends: pill frames, switch tracks, avatars.
  static const double pill = 999;

  /// App-icon and product-tile corners: this fraction of the side.
  static const double tileFraction = 0.28;

  /// [xs] as a [BorderRadius].
  static const BorderRadius xsAll = BorderRadius.all(Radius.circular(xs));

  /// [sm] as a [BorderRadius].
  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));

  /// [md] as a [BorderRadius].
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));

  /// [lg] as a [BorderRadius].
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));

  /// [xl] as a [BorderRadius].
  static const BorderRadius xlAll = BorderRadius.all(Radius.circular(xl));

  /// [pill] as a [BorderRadius].
  static const BorderRadius pillAll = BorderRadius.all(Radius.circular(pill));
}

/// Fixed sizes for touch targets, icons, controls and reading width.
abstract final class Sizes {
  /// Minimum touch target: 48 x 48.
  static const double touch = 48;

  /// Icons inside badges.
  static const double iconSm = 16;

  /// Icons beside 14-16 px text.
  static const double icon = 20;

  /// Navigation and toolbar icons.
  static const double iconLg = 24;

  /// Height of buttons, text fields and selects.
  static const double control = 48;

  /// Maximum width of running text (about 75 characters at 16 px).
  static const double content = 640;

  /// Maximum page width on large screens.
  static const double page = 1200;
}

/// Elevation shadows (`shadow-*` tokens) for each theme.
abstract final class Shadows {
  /// Resting cards on `bgSubtle`.
  static List<BoxShadow> sm(Brightness b) => <BoxShadow>[
    BoxShadow(
      color: b == Brightness.light
          ? const Color.fromRGBO(35, 56, 74, 0.08)
          : const Color.fromRGBO(0, 0, 0, 0.40),
      offset: const Offset(0, 1),
      blurRadius: 2,
    ),
  ];

  /// Menus, popovers, raised cards.
  static List<BoxShadow> md(Brightness b) => <BoxShadow>[
    BoxShadow(
      color: b == Brightness.light
          ? const Color.fromRGBO(35, 56, 74, 0.10)
          : const Color.fromRGBO(0, 0, 0, 0.45),
      offset: const Offset(0, 4),
      blurRadius: 16,
    ),
  ];

  /// Dialogs and bottom sheets.
  static List<BoxShadow> lg(Brightness b) => <BoxShadow>[
    BoxShadow(
      color: b == Brightness.light
          ? const Color.fromRGBO(35, 56, 74, 0.14)
          : const Color.fromRGBO(0, 0, 0, 0.55),
      offset: const Offset(0, 12),
      blurRadius: 32,
    ),
  ];
}
