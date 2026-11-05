import 'package:flutter/material.dart';
import 'package:obhijatra_manager/l10n/app_localizations.dart';
import 'package:obhijatra_manager/src/data/people.dart';
import 'package:obhijatra_manager/widgets/ob_badge.dart';
import 'package:obhijatra_ui/obhijatra_ui.dart';

/// A role in plain words, for example "Branch manager".
String roleName(AppLocalizations l10n, String role) => switch (role) {
  'supervisor' => l10n.roleSupervisor,
  'branch_manager' => l10n.roleBranchManager,
  'me' => l10n.roleMe,
  orgAdminRole => l10n.roleOrgAdmin,
  'donor_readonly' => l10n.roleDonorReadonly,
  fieldOfficerRole => l10n.roleFieldOfficer,
  _ => role,
};

/// "Office staff" or "Field staff".
String kindName(AppLocalizations l10n, PersonKind kind) => switch (kind) {
  PersonKind.staff => l10n.kindStaff,
  PersonKind.field => l10n.kindField,
};

/// A person's status as small badges, each with a word and an icon:
/// Active or Deactivated, then Locked and "Must choose a password" when
/// they apply.
class PersonStatusChips extends StatelessWidget {
  /// Creates the badges.
  const PersonStatusChips({
    required this.person,
    required this.locked,
    super.key,
  });

  /// Whose status.
  final Person person;

  /// Whether their sign-in is locked now.
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Wrap(
      spacing: Spacing.space1,
      runSpacing: Spacing.space1,
      children: <Widget>[
        if (person.active)
          ObBadge(
            label: l10n.statusActive,
            tone: Tone.success,
            icon: Icons.check_circle_outline,
          )
        else
          ObBadge(label: l10n.statusDeactivated, icon: Icons.block),
        if (locked)
          ObBadge(
            label: l10n.statusLocked,
            tone: Tone.danger,
            icon: Icons.lock_outline,
          ),
        if (person.mustChangePassword)
          ObBadge(
            label: l10n.statusMustChoose,
            tone: Tone.warning,
            icon: Icons.key_outlined,
          ),
      ],
    );
  }
}

/// A field that looks like a text field and opens a chooser when pressed:
/// a label above, the value inside and a small arrow at the end.
class PickerField extends StatelessWidget {
  /// Creates the field.
  const PickerField({
    required this.label,
    required this.value,
    required this.onTap,
    this.helper,
    this.error,
    this.placeholder,
    this.marker,
    super.key,
  });

  /// The field's label.
  final String label;

  /// The chosen value, or empty.
  final String value;

  /// A word shown as a badge after the value, for example "Closed".
  final String? marker;

  /// What to show when nothing is chosen.
  final String? placeholder;

  /// Help under the field.
  final String? helper;

  /// A problem with the choice.
  final String? error;

  /// Opens the chooser; null disables the field.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final palette = context.palette;
    final empty = value.isEmpty;
    final shown = empty ? (placeholder ?? '') : value;
    // One node for screen readers: the label, the value, then any help or
    // problem, announced as a button.
    return MergeSemantics(
      child: Semantics(
        button: true,
        enabled: onTap != null,
        child: InkWell(
          onTap: onTap,
          borderRadius: Radii.smAll,
          child: InputDecorator(
            isEmpty: false,
            decoration: InputDecoration(
              labelText: label,
              helperText: helper,
              helperMaxLines: 3,
              errorText: error,
              errorMaxLines: 3,
              enabled: onTap != null,
              suffixIcon: const Icon(Icons.arrow_drop_down),
            ),
            child: Wrap(
              spacing: Spacing.space2,
              runSpacing: Spacing.space1,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                Text(
                  shown,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodyLarge!.copyWith(
                    color: empty ? palette.textMuted : palette.text,
                  ),
                ),
                if (marker case final String word)
                  ObBadge(label: word, icon: Icons.block),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
