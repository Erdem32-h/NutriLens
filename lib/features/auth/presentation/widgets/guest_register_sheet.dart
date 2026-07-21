import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/l10n_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';

/// Modal bottom sheet shown to guest users when they hit a gated
/// feature (scan-limit reached, premium purchase, community submit,
/// favorites, blacklist). Returns `true` if the user tapped "Hesap aç"
/// so the caller can route to /register; `false` otherwise.
class GuestRegisterSheet extends StatelessWidget {
  final String title;
  final String message;
  final String? primaryActionLabel;

  const GuestRegisterSheet({
    super.key,
    required this.title,
    required this.message,
    this.primaryActionLabel,
  });

  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    String? primaryActionLabel,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => GuestRegisterSheet(
        title: title,
        message: message,
        primaryActionLabel: primaryActionLabel,
      ),
    );
    return result ?? false;
  }

  /// Convenience preset for the lifetime-scan-limit hard block.
  static Future<bool> showScanLimitReached(BuildContext context) {
    final l10n = context.l10n;
    return show(
      context,
      title: l10n.guestScanLimitTitle,
      message: l10n.guestScanLimitMessage,
      primaryActionLabel: l10n.createAccountCta,
    );
  }

  /// Convenience preset for cloud-only features (favorites, blacklist,
  /// premium, community submit).
  static Future<bool> showFeatureLocked(
    BuildContext context, {
    required String feature,
  }) {
    final l10n = context.l10n;
    return show(
      context,
      title: l10n.guestFeatureLockedTitle(feature),
      message: l10n.guestFeatureLockedMessage,
      primaryActionLabel: l10n.createAccountCta,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorsExtension>()!;
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
          // Drag handle
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

          // Icon
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: colors.primaryGradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.cloud_upload_outlined,
              color: Colors.black,
              size: 28,
            ),
          ),
          const SizedBox(height: 20),

          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: colors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: TextStyle(
              fontSize: 14,
              color: colors.textMuted,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Primary CTA
          AppButton(
            label: primaryActionLabel ?? context.l10n.createAccountCta,
            onPressed: () {
              Navigator.of(context).pop(true);
              context.go('/register');
            },
          ),
          const SizedBox(height: 8),

          // Secondary
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              context.l10n.notNow,
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
