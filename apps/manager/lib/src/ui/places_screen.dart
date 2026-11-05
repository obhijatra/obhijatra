import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obhijatra_manager/l10n/app_localizations.dart';
import 'package:obhijatra_manager/src/data/people.dart';
import 'package:obhijatra_manager/src/data/problem.dart';
import 'package:obhijatra_manager/src/state/navigation.dart';
import 'package:obhijatra_manager/src/state/people.dart';
import 'package:obhijatra_manager/src/state/places.dart';
import 'package:obhijatra_manager/src/state/providers.dart';
import 'package:obhijatra_manager/src/ui/leave_guard.dart';
import 'package:obhijatra_manager/src/ui/page_scaffold.dart';
import 'package:obhijatra_manager/src/ui/place_dialogs.dart';
import 'package:obhijatra_manager/src/ui/places_import_screen.dart';
import 'package:obhijatra_manager/widgets/empty_state.dart';
import 'package:obhijatra_manager/widgets/loading_block.dart';
import 'package:obhijatra_manager/widgets/ob_badge.dart';
import 'package:obhijatra_manager/widgets/ob_panel.dart';
import 'package:obhijatra_manager/widgets/problem_view.dart';
import 'package:obhijatra_ui/obhijatra_ui.dart';

/// Content width from which the tree indents by a full step per level.
const double _wideTreeFrom = 640;

/// Places, for organisation admins: the organisation tree and the
/// spreadsheet import.
class PlacesScreen extends ConsumerWidget {
  /// Creates the screen.
  const PlacesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      switch (ref.watch(placesPageProvider)) {
        PlacesPage.tree => const _PlacesTree(),
        PlacesPage.import => const PlacesImportScreen(),
      };
}

/// One line of the tree as shown.
class _Row {
  const _Row(this.place, this.depth, this.inside, {this.trail = ''});

  final Place place;
  final int depth;

  /// The places shown inside it (open, or every one with closed places
  /// shown).
  final int inside;

  /// While searching: the names of the places above it.
  final String trail;
}

class _PlacesTree extends ConsumerStatefulWidget {
  const _PlacesTree();

  @override
  ConsumerState<_PlacesTree> createState() => _PlacesTreeState();
}

class _PlacesTreeState extends ConsumerState<_PlacesTree> {
  late final TextEditingController _search;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(
      text: ref.read(placeTreeViewProvider).search,
    );
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  PlaceTreeViewNotifier get _view => ref.read(placeTreeViewProvider.notifier);

  void _clearSearch() {
    _search.clear();
    _view.setSearch('');
  }

  // ------------------------------------------------------------ actions

