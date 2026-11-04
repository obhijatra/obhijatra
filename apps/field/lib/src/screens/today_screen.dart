import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:obhijatra_core/obhijatra_core.dart';
import 'package:obhijatra_field/l10n/app_localizations.dart';
import 'package:obhijatra_field/src/forms/form_entry_controller.dart';
import 'package:obhijatra_field/src/l10n/problem_text.dart';
import 'package:obhijatra_field/src/providers/data_providers.dart';
import 'package:obhijatra_field/src/providers/locale_provider.dart';
import 'package:obhijatra_field/src/providers/platform_providers.dart';
import 'package:obhijatra_field/src/providers/session_providers.dart';
import 'package:obhijatra_field/src/providers/sync_providers.dart';
import 'package:obhijatra_field/src/screens/form_entry_screen.dart';
import 'package:obhijatra_field/src/util/bangla.dart' as fmt;
import 'package:obhijatra_field/src/widgets/bottom_nav.dart';
import 'package:obhijatra_field/src/widgets/screen_frame.dart';
import 'package:obhijatra_ui/obhijatra_ui.dart';

/// Opens a new copy of the form [formId].
void startForm(BuildContext context, String formId) {
  unawaited(
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => FormEntryScreen(
          args: FormEntryArgs(
            formId: formId,
            token: DateTime.now().microsecondsSinceEpoch,
          ),
        ),
      ),
    ),
  );
}

/// The title of a cached form, with the form id as a fallback.
String formTitleOf(CachedForm form) => form.title ?? form.formId;

/// The home screen: what is waiting, when the phone last synced, and the
/// forms to fill.
class TodayScreen extends ConsumerWidget {
  /// Creates the screen with the bottom bar [nav].
  const TodayScreen({required this.nav, required this.onSelectTab, super.key});

  /// The bottom navigation bar.
  final Widget nav;

  /// Switches to another tab.
  final ValueChanged<MainTab> onSelectTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final bangla = ref.watch(localeProvider).languageCode == 'bn';
    final now = ref.watch(nowProvider)();
    final status = ref.watch(syncStatusProvider).value ?? const SyncStatus();
    final online = ref.watch(onlineProvider).value ?? true;
    final forms = ref.watch(cachedFormsProvider).value ?? const <CachedForm>[];
    final drafts = ref.watch(draftsProvider).value ?? const <Draft>[];
    final refresh = ref.watch(formsRefreshProvider);
    final offline = !online || status.isOffline;
    final scale = MediaQuery.textScalerOf(context).scale(16) / 16;

    final stats = <Widget>[
      StatCard(
        number: fmt.digits(status.queued + status.problems, bangla: bangla),
        label: l.statWaiting,
        icon: LucideIcons.cloudUpload,
        onTap: () => onSelectTab(MainTab.sending),
      ),
      StatCard(
        number: fmt.digits(drafts.length, bangla: bangla),
        label: l.statDrafts,
        icon: LucideIcons.pencil,
        onTap: () => onSelectTab(MainTab.forms),
      ),
    ];

    final lastSynced = status.lastSyncedAt;
    final syncLine = lastSynced == null
        ? l.lastSyncedNever
        : l.lastSyncedAt(fmt.when(lastSynced, bangla: bangla, now: now));

