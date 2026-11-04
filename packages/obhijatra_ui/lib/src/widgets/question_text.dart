import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:obhijatra_ui/src/theme/obhijatra_theme.dart';
import 'package:obhijatra_ui/src/widgets/question_frame.dart';

/// What kind of text a [QuestionText] takes.
enum QuestionTextKind {
  /// Any words.
  text,

  /// A whole number (English or Bangla digits).
  integer,

  /// A number with a decimal point (English or Bangla digits).
  decimal,
}

/// A question answered by typing: words, a whole number or a decimal.
///
/// Give the widget a new [key] when the question changes, so the field
/// starts again from [value].
class QuestionText extends StatefulWidget {
  /// Creates the question.
  const QuestionText({
    required this.label,
    required this.onChanged,
    this.kind = QuestionTextKind.text,
    this.value,
    this.number,
    this.requiredLabel,
    this.help,
    this.errorText,
    this.onSubmitted,
    super.key,
  });

  /// The question.
  final String label;

  /// Called with the text after every change.
  final ValueChanged<String> onChanged;

  /// Called when the person presses "done" on the keyboard.
  final VoidCallback? onSubmitted;

  /// What kind of answer it is.
  final QuestionTextKind kind;

  /// The answer so far.
  final String? value;

  /// The question number, for example "4.".
  final String? number;

  /// The "required" word, or `null` when optional.
  final String? requiredLabel;

  /// Help text.
  final String? help;

  /// Why the answer was not accepted.
  final String? errorText;

  @override
  State<QuestionText> createState() => _QuestionTextState();
}

class _QuestionTextState extends State<QuestionText> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value ?? '',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ASCII and Bangla digits, plus the dot (and minus for whole numbers).
  static final RegExp _integerChars = RegExp(r'[0-9০-৯\-]');
  static final RegExp _decimalChars = RegExp(r'[0-9০-৯.\-]');

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final kind = widget.kind;
    final hasError = widget.errorText != null;
    return QuestionFrame(
      label: widget.label,
      number: widget.number,
      requiredLabel: widget.requiredLabel,
      help: widget.help,
      errorText: widget.errorText,
      child: Semantics(
        label: widget.label,
        textField: true,
        child: TextField(
          controller: _controller,
          onChanged: widget.onChanged,
          onSubmitted: (_) => widget.onSubmitted?.call(),
          keyboardType: switch (kind) {
            QuestionTextKind.text => TextInputType.multiline,
            QuestionTextKind.integer => const TextInputType.numberWithOptions(
              signed: true,
            ),
            QuestionTextKind.decimal => const TextInputType.numberWithOptions(
              decimal: true,
              signed: true,
            ),
          },
          textInputAction: kind == QuestionTextKind.text
              ? TextInputAction.newline
              : TextInputAction.done,
          inputFormatters: switch (kind) {
            QuestionTextKind.text => null,
            QuestionTextKind.integer => <TextInputFormatter>[
              FilteringTextInputFormatter.allow(_integerChars),
            ],
            QuestionTextKind.decimal => <TextInputFormatter>[
              FilteringTextInputFormatter.allow(_decimalChars),
            ],
          },
          minLines: 1,
          maxLines: kind == QuestionTextKind.text ? 4 : 1,
          style: Theme.of(context).textTheme.bodyLarge,
          decoration: InputDecoration(
            isDense: false,
            enabledBorder: hasError
                ? OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: p.danger, width: 2),
                  )
                : null,
          ),
        ),
      ),
    );
  }
}
