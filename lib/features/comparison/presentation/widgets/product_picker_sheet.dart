import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/score_constants.dart';
import '../../../../core/extensions/l10n_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../history/data/datasources/scan_history_local_datasource.dart';
import '../../../history/presentation/providers/history_provider.dart';

/// Bottom sheet that lists favorites + recent scans so the user can pick the
/// SECOND product to compare against [excludeBarcode]. Returns the chosen
/// barcode (or null if dismissed).
class ProductPickerSheet extends ConsumerWidget {
  final String excludeBarcode;

  const ProductPickerSheet({super.key, required this.excludeBarcode});

  /// Opens the sheet and resolves to the picked barcode, or null.
  static Future<String?> show(
    BuildContext context, {
    required String excludeBarcode,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ProductPickerSheet(excludeBarcode: excludeBarcode),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = context.colors;
    final favoritesAsync = ref.watch(favoritesProvider);
    final historyAsync = ref.watch(scanHistoryProvider);

    // Merge favorites + history, dedupe by barcode, drop the current product.
    final List<ScanHistoryWithProduct> items = [
      ...favoritesAsync.asData?.value ?? const [],
      ...historyAsync.asData?.value ?? const [],
    ];
    final seen = <String>{excludeBarcode};
    final picks = <ScanHistoryWithProduct>[];
    for (final it in items) {
      if (seen.add(it.barcode)) picks.add(it);
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (ctx, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colors.surfaceCard,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: colors.textMuted.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l10n.comparePickSecond,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: picks.isEmpty
                    ? Center(
                        child: Text(
                          l10n.comparePickerEmpty,
                          style: TextStyle(color: colors.textMuted),
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount: picks.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 8),
                        itemBuilder: (_, i) => _PickTile(
                          item: picks[i],
                          onTap: () => Navigator.pop(ctx, picks[i].barcode),
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PickTile extends StatelessWidget {
  final ScanHistoryWithProduct item;
  final VoidCallback onTap;

  const _PickTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final gauge = ScoreConstants.hpToGauge(item.effectiveHpScore);
    final gaugeColor = colors.gaugeColor(gauge);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: item.imageUrl != null
                  ? Image.network(
                      item.imageUrl!,
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, error, stackTrace) =>
                          Icon(Icons.image_outlined, color: colors.textMuted),
                    )
                  : Icon(Icons.image_outlined, color: colors.textMuted),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.productName ?? item.barcode,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
            ),
            if (item.effectiveHpScore != null) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: gaugeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$gauge/5',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: gaugeColor,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
