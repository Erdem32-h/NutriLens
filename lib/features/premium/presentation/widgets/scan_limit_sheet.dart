import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/monetization_provider.dart';
import '../../../../core/theme/app_colors.dart';

class ScanLimitSheet extends ConsumerWidget {
  const ScanLimitSheet({super.key});

  static Future<bool> show(BuildContext context) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const ScanLimitSheet(),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).extension<AppColorsExtension>()!;
    final adService = ref.read(adServiceProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colors.textSecondary.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // Icon
          Icon(Icons.qr_code_scanner, size: 48, color: colors.warning),
          const SizedBox(height: 16),

          // Title
          Text(
            'Günlük Tarama Hakkın Doldu',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          Text(
            'Premium üyelikle sınırsız tarama yapabilirsin.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.textSecondary,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Premium button
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                Navigator.pop(context, false);
                context.push('/paywall');
              },
              icon: const Icon(Icons.star),
              label: const Text("Premium'a Geç"),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Rewarded ad button
          if (adService.isRewardedAdReady)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final rewarded = await adService.showRewardedAd();
                  if (rewarded && context.mounted) {
                    final scanLimitService = ref.read(scanLimitServiceProvider);
                    final result = await scanLimitService.grantBonusScan();
                    if (result.granted && context.mounted) {
                      Navigator.pop(context, true);
                    }
                  }
                },
                icon: const Icon(Icons.play_circle_outline),
                label: const Text('Reklam İzle → +1 Tarama'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          const SizedBox(height: 8),

          // Close
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }
}
