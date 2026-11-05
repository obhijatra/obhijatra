import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obhijatra_manager/l10n/app_localizations.dart';
import 'package:obhijatra_manager/src/data/people.dart';
import 'package:obhijatra_manager/src/data/phone_number.dart';
import 'package:obhijatra_manager/src/data/problem.dart';
import 'package:obhijatra_manager/src/state/navigation.dart';
import 'package:obhijatra_manager/src/state/people.dart';
import 'package:obhijatra_manager/src/state/providers.dart';
import 'package:obhijatra_manager/src/ui/page_scaffold.dart';
import 'package:obhijatra_manager/src/ui/people_words.dart';
import 'package:obhijatra_manager/src/ui/person_editor.dart';
import 'package:obhijatra_manager/src/ui/place_picker.dart';
import 'package:obhijatra_manager/widgets/empty_state.dart';
import 'package:obhijatra_manager/widgets/focus_ring.dart';
import 'package:obhijatra_manager/widgets/loading_block.dart';
import 'package:obhijatra_manager/widgets/ob_badge.dart';
import 'package:obhijatra_manager/widgets/ob_panel.dart';
import 'package:obhijatra_manager/widgets/problem_view.dart';
import 'package:obhijatra_ui/obhijatra_ui.dart';

/// Content width from which a person's details sit side by side in a row.
const double _wideRowFrom = 760;

/// People, for organisation admins: the list, the form to add a person and
/// each person's page.
class PeopleScreen extends ConsumerWidget {
  /// Creates the screen.
  const PeopleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(peopleViewProvider);
    return switch (view.mode) {
      PeopleMode.list => const _PeopleList(),
      PeopleMode.add => PersonEditor(
        key: const ValueKey<String>('add-person'),
        kind: view.kind!,
      ),
      PeopleMode.edit => PersonEditor(
        key: ValueKey<String>('person-${view.id}'),
        kind: view.kind!,
        id: view.id,
      ),
    };
  }
}

class _PeopleList extends ConsumerStatefulWidget {
  const _PeopleList();

  @override
  ConsumerState<_PeopleList> createState() => _PeopleListState();
}

