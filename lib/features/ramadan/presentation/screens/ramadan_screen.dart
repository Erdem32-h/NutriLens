import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/analytics/analytics_event.dart';
import '../../../../core/analytics/analytics_provider.dart';
import '../../../../core/extensions/l10n_extension.dart';
import '../../../../core/services/share_service.dart';
import '../../../../core/session/app_session.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/cozy_tokens.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../water/domain/water_day.dart';
import '../../../water/domain/water_goal.dart';
import '../../../water/presentation/providers/water_provider.dart';
import '../../../water/presentation/water_actions.dart';
import '../../domain/ramadan_calendar.dart';
import '../providers/ramadan_provider.dart';
import '../ramadan_actions.dart';
import '../widgets/city_picker_sheet.dart';
import '../widgets/ramadan_share_card.dart';

/// Local calendar day `i` (1-based) of [period], built without
/// `add(Duration(...))` so DST never yields a 23h/25h day (see
/// `global-constraints.md`). `period.firstDay` is a UTC date-only marker;
/// its y/m/d components are what the local day is built from.
DateTime ramadanScreenDay(RamadanPeriod period, int i) => DateTime(
  period.firstDay.year,
  period.firstDay.month,
  period.firstDay.day + (i - 1),
);

/// Consecutive fasted days ending [today], or ending yesterday when today
/// itself hasn't been marked yet — so the streak doesn't drop to 0 for the
/// hours before the user gets around to marking the current day.
int fastingStreak(Set<String> days, DateTime today) {
  var cursor = today;
  if (!days.contains(ramadanDayKey(cursor))) {
    cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
    if (!days.contains(ramadanDayKey(cursor))) return 0;
  }
  var streak = 0;
  while (days.contains(ramadanDayKey(cursor))) {
    streak++;
    cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
  }
  return streak;
}

/// Fasting calendar + settings: a grid to mark each day of
/// `displayPeriod(now)`, the mode switch, the sahur-offset picker and a
/// share button for the summary card. Reachable from the countdown card
/// and the profile row whenever `displayPeriod(now) != null`.
class RamadanScreen extends ConsumerWidget {
  const RamadanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = context.colors;
    final now = ref.watch(ramadanClockProvider)();
    final today = DateTime(now.year, now.month, now.day);
    final period = displayPeriod(now);
    final settings = ref.watch(ramadanSettingsProvider);
    final fastedDays = ref.watch(fastingDaysProvider).value ?? const {};

    if (period == null) {
      // The entry points (countdown card, profile row) only show while
      // `displayPeriod(now) != null`, so this is defensive rather than a
      // real path — a plain empty screen beats a crash if reached anyway
      // (e.g. a stale deep link once a period rolls off the calendar).
      return Scaffold(
        appBar: AppBar(title: Text(l10n.ramadanTitle)),
        body: const SizedBox.shrink(),
      );
    }

