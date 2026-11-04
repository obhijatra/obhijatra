import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obhijatra_manager/l10n/app_localizations.dart';
import 'package:obhijatra_manager/src/state/providers.dart';
import 'package:obhijatra_manager/widgets/focus_ring.dart';
import 'package:obhijatra_ui/obhijatra_ui.dart';

/// The visible English / বাংলা switch. Each name is written in its own
/// language so anyone can find theirs.
class LanguageSwitch extends ConsumerWidget {
  /// Creates the switch.
  const LanguageSwitch({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(localeProvider).languageCode;
    final palette = context.palette;
    return Semantics(
      container: true,
      label: AppLocalizations.of(context).languageSwitch,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: Radii.pillAll,
          border: Border.all(color: palette.borderStrong),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _Segment(
              label: 'English',
              code: 'en',
              selected: current == 'en',
              onSelect: () =>
                  ref.read(localeProvider.notifier).select(const Locale('en')),
            ),
            const SizedBox(width: 2),
            _Segment(
              label: 'বাংলা',
              code: 'bn',
              selected: current == 'bn',
              onSelect: () =>
                  ref.read(localeProvider.notifier).select(const Locale('bn')),
            ),
          ],
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.code,
    required this.selected,
    required this.onSelect,
  });

  final String label;
  final String code;
  final bool selected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    // Each name is set in its own script's font, whatever language is shown.
    final style = ObhijatraTheme.isBangla(Locale(code))
        ? ObhijatraType.bnLabel.toStyle()
        : ObhijatraType.label.toStyle();
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: label,
      excludeSemantics: true,
      onTap: onSelect,
      child: FocusRing(
        borderRadius: Radii.pillAll,
        child: Material(
          color: selected ? palette.action : Colors.transparent,
          borderRadius: Radii.pillAll,
          child: InkWell(
            borderRadius: Radii.pillAll,
            onTap: onSelect,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 36, minWidth: 36),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Spacing.space4),
                child: Center(
                  widthFactor: 1,
                  child: Text(
                    label,
                    style: style.copyWith(
                      color: selected ? palette.onAction : palette.text,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
