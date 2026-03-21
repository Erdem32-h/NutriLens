import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/extensions/l10n_extension.dart';
import '../../core/theme/app_colors.dart';

class AppShellScreen extends StatelessWidget {
  final Widget child;

  const AppShellScreen({super.key, required this.child});

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    const paths = ['/scanner', '/history', '/favorites', '/profile'];
    for (var i = 0; i < paths.length; i++) {
      if (location.startsWith(paths[i])) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _currentIndex(context);
    final l10n = context.l10n;
    const paths = ['/scanner', '/history', '/favorites', '/profile'];

    return Scaffold(
      backgroundColor: context.colors.background,
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: context.colors.surface,
          border: Border(
            top: BorderSide(color: context.colors.border, width: 0.5),
          ),
        ),
        child: NavigationBar(
          selectedIndex: currentIndex,
          onDestinationSelected: (index) {
            if (index != currentIndex) context.go(paths[index]);
          },
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.qr_code_scanner_outlined),
              selectedIcon: const Icon(Icons.qr_code_scanner),
              label: l10n.scanner,
            ),
            NavigationDestination(
              icon: const Icon(Icons.history_outlined),
              selectedIcon: const Icon(Icons.history),
              label: l10n.history,
            ),
            NavigationDestination(
              icon: const Icon(Icons.favorite_outline),
              selectedIcon: const Icon(Icons.favorite),
              label: l10n.favorites,
            ),
            NavigationDestination(
              icon: const Icon(Icons.person_outline),
              selectedIcon: const Icon(Icons.person),
              label: l10n.profile,
            ),
          ],
        ),
      ),
    );
  }
}