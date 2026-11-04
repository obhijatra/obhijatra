import 'package:flutter/material.dart';
import 'package:obhijatra_ui/obhijatra_ui.dart';

/// A text field with its label above it, for sign-in and server address
/// screens. Larger than 48 dp, with a message in plain words under it.
class LabeledField extends StatelessWidget {
  /// Creates the field.
  const LabeledField({
    required this.label,
    required this.controller,
    this.help,
    this.errorText,
    this.keyboardType,
    this.obscureText = false,
    this.suffix,
    this.autofillHints,
    this.textInputAction,
    this.onSubmitted,
    this.onChanged,
    this.autocorrect = false,
    this.fieldKey,
    super.key,
  });

  /// The label above the field.
  final String label;

  /// Holds the typed text.
  final TextEditingController controller;

  /// Help text under the label.
  final String? help;

  /// A message in plain words when the text is not accepted.
  final String? errorText;

  /// The keyboard to show.
  final TextInputType? keyboardType;

  /// Whether to hide the text (passwords).
  final bool obscureText;

  /// A button at the end of the field (show or hide a password).
  final Widget? suffix;

  /// Hints for the phone's autofill.
  final Iterable<String>? autofillHints;

  /// What the keyboard's action key does.
  final TextInputAction? textInputAction;

  /// Called when the action key is pressed.
  final ValueChanged<String>? onSubmitted;

  /// Called on every change.
  final ValueChanged<String>? onChanged;

  /// Whether the keyboard may correct the text.
  final bool autocorrect;

  /// A key for the text field itself, for tests.
  final Key? fieldKey;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return QuestionFrame(
      label: label,
      help: help,
      errorText: errorText,
      child: Semantics(
        label: label,
        textField: true,
        child: TextField(
          key: fieldKey,
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          autofillHints: autofillHints,
          textInputAction: textInputAction,
          onSubmitted: onSubmitted,
          onChanged: onChanged,
          autocorrect: autocorrect,
          enableSuggestions: !obscureText,
          style: Theme.of(context).textTheme.bodyLarge,
          decoration: InputDecoration(
            suffixIcon: suffix,
            enabledBorder: errorText != null
                ? OutlineInputBorder(
                    borderRadius: Radii.smAll,
                    borderSide: BorderSide(color: p.danger, width: 2),
                  )
                : null,
          ),
        ),
      ),
    );
  }
}
