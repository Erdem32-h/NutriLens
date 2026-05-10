import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/extensions/l10n_extension.dart';
import '../../core/providers/monetization_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/ad_banner_widget.dart';
import 'widgets/nutrilens_nav_bar.dart';

class AppShellScreen extends ConsumerStatefulWidget {
  final Widget child;

  const AppShellScreen({super.key, required this.child});

  @override
  ConsumerState<AppShellScreen> createState() => _AppShellScreenState();
}

class _AppShellScreenState extends ConsumerState<AppShellScreen> {
  @override
  void initState() {
    super.initState();
    // Pre-load rewarded ad for scan limit flow
    final adService = ref.read(adServiceProvider);
    adService.loadRewardedAd();
  }

  // Tab order: 0 meals · 1 history · 2 scanner (center) · 3 favorites · 4 profile
  static const _paths = [
    '/meals',
    '/history',
    '/scanner',
    '/favorites',
    '/profile',
  ];

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    for (var i = 0; i < _paths.length; i++) {
      if (location.startsWith(_paths[i])) return i;
    }
    // Default to scanner — that's the primary action.
    return 2;
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _currentIndex(context);
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: context.colors.background,
      body: Column(
        children: [
          Expanded(child: widget.child),
          const AdBannerWidget(),
        ],
      ),
      bottomNavigationBar: NutriLensNavBar(
        currentIndex: currentIndex,
        onTap: (index) {
          if (index != currentIndex) context.go(_paths[index]);
        },
        mealsLabel: 'Öğünlerim',
        historyLabel: l10n.history,
        scannerLabel: l10n.scanner,
        favoritesLabel: l10n.favorites,
        profileLabel: l10n.profile,
      ),
    );
  }
}
