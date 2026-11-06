import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obhijatra_manager/l10n/app_localizations.dart';
import 'package:obhijatra_manager/src/data/devices.dart';
import 'package:obhijatra_manager/src/data/models.dart';
import 'package:obhijatra_manager/src/data/people.dart';
import 'package:obhijatra_manager/src/data/problem.dart';
import 'package:obhijatra_manager/src/state/devices.dart';
import 'package:obhijatra_manager/src/state/providers.dart';
import 'package:obhijatra_manager/src/ui/device_dialogs.dart';
import 'package:obhijatra_manager/src/ui/device_words.dart';
import 'package:obhijatra_manager/src/ui/format.dart';
import 'package:obhijatra_manager/src/ui/page_scaffold.dart';
import 'package:obhijatra_manager/src/ui/people_words.dart';
import 'package:obhijatra_manager/widgets/empty_state.dart';
import 'package:obhijatra_manager/widgets/focus_ring.dart';
import 'package:obhijatra_manager/widgets/loading_block.dart';
import 'package:obhijatra_manager/widgets/ob_badge.dart';
import 'package:obhijatra_manager/widgets/ob_panel.dart';
import 'package:obhijatra_manager/widgets/problem_view.dart';
import 'package:obhijatra_ui/obhijatra_ui.dart';

/// Content width from which a device's details sit side by side in a row.
const double _wideRowFrom = 820;

