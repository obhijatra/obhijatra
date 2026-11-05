import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:obhijatra_manager/l10n/app_localizations.dart';
import 'package:obhijatra_manager/src/data/people.dart';
import 'package:obhijatra_manager/src/data/places.dart';
import 'package:obhijatra_manager/src/data/problem.dart';
import 'package:obhijatra_manager/src/state/file_picker.dart';
import 'package:obhijatra_manager/src/state/navigation.dart';
import 'package:obhijatra_manager/src/state/people.dart';
import 'package:obhijatra_manager/src/state/places.dart';
import 'package:obhijatra_manager/src/state/providers.dart';
import 'package:obhijatra_manager/src/ui/leave_guard.dart';
import 'package:obhijatra_manager/src/ui/page_scaffold.dart';
import 'package:obhijatra_manager/src/ui/people_words.dart';
import 'package:obhijatra_manager/src/ui/place_picker.dart';
import 'package:obhijatra_manager/widgets/loading_block.dart';
import 'package:obhijatra_manager/widgets/notice_box.dart';
import 'package:obhijatra_manager/widgets/ob_badge.dart';
import 'package:obhijatra_manager/widgets/ob_panel.dart';
import 'package:obhijatra_manager/widgets/problem_view.dart';
import 'package:obhijatra_ui/obhijatra_ui.dart';

/// The widest the import page grows: room for the example table and a
/// deep preview, still easy to read.
const double _pageWidth = 760;

/// A problem the server found with a row, in the app's own words for the
/// codes it knows (see server/internal/places/import.go); otherwise the
/// server's sentence as it is.
@visibleForTesting
String importProblemText(AppLocalizations l10n, PlaceImportProblem problem) {
  // A refused character must not reorder or break the sentence around it.
  final name = showUnsafeText(problem.name);
  final value = showUnsafeText(problem.value);
  final fallback = problem.message.isNotEmpty
      ? problem.message
      : l10n.problemRejected;
  return switch (problem.code) {
    'no_name' => l10n.importProblemNoName,
    'too_deep' => switch (int.tryParse(value)) {
      final int limit => l10n.importProblemTooDeep(limit),
      null => l10n.importRowTooDeep,
    },
    'code_too_long' => l10n.importRowCodeTooLong,
    'name_too_long' => l10n.importRowNameTooLong,
    'place_closed' when name.isNotEmpty => l10n.importServerClosed(name),
    'code_mismatch' when name.isNotEmpty && value.isNotEmpty =>
      l10n.importServerCodeOther(name, value),
    'code_repeated' when value.isNotEmpty => l10n.importServerCodeTwice(value),
    'code_taken' when value.isNotEmpty => l10n.importServerCodeTaken(value),
    'unsafe_text' when name.isNotEmpty => l10n.importServerUnsafeName(name),
    'unsafe_text' when value.isNotEmpty => l10n.importServerUnsafeCode(value),
    _ => fallback,
  };
}

/// A problem with one row, from the app's own check or from the server.
class _LineProblem {
  const _LineProblem(this.line, this.message);

  final int line;
  final String message;
}

/// Add many places at once from a spreadsheet saved as CSV: the format
/// explained, where the places go, the file, a check with the server and a
/// preview, then the import itself.
class PlacesImportScreen extends ConsumerStatefulWidget {
  /// Creates the page.
  const PlacesImportScreen({super.key});

  @override
  ConsumerState<PlacesImportScreen> createState() => _PlacesImportScreenState();
}

class _PlacesImportScreenState extends ConsumerState<PlacesImportScreen> {
  late final LeaveGuard _guard;

  String? _parentId;
  String? _parentError;

  PickedFile? _file;
  bool? _headerChoice;
  PlaceSheet? _sheet;
  PlaceSheetException? _fileError;

  /// Counts checks, so an answer to an older one is dropped.
  int _checkRun = 0;
  bool _checking = false;
  PlaceImportResult? _check;
  AppProblem? _checkProblem;

