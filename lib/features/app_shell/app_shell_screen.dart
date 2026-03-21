import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/extensions/l10n_extension.dart';

class AppShellScreen extends StatelessWidget {
  final Widget child;

  const AppShellScreen({super.key, required this.child});

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final paths = ['/scanner', '/history', '/favorites', '/profile'];
    for (var i = 0; i < paths.length; i++) {
      if (location.startsWith(paths[i])) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _currentIndex(context);
    final l10n = context.l10n;
    final paths = ['/scanner', '/history', '/favorites', '/profile'];

    final tabs = [
      BottomNavigationBarItem(
        icon: const Icon(Icons.qr_code_scanner),
        label: l10n.scanner,
      ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.history),
        label: l10n.history,
      ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.favorite_outline),
        label: l10n.favorites,
      ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.person_outline),
        label: l10n.profile,
      ),
    ];

    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) {
          if (index != currentIndex) {
            context.go(paths[index]);
          }
        },
        items: tabs,
      ),
    );
  }
}
