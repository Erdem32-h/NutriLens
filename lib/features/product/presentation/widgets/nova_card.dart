import 'package:flutter/material.dart';

import '../../../../core/widgets/nova_badge.dart';

class NovaCard extends StatelessWidget {
  final int? novaGroup;

  const NovaCard({super.key, required this.novaGroup});

  String _novaDescription(int group) {
    return switch (group) {
      1 => 'Islenmemis veya minimal islenmis gida',
      2 => 'Islenmis mutfak malzemeleri',
      3 => 'Islenmis gida',
      4 => 'Cok islenmis gida urunleri',
      _ => 'Bilinmiyor',
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (novaGroup == null) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _novaDescription(novaGroup!),
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
