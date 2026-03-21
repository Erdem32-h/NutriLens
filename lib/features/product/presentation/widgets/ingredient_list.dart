import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class IngredientList extends StatefulWidget {
  final String? ingredientsText;

  const IngredientList({super.key, required this.ingredientsText});

  @override
  State<IngredientList> createState() => _IngredientListState();
}

class _IngredientListState extends State<IngredientList> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.ingredientsText == null || widget.ingredientsText!.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.colors.surfaceCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.colors.border),
        ),
        child: Text(
          'İçerik bilgisi mevcut değil',
          style: TextStyle(fontSize: 14, color: context.colors.textMuted),
        ),
      );
    }

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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'İçindekiler',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: context.colors.textPrimary,
                ),
              ),
              if (widget.ingredientsText!.length > 150)
                GestureDetector(
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: Text(
                    _expanded ? 'Daralt' : 'Genişlet',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.colors.primary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          AnimatedCrossFade(
            firstChild: Text(
              widget.ingredientsText!,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: context.colors.textSecondary,
                height: 1.6,
              ),
            ),
            secondChild: Text(
              widget.ingredientsText!,
              style: TextStyle(
                fontSize: 13,
                color: context.colors.textSecondary,
                height: 1.6,
              ),
            ),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }
}