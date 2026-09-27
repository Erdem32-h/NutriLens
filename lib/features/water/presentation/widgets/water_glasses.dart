import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/extensions/l10n_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../water_actions.dart';

/// Row of glasses: filled ones are logged, the first empty one carries a
/// "+" and logs a glass, tapping the last filled one takes it back.
class WaterGlasses extends ConsumerWidget {
  final int glasses;
  final int goal;
  final double glassWidth;

  const WaterGlasses({
    super.key,
    required this.glasses,
    required this.goal,
    this.glassWidth = 22,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = context.l10n;
    final met = glasses >= goal;
    final water = met ? colors.primary : colors.cozy.sky.ink;
    // ponytail: no upper cap; past goal we keep appending one empty glass.
    final slots = glasses >= goal ? glasses + 1 : goal;

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 2,
      runSpacing: 2,
      children: [
        for (var i = 0; i < slots; i++)
          _Glass(
            key: ValueKey('water-glass-$i'),
            filled: i < glasses,
            showPlus: i == glasses,
            width: glassWidth,
            water: water,
            outline: colors.border,
            plus: colors.cozy.sky.ink,
            semanticLabel: i == glasses ? l10n.waterAddGlass : null,
            onTap: i == glasses
                ? () => addWaterGlass(context, ref)
                : i == glasses - 1
                ? () => removeWaterGlass(context, ref)
                : null,
          ),
      ],
    );
  }
}

class _Glass extends StatelessWidget {
  final bool filled;
  final bool showPlus;
  final double width;
  final Color water;
  final Color outline;
  final Color plus;
  final String? semanticLabel;
  final VoidCallback? onTap;

  const _Glass({
    super.key,
    required this.filled,
    required this.showPlus,
    required this.width,
    required this.water,
    required this.outline,
    required this.plus,
    required this.semanticLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final size = Size(width, width * 1.3);
    final glass = TweenAnimationBuilder<double>(
      tween: Tween(end: filled ? 1 : 0),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      builder: (context, level, child) => CustomPaint(
        size: size,
        painter: _GlassPainter(level: level, water: water, outline: outline),
        child: child,
      ),
      child: SizedBox.fromSize(
        size: size,
        child: showPlus
            ? Icon(Icons.add_rounded, size: width * 0.55, color: plus)
            : null,
      ),
    );

    return Semantics(
      button: semanticLabel != null,
      label: semanticLabel,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: width,
        child: Padding(padding: const EdgeInsets.all(4), child: glass),
      ),
    );
  }
}

class _GlassPainter extends CustomPainter {
  final double level;
  final Color water;
  final Color outline;

  _GlassPainter({
    required this.level,
    required this.water,
    required this.outline,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final inset = w * 0.12;
    final body = Path()
      ..moveTo(0, 0)
      ..lineTo(w, 0)
      ..lineTo(w - inset, h)
      ..lineTo(inset, h)
      ..close();

    if (level > 0) {
      final top = h - (h * 0.82 * level);
      canvas.save();
      canvas.clipPath(body);
      canvas.drawRect(
        Rect.fromLTRB(0, top, w, h),
        Paint()..color = water,
      );
      canvas.restore();
    }

    canvas.drawPath(
      body,
      Paint()
        ..color = level > 0.5 ? water : outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_GlassPainter old) =>
      old.level != level || old.water != water || old.outline != outline;
}
