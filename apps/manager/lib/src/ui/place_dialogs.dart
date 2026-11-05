import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obhijatra_manager/l10n/app_localizations.dart';
import 'package:obhijatra_manager/src/data/people.dart';
import 'package:obhijatra_manager/src/data/places.dart';
import 'package:obhijatra_manager/src/data/problem.dart';
import 'package:obhijatra_manager/src/state/people.dart';
import 'package:obhijatra_manager/src/state/providers.dart';
import 'package:obhijatra_manager/src/ui/people_words.dart';
import 'package:obhijatra_manager/src/ui/place_picker.dart';
import 'package:obhijatra_manager/widgets/notice_box.dart';
import 'package:obhijatra_manager/widgets/problem_view.dart';
import 'package:obhijatra_ui/obhijatra_ui.dart';

// The server's names for the fields it can refuse.
const String _kName = 'name';
const String _kCode = 'code';
const String _kParent = 'parent';
const String _kClosed = 'closed';
const String _kId = 'id';

/// The first whole number in [message], or null: the server says how many
/// places or people are in the way ("3 active person(s) work here…").
int? countIn(String message) {
  final match = RegExp(r'\d+').firstMatch(message);
  return match == null ? null : int.tryParse(match.group(0)!);
}

/// The server's message, or the plain "not accepted" sentence.
String _orRejected(AppLocalizations l10n, String message) =>
    message.isNotEmpty ? message : l10n.problemRejected;

/// Runs [problem]'s one action from inside a dialog: sign in again (which
/// closes the dialog), or [retry].
void _onProblemAction(
  BuildContext context,
  WidgetRef ref,
  AppProblem problem, {
  required VoidCallback retry,
  required VoidCallback dismiss,
}) {
  switch (problem.action) {
    case ProblemAction.signInAgain:
      Navigator.of(context).pop();
      ref.read(sessionProvider.notifier).signOut();
    case ProblemAction.tryAgain:
      retry();
    case ProblemAction.close ||
        ProblemAction.chooseFile ||
        ProblemAction.reload:
      dismiss();
  }
}

// ------------------------------------------------------- add or rename

/// Asks for a new place's name and code, inside [parent], which may be
/// changed to another open place. Returns the place added, or null.
Future<Place?> showAddPlaceDialog(
  BuildContext context, {
  required Place parent,
}) => showDialog<Place>(
  context: context,
  builder: (context) => _PlaceEditorDialog(parent: parent),
);

/// Asks for [place]'s new name and code. Returns the place as saved, or
/// null when nothing changed or the admin cancelled.
Future<Place?> showRenamePlaceDialog(
  BuildContext context, {
  required Place place,
}) => showDialog<Place>(
  context: context,
  builder: (context) => _PlaceEditorDialog(place: place),
);

class _PlaceEditorDialog extends ConsumerStatefulWidget {
  const _PlaceEditorDialog({this.place, this.parent});

  /// The place renamed, or null to add one.
  final Place? place;

  /// Where a new place goes first.
  final Place? parent;

  @override
  ConsumerState<_PlaceEditorDialog> createState() => _PlaceEditorDialogState();
}

class _PlaceEditorDialogState extends ConsumerState<_PlaceEditorDialog> {
  late final TextEditingController _name;
  late final TextEditingController _code;
  late String _parentId;
  Map<String, String> _errors = <String, String>{};
  AppProblem? _problem;
  bool _saving = false;

