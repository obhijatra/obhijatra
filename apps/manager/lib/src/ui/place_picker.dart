import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obhijatra_manager/l10n/app_localizations.dart';
import 'package:obhijatra_manager/src/data/people.dart';
import 'package:obhijatra_manager/src/data/problem.dart';
import 'package:obhijatra_manager/src/state/people.dart';
import 'package:obhijatra_manager/widgets/loading_block.dart';
import 'package:obhijatra_manager/widgets/ob_badge.dart';
import 'package:obhijatra_manager/widgets/problem_view.dart';
import 'package:obhijatra_ui/obhijatra_ui.dart';

/// What the place chooser answers: a place, or "all places" when that
/// choice was offered.
@immutable
class PlaceChoice {
  /// A place.
  const PlaceChoice(Place this.place);

  /// Every place.
  const PlaceChoice.all() : place = null;

  /// The place chosen, or null for every place.
  final Place? place;
}

/// Asks for a place in the organisation's tree. [selectedId] is ticked;
/// [offerAll] adds "All places" first. Closed places cannot be chosen for
/// anything new, so they are left out unless [includeClosed] (for finding
/// what is already there), when they are marked "Closed". Returns null
/// when the person closes the dialog.
Future<PlaceChoice?> showPlacePicker(
  BuildContext context, {
  String? selectedId,
  bool offerAll = false,
  bool includeClosed = false,
}) => showDialog<PlaceChoice>(
  context: context,
  builder: (context) => _PlacePickerDialog(
    selectedId: selectedId,
    offerAll: offerAll,
    includeClosed: includeClosed,
  ),
);

class _PlacePickerDialog extends ConsumerStatefulWidget {
  const _PlacePickerDialog({
    required this.selectedId,
    required this.offerAll,
    required this.includeClosed,
  });

  final String? selectedId;
  final bool offerAll;
  final bool includeClosed;

  @override
  ConsumerState<_PlacePickerDialog> createState() => _PlacePickerDialogState();
}

class _PlacePickerDialogState extends ConsumerState<_PlacePickerDialog> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final places = ref.watch(placesProvider);
    final height = MediaQuery.sizeOf(context).height;
    return AlertDialog(
      title: Text(l10n.personPlaceChoose),
      contentPadding: const EdgeInsets.fromLTRB(
        Spacing.space6,
        Spacing.space4,
        Spacing.space6,
        0,
      ),
      content: SizedBox(
        width: 480,
        height: (height * 0.6).clamp(240, 560),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            TextField(
              key: const ValueKey<String>('place-search'),
              controller: _search,
              autofocus: true,
              decoration: InputDecoration(
                labelText: l10n.placeSearch,
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: (value) =>
                  setState(() => _query = value.trim().toLowerCase()),
            ),
            const SizedBox(height: Spacing.space3),
            Expanded(
              child: places.when(
                loading: () => const LoadingBlock(compact: true),
                error: (error, _) => ProblemView(
                  compact: true,
                  problem: problemFrom(error),
                  onAction: () => ref.invalidate(placesProvider),
                ),
                data: (directory) => _list(context, directory),
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
      ],
    );
  }

  Widget _list(BuildContext context, PlaceDirectory directory) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final palette = context.palette;
    if (directory.isEmpty) {
      return Center(
        child: Text(
          l10n.placeNone,
          textAlign: TextAlign.center,
          style: text.bodyMedium!.copyWith(color: palette.textMuted),
        ),
      );
    }
    final searching = _query.isNotEmpty;
    final shown = <Place>[
      for (final place in directory.ordered)
        if ((widget.includeClosed || !place.closed) &&
            (!searching ||
                place.displayName.toLowerCase().contains(_query) ||
                place.code.toLowerCase().contains(_query)))
          place,
    ];
    final rows = <Widget>[
      if (widget.offerAll && !searching)
        _PlaceRow(
          title: l10n.placeAll,
          depth: 0,
          selected: widget.selectedId == null,
          onTap: () => Navigator.of(context).pop(const PlaceChoice.all()),
        ),
      for (final place in shown)
        _PlaceRow(
          title: place.displayName,
          // While searching, the places above are named instead of shown by
          // indentation, since they may not be in the list.
          subtitle: searching
              ? (directory.trail(place)..removeLast()).join(' › ')
              : null,
          depth: searching ? 0 : directory.depthOf(place),
          selected: place.id == widget.selectedId,
          closed: place.closed,
          onTap: () => Navigator.of(context).pop(PlaceChoice(place)),
        ),
    ];
    if (shown.isEmpty) {
      return Center(
        child: Text(
          l10n.placeNoMatch,
          style: text.bodyMedium!.copyWith(color: palette.textMuted),
        ),
      );
    }
    return ListView(children: rows);
  }
}

class _PlaceRow extends StatelessWidget {
  const _PlaceRow({
    required this.title,
    required this.depth,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.closed = false,
  });

  final String title;
  final String? subtitle;
  final int depth;
  final bool selected;
  final bool closed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    final hint = subtitle;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? palette.actionSubtle : Colors.transparent,
        borderRadius: Radii.smAll,
        child: InkWell(
          borderRadius: Radii.smAll,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: Sizes.touch),
            child: Padding(
              padding: EdgeInsetsDirectional.only(
                start: Spacing.space3 + depth * Spacing.space5,
                end: Spacing.space3,
                top: Spacing.space2,
                bottom: Spacing.space2,
              ),
              child: Row(
                children: <Widget>[
                  if (depth > 0) ...<Widget>[
                    Icon(
                      Icons.subdirectory_arrow_right,
                      size: Sizes.iconSm,
                      color: palette.textMuted,
                    ),
                    const SizedBox(width: Spacing.space2),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          title,
                          style: text.bodyLarge!.copyWith(
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w400,
                          ),
                        ),
                        if (hint != null && hint.isNotEmpty)
                          Text(
                            hint,
                            style: text.bodySmall!.copyWith(
                              color: palette.textMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (closed) ...<Widget>[
                    const SizedBox(width: Spacing.space2),
                    ObBadge(label: l10n.placeClosed, icon: Icons.block),
                  ],
                  if (selected) ...<Widget>[
                    const SizedBox(width: Spacing.space2),
                    Icon(Icons.check, size: Sizes.icon, color: palette.action),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
