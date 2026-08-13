import 'package:flutter/material.dart';

import '../../../../core/extensions/l10n_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';

/// Explains why the camera is needed, immediately before the OS permission
/// prompt fires.
///
/// The prompt itself carries no product context — the user sees a bare system
/// dialog and has to guess. Answering it is also close to irreversible in
/// practice: Android stops showing the dialog after a denial, so the recovery
/// path becomes "find the app in Settings", which most people never do.
/// One screen of context ahead of an effectively one-shot question.
class CameraRationaleSheet extends StatelessWidget {
  const CameraRationaleSheet({super.key});

  /// Returns `true` when the user chose to continue (the caller should start
  /// the camera, which raises the OS prompt), and `false`/`null` when they
  /// backed out.
  ///
  /// Not dismissible by swipe on purpose: an accidental drag would fall
  /// through to the OS prompt with the explanation unread, which is the exact
  /// situation this sheet exists to prevent.
  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const CameraRationaleSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorsExtension>()!;
    final l10n = context.l10n;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.photo_camera_outlined,
              size: 44,
              color: colors.primary,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.cameraRationaleTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              l10n.cameraRationaleBody,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                height: 1.4,
                color: colors.textMuted,
              ),
            ),
            const SizedBox(height: 24),
            AppButton(
              label: l10n.cameraRationaleContinue,
              onPressed: () => Navigator.of(context).pop(true),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                l10n.cameraRationaleNotNow,
                style: TextStyle(color: colors.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
