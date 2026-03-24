import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class CommunityBadge extends StatelessWidget {
  const CommunityBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: context.colors.info.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.colors.info.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.people_outline_rounded,
            size: 14,
            color: context.colors.info,
          ),
          const SizedBox(width: 4),
          Text(
            'Topluluk Katkısı',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: context.colors.info,
            ),
          ),
        ],
      ),
    );
  }
}
