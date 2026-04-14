import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';

class AdditiveChip extends StatelessWidget {
  final String eCode;
  final String? name;
  final int riskLevel;

  const AdditiveChip({
    super.key,
    required this.eCode,
    this.name,
    required this.riskLevel,
  });

  @override
  Widget build(BuildContext context) {
    final color = context.colors.riskColor(riskLevel);

    return GestureDetector(
      onTap: () => context.pushNamed(
        RouteNames.additiveDetail,
        pathParameters: {'eCode': eCode},
      ),
      child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            eCode,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          if (name != null) ...[
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                name!,
                style: TextStyle(
                  fontSize: 12,
                  color: context.colors.textSecondary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          const SizedBox(width: 6),
          Text(
            '$riskLevel/5',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: context.colors.textMuted,
            ),
          ),
        ],
      ),
    ),
    );
  }
}
