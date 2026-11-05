import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:obhijatra_manager/src/data/phone_number.dart';
import 'package:obhijatra_ui/obhijatra_ui.dart';

/// A mobile number field with `+880` in front, which disappears when the
/// person types a number with its own country code (`+44…`, `00…`).
///
/// It accepts what people type: spaces, hyphens, brackets and Bangla
/// digits. Read the number with `normalisePhone`.
class PhoneNumberField extends StatelessWidget {
  /// Creates the field.
  const PhoneNumberField({
    required this.controller,
    required this.label,
    this.helper,
    this.errorText,
    this.autofocus = false,
    this.enabled = true,
    this.onChanged,
    this.onSubmitted,
    super.key,
  });

  /// Holds the text typed.
  final TextEditingController controller;

  /// The field's label.
  final String label;

  /// Help under the field.
  final String? helper;

  /// A problem with what was typed.
  final String? errorText;

  /// Whether the field takes focus when shown.
  final bool autofocus;

  /// Whether the field can be changed.
  final bool enabled;

  /// Runs on every change.
  final ValueChanged<String>? onChanged;

  /// Runs when the person presses Enter.
  final ValueChanged<String>? onSubmitted;

  static final RegExp _allowed = RegExp('[0-9০-৯+\\-\\s().]');

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyLarge!
        .copyWith(color: context.palette.textMuted);
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) => TextField(
        controller: controller,
        autofocus: autofocus,
        enabled: enabled,
        keyboardType: TextInputType.phone,
        textInputAction: TextInputAction.done,
        autofillHints: const <String>[AutofillHints.telephoneNumber],
        inputFormatters: <TextInputFormatter>[
          FilteringTextInputFormatter.allow(_allowed),
          LengthLimitingTextInputFormatter(24),
        ],
        decoration: InputDecoration(
          labelText: label,
          helperText: helper,
          helperMaxLines: 3,
          errorText: errorText,
          errorMaxLines: 3,
          // The label always sits above the field, so `+880` is always
          // shown, on the same line as the number.
          floatingLabelBehavior: FloatingLabelBehavior.always,
          prefixText: hasOwnCountryCode(value.text)
              ? null
              : '+$defaultCountryCode ',
          prefixStyle: style,
        ),
        onChanged: onChanged,
        onSubmitted: onSubmitted,
      ),
    );
  }
}