/// Devices: for organisation admins and branch managers, the devices to
/// approve and switch off, and their own; for everyone else, their own
/// devices only ("My devices"), so a lost laptop can be switched off.
class DevicesScreen extends ConsumerWidget {
  /// Creates the screen.
  const DevicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(sessionProvider);
    if (user == null) return const SizedBox.shrink();
    final approver = user.canApproveDevices;
    final tab = approver ? ref.watch(devicesTabProvider) : DevicesTab.mine;
    final devices = ref.watch(devicesProvider);
    return PageScaffold(
      title: approver ? l10n.navDevices : l10n.navMyDevices,
      subtitle: switch ((approver, user.isOrgAdmin)) {
        (true, true) => l10n.devicesSummaryAdmin,
        (true, false) => l10n.devicesSummaryBranch,
        (false, _) => l10n.devicesSummaryMine,
      },
      trailing: IconButton.outlined(
        tooltip: l10n.refresh,
        icon: const Icon(Icons.refresh),
        onPressed: () => ref.invalidate(devicesProvider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (approver) ...<Widget>[
            _Tabs(tab: tab),
            const SizedBox(height: Spacing.space4),
          ],
          Expanded(
            child: devices.when(
              loading: () => const LoadingBlock(),
              error: (error, _) {
                final problem = problemFrom(error);
                return ProblemView(
                  problem: problem,
                  onAction: () {
                    if (problem.action == ProblemAction.signInAgain) {
                      ref.read(sessionProvider.notifier).signOut();
                    } else {
                      ref.invalidate(devicesProvider);
                    }
                  },
                );
              },
              data: (all) => _DeviceList(
                user: user,
                mine: tab == DevicesTab.mine,
                devices: <DeviceRecord>[
                  for (final device in all)
                    if (device.isOwnedBy(user) == (tab == DevicesTab.mine))
                      device,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Other people's devices" and "My devices".
class _Tabs extends ConsumerWidget {
  const _Tabs({required this.tab});

  final DevicesTab tab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final palette = context.palette;

    Widget item(DevicesTab value, IconData icon, String label) {
      final selected = value == tab;
      return Semantics(
        button: true,
        selected: selected,
        child: FocusRing(
          child: InkWell(
            borderRadius: Radii.smAll,
            onTap: () => ref.read(devicesTabProvider.notifier).show(value),
            child: Container(
              constraints: const BoxConstraints(minHeight: Sizes.touch),
              padding: const EdgeInsets.symmetric(horizontal: Spacing.space4),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: selected ? palette.action : Colors.transparent,
                    width: 3,
                  ),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    icon,
                    size: Sizes.icon,
                    color: selected ? palette.action : palette.textMuted,
                  ),
                  const SizedBox(width: Spacing.space2),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelLarge!.copyWith(
                      color: selected ? palette.text : palette.textMuted,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Semantics(
      container: true,
      label: l10n.devicesTabsLabel,
      child: Container(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: palette.border)),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: <Widget>[
              item(
                DevicesTab.others,
                Icons.devices_other_outlined,
                l10n.devicesTabOthers,
              ),
              item(DevicesTab.mine, Icons.devices_outlined, l10n.navMyDevices),
            ],
          ),
        ),
      ),
    );
  }
}

/// One line of the list: a section heading, a note, or a device.
sealed class _Item {
  const _Item();
}

class _Heading extends _Item {
  const _Heading(this.title, this.count);
  final String title;
  final int count;
}

class _Note extends _Item {
  const _Note(this.text);
  final String text;
}

class _Device extends _Item {
  const _Device(this.device);
  final DeviceRecord device;
}

class _DeviceList extends ConsumerWidget {
  const _DeviceList({
    required this.user,
    required this.mine,
    required this.devices,
  });

  final StaffUser user;
  final bool mine;
  final List<DeviceRecord> devices;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    if (devices.isEmpty) {
      return EmptyState(
        icon: Icons.devices_outlined,
        title: l10n.devicesEmptyTitle,
        body: mine ? l10n.devicesMineEmptyBody : l10n.devicesEmptyBody,
      );
    }
    final now = ref.watch(deviceClockProvider)();
    final waiting = <DeviceRecord>[];
    final approved = <DeviceRecord>[];
    final off = <DeviceRecord>[];
    for (final device in devices) {
      if (device.status == DeviceStatus.revoked) {
        off.add(device);
      } else if (device.waitingAt(now)) {
        waiting.add(device);
      } else {
        approved.add(device);
      }
    }
    final items = <_Item>[
      _Heading(l10n.devicesWaiting, waiting.length),
      if (waiting.isEmpty) _Note(l10n.devicesWaitingNone),
      ...waiting.map(_Device.new),
      if (approved.isNotEmpty) ...<_Item>[
        _Heading(l10n.devicesApproved, approved.length),
        ...approved.map(_Device.new),
      ],
      if (off.isNotEmpty) ...<_Item>[
        _Heading(l10n.devicesSwitchedOff, off.length),
        ...off.map(_Device.new),
      ],
    ];
    final current = ref.watch(
      deviceGateProvider.select((gate) => gate.value?.deviceId),
    );
    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= _wideRowFrom;
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: Spacing.space6),
          itemCount: items.length,
          itemBuilder: (context, index) => switch (items[index]) {
            _Heading(:final title, :final count) => _SectionHeading(
              title: title,
              count: count,
              first: index == 0,
            ),
            _Note(:final text) => Padding(
              padding: const EdgeInsets.only(bottom: Spacing.space3),
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodyMedium!
                    .copyWith(color: context.palette.textMuted),
              ),
            ),
            _Device(:final device) => Padding(
              padding: const EdgeInsets.only(bottom: Spacing.space2),
              child: _DeviceRow(
                device: device,
                user: user,
                now: now,
                showOwner: !mine,
                current: device.id == current,
                wide: wide,
              ),
            ),
          },
        );
      },
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.title,
    required this.count,
    required this.first,
  });

  final String title;
  final int count;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final palette = context.palette;
    return Padding(
      padding: EdgeInsets.only(
        top: first ? 0 : Spacing.space5,
        bottom: Spacing.space2,
      ),
      child: Semantics(
        header: true,
        child: Row(
          children: <Widget>[
            Text(title, style: text.titleMedium),
            const SizedBox(width: Spacing.space2),
            Text(
              Format.number(context, count),
              style: text.labelLarge!.copyWith(color: palette.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeviceRow extends ConsumerWidget {
  const _DeviceRow({
    required this.device,
    required this.user,
    required this.now,
    required this.showOwner,
    required this.current,
    required this.wide,
  });

  final DeviceRecord device;
  final StaffUser user;
  final DateTime now;
  final bool showOwner;
  final bool current;
  final bool wide;

  /// The dialog says what came of the approval and reloads the list.
  Future<void> _approve(BuildContext context) =>
      showApproveDeviceDialog(context, device: device);

  Future<void> _switchOff(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final done = await showSwitchOffDeviceDialog(
      context,
      device: device,
      mine: device.isOwnedBy(user),
      current: current,
    );
    if (done != true) return;
    messenger.showSnackBar(SnackBar(content: Text(l10n.switchOffDone)));
    ref.invalidate(devicesProvider);
    // This device's sessions have ended: the device check shows what to do.
    if (current) ref.read(deviceRecheckProvider.notifier).request();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final palette = context.palette;
    final muted = text.bodySmall!.copyWith(color: palette.textMuted);

    final dates = <String>[
      if (device.created case final DateTime added)
        l10n.deviceAdded(Format.day(context, added)),
      if (device.status == DeviceStatus.active && device.expires != null)
        device.approvalExpiredAt(now)
            ? l10n.deviceApprovalRanOut(Format.day(context, device.expires!))
            : l10n.deviceApprovedUntil(Format.day(context, device.expires!)),
    ];

    final who = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          showOwner ? ownerName(l10n, device) : deviceName(l10n, device),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: text.titleSmall,
        ),
        if (showOwner) ...<Widget>[
          // How to reach the person, for the phone call.
          if (device.ownerContact.isNotEmpty)
            Text(
              device.ownerContact,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.bodySmall,
            ),
          Text(
            <String>[
              kindName(l10n, device.ownerKind),
              if (device.ownerKind == PersonKind.staff &&
                  device.ownerRole.isNotEmpty)
                roleName(l10n, device.ownerRole),
            ].join(' · '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: muted,
          ),
        ],
      ],
    );
    final what = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(
              platformIcon(device.platform),
              size: Sizes.icon,
              color: palette.textMuted,
            ),
            const SizedBox(width: Spacing.space2),
            Expanded(
              child: Text(
                showOwner
                    ? deviceAndPlatform(l10n, device)
                    : platformName(l10n, device.platform),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: text.bodySmall,
              ),
            ),
          ],
        ),
        if (dates.isNotEmpty) Text(dates.join(' · '), style: muted),
      ],
    );
    final badges = Wrap(
      spacing: Spacing.space1,
      runSpacing: Spacing.space1,
      children: <Widget>[
        ..._statusBadges(l10n),
        if (current)
          ObBadge(
            label: l10n.deviceThisOne,
            tone: Tone.info,
            icon: Icons.my_location,
          ),
      ],
    );
    final approve = mayApproveDevice(user, device, now);
    final switchOff = maySwitchOffDevice(user, device);
    final firstByMe =
        device.needsSecondApproval && device.firstApprovedBy == user.id;
    final actions = Wrap(
      spacing: Spacing.space2,
      runSpacing: Spacing.space2,
      alignment: WrapAlignment.end,
      children: <Widget>[
        if (approve)
          FilledButton.icon(
            key: ValueKey<String>('approve-${device.id}'),
            onPressed: () => unawaited(_approve(context)),
            icon: const Icon(Icons.verified_user_outlined),
            label: Text(l10n.actionApprove),
          ),
        if (switchOff)
          OutlinedButton.icon(
            key: ValueKey<String>('switch-off-${device.id}'),
            onPressed: () => unawaited(_switchOff(context, ref)),
            icon: const Icon(Icons.power_settings_new),
            label: Text(l10n.deviceSwitchOff),
          ),
      ],
    );
    final note = firstByMe
        ? Text(l10n.deviceYouApprovedFirst, style: muted)
        : null;

    return ObPanel(
      key: ValueKey<String>('device-${device.id}'),
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.space4,
        vertical: Spacing.space3,
      ),
      child: wide
          ? Row(
              children: <Widget>[
                Expanded(flex: 26, child: who),
                const SizedBox(width: Spacing.space3),
                Expanded(flex: 34, child: what),
                const SizedBox(width: Spacing.space3),
                Expanded(
                  flex: 40,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      badges,
                      if (note != null) ...<Widget>[
                        const SizedBox(height: Spacing.space1),
                        note,
                      ],
                      if (approve || switchOff) ...<Widget>[
                        const SizedBox(height: Spacing.space2),
                        actions,
                      ],
                    ],
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                who,
                const SizedBox(height: Spacing.space1),
                what,
                const SizedBox(height: Spacing.space2),
                badges,
                if (note != null) ...<Widget>[
                  const SizedBox(height: Spacing.space1),
                  note,
                ],
                if (approve || switchOff) ...<Widget>[
                  const SizedBox(height: Spacing.space2),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: actions,
                  ),
                ],
              ],
            ),
    );
  }

  List<Widget> _statusBadges(AppLocalizations l10n) => switch (device.status) {
    DeviceStatus.revoked => <Widget>[
      ObBadge(label: l10n.deviceStatusOff, icon: Icons.block),
    ],
    DeviceStatus.pending => <Widget>[
      ObBadge(
        label: l10n.deviceStatusWaiting,
        tone: Tone.warning,
        icon: Icons.hourglass_empty,
      ),
      if (device.needsSecondApproval)
        ObBadge(
          label: l10n.deviceNeedsSecond,
          tone: Tone.info,
          icon: Icons.how_to_reg_outlined,
        ),
    ],
    DeviceStatus.active when device.approvalExpiredAt(now) => <Widget>[
      ObBadge(
        label: l10n.deviceStatusRanOut,
        tone: Tone.warning,
        icon: Icons.history,
      ),
    ],
    DeviceStatus.active => <Widget>[
      ObBadge(
        label: l10n.deviceStatusApproved,
        tone: Tone.success,
        icon: Icons.check_circle_outline,
      ),
    ],
    DeviceStatus.unknown => <Widget>[ObBadge(label: l10n.unknownValue)],
  };
}
