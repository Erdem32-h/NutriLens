import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../analytics/analytics_event.dart';
import '../analytics/analytics_provider.dart';
import '../extensions/l10n_extension.dart';
import '../providers/monetization_provider.dart';
import '../theme/app_colors.dart';
import 'app_button.dart';

/// Wraps a free-but-premium-upsell section of content: renders [child]
/// untouched for premium users, blurred with a lock/CTA overlay for
/// everyone else (guest and registered free alike — this gates a feature
/// tier, not an account tier, unlike [GuestGateExtension.requireAuthOr]
/// which gates guest vs. registered).
///
/// The blur — rather than hiding [child] outright — is deliberate: showing
/// the shape of what's behind the lock (a real comparison, a real nutrient
/// table) sells the upgrade harder than a blank "Premium'da" card would.
class PremiumBlurGate extends ConsumerWidget {
  final Widget child;

  /// Short machine tag for the `paywall_shown` `feature` prop (e.g.
  /// `'comparison'`, `'nutrient_detail'`). Never shown to the user.
  final String feature;

  const PremiumBlurGate({
    super.key,
    required this.child,
    required this.feature,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPremium = ref.watch(isPremiumProvider);
    if (isPremium) return child;

    final colors = context.colors;
    final l10n = context.l10n;

    return Stack(
      alignment: Alignment.center,
      children: [
        IgnorePointer(
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: child,
          ),
        ),
        Positioned.fill(
          child: Container(color: colors.background.withValues(alpha: 0.35)),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: BoxDecoration(
              color: colors.surfaceCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_rounded, color: colors.primary, size: 28),
                const SizedBox(height: 10),
                Text(
                  l10n.premiumFeatureLockedTitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 14),
                AppButton(
                  label: l10n.premiumContinueCta,
                  expand: false,
                  onPressed: () {
                    ref
                        .read(analyticsServiceProvider)
                        .track(
                          FunnelEvents.paywallShown,
                          props: {'trigger': 'feature_gate', 'feature': feature},
                        );
                    context.push('/paywall');
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
