import 'package:flutter/material.dart';
import 'package:obhijatra_manager/l10n/app_localizations.dart';
import 'package:obhijatra_ui/obhijatra_ui.dart';

/// A centred spinner with a spoken and visible "Loading" label.
class LoadingBlock extends StatelessWidget {
  /// Creates the block.
  const LoadingBlock({super.key, this.compact = false});

  /// Less padding, for small spaces such as a side panel.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final label = AppLocalizations.of(context).loading;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(compact ? Spacing.space2 : Spacing.space8),
        child: Semantics(
          label: label,
          liveRegion: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              const SizedBox(height: Spacing.space3),
              ExcludeSemantics(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
