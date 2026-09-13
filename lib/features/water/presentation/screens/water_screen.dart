import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/extensions/l10n_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/water_day.dart';
import '../../domain/water_goal.dart';
import '../providers/water_provider.dart';
import '../water_actions.dart';

class WaterScreen extends ConsumerWidget {
  const WaterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final goal = ref.watch(waterGoalProvider);
    final glasses = ref.watch(waterTodayProvider).value?.glasses ?? 0;
    final week = ref.watch(waterWeekProvider).value ?? const <WaterDay>[];
    final reminderEnabled = ref.watch(waterSettingsProvider).reminderEnabled;
    final weight = ref.watch(waterMetricsWeightProvider).value;
    final liters = NumberFormat('#0.#', locale).format(goal * kGlassMl / 1000);
    final copy = waterReminderCopy(l10n);
    final controller = ref.read(waterControllerProvider);
    final sectionStyle = TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w700,
      color: colors.textPrimary,
    );

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(l10n.waterTitle),
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Center(
            child: Text(
              l10n.waterGlassesProgress(glasses, goal),
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: colors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.outlined(
                tooltip: l10n.waterRemoveGlass,
                onPressed: glasses > 0
                    ? () => removeWaterGlass(context, ref)
                    : null,
                icon: const Icon(Icons.remove_rounded),
              ),
              const SizedBox(width: 16),
              FilledButton.icon(
                onPressed: () => addWaterGlass(context, ref),
                icon: const Icon(Icons.add_rounded),
                label: Text(l10n.waterAddGlass),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Text(l10n.waterLast7Days, style: sectionStyle),
          const SizedBox(height: 12),
          _WeekChart(days: week),
          const SizedBox(height: 28),
          Text(l10n.waterDailyGoal, style: sectionStyle),
          const SizedBox(height: 4),
          Row(
            children: [
              IconButton(
                tooltip: l10n.waterDecreaseGoal,
                onPressed: goal > kMinGoalGlasses
                    ? () => controller.setGoal(goal - 1, copy)
                    : null,
                icon: const Icon(Icons.remove_rounded),
              ),
              Expanded(
                child: Text(
                  l10n.waterGoalValue(goal, liters),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: colors.textPrimary),
                ),
              ),
              IconButton(
                tooltip: l10n.waterIncreaseGoal,
                onPressed: goal < kMaxGoalGlasses
                    ? () => controller.setGoal(goal + 1, copy)
                    : null,
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          if (weight != null)
            Center(
              child: TextButton(
                onPressed: () =>
                    controller.setGoal(suggestedWaterGoal(weight), copy),
                child: Text(l10n.waterGoalFromWeight),
              ),
            ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.waterReminderSwitch),
            subtitle: Text(l10n.waterReminderSchedule),
            value: reminderEnabled,
            onChanged: (value) => setWaterReminder(context, ref, value),
          ),
        ],
      ),
    );
  }
}

class _WeekChart extends StatelessWidget {
  final List<WaterDay> days;

  const _WeekChart({required this.days});

  static const _barMaxHeight = 90.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final ink = colors.cozy.sky.ink;
    final maxValue = days.fold<int>(
      1,
      (m, d) => math.max(m, math.max(d.glasses, d.goalGlasses)),
    );
    final labelStyle = TextStyle(fontSize: 11, color: colors.textMuted);

    return SizedBox(
      height: 140,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final day in days)
            Expanded(
              child: Semantics(
                label:
                    '${DateFormat.EEEE(locale).format(DateTime.parse(day.day))}: '
                    '${l10n.waterGlassesProgress(day.glasses, day.goalGlasses)}',
                excludeSemantics: true,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text('${day.glasses}', style: labelStyle),
                      const SizedBox(height: 4),
                      Flexible(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: _barMaxHeight * day.glasses / maxValue,
                          ),
                          child: Container(
                            key: ValueKey('water-bar-${day.day}'),
                            decoration: BoxDecoration(
                              color: day.goalMet
                                  ? ink
                                  : ink.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        DateFormat.E(locale).format(DateTime.parse(day.day)),
                        style: labelStyle,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
