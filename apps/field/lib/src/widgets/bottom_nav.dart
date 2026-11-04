import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:obhijatra_field/l10n/app_localizations.dart';
import 'package:obhijatra_ui/obhijatra_ui.dart';

/// The four tabs of the main screen.
enum MainTab {
  /// Today's overview.
  today(LucideIcons.house),

  /// All forms and drafts.
  forms(LucideIcons.clipboardList),

  /// Finished forms and their sending state.
  sending(LucideIcons.send),

  /// Settings and About.
  more(LucideIcons.menu);

  const MainTab(this.icon);

  /// The Lucide icon of the tab.
  final IconData icon;
}

/// The bottom navigation bar of the design: an icon in a pill and a word
/// under it. The active tab is filled and bold, so it never relies on colour.
class AppBottomNav extends StatelessWidget {
  /// Creates the bar.
  const AppBottomNav({
    required this.selected,
    required this.onSelected,
    super.key,
  });

  /// The tab shown now.
  final MainTab selected;

  /// Called when another tab is pressed.
  final ValueChanged<MainTab> onSelected;

  String _label(AppLocalizations l, MainTab tab) => switch (tab) {
    MainTab.today => l.navToday,
    MainTab.forms => l.navForms,
    MainTab.sending => l.navSending,
    MainTab.more => l.navMore,
  };

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l = AppLocalizations.of(context);
    final label = Theme.of(context).textTheme.labelLarge!;
    return Material(
      color: p.surface,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: p.border)),
        ),
        child: SafeArea(
          top: false,
          child: Semantics(
            container: true,
            label: l.navMainMenu,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (final tab in MainTab.values)
                  Expanded(
                    child: _NavItem(
                      icon: tab.icon,
                      label: _label(l, tab),
                      active: tab == selected,
                      style: label,
                      onTap: () => onSelected(tab),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.style,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final TextStyle style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      container: true,
      button: true,
      selected: active,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: Radii.smAll,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: Sizes.touch + Spacing.space6,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.space1,
              vertical: Spacing.space2,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: Sizes.touch + Spacing.space4,
                  height: Spacing.space8,
                  decoration: BoxDecoration(
                    color: active ? p.action : null,
                    borderRadius: Radii.pillAll,
                  ),
                  child: Icon(
                    icon,
                    size: Sizes.iconLg,
                    color: active ? p.onAction : p.textMuted,
                  ),
                ),
                const SizedBox(height: Spacing.space1),
                Text(
                  label,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: style.copyWith(
                    color: active ? p.text : p.textMuted,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
