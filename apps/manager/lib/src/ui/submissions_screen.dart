import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obhijatra_manager/l10n/app_localizations.dart';
import 'package:obhijatra_manager/src/data/models.dart';
import 'package:obhijatra_manager/src/data/problem.dart';
import 'package:obhijatra_manager/src/state/providers.dart';
import 'package:obhijatra_manager/src/ui/download_dialog.dart';
import 'package:obhijatra_manager/src/ui/format.dart';
import 'package:obhijatra_manager/src/ui/page_scaffold.dart';
import 'package:obhijatra_manager/src/ui/shell.dart';
import 'package:obhijatra_manager/src/ui/submission_panel.dart';
import 'package:obhijatra_manager/widgets/empty_state.dart';
import 'package:obhijatra_manager/widgets/focus_ring.dart';
import 'package:obhijatra_manager/widgets/loading_block.dart';
import 'package:obhijatra_manager/widgets/ob_badge.dart';
import 'package:obhijatra_manager/widgets/ob_panel.dart';
import 'package:obhijatra_manager/widgets/problem_view.dart';
import 'package:obhijatra_manager/widgets/review_badge.dart';
import 'package:obhijatra_ui/obhijatra_ui.dart';

/// Width of the details panel.
const double _panelWidth = 380;

/// Content width from which the panel sits beside the table; below it the
/// panel slides over the table instead.
const double _sideBySideFrom = 1000;

