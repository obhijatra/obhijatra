import 'package:flutter/material.dart';
import 'package:obhijatra_ui/obhijatra_ui.dart';

/// The top bar of a screen: an optional back or close button, a title and an
/// optional second line. Grows with the text size; never cuts words.
class TopBar extends StatelessWidget {
  /// Creates the bar.
  const TopBar({
    required this.title,
    this.subtitle,
    this.leadingIcon,
    this.leadingLabel,
    this.onLeading,
    this.showMark = false,
    this.trailing,
    super.key,
  });

  /// The screen title.
  final String title;

  /// A second line under the title.
  final String? subtitle;

  /// The icon of the button before the title.
  final IconData? leadingIcon;

  /// What the button does, in words (spoken by screen readers).
  final String? leadingLabel;

  /// Called when the leading button is pressed.
  final VoidCallback? onLeading;

  /// Whether to show the app mark before the title (home screens).
  final bool showMark;

  /// A widget at the end of the bar.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final theme = Theme.of(context).textTheme;
    return Material(
      color: p.surface,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: p.border)),
        ),
        child: SafeArea(
          bottom: false,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: EdgeInsetsDirectional.only(
                start: leadingIcon == null ? Spacing.space4 : Spacing.space2,
                end: Spacing.space2,
              ),
              child: Row(
                children: <Widget>[
                  if (leadingIcon != null)
                    IconButton(
                      icon: Icon(leadingIcon, size: Sizes.iconLg),
                      tooltip: leadingLabel,
                      onPressed: onLeading,
                      constraints: const BoxConstraints(
                        minWidth: Sizes.touch,
                        minHeight: Sizes.touch,
                      ),
                      color: p.text,
                    ),
                  if (showMark) ...<Widget>[
                    const ObhijatraMark(size: 40),
                    const SizedBox(width: Spacing.space3),
                  ],
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: Spacing.space2,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Semantics(
                            header: true,
                            child: Text(
                              title,
                              style: theme.titleLarge,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (subtitle != null)
                            Text(
                              subtitle!,
                              style: theme.bodySmall!.copyWith(
                                color: p.textMuted,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  ?trailing,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A screen: top bar, a scrolling body kept to a readable width, and an
/// optional bar of buttons at the bottom.
class ScreenFrame extends StatelessWidget {
  /// Creates the frame.
  const ScreenFrame({
    required this.topBar,
    required this.body,
    this.bottom,
    this.banner,
    this.bottomNavigation,
    super.key,
  });

  /// The [TopBar].
  final Widget topBar;

  /// A full-width band under the top bar (for example the offline banner).
  final Widget? banner;

  /// What fills the middle; it should scroll.
  final Widget body;

  /// Buttons at the bottom (see [BottomActions]).
  final Widget? bottom;

  /// The bottom navigation bar, below [bottom].
  final Widget? bottomNavigation;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: <Widget>[
          topBar,
          if (banner != null)
            // At the largest text sizes the banner may not take over the
            // screen: it keeps to under a third and scrolls inside itself.
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.3,
              ),
              child: SingleChildScrollView(child: banner),
            ),
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: Sizes.content),
                child: body,
              ),
            ),
          ),
          ?bottom,
          ?bottomNavigation,
        ],
      ),
    );
  }
}

/// The padded bar of buttons at the bottom of a screen.
class BottomActions extends StatelessWidget {
  /// Creates the bar. Buttons are laid out in a column, or in a row when
  /// [row] is set and there is room.
  const BottomActions({required this.children, this.row = false, super.key});

  /// Usually one to three buttons.
  final List<Widget> children;

  /// Whether the buttons sit side by side (Back / Next).
  final bool row;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
    final sideBySide = row && scale < 1.4;
    return Material(
      color: p.surface,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: p.border)),
        ),
        child: SafeArea(
          top: false,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: Sizes.content),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  Spacing.space4,
                  Spacing.space3,
                  Spacing.space4,
                  Spacing.space4,
                ),
                child: sideBySide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          for (var i = 0; i < children.length; i++) ...<Widget>[
                            if (i > 0) const SizedBox(width: Spacing.space3),
                            Expanded(child: children[i]),
                          ],
                        ],
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          for (var i = 0; i < children.length; i++) ...<Widget>[
                            if (i > 0) const SizedBox(height: Spacing.space2),
                            children[i],
                          ],
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A plain surface box with a thin border, for summaries and notices.
class Panel extends StatelessWidget {
  /// Creates the panel around [child].
  const Panel({
    required this.child,
    this.color,
    this.borderColor,
    this.padding = const EdgeInsets.all(Spacing.space4),
    super.key,
  });

  /// The content.
  final Widget child;

  /// The fill; the surface colour when `null`.
  final Color? color;

  /// The edge; the border colour when `null`.
  final Color? borderColor;

  /// Space inside the edge.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? p.surface,
        border: Border.all(color: borderColor ?? p.border),
        borderRadius: Radii.mdAll,
      ),
      child: child,
    );
  }
}

/// A centred message with a round icon, used for outcomes and empty states.
class ResultHeader extends StatelessWidget {
  /// Creates the header.
  const ResultHeader({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    super.key,
  });

  /// The icon in the circle.
  final IconData icon;

  /// The icon colour.
  final Color iconColor;

  /// The circle colour.
  final Color iconBackground;

  /// The big title.
  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: iconBackground,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 36, color: iconColor),
        ),
        const SizedBox(height: Spacing.space4),
        Semantics(
          header: true,
          child: Text(title, style: Theme.of(context).textTheme.headlineLarge),
        ),
      ],
    );
  }
}
