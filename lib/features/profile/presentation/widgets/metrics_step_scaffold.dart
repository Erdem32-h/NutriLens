import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';

/// Shared chrome for every page of `MetricsWizardScreen`: a close/back
/// header with progress dots, a white circular icon badge, a title/subtitle
/// pair, and a primary CTA pinned to the bottom.
///
/// Deliberately just the page *content* — the wizard screen owns the single
/// outer `Scaffold`, background gradient and `PopScope` so a 5-page
/// `PageView` isn't nesting five separate Scaffolds inside itself.
///
/// Mirrors the profile screen's card language (rounded surfaces, circular
/// icon badges) rather than inventing a new visual system — Spec B is where
/// the app-wide visual pass happens, not here.
class MetricsStepScaffold extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;
  final String primaryLabel;
  final VoidCallback? onPrimaryPressed;

  /// Distinguishes this step's primary button from the other four, all of
  /// which share the same "Devam" label — a plain (non-lazy) `PageView`
  /// keeps every page's widgets in the tree at once, so tests must be able
  /// to target one button unambiguously by key rather than by text.
  final Key? primaryKey;

  /// Progress dots. [stepIndex] is 0-based, [stepCount] the total number of
  /// dots to draw (result page renders none — it is the destination, not a
  /// step toward it).
  final int stepIndex;
  final int stepCount;

  /// Shown as a chevron when not on the first page (goes back one page);
  /// omitted on the first page, where only the close action remains.
  final VoidCallback? onBack;
  final VoidCallback onClose;
  final String closeTooltip;
  final String backTooltip;

  const MetricsStepScaffold({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
    required this.primaryLabel,
    required this.onPrimaryPressed,
    required this.stepIndex,
    required this.stepCount,
    required this.onClose,
    required this.closeTooltip,
    required this.backTooltip,
    this.onBack,
    this.primaryKey,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
          child: Row(
            children: [
              if (onBack != null)
                IconButton(
                  onPressed: onBack,
                  tooltip: backTooltip,
                  icon: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 18,
                    color: colors.textMuted,
                  ),
                )
              else
                const SizedBox(width: 48),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(stepCount, (index) {
                    final isActive = index == stepIndex;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      height: 6,
                      width: isActive ? 24 : 6,
                      decoration: BoxDecoration(
                        color: isActive ? colors.primary : colors.border,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    );
                  }),
                ),
              ),
              IconButton(
                onPressed: onClose,
                tooltip: closeTooltip,
                icon: Icon(Icons.close_rounded, color: colors.textMuted),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: colors.surfaceCard,
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.border),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, color: colors.primary, size: 26),
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: colors.textPrimary,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: colors.textMuted,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 28),
                child,
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          child: AppButton(
            key: primaryKey,
            label: primaryLabel,
            onPressed: onPrimaryPressed,
          ),
        ),
      ],
    );
  }
}
