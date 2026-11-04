import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obhijatra_manager/l10n/app_localizations.dart';
import 'package:obhijatra_manager/src/data/models.dart';
import 'package:obhijatra_manager/src/state/navigation.dart';
import 'package:obhijatra_manager/src/state/providers.dart';
import 'package:obhijatra_manager/src/ui/about_screen.dart';
import 'package:obhijatra_manager/src/ui/forms_screen.dart';
import 'package:obhijatra_manager/src/ui/settings_screen.dart';
import 'package:obhijatra_manager/src/ui/submissions_screen.dart';
import 'package:obhijatra_manager/widgets/brand_mark.dart';
import 'package:obhijatra_manager/widgets/focus_ring.dart';
import 'package:obhijatra_manager/widgets/language_switch.dart';
import 'package:obhijatra_manager/widgets/ob_badge.dart';
import 'package:obhijatra_ui/obhijatra_ui.dart';

/// Window width from which the menu shows words beside its icons.
const double _extendedFrom = 1180;

/// Window width below which the menu moves to the bottom of the window.
const double _bottomBarBelow = 720;

/// Re-runs everything that failed to load.
void retryAll(WidgetRef ref) {
  ref
    ..invalidate(organisationNameProvider)
    ..invalidate(formsProvider)
    ..invalidate(xformTextProvider)
    ..invalidate(locationNamesProvider)
    ..invalidate(submissionsProvider)
    ..invalidate(submissionCountsProvider)
    ..invalidate(answersProvider)
    ..invalidate(formDefinitionProvider);
}

