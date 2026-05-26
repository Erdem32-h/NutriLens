import 'package:flutter/material.dart';

import '../../../../core/extensions/l10n_extension.dart';
import '../../../../core/session/guest_migration_service.dart';
import '../../../../core/theme/app_colors.dart';

/// Shown to a freshly-registered user who arrived from guest mode and
/// has local data on the device. Lets them choose whether to attach
/// that data to their new account or start clean.
class GuestMigrationPromptSheet extends StatelessWidget {
  final GuestDataSummary summary;

  const GuestMigrationPromptSheet({super.key, required this.summary});

  /// Returns:
  ///   `true`  → user wants to migrate (upload local to account)
  ///   `false` → user wants to discard local guest data
  ///   `null`  → dismissed without choosing (treat as discard)
  static Future<bool?> show(
    BuildContext context, {
    required GuestDataSummary summary,
  }) async {
    if (summary.isEmpty) return null;
    return showModalBottomSheet<bool>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => GuestMigrationPromptSheet(summary: summary),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorsExtension>()!;
    final l10n = context.l10n;
    final parts = <String>[
      if (summary.scanCount > 0) l10n.scanCountUnit(summary.scanCount),
      if (summary.mealCount > 0) l10n.mealCountUnit(summary.mealCount),
    ];
    final dataLine = parts.join(', ');

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: colors.primaryGradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.move_to_inbox_outlined,
              color: Colors.black,
              size: 28,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            l10n.migrationTitle,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: colors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            l10n.migrationMessage(dataLine),
            style: TextStyle(
              fontSize: 14,
              color: colors.textMuted,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(true),
            child: Container(
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: colors.primaryGradient,
                borderRadius: BorderRadius.circular(50),
              ),
              child: Text(
                l10n.migrationYes,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              l10n.migrationNo,
              style: TextStyle(
                color: colors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
