import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obhijatra_manager/l10n/app_localizations.dart';
import 'package:obhijatra_manager/src/data/models.dart';
import 'package:obhijatra_manager/src/data/problem.dart';
import 'package:obhijatra_manager/src/state/providers.dart';
import 'package:obhijatra_manager/src/ui/format.dart';
import 'package:obhijatra_manager/src/ui/page_scaffold.dart';
import 'package:obhijatra_manager/src/ui/shell.dart';
import 'package:obhijatra_manager/src/ui/upload_form_dialog.dart';
import 'package:obhijatra_manager/src/xform/publish_checks.dart';
import 'package:obhijatra_manager/widgets/empty_state.dart';
import 'package:obhijatra_manager/widgets/focus_ring.dart';
import 'package:obhijatra_manager/widgets/loading_block.dart';
import 'package:obhijatra_manager/widgets/ob_badge.dart';
import 'package:obhijatra_manager/widgets/ob_panel.dart';
import 'package:obhijatra_manager/widgets/problem_view.dart';
import 'package:obhijatra_manager/widgets/publish_check_list.dart';
import 'package:obhijatra_ui/obhijatra_ui.dart';

/// Forms and their versions; upload and publish.
class FormsScreen extends ConsumerWidget {
  /// Creates the screen.
  const FormsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final forms = ref.watch(formsProvider);
    return PageScaffold(
      title: l10n.formsTitle,
      child: forms.when(
        loading: () => const LoadingBlock(),
        error: (error, _) => ProblemView(
          problem: problemFrom(error),
          onAction: () => _handleAction(ref, problemFrom(error)),
        ),
        data: (list) => _FormsBody(forms: list),
      ),
    );
  }
}

void _handleAction(WidgetRef ref, AppProblem problem) {
  if (problem.action == ProblemAction.signInAgain) {
    ref.read(sessionProvider.notifier).signOut();
  } else {
    retryAll(ref);
  }
}

class _FormsBody extends ConsumerWidget {
  const _FormsBody({required this.forms});

  final List<FormSummary> forms;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(sessionProvider);
    final isAdmin = user?.isOrgAdmin ?? false;
    final selectedForm = ref.watch(selectedFormProvider);
    final selectedVersion = ref.watch(selectedVersionProvider);

    final form =
        forms.where((f) => f.id == selectedForm).firstOrNull ??
        forms.firstOrNull;
    final version = form == null
        ? null
        : (form.versions.where((v) => v.id == selectedVersion).firstOrNull ??
              form.versions.firstOrNull);

    final left = _LeftColumn(
      forms: forms,
      selected: form,
      selectedVersion: version,
      isAdmin: isAdmin,
    );
    final Widget right = form == null
        ? (forms.isEmpty
              ? EmptyState(
                  icon: Icons.description_outlined,
                  title: l10n.formsEmptyTitle,
                  body: isAdmin
                      ? l10n.formsEmptyBodyAdmin
                      : l10n.formsEmptyBodyViewer,
                )
              : EmptyState(
                  icon: Icons.description_outlined,
                  title: l10n.formsTitle,
                  body: l10n.formsSelectPrompt,
                ))
        : version == null
        ? EmptyState(
            icon: Icons.layers_outlined,
            title: form.displayTitle,
            body: l10n.formsSelectVersion,
          )
        : VersionPanel(form: form, version: version, isAdmin: isAdmin);

    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= 860;
        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: Spacing.space8),
          child: wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SizedBox(width: 340, child: left),
                    const SizedBox(width: Spacing.space5),
                    Expanded(child: right),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    left,
                    const SizedBox(height: Spacing.space5),
                    right,
                  ],
                ),
        );
      },
    );
  }
}

class _LeftColumn extends ConsumerWidget {
  const _LeftColumn({
    required this.forms,
    required this.selected,
    required this.selectedVersion,
    required this.isAdmin,
  });

  final List<FormSummary> forms;
  final FormSummary? selected;
  final FormVersion? selectedVersion;
  final bool isAdmin;