    return ScreenFrame(
      topBar: TopBar(title: l.appTitle, showMark: true),
      banner: offline
          ? OfflineBanner(title: l.offlineTitle, message: l.offlineMessage)
          : null,
      bottomNavigation: nav,
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait<void>(<Future<void>>[
            ref.read(formsRefreshProvider.notifier).refresh(),
            syncNow(ref, ignoreBackoff: true).then((_) {}),
          ]);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(Spacing.space4),
          children: <Widget>[
            Semantics(
              header: true,
              child: Text(l.todayTitle, style: text.headlineLarge),
            ),
            Text(
              fmt.fullDate(now, bangla: bangla),
              style: text.bodySmall!.copyWith(color: p.textMuted),
            ),
            const SizedBox(height: Spacing.space3),
            if (status.blockedBy == ProblemCode.signInRequired)
              _Notice(
                icon: LucideIcons.logIn,
                text: l.signInAgainBanner,
                color: p.warning,
                background: p.warningSubtle,
                action: PrimaryButton(
                  label: l.signInTitle,
                  onPressed: () => ref.read(sessionProvider.notifier).signOut(),
                ),
              )
            else if (status.blockedBy != null)
              _Notice(
                icon: LucideIcons.triangleAlert,
                text: problemText(l, status.blockedBy!),
                color: p.warning,
                background: p.warningSubtle,
              ),
            if (scale >= 1.4)
              Column(
                children: <Widget>[
                  stats[0],
                  const SizedBox(height: Spacing.space3),
                  stats[1],
                ],
              )
            else
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Expanded(child: stats[0]),
                    const SizedBox(width: Spacing.space3),
                    Expanded(child: stats[1]),
                  ],
                ),
              ),
            const SizedBox(height: Spacing.space3),
            if (status.isSending)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: SyncStatusBadge(
                  state: SyncVisualState.sending,
                  label: l.syncSendingNow,
                ),
              ),
            if (status.isSending) const SizedBox(height: Spacing.space3),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(top: Spacing.space1),
                  child: Icon(
                    LucideIcons.clock,
                    size: Sizes.icon,
                    color: p.textMuted,
                  ),
                ),
                const SizedBox(width: Spacing.space2),
                Expanded(
                  child: Text(
                    syncLine,
                    style: text.bodySmall!.copyWith(color: p.textMuted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Spacing.space5),
            Semantics(
              header: true,
              child: Text(l.formsToFill, style: text.headlineMedium),
            ),
            const SizedBox(height: Spacing.space3),
            if (forms.isEmpty)
              Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(l.formsEmptyTitle, style: text.titleMedium),
                    const SizedBox(height: Spacing.space2),
                    Text(l.formsEmptyBody, style: text.bodyMedium),
                  ],
                ),
              )
            else
              for (final form in forms) ...<Widget>[
                ActionCard(
                  icon: LucideIcons.clipboardList,
                  title: formTitleOf(form),
                  meta: _meta(l, drafts, form, bangla),
                  onTap: () => startForm(context, form.formId),
                ),
                const SizedBox(height: Spacing.space2),
              ],
            const SizedBox(height: Spacing.space2),
            PrimaryButton(
              label: refresh.isRefreshing ? l.formsUpdating : l.formsUpdate,
              icon: LucideIcons.refreshCw,
              variant: PrimaryButtonVariant.secondary,
              busy: refresh.isRefreshing,
              onPressed: () =>
                  ref.read(formsRefreshProvider.notifier).refresh(),
            ),
            if (refresh.problem != null &&
                refresh.problem != ProblemCode.offline &&
                refresh.problem != ProblemCode.timeout) ...<Widget>[
              const SizedBox(height: Spacing.space3),
              _Notice(
                icon: LucideIcons.triangleAlert,
                text: l.formsUpdateFailed(problemText(l, refresh.problem!)),
                color: p.warning,
                background: p.warningSubtle,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _meta(
    AppLocalizations l,
    List<Draft> drafts,
    CachedForm form,
    bool bangla,
  ) {
    final count = drafts.where((d) => d.formId == form.formId).length;
    return count == 0 ? l.formMetaNew : l.formMetaDrafts(count);
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.text,
    required this.color,
    required this.background,
    this.action,
  });

  final IconData icon;
  final String text;
  final Color color;
  final Color background;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.space3),
      child: Panel(
        color: background,
        borderColor: color,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Semantics(
              liveRegion: true,
              container: true,
              label: text,
              child: ExcludeSemantics(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.only(top: Spacing.space1),
                      child: Icon(icon, size: Sizes.icon, color: color),
                    ),
                    const SizedBox(width: Spacing.space3),
                    Expanded(
                      child: Text(
                        text,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (action != null) ...<Widget>[
              const SizedBox(height: Spacing.space3),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
