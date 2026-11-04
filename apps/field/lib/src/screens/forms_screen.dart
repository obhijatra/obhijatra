import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:obhijatra_core/obhijatra_core.dart';
import 'package:obhijatra_field/l10n/app_localizations.dart';
import 'package:obhijatra_field/src/forms/form_entry_controller.dart';
import 'package:obhijatra_field/src/providers/data_providers.dart';
import 'package:obhijatra_field/src/providers/locale_provider.dart';
import 'package:obhijatra_field/src/providers/platform_providers.dart';
import 'package:obhijatra_field/src/screens/form_entry_screen.dart';
import 'package:obhijatra_field/src/screens/today_screen.dart';
import 'package:obhijatra_field/src/util/bangla.dart' as fmt;
import 'package:obhijatra_field/src/widgets/screen_frame.dart';
import 'package:obhijatra_ui/obhijatra_ui.dart';

/// Drafts to continue, and every form on the phone.
class FormsScreen extends ConsumerWidget {
  /// Creates the screen with the bottom bar [nav].
  const FormsScreen({required this.nav, super.key});

  /// The bottom navigation bar.
  final Widget nav;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final bangla = ref.watch(localeProvider).languageCode == 'bn';
    final now = ref.watch(nowProvider)();
    final forms = ref.watch(cachedFormsProvider).value ?? const <CachedForm>[];
    final drafts = ref.watch(draftsProvider).value ?? const <Draft>[];
    final titles = <String, String>{
      for (final f in forms) f.formId: formTitleOf(f),
    };
    return ScreenFrame(
      topBar: TopBar(title: l.navForms),
      bottomNavigation: nav,
      body: ListView(
        padding: const EdgeInsets.all(Spacing.space4),
        children: <Widget>[
          if (drafts.isNotEmpty) ...<Widget>[
            Semantics(
              header: true,
              child: Text(l.draftsHeading, style: text.headlineMedium),
            ),
            const SizedBox(height: Spacing.space3),
            for (final draft in drafts) ...<Widget>[
              ActionCard(
                icon: LucideIcons.pencil,
                title: titles[draft.formId] ?? draft.formId,
                meta: l.draftSavedAt(
                  fmt.when(draft.updatedAt, bangla: bangla, now: now),
                ),
                onTap: () => unawaited(
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => FormEntryScreen(
                        args: FormEntryArgs(
                          formId: draft.formId,
                          draftInstanceId: draft.instanceId,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: Spacing.space2),
            ],
            const SizedBox(height: Spacing.space4),
          ],
          Semantics(
            header: true,
            child: Text(l.formsToFill, style: text.headlineMedium),
          ),
          const SizedBox(height: Spacing.space3),
          if (forms.isEmpty)
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(l.formsEmptyTitle, style: text.titleMedium),
                  const SizedBox(height: Spacing.space2),
                  Text(l.formsEmptyBody, style: text.bodyMedium),
                ],
              ),
            )
          else
            for (final form in forms) ...<Widget>[
              ActionCard(
                icon: LucideIcons.clipboardList,
                title: formTitleOf(form),
                meta: l.formMetaNew,
                onTap: () => startForm(context, form.formId),
              ),
              const SizedBox(height: Spacing.space2),
            ],
        ],
      ),
    );
  }
}
