import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/extensions/l10n_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/cozy_tile.dart' show cozyCardDecoration;
import '../../domain/fasting_session.dart';
import '../fasting_actions.dart';
import '../providers/fasting_provider.dart';
import 'fasting_ring.dart';

/// Meals-tab card: renders nothing unless a fast is active — ring, remaining
/// time, End button. After the target is reached it swaps the countdown for
/// [AppLocalizations.fastingGoalReached]. Ticks every second on its own
/// `Stream.periodic` (mirrors `RamadanCountdownCard`'s per-minute `Timer`),
/// cancelled in [dispose] so no test is left with a pending timer.
class FastingCard extends ConsumerStatefulWidget {
  const FastingCard({super.key});

  @override
  ConsumerState<FastingCard> createState() => _FastingCardState();
}

class _FastingCardState extends ConsumerState<FastingCard> {
  StreamSubscription<void>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = Stream.periodic(const Duration(seconds: 1)).listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = ref.watch(activeFastProvider).value;
    if (active == null) return const SizedBox.shrink();

    final l10n = context.l10n;
    final colors = context.colors;
    final tint = colors.cozy.mint;
    final now = ref.read(fastingClockProvider)();
    final reached = active.reachedTarget(now);

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Container(
        decoration: cozyCardDecoration(context).copyWith(color: tint.surface),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            FastingRing(
              progress: active.progress(now),
              tint: tint,
              size: 56,
              strokeWidth: 6,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                reached
                    ? l10n.fastingGoalReached
                    : l10n.fastingRemaining(
                        formatFastDuration(active.remaining(now)),
                      ),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
            ),
            TextButton(
              onPressed: () => _end(context, active, now),
              child: Text(
                l10n.fastingEnd,
                style: TextStyle(color: tint.ink, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _end(
    BuildContext context,
    FastingSession active,
    DateTime now,
  ) async {
    final proceed = await confirmEndFast(context, active, now);
    if (!proceed) return;
    await ref.read(fastingControllerProvider).end(source: 'button');
  }
}
