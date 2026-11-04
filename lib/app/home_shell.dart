import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/widgets/widgets.dart';

/// Five-tab shell. Back on a non-Home tab returns to Home first (Android convention).
class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: shell.currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && shell.currentIndex != 0) shell.goBranch(0);
      },
      child: Scaffold(
        extendBody: true,
        body: shell,
        bottomNavigationBar: TsBottomNav(
          items: TsBottomNav.defaultItems,
          selected: shell.currentIndex,
          onSelected: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
        ),
      ),
    );
  }
}