/// The signed-in frame: top bar, menu, the chosen screen.
class ManagerShell extends ConsumerWidget {
  /// Creates the shell.
  const ManagerShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final section = ref.watch(sectionProvider);
    final online = ref.watch(onlineProvider);
    final palette = context.palette;
    return Scaffold(
      backgroundColor: palette.bg,
      body: LayoutBuilder(
        builder: (context, box) {
          final width = box.maxWidth;
          final bottom = width < _bottomBarBelow;
          final extended = width >= _extendedFrom;
          final body = switch (section) {
            Section.forms => const FormsScreen(),
            Section.submissions => const SubmissionsScreen(),
            Section.settings => const SettingsScreen(),
            Section.about => const AboutScreen(),
          };
          return Column(
            children: <Widget>[
              _TopBar(compact: width < 900),
              if (!online) const _OfflineBanner(),
              Expanded(
                child: bottom
                    ? Column(
                        children: <Widget>[
                          Expanded(child: body),
                          _BottomNav(section: section),
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          _SideNav(section: section, extended: extended),
                          Expanded(child: body),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Destination {
  const _Destination(this.section, this.icon, this.selectedIcon);
  final Section section;
  final IconData icon;
  final IconData selectedIcon;
}

const List<_Destination> _destinations = <_Destination>[
  _Destination(Section.forms, Icons.description_outlined, Icons.description),
  _Destination(Section.submissions, Icons.inbox_outlined, Icons.inbox),
  _Destination(Section.settings, Icons.settings_outlined, Icons.settings),
  _Destination(Section.about, Icons.info_outline, Icons.info),
];

String _sectionLabel(AppLocalizations l10n, Section section) =>
    switch (section) {
      Section.forms => l10n.navForms,
      Section.submissions => l10n.navSubmissions,
      Section.settings => l10n.navSettings,
      Section.about => l10n.navAbout,
    };

class _TopBar extends ConsumerWidget {
  const _TopBar({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final palette = context.palette;
    final user = ref.watch(sessionProvider);
    final org = ref.watch(organisationNameProvider).asData?.value ?? '';
    final serif = Theme.of(context).textTheme.titleLarge!;
    return Material(
      color: palette.surface,
      child: Container(
        constraints: const BoxConstraints(minHeight: 64),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? Spacing.space4 : Spacing.space6,
          vertical: Spacing.space2,
        ),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: palette.border)),
        ),
        child: Row(
          children: <Widget>[
            const BrandMark(),
            const SizedBox(width: Spacing.space3),
            Text('Obhijatra', style: serif),
            if (!compact) ...<Widget>[
              const SizedBox(width: Spacing.space4),
              ObBadge(label: kIsWeb ? l10n.badgeWebApp : l10n.badgeDesktopApp),
            ],
            if (!compact && org.isNotEmpty) ...<Widget>[
              const SizedBox(width: Spacing.space4),
              Container(
                padding: const EdgeInsetsDirectional.only(
                  start: Spacing.space4,
                ),
                decoration: BoxDecoration(
                  border: BorderDirectional(
                    start: BorderSide(color: palette.border),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      Icons.apartment_outlined,
                      size: Sizes.icon,
                      color: palette.textMuted,
                    ),
                    const SizedBox(width: Spacing.space2),
                    Text(org, style: Theme.of(context).textTheme.labelLarge),
                  ],
                ),
              ),
            ],
            const Spacer(),
            const LanguageSwitch(),
            const SizedBox(width: Spacing.space2),
            if (user != null) _UserMenu(user: user, compact: compact),
          ],
        ),
      ),
    );
  }
}

class _UserMenu extends ConsumerWidget {
  const _UserMenu({required this.user, required this.compact});

  final StaffUser user;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final palette = context.palette;
    return FocusRing(
      child: PopupMenuButton<String>(
        tooltip: l10n.accountMenu,
        position: PopupMenuPosition.under,
        onSelected: (value) {
          if (value == 'settings') {
            ref.read(sectionProvider.notifier).go(Section.settings);
          } else {
            ref.read(sessionProvider.notifier).signOut();
          }
        },
        itemBuilder: (context) => <PopupMenuEntry<String>>[
          PopupMenuItem<String>(
            value: 'settings',
            child: Text(l10n.navSettings),
          ),
          PopupMenuItem<String>(
            value: 'signout',
            child: Text(l10n.menuSignOut),
          ),
        ],
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.space2,
            vertical: Spacing.space2,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              CircleAvatar(
                radius: 16,
                backgroundColor: palette.surfaceBrand,
                child: Text(
                  user.initials,
                  style: Theme.of(context).textTheme.labelSmall!.copyWith(
                    color: palette.textOnBrand,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (!compact) ...<Widget>[
                const SizedBox(width: Spacing.space2),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 180),
                  child: Text(
                    user.displayName,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
              ],
              Icon(Icons.arrow_drop_down, color: palette.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _OfflineBanner extends ConsumerWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final palette = context.palette;
    final text = Theme.of(context).textTheme;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.space4,
          vertical: Spacing.space2,
        ),
        decoration: BoxDecoration(
          color: palette.infoSubtle,
          border: Border(bottom: BorderSide(color: palette.info)),
        ),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: Spacing.space3,
          runSpacing: Spacing.space1,
          children: <Widget>[
            Icon(
              Icons.cloud_off_outlined,
              size: Sizes.icon,
              color: palette.info,
            ),
            Text(
              l10n.offlineTitle,
              style: text.labelLarge!.copyWith(color: palette.info),
            ),
            Text(l10n.offlineBody, style: text.bodySmall),
            TextButton(
              onPressed: () => retryAll(ref),
              child: Text(l10n.actionTryAgain),
            ),
          ],
        ),
      ),
    );
  }
}

class _SideNav extends ConsumerWidget {
  const _SideNav({required this.section, required this.extended});

  final Section section;
  final bool extended;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final palette = context.palette;
    return Semantics(
      container: true,
      label: l10n.navMain,
      child: Container(
        width: extended ? 232 : 96,
        padding: const EdgeInsets.symmetric(
          vertical: Spacing.space5,
          horizontal: Spacing.space2,
        ),
        decoration: BoxDecoration(
          color: palette.surface,
          border: Border(right: BorderSide(color: palette.border)),
        ),
        child: FocusTraversalGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (final destination in _destinations)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: _NavItem(
                    icon: destination.section == section
                        ? destination.selectedIcon
                        : destination.icon,
                    label: _sectionLabel(l10n, destination.section),
                    selected: destination.section == section,
                    extended: extended,
                    onTap: () => ref
                        .read(sectionProvider.notifier)
                        .go(destination.section),
                  ),
                ),
            ],
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
    required this.selected,
    required this.extended,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool extended;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final style = Theme.of(context).textTheme.labelLarge!.copyWith(
      color: selected ? palette.text : palette.textMuted,
      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
    );
    final iconWidget = Icon(
      icon,
      size: Sizes.iconLg,
      color: selected ? palette.action : palette.textMuted,
    );
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: FocusRing(
        child: Material(
          color: selected ? palette.actionSubtle : Colors.transparent,
          borderRadius: Radii.smAll,
          child: InkWell(
            borderRadius: Radii.smAll,
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: extended
                  ? Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Spacing.space3,
                        vertical: Spacing.space2,
                      ),
                      child: Row(
                        children: <Widget>[
                          iconWidget,
                          const SizedBox(width: Spacing.space3),
                          Expanded(child: Text(label, style: style)),
                        ],
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Spacing.space1,
                        vertical: Spacing.space2,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          iconWidget,
                          const SizedBox(height: 2),
                          Text(
                            label,
                            style: style,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
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

class _BottomNav extends ConsumerWidget {
  const _BottomNav({required this.section});

  final Section section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final palette = context.palette;
    return Semantics(
      container: true,
      label: l10n.navMain,
      child: Container(
        decoration: BoxDecoration(
          color: palette.surface,
          border: Border(top: BorderSide(color: palette.border)),
        ),
        padding: const EdgeInsets.all(Spacing.space1),
        child: Row(
          children: <Widget>[
            for (final destination in _destinations)
              Expanded(
                child: _NavItem(
                  icon: destination.section == section
                      ? destination.selectedIcon
                      : destination.icon,
                  label: _sectionLabel(l10n, destination.section),
                  selected: destination.section == section,
                  extended: false,
                  onTap: () => ref
                      .read(sectionProvider.notifier)
                      .go(destination.section),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