class _PeopleListState extends ConsumerState<_PeopleList> {
  late final TextEditingController _search;
  Timer? _searchDelay;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(
      text: ref.read(peopleFilterProvider).search,
    );
  }

  @override
  void dispose() {
    _searchDelay?.cancel();
    _search.dispose();
    super.dispose();
  }

  /// Searches once the person pauses typing.
  void _onSearchTyped(String text) {
    setState(() {}); // Shows or hides the clear button.
    _searchDelay?.cancel();
    _searchDelay = Timer(
      const Duration(milliseconds: 400),
      () => ref.read(peopleFilterProvider.notifier).setSearch(text),
    );
  }

  void _searchNow() {
    _searchDelay?.cancel();
    ref.read(peopleFilterProvider.notifier).setSearch(_search.text);
  }

  void _clearSearch() {
    _search.clear();
    _searchNow();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final query = ref.watch(peopleFilterProvider);
    final listing = ref.watch(peopleListProvider(query));
    return PageScaffold(
      title: l10n.peopleTitle,
      subtitle: l10n.peopleSummary,
      trailing: Wrap(
        spacing: Spacing.space2,
        runSpacing: Spacing.space2,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          IconButton.outlined(
            tooltip: l10n.refresh,
            icon: const Icon(Icons.refresh),
            onPressed: () => ref
              ..invalidate(peopleListProvider)
              ..invalidate(placesProvider),
          ),
          FilledButton.icon(
            onPressed: () => ref
                .read(peopleViewProvider.notifier)
                .open(PeopleView.add(query.kind)),
            icon: const Icon(Icons.person_add_alt_1_outlined),
            label: Text(l10n.peopleAdd),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _KindTabs(kind: query.kind),
          const SizedBox(height: Spacing.space4),
          _Filters(
            query: query,
            search: _search,
            onSearchTyped: _onSearchTyped,
            onSearchSubmitted: _searchNow,
            onSearchCleared: _clearSearch,
          ),
          const SizedBox(height: Spacing.space3),
          Expanded(
            child: listing.when(
              loading: () => const LoadingBlock(),
              error: (error, _) {
                final problem = problemFrom(error);
                return ProblemView(
                  problem: problem,
                  onAction: () {
                    if (problem.action == ProblemAction.signInAgain) {
                      ref.read(sessionProvider.notifier).signOut();
                    } else {
                      ref.invalidate(peopleListProvider);
                    }
                  },
                );
              },
              data: (data) => data.page.items.isEmpty
                  ? _Empty(query: query)
                  : _List(listing: data),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Office staff" and "Field staff".
class _KindTabs extends ConsumerWidget {
  const _KindTabs({required this.kind});

  final PersonKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final palette = context.palette;

    Widget tab(PersonKind value) {
      final selected = value == kind;
      return Semantics(
        button: true,
        selected: selected,
        child: FocusRing(
          child: InkWell(
            borderRadius: Radii.smAll,
            onTap: () => ref.read(peopleFilterProvider.notifier).setKind(value),
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
                    value == PersonKind.staff
                        ? Icons.badge_outlined
                        : Icons.directions_walk,
                    size: Sizes.icon,
                    color: selected ? palette.action : palette.textMuted,
                  ),
                  const SizedBox(width: Spacing.space2),
                  Text(
                    kindName(l10n, value),
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
      label: l10n.peopleKindLabel,
      child: Container(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: palette.border)),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: <Widget>[tab(PersonKind.staff), tab(PersonKind.field)],
          ),
        ),
      ),
    );
  }
}

/// The status filter's choices: everyone, or one status.
enum _StatusChoice { everyone, active, deactivated, locked }

class _Filters extends ConsumerWidget {
  const _Filters({
    required this.query,
    required this.search,
    required this.onSearchTyped,
    required this.onSearchSubmitted,
    required this.onSearchCleared,
  });

  final PeopleQuery query;
  final TextEditingController search;
  final ValueChanged<String> onSearchTyped;
  final VoidCallback onSearchSubmitted;
  final VoidCallback onSearchCleared;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final notifier = ref.read(peopleFilterProvider.notifier);
    final places = ref.watch(placesProvider).asData?.value;
    final placePath = query.placePath;
    final placeName = placePath == null
        ? l10n.placeAll
        : (places?.nameAt(placePath) ?? '');
    final status = switch (query.status) {
      null => _StatusChoice.everyone,
      PeopleStatus.active => _StatusChoice.active,
      PeopleStatus.deactivated => _StatusChoice.deactivated,
      PeopleStatus.locked => _StatusChoice.locked,
    };

    Future<void> choosePlace() async {
      final current = placePath == null ? null : places?.byPath(placePath);
      final choice = await showPlacePicker(
        context,
        selectedId: current?.id,
        offerAll: true,
        // Deactivated people may still be at a closed place.
        includeClosed: true,
      );
      if (choice == null) return;
      notifier.setPlace(choice.place?.path);
    }

    return LayoutBuilder(
      builder: (context, box) {
        // One row when there is room; otherwise the search on its own line
        // and the choices beside each other, three or two at a time; on a
        // very narrow window, one under another.
        final width = box.maxWidth;
        final oneRow = width >= 960;
        final across = width >= 660 ? 3 : (width >= 400 ? 2 : 1);
        final fieldWidth = oneRow
            ? 200.0
            : ((width - (across - 1) * Spacing.space3) / across)
                  .floorToDouble();
        return Wrap(
          spacing: Spacing.space3,
          runSpacing: Spacing.space3,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            SizedBox(
              width: oneRow ? 300 : width,
              child: TextField(
                key: const ValueKey<String>('people-search'),
                controller: search,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  labelText: l10n.peopleSearch,
                  hintText: l10n.peopleSearchHint,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: search.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: l10n.peopleSearchClear,
                          icon: const Icon(Icons.close),
                          onPressed: onSearchCleared,
                        ),
                ),
                onChanged: onSearchTyped,
                onSubmitted: (_) => onSearchSubmitted(),
              ),
            ),
            DropdownMenu<_StatusChoice>(
              key: ValueKey<String>('status-${status.name}'),
              label: Text(l10n.peopleStatus),
              width: fieldWidth,
              requestFocusOnTap: false,
              initialSelection: status,
              onSelected: (value) => notifier.setStatus(switch (value) {
                null || _StatusChoice.everyone => null,
                _StatusChoice.active => PeopleStatus.active,
                _StatusChoice.deactivated => PeopleStatus.deactivated,
                _StatusChoice.locked => PeopleStatus.locked,
              }),
              dropdownMenuEntries: <DropdownMenuEntry<_StatusChoice>>[
                DropdownMenuEntry<_StatusChoice>(
                  value: _StatusChoice.everyone,
                  label: l10n.peopleStatusAll,
                ),
                DropdownMenuEntry<_StatusChoice>(
                  value: _StatusChoice.active,
                  label: l10n.statusActive,
                ),
                DropdownMenuEntry<_StatusChoice>(
                  value: _StatusChoice.deactivated,
                  label: l10n.statusDeactivated,
                ),
                DropdownMenuEntry<_StatusChoice>(
                  value: _StatusChoice.locked,
                  label: l10n.statusLocked,
                ),
              ],
            ),
            SizedBox(
              width: fieldWidth,
              child: PickerField(
                key: const ValueKey<String>('people-place'),
                label: l10n.personPlace,
                value: placeName,
                onTap: () => unawaited(choosePlace()),
              ),
            ),
            DropdownMenu<PeopleSort>(
              key: ValueKey<String>('sort-${query.sort.name}'),
              label: Text(l10n.peopleSort),
              width: fieldWidth,
              requestFocusOnTap: false,
              initialSelection: query.sort,
              onSelected: (value) {
                if (value != null) notifier.setSort(value);
              },
              dropdownMenuEntries: <DropdownMenuEntry<PeopleSort>>[
                DropdownMenuEntry<PeopleSort>(
                  value: PeopleSort.newest,
                  label: l10n.peopleSortNewest,
                ),
                DropdownMenuEntry<PeopleSort>(
                  value: PeopleSort.name,
                  label: l10n.peopleSortName,
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.query});

  final PeopleQuery query;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (query.status == PeopleStatus.locked &&
        query.search.isEmpty &&
        query.placePath == null) {
      return EmptyState(
        icon: Icons.lock_open_outlined,
        title: l10n.peopleNoLockedTitle,
        body: l10n.peopleNoLockedBody,
      );
    }
    if (query.isFiltered) {
      return EmptyState(
        icon: Icons.search_off,
        title: l10n.peopleNoMatchTitle,
        body: l10n.peopleNoMatchBody,
      );
    }
    return EmptyState(
      icon: Icons.people_outline,
      title: query.kind == PersonKind.staff
          ? l10n.peopleEmptyStaffTitle
          : l10n.peopleEmptyFieldTitle,
      body: l10n.peopleEmptyBody,
    );
  }
}

class _List extends ConsumerWidget {
  const _List({required this.listing});

  final PeopleListing listing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final places = ref.watch(placesProvider).asData?.value;
    final page = listing.page;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(
          child: ObPanel(
            child: ClipRRect(
              borderRadius: Radii.mdAll,
              child: LayoutBuilder(
                builder: (context, box) {
                  final wide = box.maxWidth >= _wideRowFrom;
                  return ListView.separated(
                    itemCount: page.items.length,
                    separatorBuilder: (context, index) =>
                        Divider(height: 1, color: palette.border),
                    itemBuilder: (context, index) {
                      final person = page.items[index];
                      return _PersonRow(
                        person: person,
                        place: places?.nameAt(person.locationPath) ?? '',
                        locked: listing.isLocked(person),
                        wide: wide,
                        onTap: () => ref
                            .read(peopleViewProvider.notifier)
                            .open(PeopleView.edit(person.kind, person.id)),
                      );
                    },
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

class _PersonRow extends StatelessWidget {
  const _PersonRow({
    required this.person,
    required this.place,
    required this.locked,
    required this.wide,
    required this.onTap,
  });

  final Person person;
  final String place;
  final bool locked;
  final bool wide;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final palette = context.palette;
    final muted = text.bodySmall!.copyWith(color: palette.textMuted);

    final who = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          person.displayName,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: text.titleSmall,
        ),
        Text(
          <String>[
            roleName(l10n, person.role),
            if (place.isNotEmpty) place,
          ].join(' · '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: muted,
        ),
      ],
    );
    final contact = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (person.email.isNotEmpty)
          Wrap(
            spacing: Spacing.space2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Text(person.email, style: text.bodySmall),
              if (person.verified)
                ObBadge(
                  label: l10n.emailConfirmed,
                  tone: Tone.info,
                  icon: Icons.verified_outlined,
                ),
            ],
          ),
        if (person.phone.isNotEmpty)
          Text(displayPhone(person.phone), style: text.bodySmall),
      ],
    );
    final chips = PersonStatusChips(person: person, locked: locked);

    return Semantics(
      button: true,
      child: FocusRing(
        borderRadius: BorderRadius.zero,
        child: Material(
          color: palette.surface,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 64),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.space4,
                  vertical: Spacing.space3,
                ),
                child: wide
                    ? Row(
                        children: <Widget>[
                          Expanded(flex: 32, child: who),
                          const SizedBox(width: Spacing.space3),
                          Expanded(flex: 36, child: contact),
                          const SizedBox(width: Spacing.space3),
                          Expanded(flex: 30, child: chips),
                          Icon(Icons.chevron_right, color: palette.textMuted),
                        ],
                      )
                    : Row(
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                who,
                                const SizedBox(height: Spacing.space1),
                                contact,
                                const SizedBox(height: Spacing.space2),
                                chips,
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right, color: palette.textMuted),
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

  final PeoplePage page;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final palette = context.palette;
    final text = Theme.of(context).textTheme;
    final notifier = ref.read(peopleFilterProvider.notifier);
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
