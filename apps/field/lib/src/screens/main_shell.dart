import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obhijatra_field/src/providers/sync_providers.dart';
import 'package:obhijatra_field/src/screens/forms_screen.dart';
import 'package:obhijatra_field/src/screens/more_screen.dart';
import 'package:obhijatra_field/src/screens/sending_screen.dart';
import 'package:obhijatra_field/src/screens/today_screen.dart';
import 'package:obhijatra_field/src/widgets/bottom_nav.dart';

/// The signed-in app: four tabs under one bottom navigation bar.
class MainShell extends ConsumerStatefulWidget {
  /// Creates the shell, showing [initialTab] first.
  const MainShell({this.initialTab = MainTab.today, super.key});

  /// The tab shown first.
  final MainTab initialTab;

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  late MainTab _tab = widget.initialTab;

  @override
  void initState() {
    super.initState();
    // Get new forms and send waiting ones as soon as the app opens.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(ref.read(formsRefreshProvider.notifier).refresh());
      unawaited(syncNow(ref));
    });
  }

  @override
  Widget build(BuildContext context) {
    // Sync on app resume and when the connection returns.
    ref.watch(syncTriggersProvider);
    final nav = AppBottomNav(
      selected: _tab,
      onSelected: (tab) => setState(() => _tab = tab),
    );
    void select(MainTab tab) => setState(() => _tab = tab);
    return switch (_tab) {
      MainTab.today => TodayScreen(nav: nav, onSelectTab: select),
      MainTab.forms => FormsScreen(nav: nav),
      MainTab.sending => SendingScreen(nav: nav),
      MainTab.more => MoreScreen(nav: nav),
    };
  }
}