  bool _importing = false;
  bool _done = false;

  /// Marks the check, so the page can scroll to it once a file is read.
  final GlobalKey _checkKey = GlobalKey();

  /// The real import found problems the check had not.
  bool _changedSinceCheck = false;

  @override
  void initState() {
    super.initState();
    _guard = ref.read(leaveGuardProvider)
      ..attach(
        this,
        () => _file != null && !_done,
        prompt: (l10n) => LeavePrompt(
          title: l10n.leaveImportTitle,
          body: l10n.leaveImportBody,
          leave: l10n.leaveImportLeave,
        ),
      );
  }

  @override
  void dispose() {
    _guard.detach(this);
    super.dispose();
  }

  // ------------------------------------------------------------- state

  Place? _parent(PlaceDirectory? places) {
    if (places == null) return null;
    final chosen = _parentId == null ? null : places.byId(_parentId!);
    return chosen ?? places.root;
  }

  Future<void> _back() async {
    if (!await confirmLeave(context, ref) || !mounted) return;
    ref.read(placesPageProvider.notifier).open(PlacesPage.tree);
  }

  Future<void> _chooseParent() async {
    final places = ref.read(placesProvider).asData?.value;
    final choice = await showPlacePicker(
      context,
      selectedId: _parent(places)?.id,
    );
    final place = choice?.place;
    if (place == null || !mounted) return;
    setState(() {
      _parentId = place.id;
      _parentError = null;
    });
    unawaited(_runCheck());
  }

  Future<void> _chooseFile() async {
    final picked = await ref
        .read(csvFilePickerProvider)
        .pickCsvFile(maxBytes: maxImportBytes);
    if (picked == null || !mounted) return;
    setState(() {
      _file = picked;
      _headerChoice = null;
    });
    _read();
  }

  void _setHeader(bool hasHeader) {
    setState(() => _headerChoice = hasHeader);
    _read();
  }