  bool get _adding => widget.place == null;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.place?.name ?? '');
    _code = TextEditingController(text: widget.place?.code ?? '');
    _parentId = widget.place?.parentId ?? widget.parent?.id ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  String _parentName(PlaceDirectory? places) =>
      places?.byId(_parentId)?.displayName ?? widget.parent?.displayName ?? '';

  Future<void> _chooseParent() async {
    final choice = await showPlacePicker(context, selectedId: _parentId);
    final place = choice?.place;
    if (place == null || !mounted) return;
    setState(() {
      _parentId = place.id;
      _errors
        ..remove(_kParent)
        ..remove(_kName);
    });
  }

  /// The server's refusals, under the right fields and in the app's own
  /// words for the reasons it knows.
  Map<String, String> _serverErrors(
    AppLocalizations l10n,
    AppProblem problem,
    String parentName,
  ) => <String, String>{
    for (final entry in problem.fields.entries)
      entry.key: switch ((entry.key, problem.codes[entry.key])) {
        (_kName, 'validation_place_name_taken') => l10n.placeErrorNameTaken(
          parentName,
        ),
        (_kName, 'validation_required') => l10n.placeErrorName,
        (_kCode, 'validation_not_unique') => l10n.placeErrorCodeTaken,
        (
          _kParent,
          'validation_place_parent_closed' || 'validation_place_closed',
        ) =>
          l10n.placeErrorParentClosed,
        _ => _orRejected(l10n, entry.value),
      },
  };

  Future<void> _save() async {
    if (_saving) return;
    final l10n = AppLocalizations.of(context);
    final name = _name.text.trim();
    final code = _code.text.trim();
    if (name.isEmpty) {
      setState(() {
        _errors = <String, String>{_kName: l10n.placeErrorName};
        _problem = null;
      });
      return;
    }
    final place = widget.place;
    if (place != null && name == place.name && code == place.code) {
      Navigator.of(context).pop();
      return;
    }
    final api = ref.read(apiProvider);
    final parentName = _parentName(ref.read(placesProvider).asData?.value);
    setState(() {
      _saving = true;
      _errors = <String, String>{};
      _problem = null;
    });
    try {
      final saved = await trackedUi(
        ref,
        () => place == null
            ? api.createPlace(parentId: _parentId, name: name, code: code)
            : api.updatePlace(place, name: name, code: code),
      );
      if (mounted) Navigator.of(context).pop(saved);
    } on AppProblem catch (problem) {
      if (!mounted) return;
      setState(() {
        if (problem.fields.isNotEmpty) {
          _errors = _serverErrors(l10n, problem, parentName);
        } else {
          _problem = problem;
        }
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final palette = context.palette;
    final places = ref.watch(placesProvider).asData?.value;
    final parent = places?.byId(_parentId) ?? widget.parent;
    final unplaced = <String>[
      for (final entry in _errors.entries)
        if (entry.key != _kName &&
            entry.key != _kCode &&
            (entry.key != _kParent || !_adding))
          entry.value,
    ];
    final place = widget.place;
    return AlertDialog(
      title: Text(_adding ? l10n.placeAddTitle : l10n.placeRename),
      scrollable: true,
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (_adding) ...<Widget>[
              PickerField(
                key: const ValueKey<String>('place-parent'),
                label: l10n.placeParent,
                value: parent == null || places == null
                    ? (parent?.displayName ?? '')
                    : places.trail(parent).join(' › '),
                helper: l10n.placeParentHelp,
                error: _errors[_kParent],
                onTap: _saving ? null : () => unawaited(_chooseParent()),
              ),
              const SizedBox(height: Spacing.space5),
            ] else if (place != null && !place.isRoot)
              Padding(
                padding: const EdgeInsets.only(bottom: Spacing.space4),
                child: Text(
                  l10n.placeParentFixed(_parentName(places)),
                  style: text.bodyMedium!.copyWith(color: palette.textMuted),
                ),
              ),
            TextField(
              key: const ValueKey<String>('place-name'),
              controller: _name,
              autofocus: true,
              enabled: !_saving,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              inputFormatters: <TextInputFormatter>[
                LengthLimitingTextInputFormatter(maxPlaceName),
              ],
              decoration: InputDecoration(
                labelText: l10n.placeName,
                helperText: l10n.placeNameHelp,
                helperMaxLines: 3,
                errorText: _errors[_kName],
                errorMaxLines: 4,
              ),
              onChanged: (_) => setState(() => _errors.remove(_kName)),
            ),
            const SizedBox(height: Spacing.space5),
            TextField(
              key: const ValueKey<String>('place-code'),
              controller: _code,
              enabled: !_saving,
              autocorrect: false,
              enableSuggestions: false,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.done,
              inputFormatters: <TextInputFormatter>[
                LengthLimitingTextInputFormatter(maxPlaceCode),
              ],
              decoration: InputDecoration(
                labelText: l10n.placeCode,
                helperText: l10n.placeCodeHelp,
                helperMaxLines: 3,
                errorText: _errors[_kCode],
                errorMaxLines: 4,
              ),
              onChanged: (_) => setState(() => _errors.remove(_kCode)),
              onSubmitted: (_) => unawaited(_save()),
            ),
            for (final message in unplaced) ...<Widget>[
              const SizedBox(height: Spacing.space4),
              NoticeBox(message: message),
            ],
            if (_problem case final AppProblem problem) ...<Widget>[
              const SizedBox(height: Spacing.space4),
              ProblemBanner(
                problem: problem,
                onAction: () => _onProblemAction(
                  context,
                  ref,
                  problem,
                  retry: () => unawaited(_save()),
                  dismiss: () => setState(() => _problem = null),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          key: const ValueKey<String>('place-save'),
          onPressed: _saving ? null : () => unawaited(_save()),
          child: Text(switch ((_adding, _saving)) {
            (true, true) => l10n.personAdding,
            (true, false) => l10n.placesAdd,
            (false, true) => l10n.actionSaving,
            (false, false) => l10n.actionSave,
          }),
        ),
      ],
    );
  }
}

// ----------------------------------------------------- close or reopen

/// What came of the close or reopen dialog.
enum PlaceStatusOutcome {
  /// The place was closed or reopened.
  done,

  /// The admin wants to see the people who still work there.
  seePeople,
}

/// Asks before closing ([close] true) or reopening [place], explains what
/// that does, and shows the server's reason when it refuses.
Future<PlaceStatusOutcome?> showPlaceStatusDialog(
  BuildContext context, {
  required Place place,
  required bool close,
}) => showDialog<PlaceStatusOutcome>(
  context: context,
  builder: (context) => _PlaceStatusDialog(place: place, close: close),
);

class _PlaceStatusDialog extends ConsumerStatefulWidget {
  const _PlaceStatusDialog({required this.place, required this.close});

  final Place place;
  final bool close;

  @override
  ConsumerState<_PlaceStatusDialog> createState() => _PlaceStatusDialogState();
}

class _PlaceStatusDialogState extends ConsumerState<_PlaceStatusDialog> {
  bool _busy = false;
  String? _refusal;
  bool _peopleInTheWay = false;
  AppProblem? _problem;

  String _reason(AppLocalizations l10n, AppProblem problem) {
    final key = problem.codes.containsKey(_kClosed)
        ? _kClosed
        : problem.fields.keys.first;
    final message = problem.fields[key] ?? '';
    final count = countIn(message);
    return switch (problem.codes[key]) {
      'validation_place_has_open_places' when count != null =>
        l10n.placeErrorOpenInside(count),
      'validation_place_has_people' when count != null => l10n.placeErrorPeople(
        count,
      ),
      'validation_place_root' => l10n.placeErrorRoot,
      'validation_place_parent_closed' => l10n.placeErrorAboveClosed,
      _ => _orRejected(l10n, message),
    };
  }

  Future<void> _run() async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context);
    final api = ref.read(apiProvider);
    setState(() {
      _busy = true;
      _refusal = null;
      _peopleInTheWay = false;
      _problem = null;
    });
    try {
      await trackedUi(
        ref,
        () => api.setPlaceClosed(widget.place, closed: widget.close),
      );
      if (mounted) Navigator.of(context).pop(PlaceStatusOutcome.done);
    } on AppProblem catch (problem) {
      if (!mounted) return;
      setState(() {
        if (problem.fields.isNotEmpty) {
          _refusal = _reason(l10n, problem);
          _peopleInTheWay = problem.codes.values.contains(
            'validation_place_has_people',
          );
        } else {
          _problem = problem;
        }
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final name = widget.place.displayName;
    return AlertDialog(
      title: Text(
        widget.close ? l10n.placeCloseTitle(name) : l10n.placeReopenTitle(name),
      ),
      scrollable: true,
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(widget.close ? l10n.placeCloseBody : l10n.placeReopenBody),
            if (_refusal case final String refusal) ...<Widget>[
              const SizedBox(height: Spacing.space4),
              NoticeBox(
                message: refusal,
                actions: <Widget>[
                  if (_peopleInTheWay)
                    TextButton.icon(
                      onPressed: () =>
                          Navigator.of(context)
                              .pop(PlaceStatusOutcome.seePeople),
                      icon: const Icon(Icons.people_outline),
                      label: Text(l10n.placeSeePeople),
                    ),
                ],
              ),
            ],
            if (_problem case final AppProblem problem) ...<Widget>[
              const SizedBox(height: Spacing.space4),
              ProblemBanner(
                problem: problem,
                onAction: () => _onProblemAction(
                  context,
                  ref,
                  problem,
                  retry: () => unawaited(_run()),
                  dismiss: () => setState(() => _problem = null),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          autofocus: true,
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          key: const ValueKey<String>('place-status-confirm'),
          onPressed: _busy ? null : () => unawaited(_run()),
          child: Text(
            widget.close ? l10n.placeCloseButton : l10n.placeReopenButton,
          ),
        ),
      ],
    );
  }
}

// --------------------------------------------------------------- delete

/// What came of the delete dialog.
enum PlaceDeleteOutcome {
  /// The place was deleted.
  deleted,

  /// The place is in use; the admin chose to close it instead.
  closeInstead,
}

/// Asks before deleting [place], and says why when the server refuses.
Future<PlaceDeleteOutcome?> showDeletePlaceDialog(
  BuildContext context, {
  required Place place,
}) => showDialog<PlaceDeleteOutcome>(
  context: context,
  builder: (context) => _DeletePlaceDialog(place: place),
);

class _DeletePlaceDialog extends ConsumerStatefulWidget {
  const _DeletePlaceDialog({required this.place});

  final Place place;

  @override
  ConsumerState<_DeletePlaceDialog> createState() => _DeletePlaceDialogState();
}

class _DeletePlaceDialogState extends ConsumerState<_DeletePlaceDialog> {
  bool _busy = false;
  String? _refusal;
  bool _inUse = false;
  AppProblem? _problem;

  Future<void> _run() async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context);
    final api = ref.read(apiProvider);
    setState(() {
      _busy = true;
      _refusal = null;
      _problem = null;
    });
    try {
      await trackedUi(ref, () => api.deletePlace(widget.place));
      if (mounted) Navigator.of(context).pop(PlaceDeleteOutcome.deleted);
    } on AppProblem catch (problem) {
      if (!mounted) return;
      setState(() {
        if (problem.fields.isNotEmpty) {
          final key = problem.codes.containsKey(_kId)
              ? _kId
              : problem.fields.keys.first;
          final code = problem.codes[key];
          _inUse = code == 'validation_place_in_use';
          _refusal = switch (code) {
            'validation_place_in_use' => l10n.placeErrorInUse,
            'validation_place_root' => l10n.placeErrorRoot,
            _ => _orRejected(l10n, problem.fields[key] ?? ''),
          };
        } else {
          _problem = problem;
        }
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = context.palette;
    final closeInstead = _inUse && !widget.place.closed;
    return AlertDialog(
      title: Text(l10n.placeDeleteTitle(widget.place.displayName)),
      scrollable: true,
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(l10n.placeDeleteBody),
            if (_refusal case final String refusal) ...<Widget>[
              const SizedBox(height: Spacing.space4),
              NoticeBox(message: refusal),
            ],
            if (_problem case final AppProblem problem) ...<Widget>[
              const SizedBox(height: Spacing.space4),
              ProblemBanner(
                problem: problem,
                onAction: () => _onProblemAction(
                  context,
                  ref,
                  problem,
                  retry: () => unawaited(_run()),
                  dismiss: () => setState(() => _problem = null),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          autofocus: true,
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        if (closeInstead)
          FilledButton(
            key: const ValueKey<String>('place-close-instead'),
            onPressed: () =>
                Navigator.of(context).pop(PlaceDeleteOutcome.closeInstead),
            child: Text(l10n.placeCloseInstead),
          )
        else
          FilledButton(
            key: const ValueKey<String>('place-delete-confirm'),
            style: FilledButton.styleFrom(
              backgroundColor: palette.danger,
              foregroundColor: palette.onAction,
            ),
            onPressed: _busy || _inUse ? null : () => unawaited(_run()),
            child: Text(l10n.placeDeleteButton),
          ),
      ],
    );
  }
}
