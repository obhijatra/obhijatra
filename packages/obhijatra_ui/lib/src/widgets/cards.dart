import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:obhijatra_ui/src/theme/obhijatra_theme.dart';
import 'package:obhijatra_ui/src/tokens/spacing.dart';

/// A large, tappable card: icon tile, title, a line of detail and a chevron.
/// At least 72 dp high, for thumbs in sunlight.
class ActionCard extends StatelessWidget {
  /// Creates the card.
  const ActionCard({
    required this.icon,
    required this.title,
    required this.onTap,
    this.meta,
    super.key,
  });

  /// The icon in the tile.
  final IconData icon;

  /// The card title.
  final String title;

  /// A line of detail under the title.
  final String? meta;

  /// Called when the card is pressed.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final theme = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      container: true,
      label: meta == null ? title : '$title. $meta',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: Radii.mdAll,
          side: BorderSide(color: p.borderStrong),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: Radii.mdAll,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 72),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 12, 12),
              child: Row(
                children: <Widget>[
                  _IconTile(icon: icon),
                  const SizedBox(width: Spacing.space3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          title,
                          style: theme.titleSmall!.copyWith(
                            fontSize: theme.bodyMedium!.fontSize,
                            height: theme.bodyMedium!.height,
                          ),
                        ),
                        if (meta != null)
                          Text(
                            meta!,
                            style: theme.bodySmall!.copyWith(
                              color: p.textMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: Spacing.space2),
                  Icon(
                    LucideIcons.chevronRight,
                    size: Sizes.iconLg,
                    color: p.textMuted,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: p.actionSubtle,
        borderRadius: Radii.smAll,
      ),
      child: Icon(icon, size: Sizes.iconLg, color: p.action),
    );
  }
}

/// A large number with an icon and a label, tappable: for example how many
/// forms are waiting to be sent.
class StatCard extends StatelessWidget {
  /// Creates the card; [number] is already written in the person's language.
  const StatCard({
    required this.number,
    required this.label,
    required this.icon,
    required this.onTap,
    super.key,
  });

  /// The number, for example "৩".
  final String number;

  /// What it counts.
  final String label;

  /// The icon at the end of the number row.
  final IconData icon;

  /// Called when the card is pressed.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final theme = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      container: true,
      label: '$number $label',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: Radii.mdAll,
          side: BorderSide(color: p.borderStrong),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: Radii.mdAll,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 96),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: Spacing.space3,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text(
                        number,
                        style: theme.headlineMedium!.copyWith(
                          fontFamily: theme.bodyMedium!.fontFamily,
                          fontFamilyFallback:
                              theme.bodyMedium!.fontFamilyFallback,
                          fontWeight: FontWeight.w700,
                          fontSize: 32,
                        ),
                      ),
                      Icon(icon, size: Sizes.iconLg, color: p.action),
                    ],
                  ),
                  Text(label, style: theme.titleSmall),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The neutral placeholder app mark: a rounded tile with a compass.
/// Replaced when the app icon is redesigned.
class ObhijatraMark extends StatelessWidget {
  /// Creates the mark, [size] logical pixels wide.
  const ObhijatraMark({this.size = 40, super.key});

  /// Width and height.
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: p.surfaceBrand,
          borderRadius: BorderRadius.circular(size * Radii.tileFraction),
        ),
        child: Icon(
          LucideIcons.compass,
          size: size * 0.6,
          color: p.textOnBrand,
        ),
      ),
    );
  }
}
