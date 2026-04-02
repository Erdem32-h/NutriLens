import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/product_entity.dart';
import '../providers/product_provider.dart';
import 'additive_chip.dart';

class AdditiveClassification extends ConsumerWidget {
  final ProductEntity product;

  const AdditiveClassification({super.key, required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final additivesAsync = ref.watch(
      additivesByCodesProvider(product.additivesTags),
    );

    return additivesAsync.when(
      loading: () => _buildLoading(context),
      error: (_, _) => _buildWithDefaults(context),
      data: (additives) => _buildContent(context, additives),
    );
  }

  Widget _buildLoading(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.colors.border),
      ),
      child: Center(
        child: CircularProgressIndicator(
          color: context.colors.primary,
          strokeWidth: 2,
        ),
      ),
    );
  }

  Widget _buildWithDefaults(BuildContext context) {
    final grouped = <int, List<String>>{};
    for (final code in product.additivesTags) {
      final riskLevel = 3;
      grouped.putIfAbsent(riskLevel, () => []).add(code);
    }
    return _buildContentFromMap(context, grouped);
  }

  Widget _buildContent(BuildContext context, Map<String, int> additiveRisks) {
    final grouped = <int, List<String>>{};
    for (final entry in additiveRisks.entries) {
      grouped.putIfAbsent(entry.value, () => []).add(entry.key);
    }
    return _buildContentFromMap(context, grouped);
  }

  Widget _buildContentFromMap(
    BuildContext context,
    Map<int, List<String>> grouped,
  ) {
    if (grouped.isEmpty || grouped.values.every((list) => list.isEmpty)) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.colors.surfaceCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.colors.border),
        ),
        child: Text(
          'Bu üründe katkı maddesi bulunmuyor',
          style: TextStyle(fontSize: 14, color: context.colors.textMuted),
        ),
      );
    }

    final sortedLevels = grouped.keys.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final level in sortedLevels) ...[
          _buildRiskSection(context, level, grouped[level]!),
        ],
      ],
    );
  }

  Widget _buildRiskSection(
    BuildContext context,
    int level,
    List<String> additives,
  ) {
    final label = _getRiskLabel(level);
    final color = context.colors.riskColor(level);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '(${additives.length})',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.colors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: additives
                .map((code) => AdditiveChip(eCode: code, riskLevel: level))
                .toList(),
          ),
        ],
      ),
    );
  }

  String _getRiskLabel(int level) {
    return switch (level) {
      1 => 'Düşük Risk',
      2 => 'Kabul Edilebilir',
      3 => 'Orta Risk',
      4 => 'Yüksek Risk',
      _ => 'Tehlikeli',
    };
  }
}