  /// Reads the chosen file again, then checks it with the server.
  void _read() {
    final file = _file;
    if (file == null) return;
    setState(() {
      _checkRun++;
      _check = null;
      _checkProblem = null;
      _checking = false;
      _changedSinceCheck = false;
      try {
        if (file.tooLarge) {
          throw const PlaceSheetException(PlaceSheetError.tooBig);
        }
        _sheet = readPlaceSheet(file.bytes, hasHeader: _headerChoice);
        _fileError = null;
      } on PlaceSheetException catch (error) {
        _sheet = null;
        _fileError = error;
      }
    });
    if (_sheet != null) {
      // Bring the check and the preview into view.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final target = _checkKey.currentContext;
        if (target == null || !target.mounted) return;
        unawaited(
          Scrollable.ensureVisible(
            target,
            duration: const Duration(milliseconds: 300),
            alignment: 0.05,
          ),
        );
      });
    }
    unawaited(_runCheck());
  }

  Future<void> _runCheck() async {
    final sheet = _sheet;
    final parent = _parent(ref.read(placesProvider).asData?.value);
    if (sheet == null || parent == null) return;
    final run = ++_checkRun;
    if (sheet.rows.isEmpty) {
      setState(() {
        _check = null;
        _checking = false;
      });
      return;
    }
    setState(() {
      _checking = true;
      _check = null;
      _checkProblem = null;
      _changedSinceCheck = false;
    });
    final api = ref.read(apiProvider);
    try {
      final result = await trackedUi(
        ref,
        () => api.importPlaces(
          parentId: parent.id,
          rows: sheet.rows,
          dryRun: true,
        ),
      );
      if (!mounted || run != _checkRun) return;
      setState(() => _check = result);
    } on AppProblem catch (problem) {
      if (!mounted || run != _checkRun) return;
      setState(() => _refused(problem));
    } finally {
      if (mounted && run == _checkRun) setState(() => _checking = false);
    }
  }

  /// Shows a refusal: under "New places go inside" when it is about the
  /// place chosen, else as a problem with its one action.
  void _refused(AppProblem problem) {
    final l10n = AppLocalizations.of(context);
    if (problem.fields.containsKey('parent')) {
      _parentError = switch (problem.codes['parent']) {
        'validation_place_closed' => l10n.placeErrorParentClosed,
        'validation_place_missing' => l10n.problemNotFound,
        _ =>
          problem.fields['parent']!.isNotEmpty
              ? problem.fields['parent']
              : l10n.problemRejected,
      };
    } else {
      _checkProblem = problem;
    }
  }

  Future<void> _import() async {
    final sheet = _sheet;
    final places = ref.read(placesProvider).asData?.value;
    final parent = _parent(places);
    if (sheet == null || parent == null || _importing) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final api = ref.read(apiProvider);
    setState(() {
      _importing = true;
      _checkProblem = null;
    });
    try {
      final result = await trackedUi(
        ref,
        () => api.importPlaces(
          parentId: parent.id,
          rows: sheet.rows,
          dryRun: false,
        ),
      );
      if (!mounted) return;
      if (!result.saved) {
        setState(() {
          _check = result;
          _changedSinceCheck = true;
        });
        return;
      }
      _done = true;
      ref.invalidate(placesProvider);
      // Open the chosen place and every place above it, so the new places
      // show in the tree.
      ref
          .read(placeTreeViewProvider.notifier)
          .open(parent.path.split('/').where((id) => id.isNotEmpty));
      ref.read(placesPageProvider.notifier).open(PlacesPage.tree);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.importDone(result.created))),
      );
    } on AppProblem catch (problem) {
      if (!mounted) return;
      setState(() => _refused(problem));
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  void _onCheckProblem(AppProblem problem) {
    switch (problem.action) {
      case ProblemAction.signInAgain:
        ref.read(sessionProvider.notifier).signOut();
      case ProblemAction.tryAgain:
        unawaited(_runCheck());
      case ProblemAction.close ||
          ProblemAction.chooseFile ||
          ProblemAction.reload:
        setState(() => _checkProblem = null);
    }
  }

  // ----------------------------------------------------------- words

  String _fileErrorText(AppLocalizations l10n, PlaceSheetException error) =>
      switch (error.error) {
        PlaceSheetError.tooBig => l10n.importErrorTooBig,
        PlaceSheetError.excel => l10n.importErrorExcel,
        PlaceSheetError.notUtf8 => l10n.importErrorNotUtf8,
        PlaceSheetError.unclosedQuote => l10n.importErrorQuote(error.line),
        PlaceSheetError.empty => l10n.importErrorEmpty,
        PlaceSheetError.onlyHeader => l10n.importErrorOnlyHeader,
        PlaceSheetError.tooManyRows => l10n.importErrorTooMany(error.count),
      };

  String _rowErrorText(AppLocalizations l10n, PlaceRowProblem problem) =>
      switch (problem.error) {
        PlaceRowError.noName => l10n.importRowNoName,
        PlaceRowError.gap => l10n.importRowGap(columnLetter(problem.column)),
        PlaceRowError.tooDeep => l10n.importRowTooDeep,
        PlaceRowError.nameTooLong => l10n.importRowNameTooLong,
        PlaceRowError.codeTooLong => l10n.importRowCodeTooLong,
      };

  /// Every problem with a row, the app's own and the server's, by line.
  List<_LineProblem> _problems(AppLocalizations l10n) {
    final sheet = _sheet;
    if (sheet == null) return const <_LineProblem>[];
    return <_LineProblem>[
      for (final problem in sheet.problems)
        _LineProblem(problem.line, _rowErrorText(l10n, problem)),
      for (final problem in _check?.problems ?? const <PlaceImportProblem>[])
        _LineProblem(problem.line, importProblemText(l10n, problem)),
    ]..sort((a, b) => a.line.compareTo(b.line));
  }

  // ------------------------------------------------------------ layout

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final places = ref.watch(placesProvider);
    return PageScaffold(
      leading: TextButton.icon(
        onPressed: () => unawaited(_back()),
        icon: const Icon(Icons.arrow_back),
        label: Text(l10n.placesBack),
      ),
      title: l10n.importTitle,
      subtitle: l10n.importSummary,
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
        data: (directory) => _page(context, directory),
      ),
    );
  }

  Widget _page(BuildContext context, PlaceDirectory directory) {
    final l10n = AppLocalizations.of(context);
    final parent = _parent(directory);
    final sheet = _sheet;
    final problems = _problems(l10n);
    // Rows the server found a problem with add nothing, so they are left
    // out of the preview.
    final refusedLines = <int>{
      for (final problem in _check?.problems ?? const <PlaceImportProblem>[])
        problem.line,
    };
    final preview = sheet == null || parent == null
        ? const <PlacePreviewNode>[]
        : previewImport(directory, parent, <PlaceImportRow>[
            for (final row in sheet.rows)
              if (!refusedLines.contains(row.line)) row,
          ]);
    final checked = sheet != null && !_checking && _check != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(
          child: CustomScrollView(
            key: const ValueKey<String>('import-page'),
            slivers: <Widget>[
              _box(_formatStep(context)),
              _gap(),
              _box(_parentStep(context, directory, parent)),
              _gap(),
              _box(_fileStep(context)),
              if (sheet != null) ...<Widget>[
                _gap(),
                _box(
                  KeyedSubtree(
                    key: _checkKey,
                    child: _checkStep(context, problems),
                  ),
                ),
                if (problems.isNotEmpty) ...<Widget>[
                  _gap(Spacing.space3),
                  _slices(
                    key: 'import-problems',
                    count: problems.length,
                    builder: (context, index) =>
                        _ProblemRow(problem: problems[index]),
                  ),
                ],
                if (checked && preview.isNotEmpty) ...<Widget>[
                  _gap(Spacing.space5),
                  _box(
                    Semantics(
                      header: true,
                      child: Text(
                        l10n.importPreview,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ),
                  _gap(Spacing.space2),
                  _slices(
                    key: 'import-preview',
                    count: preview.length,
                    builder: (context, index) =>
                        _PreviewRow(node: preview[index]),
                  ),
                ],
              ],
              _gap(Spacing.space8),
            ],
          ),
        ),
        if (sheet != null) _box(_addBar(context, problems), sliver: false),
      ],
    );
  }

  /// [child] in a box no wider than the page, at the start.
  Widget _box(Widget child, {bool sliver = true}) {
    final boxed = Align(
      alignment: AlignmentDirectional.topStart,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _pageWidth),
        child: child,
      ),
    );
    return sliver ? SliverToBoxAdapter(child: boxed) : boxed;
  }

  Widget _gap([double height = Spacing.space5]) =>
      SliverToBoxAdapter(child: SizedBox(height: height));

  /// A long list drawn as one panel, built only as it scrolls into view.
  Widget _slices({
    required String key,
    required int count,
    required IndexedWidgetBuilder builder,
  }) => SliverList.builder(
    key: ValueKey<String>(key),
    itemCount: count,
    itemBuilder: (context, index) => Align(
      alignment: AlignmentDirectional.topStart,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _pageWidth),
        child: _PanelSlice(
          first: index == 0,
          last: index == count - 1,
          child: builder(context, index),
        ),
      ),
    ),
  );

  Widget _formatStep(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _Step(
      number: 1,
      title: l10n.importStepFile,
      children: <Widget>[
        for (final rule in <String>[
          l10n.importRuleRows,
          l10n.importRuleHeader,
          l10n.importRuleCode,
          l10n.importRuleEmpty,
          l10n.importRuleReuse,
          l10n.importRuleBangla,
          l10n.importRuleSave,
          l10n.importRuleLimits,
        ])
          _Bullet(rule),
        const SizedBox(height: Spacing.space4),
        const _ExampleTable(),
      ],
    );
  }

  Widget _parentStep(
    BuildContext context,
    PlaceDirectory directory,
    Place? parent,
  ) {
    final l10n = AppLocalizations.of(context);
    return _Step(
      number: 2,
      title: l10n.importStepParent,
      children: <Widget>[
        PickerField(
          key: const ValueKey<String>('import-parent'),
          label: l10n.importParent,
          value: parent == null ? '' : directory.trail(parent).join(' › '),
          placeholder: l10n.personPlaceChoose,
          helper: l10n.importParentHelp,
          error: _parentError,
          onTap: _importing ? null : () => unawaited(_chooseParent()),
        ),
      ],
    );
  }

  Widget _fileStep(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final palette = context.palette;
    final muted = text.bodySmall!.copyWith(color: palette.textMuted);
    final file = _file;
    final sheet = _sheet;
    final error = _fileError;
    final rowCount = sheet == null
        ? 0
        : sheet.rows.length + sheet.problems.length;
    // The switch shows once a file is read, and when the only problem is
    // that the first row might be a place.
    final headerSwitch =
        sheet != null ||
        (error != null && error.error == PlaceSheetError.onlyHeader);
    final hasHeader = sheet?.hasHeader ?? _headerChoice ?? true;
    return _Step(
      number: 3,
      title: l10n.importStepChoose,
      children: <Widget>[
        if (file != null) ...<Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.description_outlined,
                size: Sizes.icon,
                color: palette.textMuted,
              ),
              const SizedBox(width: Spacing.space2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      l10n.importFileName(file.name),
                      style: text.titleSmall,
                    ),
                    if (sheet != null)
                      Text(l10n.importRowCount(rowCount), style: muted),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.space3),
        ],
        if (error != null) ...<Widget>[
          NoticeBox(message: _fileErrorText(l10n, error)),
          const SizedBox(height: Spacing.space3),
        ],
        if (headerSwitch) ...<Widget>[
          MergeSemantics(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(l10n.importHeader, style: text.labelLarge),
                      const SizedBox(height: Spacing.space1),
                      Text(l10n.importHeaderHelp, style: muted),
                    ],
                  ),
                ),
                const SizedBox(width: Spacing.space3),
                Switch(
                  key: const ValueKey<String>('import-header'),
                  value: hasHeader,
                  onChanged: _importing ? null : _setHeader,
                ),
              ],
            ),
          ),
          if (sheet != null && sheet.columnNames.isNotEmpty) ...<Widget>[
            const SizedBox(height: Spacing.space2),
            Text(
              l10n.importColumns(sheet.columnNames.join(' | ')),
              style: text.bodyMedium,
            ),
          ],
          if (sheet?.codeColumn case final String code) ...<Widget>[
            const SizedBox(height: Spacing.space1),
            Text(l10n.importCodeColumn(code), style: text.bodyMedium),
          ],
          const SizedBox(height: Spacing.space4),
        ],
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: file == null
              ? FilledButton.icon(
                  key: const ValueKey<String>('import-choose'),
                  onPressed: () => unawaited(_chooseFile()),
                  icon: const Icon(Icons.upload_file_outlined),
                  label: Text(l10n.importChoose),
                )
              : OutlinedButton.icon(
                  key: const ValueKey<String>('import-choose'),
                  onPressed: _importing ? null : () => unawaited(_chooseFile()),
                  icon: const Icon(Icons.upload_file_outlined),
                  label: Text(l10n.importChooseAnother),
                ),
        ),
      ],
    );
  }

  Widget _checkStep(BuildContext context, List<_LineProblem> problems) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final check = _check;
    final children = <Widget>[];
    if (_checking) {
      children.add(
        Semantics(
          liveRegion: true,
          child: Row(
            children: <Widget>[
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: Spacing.space3),
              Expanded(child: Text(l10n.importChecking, style: text.bodyLarge)),
            ],
          ),
        ),
      );
    } else if (_checkProblem case final AppProblem problem) {
      children.add(
        ProblemBanner(
          problem: problem,
          onAction: () => _onCheckProblem(problem),
        ),
      );
    } else if (check != null) {
      children.add(
        Semantics(
          liveRegion: true,
          child: Text(
            '${l10n.importNewCount(check.created)} · '
            '${l10n.importExistingCount(check.existing)}',
            key: const ValueKey<String>('import-summary'),
            style: text.titleMedium,
          ),
        ),
      );
    }
    if (_changedSinceCheck) {
      children.addAll(<Widget>[
        const SizedBox(height: Spacing.space3),
        NoticeBox(message: l10n.importChanged),
      ]);
    }
    if (problems.isNotEmpty) {
      children.addAll(<Widget>[
        const SizedBox(height: Spacing.space3),
        NoticeBox(
          key: const ValueKey<String>('import-problems-summary'),
          message:
              '${l10n.importProblems(problems.length)}. '
              '${l10n.importProblemsHelp}',
        ),
      ]);
    } else if (check != null && !_checking && check.created == 0) {
      children.addAll(<Widget>[
        const SizedBox(height: Spacing.space3),
        NoticeBox(message: l10n.importNothingNew, tone: Tone.info),
      ]);
    }
    return _Step(number: 4, title: l10n.importStepCheck, children: children);
  }

  Widget _addBar(BuildContext context, List<_LineProblem> problems) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final palette = context.palette;
    final check = _check;
    final count = check?.created ?? 0;
    final ready =
        !_checking &&
        !_importing &&
        check != null &&
        problems.isEmpty &&
        _parentError == null &&
        count > 0;
    final String status;
    if (_checking) {
      status = l10n.importChecking;
    } else if (problems.isNotEmpty) {
      status = l10n.importProblems(problems.length);
    } else if (check != null) {
      status =
          '${l10n.importNewCount(check.created)} · '
          '${l10n.importExistingCount(check.existing)}';
    } else {
      status = '';
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: Spacing.space3),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: palette.border)),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: Spacing.space3,
        runSpacing: Spacing.space2,
        children: <Widget>[
          Text(
            status,
            style: text.bodyMedium!.copyWith(color: palette.textMuted),
          ),
          if (count > 0)
            FilledButton.icon(
              key: const ValueKey<String>('import-add'),
              onPressed: ready ? () => unawaited(_import()) : null,
              icon: _importing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.playlist_add),
              label: Text(
                _importing ? l10n.importAdding : l10n.importAdd(count),
              ),
            ),
        ],
      ),
    );
  }
}