/// Submissions: filters, review tabs, table, paging and the details panel.
class SubmissionsScreen extends ConsumerWidget {
  /// Creates the screen.
  const SubmissionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final filter = ref.watch(submissionFilterProvider);
    final query = filter.query;
    final page = ref.watch(submissionsProvider(query));
    final total = page.asData?.value.totalItems;
    // Only org admins and M&E staff may download; the server decides.
    final canDownload = ref.watch(
      sessionProvider.select((user) => user?.canDownloadSubmissions ?? false),
    );
    return PageScaffold(
      title: l10n.subsTitle,
      subtitle: total == null ? null : l10n.subsCount(total),
      trailing: Wrap(
        spacing: Spacing.space2,
        runSpacing: Spacing.space2,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          if (canDownload)
            FilledButton.tonalIcon(
              key: const ValueKey<String>('subs-download'),
              onPressed: () =>
                  unawaited(showDownloadDialog(context, query: query)),
              icon: const Icon(Icons.download_outlined),
              label: Text(l10n.actionDownload),
            ),
          IconButton.outlined(
            tooltip: l10n.refresh,
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(submissionFilterProvider.notifier).refreshDates();
              ref
                ..invalidate(submissionsProvider)
                ..invalidate(submissionCountsProvider);
            },
          ),
        ],
      ),
      child: _Body(page: page),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.page});

  final AsyncValue<SubmissionPage> page;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedId = ref.watch(selectedSubmissionProvider);
    final user = ref.watch(sessionProvider);
    final locations =
        ref.watch(locationNamesProvider).asData?.value ??
        const <String, String>{};
    final row = selectedId == null
        ? null
        : page.asData?.value.items.where((r) => r.id == selectedId).firstOrNull;

    void close() => ref.read(selectedSubmissionProvider.notifier).select(null);

    return LayoutBuilder(
      builder: (context, box) {
        final sideBySide = box.maxWidth >= _sideBySideFrom;
        final table = _TableArea(page: page, locations: locations);
        final panel = row == null
            ? null
            : SubmissionPanel(
                key: ValueKey<String>(row.id),
                row: row,
                locationName: locations[row.locationPath] ?? '',
                canReview: user?.canReview ?? false,
                onClose: close,
              );
        return CallbackShortcuts(
          bindings: <ShortcutActivator, VoidCallback>{
            const SingleActivator(LogicalKeyboardKey.escape): close,
          },
          // Keeps Escape working after a mouse click, without adding a stop
          // to the Tab order.
          child: Focus(
            autofocus: true,
            skipTraversal: true,
            child: sideBySide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(child: table),
                      if (panel != null) ...<Widget>[
                        const SizedBox(width: Spacing.space5),
                        SizedBox(
                          width: _panelWidth,
                          child: Padding(
                            padding: const EdgeInsets.only(
                              bottom: Spacing.space6,
                            ),
                            child: panel,
                          ),
                        ),
                      ],
                    ],
                  )
                : Stack(
                    children: <Widget>[
                      Positioned.fill(child: table),
                      if (panel != null)
                        Positioned(
                          top: 0,
                          bottom: Spacing.space6,
                          right: 0,
                          width: box.maxWidth < _panelWidth + Spacing.space4
                              ? box.maxWidth
                              : _panelWidth,
                          child: panel,
                        ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

class _TableArea extends ConsumerWidget {
  const _TableArea({required this.page, required this.locations});

  final AsyncValue<SubmissionPage> page;
  final Map<String, String> locations;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(submissionFilterProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const _Filters(),
        const SizedBox(height: Spacing.space3),
        _StateTabs(query: filter.query),
        const SizedBox(height: Spacing.space3),
        Expanded(
          child: page.when(
            loading: () => const LoadingBlock(),
            error: (error, _) {
              final problem = problemFrom(error);
              return ProblemView(
                problem: problem,
                onAction: () {
                  if (problem.action == ProblemAction.signInAgain) {
                    ref.read(sessionProvider.notifier).signOut();
                  } else {
                    retryAll(ref);
                  }
                },
              );
            },
            data: (data) => data.items.isEmpty
                ? EmptyState(
                    icon: Icons.inbox_outlined,
                    title: AppLocalizations.of(context).subsEmptyTitle,
                    body: AppLocalizations.of(context).subsEmptyBody,
                  )
                : _Table(page: data, locations: locations),
          ),
        ),
      ],
    );
  }
}

class _Filters extends ConsumerWidget {
  const _Filters();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final filter = ref.watch(submissionFilterProvider);
    final forms =
        ref.watch(formsProvider).asData?.value ?? const <FormSummary>[];
    final notifier = ref.read(submissionFilterProvider.notifier);
    final query = filter.query;

    final customLabel =
        filter.preset == DatePreset.custom &&
            query.from != null &&
            query.to != null
        ? l10n.filterRange(
            Format.shortDay(context, query.from!),
            Format.shortDay(
              context,
              query.to!.subtract(const Duration(days: 1)),
            ),
          )
        : l10n.filterChoose;

    Future<void> chooseDates() async {
      final now = DateTime.now();
      final range = await showDateRangePicker(
        context: context,
        firstDate: DateTime(now.year - 10),
        lastDate: now,
        initialDateRange:
            filter.preset == DatePreset.custom &&
                query.from != null &&
                query.to != null
            ? DateTimeRange(
                start: query.from!,
                end: query.to!.subtract(const Duration(days: 1)),
              )
            : null,
      );
      if (range != null) notifier.setRange(range.start, range.end);
    }

    return Wrap(
      spacing: Spacing.space3,
      runSpacing: Spacing.space3,
      children: <Widget>[
        DropdownMenu<String>(
          key: ValueKey<String>('form-${query.formRecordId}-${forms.length}'),
          label: Text(l10n.filterForm),
          width: 240,
          requestFocusOnTap: false,
          initialSelection: query.formRecordId ?? '',
          onSelected: (value) =>
              notifier.setForm(value == null || value.isEmpty ? null : value),
          dropdownMenuEntries: <DropdownMenuEntry<String>>[
            DropdownMenuEntry<String>(value: '', label: l10n.filterAllForms),
            for (final form in forms)
              DropdownMenuEntry<String>(
                value: form.id,
                label: form.displayTitle,
              ),
          ],
        ),
        DropdownMenu<DatePreset>(
          key: ValueKey<String>(
            'dates-${filter.preset.name}-${query.from}-${query.to}',
          ),
          label: Text(l10n.filterDates),
          width: 240,
          requestFocusOnTap: false,
          initialSelection: filter.preset,
          onSelected: (value) {
            if (value == null) return;
            if (value == DatePreset.custom) {
              unawaited(chooseDates());
            } else {
              notifier.setPreset(value);
            }
          },
          dropdownMenuEntries: <DropdownMenuEntry<DatePreset>>[
            DropdownMenuEntry<DatePreset>(
              value: DatePreset.last7,
              label: l10n.filterLast7,
            ),
            DropdownMenuEntry<DatePreset>(
              value: DatePreset.last30,
              label: l10n.filterLast30,
            ),
            DropdownMenuEntry<DatePreset>(
              value: DatePreset.allTime,
              label: l10n.filterAllTime,
            ),
            DropdownMenuEntry<DatePreset>(
              value: DatePreset.custom,
              label: customLabel,
            ),
          ],
        ),
      ],
    );
  }
}

class _StateTabs extends ConsumerWidget {
  const _StateTabs({required this.query});

  final SubmissionQuery query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final palette = context.palette;
    final counts = ref
        .watch(submissionCountsProvider(query.forCounts))
        .asData
        ?.value;
    final notifier = ref.read(submissionFilterProvider.notifier);
    final all = counts?.values.fold<int>(0, (a, b) => a + b);

    Widget tab(String label, ReviewState? state, int? count) {
      final selected = query.state == state;
      return Semantics(
        button: true,
        selected: selected,
        child: FocusRing(
          child: InkWell(
            borderRadius: Radii.smAll,
            onTap: () => notifier.setState(state),
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
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelLarge!.copyWith(
                      color: selected ? palette.text : palette.textMuted,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                  if (count != null) ...<Widget>[
                    const SizedBox(width: Spacing.space2),
                    ObBadge(label: Format.number(context, count)),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Semantics(
      container: true,
      label: l10n.filterReviewState,
      child: Container(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: palette.border)),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: <Widget>[
              tab(l10n.reviewAll, null, all),
              for (final state in ReviewState.values)
                tab(reviewStateWord(l10n, state), state, counts?[state]),
            ],
          ),
        ),
      ),
    );
  }
}

class _Table extends ConsumerWidget {
  const _Table({required this.page, required this.locations});

  final SubmissionPage page;
  final Map<String, String> locations;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final selectedId = ref.watch(selectedSubmissionProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(
          child: ObPanel(
            child: ClipRRect(
              borderRadius: Radii.mdAll,
              child: LayoutBuilder(
                builder: (context, box) {
                  final narrow = box.maxWidth < 600;
                  return Column(
                    children: <Widget>[
                      _HeaderRow(narrow: narrow),
                      Divider(height: 1, color: palette.border),
                      Expanded(
                        child: ListView.separated(
                          itemCount: page.items.length,
                          separatorBuilder: (context, index) =>
                              Divider(height: 1, color: palette.border),
                          itemBuilder: (context, index) {
                            final row = page.items[index];
                            return _DataRow(
                              row: row,
                              narrow: narrow,
                              selected: row.id == selectedId,
                              location: locations[row.locationPath] ?? '',
                              onTap: () => ref
                                  .read(selectedSubmissionProvider.notifier)
                                  .select(row.id),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: Spacing.space3),
        _PagingBar(page: page),
        const SizedBox(height: Spacing.space4),
      ],
    );
  }
}

const List<int> _flex = <int>[20, 26, 20, 20, 22];

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.narrow});

  final bool narrow;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = context.palette;
    final style = Theme.of(context).textTheme.labelLarge!
        .copyWith(color: palette.textMuted);
    Widget cell(int flex, String label) => Expanded(
      flex: flex,
      child: Text(label, style: style),
    );
    return Semantics(
      container: true,
      child: Container(
        color: palette.bgSubtle,
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.space3,
          vertical: Spacing.space3,
        ),
        child: Row(
          children: <Widget>[
            cell(_flex[0], l10n.colDate),
            cell(_flex[1], l10n.colForm),
            if (!narrow) cell(_flex[2], l10n.colCollector),
            if (!narrow) cell(_flex[3], l10n.colLocation),
            cell(_flex[4], l10n.colReview),
          ],
        ),
      ),
    );
  }
}

class _DataRow extends StatelessWidget {
  const _DataRow({
    required this.row,
    required this.narrow,
    required this.selected,
    required this.location,
    required this.onTap,
  });

  final SubmissionRow row;
  final bool narrow;
  final bool selected;
  final String location;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = context.palette;
    final text = Theme.of(context).textTheme;
    Widget cell(int flex, String value, {bool strong = false}) => Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(end: Spacing.space2),
        child: Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: text.bodySmall!.copyWith(
            fontWeight: strong || selected ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ),
    );
    return Semantics(
      button: true,
      selected: selected,
      child: FocusRing(
        borderRadius: BorderRadius.zero,
        child: Material(
          color: selected ? palette.actionSubtle : palette.surface,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 52),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.space3,
                  vertical: 10,
                ),
                child: Row(
                  children: <Widget>[
                    cell(_flex[0], Format.when(context, row.receivedAt)),
                    cell(
                      _flex[1],
                      row.formTitle.isEmpty ? l10n.unknownValue : row.formTitle,
                      strong: true,
                    ),
                    if (!narrow)
                      cell(
                        _flex[2],
                        row.collector.isEmpty
                            ? l10n.unknownValue
                            : row.collector,
                      ),
                    if (!narrow)
                      cell(
                        _flex[3],
                        location.isEmpty ? l10n.unknownValue : location,
                      ),
                    Expanded(
                      flex: _flex[4],
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: ReviewBadge(row.state),
                      ),
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

class _PagingBar extends ConsumerWidget {
  const _PagingBar({required this.page});

  final SubmissionPage page;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final palette = context.palette;
    final text = Theme.of(context).textTheme;
    final notifier = ref.read(submissionFilterProvider.notifier);
    final first = (page.page - 1) * page.perPage + 1;
    final last = first + page.items.length - 1;
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: Spacing.space4,
      runSpacing: Spacing.space2,
      children: <Widget>[
        Text(
          l10n.pagingRange(first, last, page.totalItems),
          style: text.bodySmall!.copyWith(color: palette.textMuted),
        ),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: Spacing.space2,
          children: <Widget>[
            OutlinedButton.icon(
              onPressed: page.page > 1
                  ? () => notifier.setPage(page.page - 1)
                  : null,
              icon: const Icon(Icons.chevron_left),
              label: Text(l10n.pagingPrevious),
            ),
            Text(
              l10n.pagingPage(page.page, page.totalPages),
              style: text.labelLarge,
            ),
            OutlinedButton.icon(
              onPressed: page.page < page.totalPages
                  ? () => notifier.setPage(page.page + 1)
                  : null,
              iconAlignment: IconAlignment.end,
              icon: const Icon(Icons.chevron_right),
              label: Text(l10n.pagingNext),
            ),
          ],
        ),
      ],
    );
  }
}
