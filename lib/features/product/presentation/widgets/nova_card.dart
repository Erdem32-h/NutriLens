import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/nova_badge.dart';

class NovaCard extends StatelessWidget {
  final int? novaGroup;

  const NovaCard({super.key, required this.novaGroup});

  String _novaDescription(int group) {
    return switch (group) {
      1 => 'İşlenmemiş veya minimal işlenmiş gıda',
      2 => 'İşlenmiş mutfak malzemeleri',
      3 => 'İşlenmiş gıda',
      4 => 'Çok işlenmiş gıda ürünleri',
      _ => 'Bilinmiyor',
    };
  }

  @override
  Widget build(BuildContext context) {
    if (novaGroup == null) return const SizedBox.shrink();

    final accentColor = context.colors.novaColor(novaGroup!);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          NovaBadge(novaGroup: novaGroup!, size: 48),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NOVA Grubu',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: context.colors.textMuted,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _novaDescription(novaGroup!),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: context.colors.textPrimary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}