import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:obhijatra_core/obhijatra_core.dart';
import 'package:obhijatra_field/l10n/app_localizations.dart';
import 'package:obhijatra_field/src/l10n/problem_text.dart';
import 'package:obhijatra_field/src/providers/data_providers.dart';
import 'package:obhijatra_field/src/providers/locale_provider.dart';
import 'package:obhijatra_field/src/providers/platform_providers.dart';
import 'package:obhijatra_field/src/providers/sync_providers.dart';
import 'package:obhijatra_field/src/screens/today_screen.dart';
import 'package:obhijatra_field/src/util/bangla.dart' as fmt;
import 'package:obhijatra_field/src/widgets/screen_frame.dart';
import 'package:obhijatra_ui/obhijatra_ui.dart';

/// Every finished form and where it is: waiting, sending, sent or in trouble.
class SendingScreen extends ConsumerWidget {
  /// Creates the screen with the bottom bar [nav].
  const SendingScreen({required this.nav, super.key});

  /// The bottom navigation bar.
  final Widget nav;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final bangla = ref.watch(localeProvider).languageCode == 'bn';
    final now = ref.watch(nowProvider)();
    final entries =
        ref.watch(outboxEntriesProvider).value ?? const <OutboxEntry>[];
    final forms = ref.watch(cachedFormsProvider).value ?? const <CachedForm>[];
    final status = ref.watch(syncStatusProvider).value ?? const SyncStatus();
    final online = ref.watch(onlineProvider).value ?? true;
    final titles = <String, String>{
      for (final f in forms) f.formId: formTitleOf(f),
    };
    final offline = !online || status.isOffline;
    final waiting = entries.any(
      (e) => e.state == OutboxState.queued || e.state == OutboxState.problem,
    );
    return ScreenFrame(
      topBar: TopBar(title: l.sendingTitle),
      banner: offline
          ? OfflineBanner(title: l.offlineTitle, message: l.offlineMessage)
          : null,
      bottomNavigation: nav,
      body: ListView(
        padding: const EdgeInsets.all(Spacing.space4),
        children: <Widget>[
          if (status.blockedBy != null) ...<Widget>[
            Panel(
              color: context.palette.warningSubtle,
              borderColor: context.palette.warning,
              child: Text(
                problemText(l, status.blockedBy!),
                style: text.bodyMedium,
              ),
            ),
            const SizedBox(height: Spacing.space3),
          ],
          if (waiting) ...<Widget>[
            PrimaryButton(
              label: status.isSending ? l.syncSendingNow : l.sendingNow,
              icon: LucideIcons.send,
              busy: status.isSending,
              onPressed: () => syncNow(ref, ignoreBackoff: true),
            ),
            const SizedBox(height: Spacing.space4),
          ],
          if (entries.isEmpty)
            Panel(child: Text(l.sendingEmpty, style: text.bodyMedium))
          else
            for (final entry in entries) ...<Widget>[
              _EntryCard(
                entry: entry,
                title: titles[entry.formId] ?? entry.formId,
                bangla: bangla,
                now: now,
              ),
              const SizedBox(height: Spacing.space2),
            ],
        ],
      ),
    );
  }
}

class _EntryCard extends ConsumerWidget {
  const _EntryCard({
    required this.entry,
    required this.title,
    required this.bangla,
    required this.now,
  });

  final OutboxEntry entry;
  final String title;
  final bool bangla;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final (SyncVisualState visual, String label) = switch (entry.state) {
      OutboxState.sent => (
        SyncVisualState.synced,
        l.stateSent(
          fmt.when(entry.sentAt ?? entry.updatedAt, bangla: bangla, now: now),
        ),
      ),
      OutboxState.sending => (SyncVisualState.sending, l.stateSending),
      OutboxState.problem => (SyncVisualState.problem, l.stateProblem),
      OutboxState.queued => (SyncVisualState.local, l.stateQueued),
    };
    final code = entry.lastError == null
        ? null
        : ProblemCode.fromName(entry.lastError);
    final showReason = entry.state != OutboxState.sent && code != null;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: text.titleSmall!.copyWith(
              fontSize: text.bodyMedium!.fontSize,
              height: text.bodyMedium!.height,
            ),
          ),
          Text(
            l.sendingFinishedAt(
              fmt.when(entry.createdAt, bangla: bangla, now: now),
            ),
            style: text.bodySmall!.copyWith(color: p.textMuted),
          ),
          const SizedBox(height: Spacing.space2),
          SyncStatusBadge(state: visual, label: label),
          if (showReason) ...<Widget>[
            const SizedBox(height: Spacing.space2),
            Text(problemText(l, code), style: text.bodySmall),
          ],
          if (entry.state == OutboxState.problem) ...<Widget>[
            const SizedBox(height: Spacing.space2),
            PrimaryButton(
              label: l.actionTryAgain,
              icon: LucideIcons.refreshCw,
              variant: PrimaryButtonVariant.secondary,
              onPressed: () async {
                final db = await ref.read(deviceDatabaseProvider.future);
                await OutboxRepository(db).retry(entry.instanceId);
                await syncNow(ref, ignoreBackoff: true);
              },
            ),
          ],
        ],
      ),
    );
  }
}
