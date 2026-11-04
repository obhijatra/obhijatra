import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:obhijatra_ui/src/theme/obhijatra_theme.dart';
import 'package:obhijatra_ui/src/tokens/spacing.dart';

/// A full-width band that says the phone is offline and that work is safe.
///
/// Blue ("information"), never red: being offline is normal in the field.
class OfflineBanner extends StatelessWidget {
  /// Creates the banner: [title] in bold, then [message].
  const OfflineBanner({required this.title, required this.message, super.key});

  /// The short bold start, for example "You are offline."
  final String title;

  /// The reassurance after it.
  final String message;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme.bodyMedium!;
    return Semantics(
      container: true,
      liveRegion: true,
      label: '$title $message',
      child: ExcludeSemantics(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.space4,
            vertical: Spacing.space3,
          ),
          decoration: BoxDecoration(
            color: p.infoSubtle,
            border: Border(bottom: BorderSide(color: p.info)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(top: Spacing.space1),
                child: Icon(
                  LucideIcons.wifiOff,
                  size: Sizes.icon,
                  color: p.info,
                ),
              ),
              const SizedBox(width: Spacing.space3),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: <InlineSpan>[
                      TextSpan(
                        text: '$title ',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: p.info,
                        ),
                      ),
                      TextSpan(text: message),
                    ],
                  ),
                  style: text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