/// A numbered step: a circle with the number, a heading and what to do.
class _Step extends StatelessWidget {
  const _Step({
    required this.number,
    required this.title,
    required this.children,
  });

  final int number;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final palette = context.palette;
    final locale = Localizations.localeOf(context).toLanguageTag();
    return ObPanel(
      padding: const EdgeInsets.all(Spacing.space6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Semantics(
            header: true,
            label: '${l10n.importStep(number)}: $title',
            excludeSemantics: true,
            child: Row(
              children: <Widget>[
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: palette.surfaceBrand,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    NumberFormat.decimalPattern(locale).format(number),
                    style: text.labelLarge!.copyWith(
                      color: palette.textOnBrand,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: Spacing.space3),
                Expanded(child: Text(title, style: text.titleLarge)),
              ],
            ),
          ),
          if (children.isNotEmpty) const SizedBox(height: Spacing.space4),
          ...children,
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.space2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ExcludeSemantics(child: Text('•', style: style)),
          const SizedBox(width: Spacing.space2),
          Expanded(child: Text(text, style: style)),
        ],
      ),
    );
  }
}

/// A small spreadsheet showing the format: three columns of levels and the
/// code column.
class _ExampleTable extends StatelessWidget {
  const _ExampleTable();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final palette = context.palette;
    final rows = <List<String>>[
      <String>[
        l10n.importExampleRegion,
        l10n.importExampleArea,
        l10n.importExampleBranch,
        'code',
      ],
      <String>[
        l10n.importExampleRegion1,
        l10n.importExampleArea1,
        l10n.importExampleBranch1,
        'MRP10',
      ],
      <String>[
        l10n.importExampleRegion1,
        l10n.importExampleArea1,
        l10n.importExampleBranch2,
        'PLB',
      ],
      <String>[l10n.importExampleRegion2, l10n.importExampleArea2, '', ''],
    ];
    Widget cell(String value, {required bool heading}) => Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.space3,
        vertical: Spacing.space2,
      ),
      child: Text(value, style: (heading ? text.labelLarge : text.bodyMedium)!),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(l10n.importExample, style: text.labelLarge),
        const SizedBox(height: Spacing.space2),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Table(
            defaultColumnWidth: const IntrinsicColumnWidth(),
            border: TableBorder.all(
              color: palette.borderStrong,
              borderRadius: Radii.xsAll,
            ),
            children: <TableRow>[
              for (var i = 0; i < rows.length; i++)
                TableRow(
                  decoration: i == 0
                      ? BoxDecoration(color: palette.surfaceSunken)
                      : null,
                  children: <Widget>[
                    for (final value in rows[i]) cell(value, heading: i == 0),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One item of a long list drawn as part of one panel.
class _PanelSlice extends StatelessWidget {
  const _PanelSlice({
    required this.first,
    required this.last,
    required this.child,
  });

  final bool first;
  final bool last;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final side = BorderSide(color: palette.border);
    const radius = Radius.circular(Radii.md);
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(
          left: side,
          right: side,
          top: first ? side : BorderSide.none,
          bottom: last ? side : BorderSide(color: palette.border, width: 0.5),
        ),
        borderRadius: first || last
            ? BorderRadius.vertical(
                top: first ? radius : Radius.zero,
                bottom: last ? radius : Radius.zero,
              )
            : null,
      ),
      child: child,
    );
  }
}

class _ProblemRow extends StatelessWidget {
  const _ProblemRow({required this.problem});

  final _LineProblem problem;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final palette = context.palette;
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.space4,
          vertical: Spacing.space3,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(Icons.error_outline, size: Sizes.icon, color: palette.danger),
            const SizedBox(width: Spacing.space2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(l10n.importLine(problem.line), style: text.labelLarge),
                  Text(problem.message, style: text.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({required this.node});

  final PlacePreviewNode node;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final palette = context.palette;
    final muted = text.bodySmall!.copyWith(color: palette.textMuted);
    return LayoutBuilder(
      builder: (context, box) {
        final step = box.maxWidth >= 600 ? Spacing.space6 : Spacing.space3;
        final indent = math.min(node.depth * step, box.maxWidth * 0.3);
        return MergeSemantics(
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: Sizes.touch),
            child: Padding(
              padding: EdgeInsetsDirectional.only(
                start: Spacing.space4 + indent,
                end: Spacing.space4,
                top: Spacing.space2,
                bottom: Spacing.space2,
              ),
              child: Row(
                children: <Widget>[
                  ExcludeSemantics(
                    child: Icon(
                      node.isNew
                          ? Icons.add_location_alt_outlined
                          : Icons.location_on_outlined,
                      size: Sizes.icon,
                      color: node.isNew ? palette.success : palette.textMuted,
                    ),
                  ),
                  const SizedBox(width: Spacing.space2),
                  Expanded(
                    child: Wrap(
                      spacing: Spacing.space2,
                      runSpacing: Spacing.space1,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        Text(
                          node.name,
                          style: node.isNew
                              ? text.titleSmall
                              : text.bodyMedium!.copyWith(
                                  color: palette.textMuted,
                                ),
                        ),
                        if (node.code.isNotEmpty)
                          Text(l10n.placeCodeShown(node.code), style: muted),
                        if (node.isNew)
                          ObBadge(
                            label: l10n.importNew,
                            tone: Tone.success,
                            icon: Icons.add,
                          )
                        else
                          Text(l10n.importAlready, style: muted),
                        if (node.closed)
                          ObBadge(label: l10n.placeClosed, icon: Icons.block),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
