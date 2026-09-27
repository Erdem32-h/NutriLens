import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/extensions/l10n_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_tap_card.dart';
import '../../../../core/widgets/cozy_tile.dart';
import '../../../water/presentation/water_actions.dart';
import '../../domain/fasting_times.dart';
import '../../domain/ramadan_calendar.dart';
import '../ramadan_actions.dart';
import '../providers/ramadan_provider.dart';
import 'city_picker_sheet.dart';

/// Sahur/iftar countdown on the Meals tab, visible whenever the mode is on
/// and today falls inside the current Ramadan window (regardless of the
/// earlier offer window). Ticks every minute so it never shows a stale
/// countdown across midnight; recomputes imsak/iftar from the stored
/// location and the current clock on every tick rather than reading the
/// cached `fastingToday`/`fastingTomorrowProvider` (those are only
/// refreshed on `onResume` — see `RamadanController.onResume`).
class RamadanCountdownCard extends ConsumerStatefulWidget {
  const RamadanCountdownCard({super.key});

  @override
  ConsumerState<RamadanCountdownCard> createState() =>
      _RamadanCountdownCardState();
}

class _RamadanCountdownCardState extends ConsumerState<RamadanCountdownCard> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final settings = ref.watch(ramadanSettingsProvider);
    final now = ref.watch(ramadanClockProvider)();
    final period = currentRamadan(now);
    if (!settings.enabled || period == null) return const SizedBox.shrink();

    final tint = colors.cozy.lilac;
    final location = settings.location;

    if (location == null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: AppTapCard(
          onTap: () => _pickLocation(context),
          semanticLabel: l10n.ramadanChooseLocation,
          borderRadius: BorderRadius.circular(24),
          decoration: cozyCardDecoration(context).copyWith(color: tint.surface),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.location_on_rounded, color: tint.ink),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.ramadanChooseLocation,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: tint.ink),
              ],
            ),
          ),
        ),
      );
    }

    // Countdown target: today's imsak if still ahead of `now`, else today's
    // iftar if that's still ahead, else tomorrow's imsak. This is the
    // fasting-cycle order (imsak -> iftar -> next imsak) rather than a
    // single "before today's iftar" check, so the early-morning hours
    // before imsak correctly count down to sahur rather than to the
    // (much later) iftar.
    final today = fastingTimes(now, location.lat, location.lng);
    final DateTime target;
    final bool isIftar;
    if (now.isBefore(today.imsak)) {
      target = today.imsak;
      isIftar = false;
    } else if (now.isBefore(today.iftar)) {
      target = today.iftar;
      isIftar = true;
    } else {
      final tomorrow = fastingTimes(
        DateTime(now.year, now.month, now.day + 1),
        location.lat,
        location.lng,
      );
      target = tomorrow.imsak;
      isIftar = false;
    }

    final diffMinutes = target.difference(now).inMinutes;
    final h = diffMinutes ~/ 60;
    final m = diffMinutes % 60;
    final countdownText = isIftar
        ? l10n.ramadanUntilIftar(h, m)
        : l10n.ramadanUntilSahur(h, m);

    final timeFormat = DateFormat('HH:mm');
    final fastedToday =
        (ref.watch(fastingDaysProvider).value ?? const {}).contains(
          ramadanDayKey(now),
        );

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Container(
        padding: const EdgeInsets.all(16),
        // No `onTap`: the day-detail route (`/ramadan`) doesn't exist yet
        // (Task 8) — this card is read-only until then.
        decoration: cozyCardDecoration(context).copyWith(color: tint.surface),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.nightlight_round, color: tint.ink),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    countdownText,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              l10n.ramadanImsakIftar(
                timeFormat.format(today.imsak),
                timeFormat.format(today.iftar),
              ),
              style: TextStyle(fontSize: 12, color: colors.textMuted),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => ref
                  .read(ramadanControllerProvider)
                  .setFasted(now, !fastedToday),
              child: Row(
                children: [
                  Icon(
                    fastedToday
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
                    color: tint.ink,
                    size: 20,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    l10n.ramadanFastingToday,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.ramadanTimesDisclaimer,
              style: TextStyle(fontSize: 11, color: colors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickLocation(BuildContext context) async {
    final pick = await showCityPicker(context);
    if (pick == null || !context.mounted) return;
    final l10n = context.l10n;
    await ref
        .read(ramadanControllerProvider)
        .setLocation(
          lat: pick.lat,
          lng: pick.lng,
          label: pick.label,
          plate: pick.plate,
          copy: ramadanCopy(l10n, ref.read(ramadanSettingsProvider).sahurOffsetMin),
          waterCopy: waterReminderCopy(l10n),
        );
  }
}
