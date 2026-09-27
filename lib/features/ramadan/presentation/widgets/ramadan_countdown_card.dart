import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../config/router/route_names.dart';
import '../../../../core/extensions/l10n_extension.dart';
import '../../../../core/services/notification_service.dart';
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
/// location and the current clock on every tick.
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
    _scheduleTick();
  }

  /// Ticks on every full minute (:00) so the shown minutes change exactly
  /// when the wall clock does, rather than up to a minute late.
  void _scheduleTick() {
    final now = ref.read(ramadanClockProvider)();
    final next = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute + 1,
    );
    _timer = Timer(next.difference(now), () {
      if (!mounted) return;
      setState(() {});
      _scheduleTick();
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
    // (much later) iftar. After the last day's iftar there is no next
    // sahur (tomorrow is Eid), so no countdown is shown.
    final today = fastingTimes(now, location.lat, location.lng);
    final DateTime? target;
    final bool isIftar;
    if (now.isBefore(today.imsak)) {
      target = today.imsak;
      isIftar = false;
    } else if (now.isBefore(today.iftar)) {
      target = today.iftar;
      isIftar = true;
    } else {
      final tomorrowDay = DateTime(now.year, now.month, now.day + 1);
      target = currentRamadan(tomorrowDay) == null
          ? null
          : fastingTimes(tomorrowDay, location.lat, location.lng).imsak;
      isIftar = false;
    }

    // Safety rounding: iftar rounds the remaining minutes up (never shows
    // 0 while iftar is still ahead), sahur rounds down (never overstates
    // the time left to eat).
    String? countdownText;
    if (target != null) {
      const perMinute = Duration.microsecondsPerMinute;
      final remaining = target.difference(now).inMicroseconds;
      final minutes = isIftar
          ? (remaining + perMinute - 1) ~/ perMinute
          : remaining ~/ perMinute;
      final h = minutes ~/ 60;
      final m = minutes % 60;
      countdownText = isIftar
          ? l10n.ramadanUntilIftar(h, m)
          : l10n.ramadanUntilSahur(h, m);
    }

    final timeFormat = DateFormat('HH:mm');
    final fastedToday = (ref.watch(fastingDaysProvider).value ?? const {})
        .contains(ramadanDayKey(now));
    // `.value` reads null while loading/erroring — the link only appears
    // once we positively know permission is off, never as a loading guess.
    final notificationsOff =
        ref.watch(notificationsPermittedProvider).value == false;

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: AppTapCard(
        onTap: () => context.pushNamed(RouteNames.ramadan),
        semanticLabel: l10n.ramadanTitle,
        borderRadius: BorderRadius.circular(24),
        decoration: cozyCardDecoration(context).copyWith(color: tint.surface),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (countdownText != null) ...[
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
              ],
              Text(
                l10n.ramadanImsakIftar(
                  timeFormat.format(today.imsak),
                  timeFormat.format(today.iftar),
                ),
                style: TextStyle(fontSize: 12, color: colors.textMuted),
              ),
              if (notificationsOff) ...[
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () => _enableNotifications(context),
                  child: Text(
                    l10n.ramadanNotificationsOff,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: tint.ink,
                    ),
                  ),
                ),
              ],
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
      ),
    );
  }

  Future<void> _enableNotifications(BuildContext context) async {
    final granted = await ref
        .read(notificationServiceProvider)
        .requestPermission();
    ref.invalidate(notificationsPermittedProvider);
    if (!granted || !context.mounted) return;
    final l10n = context.l10n;
    await ref
        .read(ramadanControllerProvider)
        .reschedule(ramadanCopy(l10n));
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
          copy: ramadanCopy(l10n),
          waterCopy: waterReminderCopy(l10n),
        );
  }
}
