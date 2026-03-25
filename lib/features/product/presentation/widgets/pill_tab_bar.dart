import 'package:flutter/material.dart';

import '../../../../core/extensions/l10n_extension.dart';
import '../../../../core/theme/app_colors.dart';

class PillTabBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTabChanged;

  const PillTabBar({
    super.key,
    required this.selectedIndex,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final labels = [l10n.tabHealth, l10n.tabNutrient, l10n.tabAlternative];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: colors.surfaceCard,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: List.generate(labels.length, (index) {
            final isActive = index == selectedIndex;
            return Expanded(
              child: GestureDetector(
                onTap: () => onTabChanged(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isActive ? colors.surface : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                    border: isActive
                        ? Border(
                            bottom: BorderSide(
                              color: colors.primary,
                              width: 2,
                            ),
                          )
                        : null,
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: colors.primary.withValues(alpha: 0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    labels[index],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                      color: isActive ? colors.primary : colors.textMuted,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
