import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/analytics/analytics_event.dart';
import '../../../../core/analytics/analytics_provider.dart';
import '../../../../core/extensions/l10n_extension.dart';
import '../../../../core/providers/monetization_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/cozy_tokens.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/cozy_header.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/fasting_protocol.dart';
import '../../domain/fasting_session.dart';
import '../../domain/fasting_stats.dart';
import '../fasting_actions.dart';
import '../providers/fasting_provider.dart';
import '../widgets/fasting_ring.dart';

/// `/fasting`: protocol picker, live ring, Start/End, "last fast" (free),
/// and a streak/average/history section gated behind Premium. Ticks every
/// second on its own `Stream.periodic` so the ring and elapsed/remaining
/// text stay live while the screen is open — cancelled in [dispose].
class FastingScreen extends ConsumerStatefulWidget {
  const FastingScreen({super.key});

  @override
  ConsumerState<FastingScreen> createState() => _FastingScreenState();
}

class _FastingScreenState extends ConsumerState<FastingScreen> {
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
    final l10n = context.l10n;
    final colors = context.colors;
    final tint = colors.cozy.mint;
    final now = ref.read(fastingClockProvider)();
    final active = ref.watch(activeFastProvider).value;
    final protocol = ref.watch(fastingProtocolProvider);
    final blocked = ref.watch(fastingBlockedByRamadanProvider);
    final history = ref.watch(fastingHistoryProvider).value ?? const [];
    final isPremium = ref.watch(isPremiumProvider);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(l10n.fastingTitle),
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            l10n.fastingSubtitle,
            style: TextStyle(fontSize: 13, color: colors.textMuted),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            children: FastingProtocol.values.map((p) {
              return ChoiceChip(
                label: Text(p.label),
                selected: protocol == p,
                onSelected: active != null
                    ? null
                    : (_) => ref.read(fastingControllerProvider).setProtocol(p),
              );
            }).toList(),
          ),
          const SizedBox(height: 28),
          Center(
            child: FastingRing(
              progress: active?.progress(now) ?? 0,
              tint: tint,
              size: 200,
              child: active == null
                  ? null
                  : _RingCenterText(active: active, now: now, l10n: l10n),
            ),
          ),
          const SizedBox(height: 24),
          if (blocked) ...[
            Text(
              l10n.fastingBlockedByRamadan,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: colors.textMuted),
            ),
            const SizedBox(height: 12),
          ],
          AppButton(
            label: active != null ? l10n.fastingEnd : l10n.fastingStart,
            onPressed: active != null
                ? () => _handleEnd(active, now)
                : (blocked ? null : _handleStart),
          ),
          if (history.isNotEmpty) ...[
            const SizedBox(height: 20),
            Center(
              child: Text(
                l10n.fastingLastFast(
                  formatFastDuration(
                    history.first.endedAt!.difference(history.first.startedAt),
                  ),
                ),
                style: TextStyle(fontSize: 13, color: colors.textMuted),
              ),
            ),
          ],
          const SizedBox(height: 32),
          CozySectionLabel(l10n.fastingHistory),
          const SizedBox(height: 8),
          isPremium
              ? _PremiumHistory(history: history, now: now)
              : _PremiumTeaser(tint: tint),
        ],
      ),
    );
  }

  Future<void> _handleStart() async {
    final copy = fastingCopy(context.l10n);
    await ref.read(fastingControllerProvider).start(copy);
    // Blocked/duplicate-active both return `false`; nothing extra to show —
    // the blocked state is already visible via `fastingBlockedByRamadan`.
  }

  Future<void> _handleEnd(FastingSession active, DateTime now) async {
    final proceed = await confirmEndFast(context, active, now);
    if (!proceed) return;
    await ref.read(fastingControllerProvider).end(source: 'button');
  }
}

class _RingCenterText extends StatelessWidget {
  final FastingSession active;
  final DateTime now;
  final AppLocalizations l10n;

  const _RingCenterText({
    required this.active,
    required this.now,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    if (active.reachedTarget(now)) {
      return Text(
        l10n.fastingGoalReached,
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.fastingElapsed(formatFastDuration(active.elapsed(now))),
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        const SizedBox(height: 6),
        Text(
          l10n.fastingRemaining(formatFastDuration(active.remaining(now))),
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
      ],
    );
  }
}

class _PremiumHistory extends StatelessWidget {
  final List<FastingSession> history;
  final DateTime now;

  const _PremiumHistory({required this.history, required this.now});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final streak = fastingStreak(history, now);
    final average = averageFastDuration(history);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final dateFormat = DateFormat('d MMM', locale);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (streak > 0) ...[
          Text(
            l10n.fastingStreak(streak),
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
        ],
        if (average != null) ...[
          Text(
            l10n.fastingAverage(formatFastDuration(average)),
            style: TextStyle(color: colors.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 12),
        ],
        for (final session in history.take(10))
          if (session.endedAt != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    dateFormat.format(session.endedAt!),
                    style: TextStyle(color: colors.textMuted, fontSize: 13),
                  ),
                  Text(
                    formatFastDuration(
                      session.endedAt!.difference(session.startedAt),
                    ),
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

/// Free-tier placeholder: a visually blurred stand-in for the streak/average
/// rows, tapping through to the paywall — the spec's "blurred teaser".
class _PremiumTeaser extends ConsumerWidget {
  final CozyTint tint;

  const _PremiumTeaser({required this.tint});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    return GestureDetector(
      onTap: () => _openPaywall(ref, context),
      child: Stack(
        alignment: Alignment.center,
        children: [
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.fastingStreak(3)),
                const SizedBox(height: 6),
                Text(l10n.fastingAverage('16:00')),
              ],
            ),
          ),
          Text(
            l10n.fastingPremiumTeaser,
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w700, color: tint.ink),
          ),
        ],
      ),
    );
  }

  void _openPaywall(WidgetRef ref, BuildContext context) {
    ref
        .read(analyticsServiceProvider)
        .track(FunnelEvents.ifHistoryPaywallTapped);
    ref
        .read(analyticsServiceProvider)
        .track(FunnelEvents.paywallShown, props: {'source': 'fasting_history'});
    context.push('/paywall');
  }
}