  Future<void> _upload(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final created = await showUploadFormDialog(context);
    if (created == null) return;
    ref.invalidate(formsProvider);
    ref.read(selectedFormProvider.notifier).select(created.formRecordId);
    ref.read(selectedVersionProvider.notifier).select(created.id);
    messenger.showSnackBar(SnackBar(content: Text(l10n.uploadDone)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (isAdmin)
          Container(
            padding: const EdgeInsets.all(Spacing.space4),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: Radii.mdAll,
              border: Border.all(color: palette.borderStrong, width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.upload_outlined,
                      size: Sizes.icon,
                      color: palette.action,
                    ),
                    const SizedBox(width: Spacing.space2),
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          l10n.formsUploadTitle,
                          style: text.titleMedium,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Spacing.space2),
                Text(
                  l10n.formsUploadHelp,
                  style: text.bodySmall!.copyWith(color: palette.textMuted),
                ),
                const SizedBox(height: Spacing.space3),
                OutlinedButton(
                  onPressed: () => _upload(context, ref),
                  child: Text(l10n.formsChooseFile),
                ),
              ],
            ),
          )
        else
          Text(
            l10n.adminOnlyForms,
            style: text.bodySmall!.copyWith(color: palette.textMuted),
          ),
        const SizedBox(height: Spacing.space4),
        Semantics(
          header: true,
          child: Text(l10n.formsYourForms, style: text.titleMedium),
        ),
        const SizedBox(height: Spacing.space2),
        if (forms.isEmpty)
          Text(
            l10n.formsEmptyTitle,
            style: text.bodyMedium!.copyWith(color: palette.textMuted),
          )
        else
          for (final form in forms)
            Padding(
              padding: const EdgeInsets.only(bottom: Spacing.space2),
              child: _FormGroup(
                form: form,
                isSelected: form.id == selected?.id,
                selectedVersion: selectedVersion,
              ),
            ),
      ],
    );
  }
}

class _FormGroup extends ConsumerWidget {
  const _FormGroup({
    required this.form,
    required this.isSelected,
    required this.selectedVersion,
  });