  void _say(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  Future<void> _add(Place parent) async {
    final l10n = AppLocalizations.of(context);
    final added = await showAddPlaceDialog(context, parent: parent);
    if (added == null || !mounted) return;
    ref.invalidate(placesProvider);
    // Open every place above the new one, so it can be seen.
    final above = added.path
        .split('/')
        .where((id) => id.isNotEmpty && id != added.id);
    _view.open(above);
    _say(l10n.placeAdded(added.displayName));
  }

  Future<void> _rename(Place place) async {
    final l10n = AppLocalizations.of(context);
    final saved = await showRenamePlaceDialog(context, place: place);
    if (saved == null || !mounted) return;
    ref.invalidate(placesProvider);
    _say(l10n.personSaved);
  }

  Future<void> _setClosed(Place place, {required bool close}) async {
    final l10n = AppLocalizations.of(context);
    final outcome = await showPlaceStatusDialog(
      context,
      place: place,
      close: close,
    );
    if (outcome == null || !mounted) return;
    switch (outcome) {
      case PlaceStatusOutcome.done:
        ref.invalidate(placesProvider);
        _say(
          close
              ? l10n.placeClosedDone(place.displayName)
              : l10n.placeReopenedDone(place.displayName),
        );
      case PlaceStatusOutcome.seePeople:
        // Only active people stop a place closing; the places inside a
        // place that may close are closed, so nobody active is there.
        ref.read(peopleFilterProvider.notifier)
          ..setPlace(place.path)
          ..setStatus(PeopleStatus.active)
          ..setSearch('');
        await goToSection(context, ref, Section.people);
    }
  }

  Future<void> _delete(Place place) async {
    final l10n = AppLocalizations.of(context);
    final outcome = await showDeletePlaceDialog(context, place: place);
    if (outcome == null || !mounted) return;
    switch (outcome) {
      case PlaceDeleteOutcome.deleted:
        ref.invalidate(placesProvider);
        _say(l10n.placeDeletedDone(place.displayName));
      case PlaceDeleteOutcome.closeInstead:
        await _setClosed(place, close: true);
    }
  }

  void _onAction(_PlaceAction action, Place place) {
    unawaited(switch (action) {
      _PlaceAction.addInside => _add(place),
      _PlaceAction.rename => _rename(place),
      _PlaceAction.close => _setClosed(place, close: true),
      _PlaceAction.reopen => _setClosed(place, close: false),
      _PlaceAction.delete => _delete(place),
    });
  }

  // ------------------------------------------------------------- layout

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final places = ref.watch(placesProvider);
    final root = places.asData?.value.root;
    return PageScaffold(
      title: l10n.placesTitle,
      subtitle: l10n.placesSummary,
      trailing: Wrap(
        spacing: Spacing.space2,
        runSpacing: Spacing.space2,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          IconButton.outlined(
            tooltip: l10n.refresh,
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(placesProvider),
          ),
          if (root != null)
            FilledButton.icon(
              key: const ValueKey<String>('places-add'),
              onPressed: () => unawaited(_add(root)),
              icon: const Icon(Icons.add_location_alt_outlined),
              label: Text(l10n.placesAdd),
            ),
        ],
      ),
      child: places.when(
        loading: () => const LoadingBlock(),
        error: (error, _) {
          final problem = problemFrom(error);
          return ProblemView(
            problem: problem,
            onAction: () {
              if (problem.action == ProblemAction.signInAgain) {
                ref.read(sessionProvider.notifier).signOut();
              } else {
                ref.invalidate(placesProvider);
              }
            },
          );
        },
        data: (directory) => directory.isEmpty
            ? EmptyState(
                icon: Icons.account_tree_outlined,
                title: l10n.placesNoneTitle,
                body: l10n.placeNone,
              )
            : _body(context, directory),
      ),
    );
  }

  /// The rows to show, in order: the tree as opened, or the places that
  /// match the search with the names above them.
  List<_Row> _rows(PlaceDirectory directory, PlaceTreeView view) {
    bool shown(Place place) => view.showClosed || !place.closed;
    int insideCount(Place place) =>
        directory.childrenOf(place.id).where(shown).length;
    final search = view.search.toLowerCase();
    if (search.isNotEmpty) {
      return <_Row>[
        for (final place in directory.ordered)
          if (shown(place) &&
              (place.displayName.toLowerCase().contains(search) ||
                  place.code.toLowerCase().contains(search)))
            _Row(
              place,
              0,
              insideCount(place),
              trail: (directory.trail(place)..removeLast()).join(' › '),
            ),
      ];
    }
    final rows = <_Row>[];
    void visit(Place place, int depth) {
      final inside = insideCount(place);
      rows.add(_Row(place, depth, inside));
      if (inside == 0 || !view.isOpen(place, depth)) return;
      for (final child in directory.childrenOf(place.id)) {
        if (shown(child)) visit(child, depth + 1);
      }
    }

    for (final top in directory.tops) {
      if (shown(top)) visit(top, 0);
    }
    return rows;
  }

  Widget _body(BuildContext context, PlaceDirectory directory) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final palette = context.palette;
    final view = ref.watch(placeTreeViewProvider);
    final rows = _rows(directory, view);
    final searching = view.search.isNotEmpty;
    final closedCount = directory.ordered.where((p) => p.closed).length;
    final root = directory.root;
    final onlyRoot = root != null && directory.length == 1;
    final organisation = root?.displayName ?? '';
    final status = searching
        ? l10n.placesMatches(rows.length)
        : (!view.showClosed && closedCount > 0
              ? l10n.placesClosedHidden(closedCount)
              : '');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        LayoutBuilder(
          builder: (context, box) => Wrap(
            spacing: Spacing.space3,
            runSpacing: Spacing.space3,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              SizedBox(
                width: math.min(360, box.maxWidth),
                child: TextField(
                  key: const ValueKey<String>('places-search'),
                  controller: _search,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    labelText: l10n.placeSearch,
                    hintText: l10n.placesSearchHint,
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: l10n.peopleSearchClear,
                            icon: const Icon(Icons.close),
                            onPressed: _clearSearch,
                          ),
                  ),
                  onChanged: _view.setSearch,
                ),
              ),
              _ShowClosedSwitch(
                value: view.showClosed,
                onChanged: (show) => _view.setShowClosed(show: show),
              ),
              OutlinedButton.icon(
                key: const ValueKey<String>('places-import'),
                onPressed: root == null
                    ? null
                    : () => ref
                          .read(placesPageProvider.notifier)
                          .open(PlacesPage.import),
                icon: const Icon(Icons.upload_file_outlined),
                label: Text(l10n.placesImport),
              ),
            ],
          ),
        ),
        const SizedBox(height: Spacing.space2),
        Semantics(
          liveRegion: true,
          child: Text(
            status,
            style: text.bodySmall!.copyWith(color: palette.textMuted),
          ),
        ),
        const SizedBox(height: Spacing.space2),
        Expanded(
          child: rows.isEmpty
              ? EmptyState(
                  icon: Icons.search_off,
                  title: l10n.placeNoMatch,
                  body:
                      !view.showClosed &&
                          directory.ordered.any(
                            (p) =>
                                p.closed &&
                                (p.displayName.toLowerCase().contains(
                                      view.search.toLowerCase(),
                                    ) ||
                                    p.code.toLowerCase().contains(
                                      view.search.toLowerCase(),
                                    )),
                          )
                      ? l10n.placesNoMatchClosedBody
                      : l10n.placesNoMatchBody,
                )
              : Padding(
                  padding: const EdgeInsets.only(bottom: Spacing.space4),
                  child: ObPanel(
                    child: ClipRRect(
                      borderRadius: Radii.mdAll,
                      child: LayoutBuilder(
                        builder: (context, box) {
                          final step = box.maxWidth >= _wideTreeFrom
                              ? Spacing.space6
                              : Spacing.space3;
                          // Deep trees on a narrow window keep room for
                          // the names.
                          final maxIndent = box.maxWidth * 0.3;
                          return ListView.builder(
                            key: const ValueKey<String>('places-tree'),
                            itemCount: rows.length + (onlyRoot ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == rows.length) {
                                return _FirstPlacesHint(
                                  organisation: organisation,
                                );
                              }
                              final row = rows[index];
                              return _PlaceRow(
                                key: ValueKey<String>('place-${row.place.id}'),
                                row: row,
                                indent: math.min(row.depth * step, maxIndent),
                                searching: searching,
                                open: view.isOpen(row.place, row.depth),
                                canDelete:
                                    !row.place.isRoot &&
                                    directory.childrenOf(row.place.id).isEmpty,
                                onToggle: () =>
                                    _view.toggle(row.place, row.depth),
                                onAction: (action) =>
                                    _onAction(action, row.place),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

/// "Show closed places", as a switch with its words beside it; the whole
/// line can be pressed.
class _ShowClosedSwitch extends StatelessWidget {
  const _ShowClosedSwitch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return MergeSemantics(
      child: InkWell(
        borderRadius: Radii.smAll,
        onTap: () => onChanged(!value),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: Sizes.touch),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.space2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Switch(
                  key: const ValueKey<String>('places-show-closed'),
                  value: value,
                  onChanged: onChanged,
                ),
                const SizedBox(width: Spacing.space2),
                Flexible(
                  child: Text(
                    l10n.placesShowClosed,
                    style: Theme.of(context).textTheme.labelLarge,
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

/// What can be done to one place.
enum _PlaceAction { addInside, rename, close, reopen, delete }

class _PlaceRow extends StatelessWidget {
  const _PlaceRow({
    required this.row,
    required this.indent,
    required this.searching,
    required this.open,
    required this.canDelete,
    required this.onToggle,
    required this.onAction,
    super.key,
  });

  final _Row row;
  final double indent;
  final bool searching;
  final bool open;

  /// Whether deleting may work: nothing is inside it and it is not the
  /// organisation (the server decides about people and records).
  final bool canDelete;
  final VoidCallback onToggle;
  final ValueChanged<_PlaceAction> onAction;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final palette = context.palette;
    final place = row.place;
    final name = place.displayName;
    final hasInside = !searching && row.inside > 0;
    final muted = text.bodySmall!.copyWith(color: palette.textMuted);
    final details = <String>[
      if (place.isRoot) l10n.placeRootNote,
      if (searching && row.trail.isNotEmpty) row.trail,
      if (row.inside > 0) l10n.placeInsideCount(row.inside),
    ];

    return Material(
      color: palette.surface,
      child: InkWell(
        // The open and shut button says the same to screen readers.
        excludeFromSemantics: true,
        onTap: hasInside ? onToggle : null,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: palette.border)),
          ),
          padding: EdgeInsetsDirectional.only(
            start: Spacing.space1 + indent,
            end: Spacing.space1,
            top: Spacing.space1,
            bottom: Spacing.space1,
          ),
          child: Row(
            children: <Widget>[
              if (hasInside)
                Semantics(
                  expanded: open,
                  child: IconButton(
                    key: ValueKey<String>('place-toggle-${place.id}'),
                    tooltip: open
                        ? l10n.placeShutInside(name)
                        : l10n.placeOpenInside(name),
                    onPressed: onToggle,
                    icon: Icon(
                      open ? Icons.expand_more : Icons.chevron_right,
                      color: palette.textMuted,
                    ),
                  ),
                )
              else
                const SizedBox(width: Sizes.touch),
              ExcludeSemantics(
                child: Icon(
                  place.isRoot
                      ? Icons.apartment_outlined
                      : (place.closed
                            ? Icons.location_off_outlined
                            : Icons.location_on_outlined),
                  size: Sizes.icon,
                  color: place.closed ? palette.textMuted : palette.action,
                ),
              ),
              const SizedBox(width: Spacing.space3),
              Expanded(
                child: MergeSemantics(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: Spacing.space2,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Wrap(
                          spacing: Spacing.space2,
                          runSpacing: Spacing.space1,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: <Widget>[
                            Text(
                              name,
                              style: text.titleSmall!.copyWith(
                                color: place.closed
                                    ? palette.textMuted
                                    : palette.text,
                              ),
                            ),
                            if (place.code.isNotEmpty)
                              Text(
                                l10n.placeCodeShown(place.code),
                                style: muted,
                              ),
                            if (place.closed)
                              ObBadge(
                                label: l10n.placeClosed,
                                icon: Icons.block,
                              ),
                          ],
                        ),
                        if (details.isNotEmpty)
                          Text(details.join(' · '), style: muted),
                      ],
                    ),
                  ),
                ),
              ),
              _ActionsButton(
                place: place,
                canDelete: canDelete,
                onAction: onAction,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionsButton extends StatelessWidget {
  const _ActionsButton({
    required this.place,
    required this.canDelete,
    required this.onAction,
  });

  final Place place;
  final bool canDelete;
  final ValueChanged<_PlaceAction> onAction;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = context.palette;
    PopupMenuItem<_PlaceAction> item(
      _PlaceAction action,
      IconData icon,
      String label, {
      bool danger = false,
    }) => PopupMenuItem<_PlaceAction>(
      value: action,
      child: Row(
        children: <Widget>[
          Icon(
            icon,
            size: Sizes.icon,
            color: danger ? palette.danger : palette.textMuted,
          ),
          const SizedBox(width: Spacing.space3),
          Flexible(child: Text(label)),
        ],
      ),
    );

    return PopupMenuButton<_PlaceAction>(
      key: ValueKey<String>('place-actions-${place.id}'),
      tooltip: l10n.placeActions(place.displayName),
      icon: Icon(Icons.more_vert, color: palette.textMuted),
      position: PopupMenuPosition.under,
      onSelected: onAction,
      itemBuilder: (context) => <PopupMenuEntry<_PlaceAction>>[
        if (!place.closed)
          item(
            _PlaceAction.addInside,
            Icons.add_location_alt_outlined,
            l10n.placeAddInside,
          ),
        item(_PlaceAction.rename, Icons.edit_outlined, l10n.placeRename),
        if (!place.closed && !place.isRoot)
          item(
            _PlaceAction.close,
            Icons.location_off_outlined,
            l10n.placeCloseAction,
          ),
        if (place.closed)
          item(
            _PlaceAction.reopen,
            Icons.location_on_outlined,
            l10n.placeReopenAction,
          ),
        if (canDelete)
          item(
            _PlaceAction.delete,
            Icons.delete_outline,
            l10n.placeDeleteAction,
            danger: true,
          ),
      ],
    );
  }
}

/// Under the organisation, while nothing is inside it yet.
class _FirstPlacesHint extends StatelessWidget {
  const _FirstPlacesHint({required this.organisation});

  final String organisation;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return EmptyState(
      icon: Icons.add_location_alt_outlined,
      title: l10n.placesEmptyTitle,
      body: l10n.placesEmptyBody(organisation),
    );
  }
}
