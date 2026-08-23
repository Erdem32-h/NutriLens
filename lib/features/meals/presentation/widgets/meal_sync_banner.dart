import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/analytics/analytics_event.dart';
import '../../../../core/analytics/analytics_provider.dart';
import '../../../../core/extensions/l10n_extension.dart';
import '../../../../core/providers/monetization_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/meal_sync_banner_provider.dart';

/// Dismissible strip above the meal list telling a non-premium user their
/// meals are device-local only. Same shape as [CompareHintStrip] (dismiss
/// once, gone forever via SharedPreferences) but tappable — the whole
/// strip, not just an icon, opens the paywall, since this is a conversion
/// nudge rather than a pure feature hint.
class MealSyncBanner extends ConsumerWidget {
  const MealSyncBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPremium = ref.watch(isPremiumProvider);
    final dismissed = ref.watch(mealSyncBannerDismissedProvider);
    if (isPremium || dismissed) return const SizedBox.shrink();

    final colors = context.colors;
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 4, 4, 4),
        decoration: BoxDecoration(
          color: colors.surfaceCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            Icon(Icons.cloud_sync_rounded, size: 18, color: colors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  ref
                      .read(analyticsServiceProvider)
                      .track(
                        FunnelEvents.paywallShown,
                        props: {
                          'trigger': 'feature_gate',
                          'feature': 'meal_sync',
                        },
                      );
                  context.push('/paywall');
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    l10n.mealSyncBannerText,
                    style: TextStyle(fontSize: 12.5, color: colors.textMuted),
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 18),
              color: colors.textMuted,
              tooltip: l10n.compareHintDismiss,
              visualDensity: VisualDensity.compact,
              onPressed: () => dismissMealSyncBanner(ref),
            ),
          ],
        ),
      ),
    );
  }
}
