import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/analytics/analytics_event.dart';
import '../../../../core/analytics/analytics_provider.dart';
import '../../../../core/extensions/l10n_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/cozy_tile.dart';
import '../../../water/presentation/water_actions.dart';
import '../../domain/ramadan_calendar.dart';
import '../ramadan_actions.dart';
import '../providers/ramadan_provider.dart';
import 'city_picker_sheet.dart';

/// Pre-Ramadan opt-in card on the Meals tab: visible from 3 days before
/// `firstDay` through the whole window while the mode is off and the user
/// hasn't dismissed it for this year's period. Dismissal is per-year (see
/// `RamadanController.dismissOffer`), so it comes back for the next Ramadan.
class RamadanOfferCard extends ConsumerStatefulWidget {
  const RamadanOfferCard({super.key});

  @override
  ConsumerState<RamadanOfferCard> createState() => _RamadanOfferCardState();
}

class _RamadanOfferCardState extends ConsumerState<RamadanOfferCard> {
  @override
  void initState() {
    super.initState();
    // Tracked once per mount (not per rebuild) — the card stays mounted
    // after a dismiss (it just renders nothing), so `initState` running
    // exactly once is what keeps this a single "shown" event instead of
    // one per rebuild.
    if (_isVisible()) {
      ref.read(analyticsServiceProvider).track(FunnelEvents.ramadanOfferShown);
    }
  }

  bool _isVisible() {
    final settings = ref.read(ramadanSettingsProvider);
    final now = ref.read(ramadanClockProvider)();
    final period = offerPeriod(now);
    return period != null &&
        !settings.enabled &&
        settings.offerDismissedYear != period.year;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final settings = ref.watch(ramadanSettingsProvider);
    final now = ref.watch(ramadanClockProvider)();
    final period = offerPeriod(now);
    final visible =
        period != null &&
        !settings.enabled &&
        settings.offerDismissedYear != period.year;
    if (!visible) return const SizedBox.shrink();

    final tint = colors.cozy.peach;

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: cozyCardDecoration(context).copyWith(color: tint.surface),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.nights_stay_rounded, color: tint.ink),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.ramadanOfferTitle,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () =>
                      ref.read(ramadanControllerProvider).dismissOffer(period.year),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              l10n.ramadanOfferBody,
              style: TextStyle(fontSize: 13, color: colors.textMuted),
            ),
            const SizedBox(height: 12),
            AppButton(
              label: l10n.ramadanOfferCta,
              expand: false,
              onPressed: () => _openPicker(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openPicker(BuildContext context) async {
    final pick = await showCityPicker(context);
    if (pick == null || !context.mounted) return;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    await ref
        .read(ramadanControllerProvider)
        .enable(
          lat: pick.lat,
          lng: pick.lng,
          label: pick.label,
          plate: pick.plate,
          source: pick.source,
          copy: ramadanCopy(l10n),
          waterCopy: waterReminderCopy(l10n),
        );
    // The card disappears once enabled, so point at where the settings
    // live now (Profile › Ramazan, visible from the offer window on).
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.ramadanEnabledConfirm)),
    );
  }
}
