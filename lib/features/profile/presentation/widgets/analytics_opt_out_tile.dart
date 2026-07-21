import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/analytics/analytics_provider.dart';
import '../../../../core/extensions/l10n_extension.dart';
import '../../../../core/theme/app_colors.dart';

/// Switch that lets the user stop the app from recording funnel events.
///
/// Phrased as an opt-*in* ("share usage data", on by default) rather than as
/// an opt-out checkbox, so the switch position matches the plain meaning of
/// the label — on means data is being sent.
///
/// Deliberately not itself instrumented: firing an analytics event to record
/// that someone just asked to stop being recorded is the one thing this
/// control must never do.
class AnalyticsOptOutTile extends ConsumerStatefulWidget {
  const AnalyticsOptOutTile({super.key});

  @override
  ConsumerState<AnalyticsOptOutTile> createState() =>
      _AnalyticsOptOutTileState();
}

class _AnalyticsOptOutTileState extends ConsumerState<AnalyticsOptOutTile> {
  /// The preference is read straight from SharedPreferences rather than
  /// watched, so nothing rebuilds this on its own — local state after an
  /// awaited write is what moves the switch.
  Future<void> _setSharing(bool sharing) async {
    await ref.read(analyticsServiceProvider).setOptedOut(!sharing);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final sharing = !ref.read(analyticsServiceProvider).isOptedOut;

    return Container(
      decoration: BoxDecoration(
        color: context.colors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        // Merges the label, the description and the switch into a single
        // accessibility node, so a screen reader announces what the toggle
        // actually controls instead of an unlabelled switch.
        child: MergeSemantics(
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: context.colors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.insights_rounded,
                  size: 18,
                  color: context.colors.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.analyticsSharing,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: context.colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.analyticsSharingDescription,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: context.colors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Switch(value: sharing, onChanged: _setSharing),
            ],
          ),
        ),
      ),
    );
  }
}