  final FormSummary form;
  final bool isSelected;
  final FormVersion? selectedVersion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final palette = context.palette;
    final text = Theme.of(context).textTheme;
    final published = form.latestPublished;
    final meta = form.versions.length > 1
        ? l10n.formsVersionCount(form.versions.length)
        : published != null
        ? l10n.formsPublishedSummary(published.version)
        : form.versions.isEmpty
        ? l10n.formsNoVersions
        : l10n.formsDraftSummary;
    final header = FocusRing(
      borderRadius: Radii.mdAll,
      child: Semantics(
        button: true,
        selected: isSelected,
        child: InkWell(
          borderRadius: Radii.mdAll,
          onTap: () {
            ref.read(selectedFormProvider.notifier).select(form.id);
            ref
                .read(selectedVersionProvider.notifier)
                .select(form.versions.firstOrNull?.id);
          },
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.space3,
                vertical: 10,
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.description_outlined,
                    size: Sizes.iconLg,
                    color: palette.action,
                  ),
                  const SizedBox(width: Spacing.space3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          form.displayTitle,
                          style: text.titleSmall!.copyWith(
                            fontSize: text.bodyMedium!.fontSize,
                          ),
                        ),
                        Text(
                          meta,
                          style: text.bodySmall!.copyWith(
                            color: palette.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return Container(
      decoration: BoxDecoration(
        color: isSelected ? palette.actionSubtle : palette.surface,
        borderRadius: Radii.mdAll,
        border: Border.all(
          color: isSelected ? palette.action : palette.border,
          width: isSelected ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Material(color: Colors.transparent, child: header),
          if (isSelected && form.versions.isNotEmpty)
            Container(
              color: palette.surface,
              padding: const EdgeInsets.fromLTRB(
                Spacing.space2,
                6,
                Spacing.space2,
                Spacing.space2,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  for (final version in form.versions)
                    _VersionTile(
                      version: version,
                      selected: version.id == selectedVersion?.id,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _VersionTile extends ConsumerWidget {
  const _VersionTile({required this.version, required this.selected});

  final FormVersion version;
  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final palette = context.palette;
    final text = Theme.of(context).textTheme;
    final needsFix = selected && !version.published && _needsFix(ref, context);
    final when = version.published && version.publishedAt != null
        ? l10n.versionPublished(Format.day(context, version.publishedAt!))
        : l10n.versionUploaded(Format.when(context, version.created));
    return FocusRing(
      child: Material(
        color: selected ? palette.bgSubtle : Colors.transparent,
        borderRadius: Radii.smAll,
        child: InkWell(
          borderRadius: Radii.smAll,
          onTap: () =>
              ref.read(selectedVersionProvider.notifier).select(version.id),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.space3,
                vertical: Spacing.space1,
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          l10n.versionLabel(version.version),
                          style: text.titleSmall,
                        ),
                        Text(
                          when,
                          style: text.bodySmall!.copyWith(
                            color: palette.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: Spacing.space2),
                  if (version.published)
                    ObBadge(label: l10n.badgePublished, tone: Tone.success)
                  else if (needsFix)
                    ObBadge(
                      label: l10n.badgeNeedsFix,
                      tone: Tone.warning,
                      icon: Icons.schedule,
                    )
                  else
                    ObBadge(label: l10n.badgeDraft),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _needsFix(WidgetRef ref, BuildContext context) {
    final xml = ref.watch(xformTextProvider(version)).asData?.value;
    if (xml == null) return false;
    final lang = Localizations.localeOf(context).languageCode;
    return !checkXForm(xml, lang: lang).canPublish;
  }
}

/// The right-hand panel: one version, its checks and Publish.
class VersionPanel extends ConsumerStatefulWidget {
  /// Creates the panel.
  const VersionPanel({
    required this.form,
    required this.version,
    required this.isAdmin,
    super.key,
  });

  /// The form the version belongs to.
  final FormSummary form;

  /// The version shown.
  final FormVersion version;

  /// Whether the signed-in user may publish.
  final bool isAdmin;

  @override
  ConsumerState<VersionPanel> createState() => _VersionPanelState();
}

class _VersionPanelState extends ConsumerState<VersionPanel> {
  bool _busy = false;
  AppProblem? _problem;

  Future<void> _publish() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final version = widget.version;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.publishConfirmTitle(version.version)),
        content: Text(l10n.publishConfirmBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.publishConfirmNo),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.publishButton),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _problem = null;
    });
    try {
      await trackedUi(ref, () => ref.read(apiProvider).publish(version));
      ref
        ..invalidate(formsProvider)
        ..invalidate(xformTextProvider(version));
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.publishDone(version.version))),
      );
    } on AppProblem catch (problem) {
      if (mounted) setState(() => _problem = problem);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = context.palette;
    final text = Theme.of(context).textTheme;
    final version = widget.version;
    final lang = Localizations.localeOf(context).languageCode;
    final xml = ref.watch(xformTextProvider(version));

    final existing = widget.form.versions
        .where((v) => v.id != version.id)
        .map((v) => v.version);
    final report = xml.asData == null
        ? null
        : checkXForm(
            xml.asData!.value,
            existingVersions: version.published ? const <String>[] : existing,
            lang: lang,
          );

    final badge = version.published
        ? ObBadge(label: l10n.badgePublished, tone: Tone.success)
        : (report != null && !report.canPublish)
        ? ObBadge(
            label: l10n.badgeNeedsFix,
            tone: Tone.warning,
            icon: Icons.schedule,
          )
        : ObBadge(label: l10n.badgeDraft);

    return ObPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Spacing.space6,
              Spacing.space5,
              Spacing.space6,
              Spacing.space4,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Semantics(
                        header: true,
                        child: Text(
                          l10n.versionHeading(
                            widget.form.displayTitle,
                            version.version,
                          ),
                          style: text.titleLarge,
                        ),
                      ),
                      Text(
                        l10n.versionUploaded(
                          Format.when(context, version.created),
                        ),
                        style: text.bodySmall!.copyWith(
                          color: palette.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: Spacing.space3),
                badge,
              ],
            ),
          ),
          Divider(height: 1, color: palette.border),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Spacing.space6,
              Spacing.space4,
              Spacing.space6,
              Spacing.space3,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Semantics(
                  header: true,
                  child: Text(
                    version.published
                        ? l10n.formCheckTitle
                        : l10n.publishCheckTitle,
                    style: text.titleMedium,
                  ),
                ),
                if (report != null)
                  Text(
                    publishSummary(context, report),
                    style: text.bodyMedium!.copyWith(color: palette.textMuted),
                  ),
              ],
            ),
          ),
          xml.when(
            loading: () => const LoadingBlock(compact: true),
            error: (error, _) => ProblemView(
              compact: true,
              problem: problemFrom(error),
              onAction: () => _handleAction(ref, problemFrom(error)),
            ),
            data: (_) => PublishCheckList(
              report: report!,
              horizontalPadding: Spacing.space6,
            ),
          ),
          if (_problem != null)
            Padding(
              padding: const EdgeInsets.all(Spacing.space4),
              child: ProblemBanner(
                problem: _problem!,
                onAction: () => setState(() => _problem = null),
              ),
            ),
          Container(
            padding: const EdgeInsets.fromLTRB(
              Spacing.space6,
              Spacing.space4,
              Spacing.space6,
              Spacing.space5,
            ),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: palette.border)),
            ),
            child: version.published
                ? Text(
                    l10n.publishedReadOnly,
                    style: text.bodyMedium!.copyWith(color: palette.textMuted),
                  )
                : Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: Spacing.space4,
                    runSpacing: Spacing.space3,
                    children: <Widget>[
                      FilledButton.icon(
                        onPressed:
                            (widget.isAdmin &&
                                report != null &&
                                report.canPublish &&
                                !_busy)
                            ? _publish
                            : null,
                        icon: const Icon(Icons.cloud_upload_outlined),
                        label: Text(l10n.publishButton),
                      ),
                      if (!(widget.isAdmin &&
                          report != null &&
                          report.canPublish))
                        Text(
                          widget.isAdmin
                              ? l10n.publishHint
                              : l10n.adminOnlyForms,
                          style: text.bodySmall!.copyWith(
                            color: palette.textMuted,
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
