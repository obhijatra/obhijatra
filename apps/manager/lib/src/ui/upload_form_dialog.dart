import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obhijatra_manager/l10n/app_localizations.dart';
import 'package:obhijatra_manager/src/data/models.dart';
import 'package:obhijatra_manager/src/data/problem.dart';
import 'package:obhijatra_manager/src/state/file_picker.dart';
import 'package:obhijatra_manager/src/state/providers.dart';
import 'package:obhijatra_manager/src/xform/publish_checks.dart';
import 'package:obhijatra_manager/widgets/ob_badge.dart';
import 'package:obhijatra_manager/widgets/problem_view.dart';
import 'package:obhijatra_manager/widgets/publish_check_list.dart';
import 'package:obhijatra_ui/obhijatra_ui.dart';

/// The largest file the server accepts for a form.
const int maxFormBytes = 10 * 1024 * 1024;

/// Checks an XForm for upload: the form's existing versions are taken into
/// account so that uploading the same version twice is caught early.
PublishReport checkForUpload(
  String xml,
  List<FormSummary> forms, {
  required String lang,
}) {
  final first = checkXForm(xml, lang: lang);
  if (first.formId.isEmpty) return first;
  final existing = forms
      .where((form) => form.formId == first.formId)
      .expand((form) => form.versions)
      .map((version) => version.version);
  return checkXForm(xml, existingVersions: existing, lang: lang);
}

/// Opens the upload dialog. Returns the new draft version, or null.
Future<FormVersion?> showUploadFormDialog(BuildContext context) =>
    showDialog<FormVersion>(
      context: context,
      builder: (context) => const UploadFormDialog(),
    );

/// Choose an XForm, see the publish check, then save it as a draft.
class UploadFormDialog extends ConsumerStatefulWidget {
  /// Creates the dialog.
  const UploadFormDialog({super.key});

  @override
  ConsumerState<UploadFormDialog> createState() => _UploadFormDialogState();
}

class _UploadFormDialogState extends ConsumerState<UploadFormDialog> {
  PickedFile? _file;
  PublishReport? _report;
  bool _spreadsheet = false;
  bool _busy = false;
  AppProblem? _problem;

  Future<void> _choose() async {
    final picked = await ref.read(formFilePickerProvider).pickFormFile();
    if (picked == null || !mounted) return;
    final lang = Localizations.localeOf(context).languageCode;
    final forms =
        ref.read(formsProvider).asData?.value ?? const <FormSummary>[];
    final lower = picked.name.toLowerCase();
    if (lower.endsWith('.xlsx') || lower.endsWith('.xls')) {
      setState(() {
        _file = picked;
        _report = null;
        _spreadsheet = true;
        _problem = null;
      });
      return;
    }
    if (picked.bytes.length > maxFormBytes) {
      setState(() {
        _file = picked;
        _report = null;
        _spreadsheet = false;
        _problem = const AppProblem(ProblemKind.tooLarge);
      });
      return;
    }
    String xml;
    try {
      xml = utf8.decode(picked.bytes);
      if (xml.startsWith('﻿')) xml = xml.substring(1);
    } on FormatException {
      setState(() {
        _file = picked;
        _report = null;
        _spreadsheet = false;
        _problem = const AppProblem(ProblemKind.unreadableFile);
      });
      return;
    }
    setState(() {
      _file = picked;
      _spreadsheet = false;
      _problem = null;
      _report = checkForUpload(xml, forms, lang: lang);
    });
  }

  Future<void> _upload() async {
    final report = _report;
    final file = _file;
    if (report == null || file == null || !report.canPublish || _busy) return;
    setState(() {
      _busy = true;
      _problem = null;
    });
    try {
      final version = await trackedUi(
        ref,
        () => ref
            .read(apiProvider)
            .uploadDraft(
              formId: report.formId,
              title: report.title,
              version: report.version,
              xmlBytes: file.bytes,
            ),
      );
      if (mounted) Navigator.of(context).pop(version);
    } on AppProblem catch (problem) {
      if (mounted) {
        setState(() {
          _problem = problem;
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final palette = context.palette;
    final report = _report;
    final chosen = _file != null;
    return AlertDialog(
      title: Text(l10n.formsUploadTitle),
      scrollable: true,
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (!chosen)
              Text(l10n.uploadChoosePrompt, style: text.bodyMedium)
            else ...<Widget>[
              Text(l10n.uploadFile(_file!.name), style: text.titleSmall),
              const SizedBox(height: Spacing.space3),
            ],
            if (_spreadsheet)
              _Notice(
                message: l10n.uploadXlsNotice,
                tone: Tone.warning,
                icon: Icons.table_chart_outlined,
              ),
            if (report != null) ...<Widget>[
              Text(
                publishSummary(context, report),
                style: text.bodyMedium!.copyWith(color: palette.textMuted),
              ),
              const SizedBox(height: Spacing.space2),
              _Notice(
                message: report.canPublish
                    ? l10n.uploadReady
                    : l10n.uploadBlocked,
                tone: report.canPublish ? Tone.success : Tone.danger,
                icon: report.canPublish
                    ? Icons.check_circle_outline
                    : Icons.cancel_outlined,
              ),
              const SizedBox(height: Spacing.space2),
              PublishCheckList(report: report),
            ],
            if (_problem != null) ...<Widget>[
              const SizedBox(height: Spacing.space3),
              ProblemBanner(
                problem: _problem!,
                onAction: () => switch (_problem!.action) {
                  ProblemAction.chooseFile => _choose(),
                  ProblemAction.tryAgain => _upload(),
                  _ => Navigator.of(context).pop(),
                },
              ),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        if (chosen)
          OutlinedButton(
            onPressed: _busy ? null : _choose,
            child: Text(l10n.actionChooseFile),
          )
        else
          FilledButton.icon(
            onPressed: _choose,
            icon: const Icon(Icons.upload_file),
            label: Text(l10n.formsChooseFile),
          ),
        if (chosen)
          FilledButton(
            onPressed: (report != null && report.canPublish && !_busy)
                ? _upload
                : null,
            child: Text(_busy ? l10n.uploadUploading : l10n.uploadButton),
          ),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.message,
    required this.tone,
    required this.icon,
  });

  final String message;
  final Tone tone;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      margin: const EdgeInsets.only(bottom: Spacing.space2),
      padding: const EdgeInsets.all(Spacing.space3),
      decoration: BoxDecoration(
        color: tone.background(palette),
        borderRadius: Radii.smAll,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: Sizes.icon, color: tone.foreground(palette)),
          const SizedBox(width: Spacing.space2),
          Expanded(
            child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
