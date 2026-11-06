import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:obhijatra_core/obhijatra_core.dart';
import 'package:obhijatra_field/l10n/app_localizations.dart';
import 'package:obhijatra_field/src/providers/device_providers.dart';
import 'package:obhijatra_field/src/providers/locale_provider.dart';
import 'package:obhijatra_field/src/providers/platform_providers.dart';
import 'package:obhijatra_field/src/providers/session_providers.dart';
import 'package:obhijatra_field/src/providers/sync_providers.dart';
import 'package:obhijatra_field/src/screens/device_screen.dart';
import 'package:obhijatra_field/src/util/bangla.dart' as fmt;
import 'package:obhijatra_field/src/widgets/screen_frame.dart';
import 'package:obhijatra_ui/obhijatra_ui.dart';

/// Asks whether to sign out, saying how many forms are still waiting
/// (they stay on the phone), and signs out if the person agrees. The app
/// then returns to the sign-in screen by itself.
Future<void> confirmSignOut(BuildContext context, WidgetRef ref) async {
  final l = AppLocalizations.of(context);
  final status = ref.read(syncStatusProvider).value ?? const SyncStatus();
  final unsent = status.queued + status.problems;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l.signOutConfirmTitle),
      content: Text(
        unsent > 0 ? l.signOutOutboxWarning(unsent) : l.signOutNothingWaiting,
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l.actionCancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l.settingsSignOut),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  ref.read(sessionProvider.notifier).signOut();
  Navigator.of(context).popUntil((route) => route.isFirst);
}

/// Language, this phone's approval, and sign out.
class SettingsScreen extends ConsumerWidget {
  /// Creates the screen.
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final locale = ref.watch(localeProvider);
    final user = ref.watch(sessionProvider);
    final device = ref.watch(deviceTrustProvider).value;
    // Watched (not only read at sign-out) so the waiting count is already
    // known when the person taps Sign out.
    ref.watch(syncStatusProvider);
    return ScreenFrame(
      topBar: TopBar(
        title: l.settingsTitle,
        leadingIcon: LucideIcons.arrowLeft,
        leadingLabel: l.actionBack,
        onLeading: () => Navigator.of(context).maybePop(),
      ),
      body: ListView(
        padding: const EdgeInsets.all(Spacing.space4),
        children: <Widget>[
          Semantics(
            header: true,
            child: Text(l.settingsLanguage, style: text.headlineMedium),
          ),
          const SizedBox(height: Spacing.space3),
          QuestionChoice(
            label: l.settingsLanguage,
            options: <ChoiceOption>[
              ChoiceOption('bn', l.languageBangla),
              ChoiceOption('en', l.languageEnglish),
            ],
            selected: <String>{locale.languageCode},
            onChanged: (values) =>
                ref.read(localeProvider.notifier).select(Locale(values.first)),
          ),
          if (device != null) ...<Widget>[
            const SizedBox(height: Spacing.space8),
            Semantics(
              header: true,
              child: Text(l.settingsThisPhone, style: text.headlineMedium),
            ),
            const SizedBox(height: Spacing.space3),
            _ThisPhone(state: device),
          ],
          const SizedBox(height: Spacing.space8),
          Semantics(
            header: true,
            child: Text(l.settingsAccount, style: text.headlineMedium),
          ),
          const SizedBox(height: Spacing.space3),
          if (user != null)
            Padding(
              padding: const EdgeInsets.only(bottom: Spacing.space3),
              child: Text(
                l.settingsSignedInAs(
                  user.name.isEmpty ? user.email : user.name,
                ),
                style: text.bodyMedium,
              ),
            ),
          PrimaryButton(
            label: l.settingsSignOut,
            icon: LucideIcons.logOut,
            variant: PrimaryButtonVariant.secondary,
            onPressed: () => confirmSignOut(context, ref),
          ),
        ],
      ),
    );
  }
}

/// This phone's approval and its numbers, with a way to ask the server
/// again.
class _ThisPhone extends ConsumerWidget {
  const _ThisPhone({required this.state});

  final DeviceTrustState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final bangla = ref.watch(localeProvider).languageCode == 'bn';
    final expires = state.status?.expires;
    final (icon, color, line) = switch (state.phase) {
      DevicePhase.approved => (
        LucideIcons.shieldCheck,
        p.success,
        expires == null
            ? l.deviceStatusWaiting
            : l.deviceStatusApproved(
                fmt.shortDate(expires.toLocal(), bangla: bangla),
              ),
      ),
      DevicePhase.waiting => (
        LucideIcons.hourglass,
        p.info,
        l.deviceStatusWaiting,
      ),
      DevicePhase.renewal => (
        LucideIcons.calendarClock,
        p.warning,
        l.deviceStatusRenewal,
      ),
      DevicePhase.switchedOff => (
        LucideIcons.ban,
        p.danger,
        l.deviceStatusSwitchedOff,
      ),
      DevicePhase.settingUp => (
        LucideIcons.smartphone,
        p.info,
        l.deviceStatusSettingUp,
      ),
    };
    final checked = state.checkedAt;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(top: Spacing.space1),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: Spacing.space3),
              Expanded(
                child: Text(
                  line,
                  style: text.bodyLarge!.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          if (checked != null) ...<Widget>[
            const SizedBox(height: Spacing.space1),
            Text(
              l.deviceLastChecked(
                fmt.when(
                  checked,
                  bangla: bangla,
                  now: ref.watch(nowProvider)(),
                ),
              ),
              style: text.bodySmall!.copyWith(color: p.textMuted),
            ),
          ],
          if (state.phase != DevicePhase.switchedOff &&
              state.phase != DevicePhase.settingUp) ...<Widget>[
            const SizedBox(height: Spacing.space4),
            Text(l.deviceCodeHeading, style: text.titleSmall),
            const SizedBox(height: Spacing.space2),
            DeviceCodeView(code: state.code, compact: true),
          ],
          const SizedBox(height: Spacing.space4),
          PrimaryButton(
            label: state.checking ? l.deviceChecking : l.deviceCheckAgain,
            icon: LucideIcons.refreshCw,
            variant: PrimaryButtonVariant.secondary,
            busy: state.checking,
            onPressed: () => ref.read(deviceTrustProvider.notifier).check(),
          ),
        ],
      ),
    );
  }
}
