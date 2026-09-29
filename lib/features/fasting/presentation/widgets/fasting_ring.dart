import 'package:flutter/material.dart';

import '../../../../core/theme/cozy_tokens.dart';

/// Circular fast-progress indicator, shared by [FastingScreen] and
/// [FastingCard]. Dumb by design — takes a plain 0..1 [progress] rather than
/// a session/clock, so ticking stays owned by each caller's own
/// `Stream.periodic` (screen ring, meals-tab card) instead of a third timer
/// living in here.
class FastingRing extends StatelessWidget {
  final double progress;
  final CozyTint tint;
  final double size;
  final double strokeWidth;

  /// Track behind the arc; defaults to `tint.surface`. Callers drawing the
  /// ring on a `tint.surface` card must pass another colour, otherwise the
  /// track vanishes and a fresh (progress 0) fast shows as a lone dot.
  final Color? trackColor;
  final Widget? child;

  const FastingRing({
    super.key,
    required this.progress,
    required this.tint,
    this.size = 160,
    this.strokeWidth = 10,
    this.trackColor,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              strokeWidth: strokeWidth,
              backgroundColor: trackColor ?? tint.surface,
              valueColor: AlwaysStoppedAnimation<Color>(tint.ink),
              strokeCap: StrokeCap.round,
            ),
          ),
          if (child != null)
            Padding(padding: const EdgeInsets.all(12), child: child),
        ],
      ),
    );
  }
}