    final streak = fastingStreak(fastedDays, today);
    final tint = colors.cozy.lilac;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(l10n.ramadanTitle),
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Center(
            child: Column(
              children: [
                Text(
                  l10n.ramadanDaysProgress(fastedDays.length, period.length),
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: colors.textPrimary,
                  ),
                ),
                if (streak > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    l10n.ramadanStreak(streak),
                    style: TextStyle(fontSize: 13, color: colors.textMuted),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: period.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemBuilder: (context, index) {
              final i = index + 1;
              final day = ramadanScreenDay(period, i);
              final fasted = fastedDays.contains(ramadanDayKey(day));
              final isFuture = day.isAfter(today);
              final isToday = ramadanDayKey(day) == ramadanDayKey(today);
              return _DayCell(
                index: i,
                fasted: fasted,
                isToday: isToday,
                tint: tint,
                colors: colors,
                onTap: isFuture
                    ? null
                    : () => ref
                          .read(ramadanControllerProvider)
                          .setFasted(day, !fasted),
              );
            },
          ),
          const SizedBox(height: 28),
          AppButton(
            label: l10n.ramadanShareSummary,
            expand: false,
            onPressed: () => _shareSummary(context, ref, period, fastedDays),
          ),
          const SizedBox(height: 28),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.ramadanModeSwitch),
            value: settings.enabled,
            // Once the offer window has closed (after Eid) the mode can't
            // be turned on — `onResume` would switch it straight back off.
            onChanged: offerPeriod(now) == null
                ? null
                : (value) => _toggleMode(context, ref, value),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.location_on_rounded, color: colors.textPrimary),
            title: Text(settings.location?.label ?? l10n.ramadanChooseLocation),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _pickLocation(context, ref),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.ramadanSahurOffset,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [30, 45, 60].map((min) {
              return ChoiceChip(
                label: Text(l10n.ramadanMinutesBefore(min)),
                selected: settings.sahurOffsetMin == min,
                onSelected: (_) => ref
                    .read(ramadanControllerProvider)
                    .setSahurOffset(min, ramadanCopy(l10n, min)),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.ramadanTimesDisclaimer,
            style: TextStyle(fontSize: 11, color: colors.textMuted),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleMode(
    BuildContext context,
    WidgetRef ref,
    bool value,
  ) async {
    final l10n = context.l10n;
    if (!value) {
      await ref
          .read(ramadanControllerProvider)
          .disable(waterReminderCopy(l10n));
      return;
    }
    final location = ref.read(ramadanSettingsProvider).location;
    if (location != null) {
      // A location is already on file (e.g. left over from a previous
      // disable, or set via the location row below) — enable straight
      // away with it. The picker is only required when there's nothing
      // stored yet, per the fix-round-1 ruling.
      await ref
          .read(ramadanControllerProvider)
          .enable(
            lat: location.lat,
            lng: location.lng,
            label: location.label,
            plate: location.plate,
            source: location.plate != null ? 'city' : 'gps',
            copy: ramadanCopy(
              l10n,
              ref.read(ramadanSettingsProvider).sahurOffsetMin,
            ),
            waterCopy: waterReminderCopy(l10n),
          );
      return;
    }
    final pick = await showCityPicker(context);
    if (pick == null || !context.mounted) return;
    final freshL10n = context.l10n;
    await ref
        .read(ramadanControllerProvider)
        .enable(
          lat: pick.lat,
          lng: pick.lng,
          label: pick.label,
          plate: pick.plate,
          source: pick.source,
          copy: ramadanCopy(
            freshL10n,
            ref.read(ramadanSettingsProvider).sahurOffsetMin,
          ),
          waterCopy: waterReminderCopy(freshL10n),
        );
  }

  /// Location row's tap target — mirrors `_pickLocation` in
  /// `ramadan_countdown_card.dart`: opens the city picker and writes the
  /// pick straight to storage (independent of whether the mode is on).
  Future<void> _pickLocation(BuildContext context, WidgetRef ref) async {
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
          copy: ramadanCopy(
            l10n,
            ref.read(ramadanSettingsProvider).sahurOffsetMin,
          ),
          waterCopy: waterReminderCopy(l10n),
        );
  }

  Future<void> _shareSummary(
    BuildContext context,
    WidgetRef ref,
    RamadanPeriod period,
    Set<String> fastedDays,
  ) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    try {
      final userId = ref.read(effectiveUserIdProvider);
      final rows = userId == null
          ? const <WaterDay>[]
          : await ref
                .read(waterLocalDataSourceProvider)
                .getRange(
                  userId: userId,
                  fromDay: ramadanDayKey(period.firstDay),
                  toDay: ramadanDayKey(ramadanScreenDay(period, period.length)),
                );
      if (!context.mounted) return;
      final glasses = rows.fold<int>(0, (sum, d) => sum + d.glasses);
      final liters = glasses * kGlassMl / 1000;
      final litersText = NumberFormat('#0.#', locale).format(liters);
      final caption =
          '${l10n.ramadanShareFasted(fastedDays.length)} · '
          '${l10n.ramadanShareWater(litersText)}';

      await ref
          .read(shareServiceProvider)
          .captureAndShare(
            context: context,
            card: RamadanShareCard(
              fasted: fastedDays.length,
              total: period.length,
              liters: liters,
            ),
            logicalSize: const Size(360, 640),
            pixelRatio: 3.0,
            fileName: 'nutrilens-ramadan-${period.year}.png',
            caption: caption,
          );
      ref
          .read(analyticsServiceProvider)
          .track(FunnelEvents.ramadanSummaryShared);
    } catch (e) {
      if (context.mounted) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.shareFailed)));
      }
    }
  }
}

class _DayCell extends StatelessWidget {
  final int index;
  final bool fasted;

  /// Whether this cell is the current calendar day — gets a distinct
  /// outline regardless of [fasted], so "today" reads at a glance in both
  /// the filled and unfilled state.
  final bool isToday;
  final CozyTint tint;
  final AppColorsExtension colors;
  final VoidCallback? onTap;

  const _DayCell({
    required this.index,
    required this.fasted,
    required this.isToday,
    required this.tint,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final Color bg;
    final Color fg;
    if (!enabled) {
      bg = colors.surfaceCard2;
      fg = colors.textMuted;
    } else if (fasted) {
      bg = tint.ink;
      fg = Colors.white;
    } else {
      bg = tint.surface;
      fg = colors.textPrimary;
    }

    return GestureDetector(
      key: ValueKey('ramadan-day-$index'),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: isToday ? Border.all(color: colors.primary, width: 2) : null,
        ),
        alignment: Alignment.center,
        child: Text(
          '$index',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: fg,
          ),
        ),
      ),
    );
  }
}
