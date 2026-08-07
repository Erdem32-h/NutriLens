import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Persistent bottom bar carrying the food-result screen's primary action.
///
/// Lives outside the scroll view on purpose. The save CTA used to be the last
/// widget of a long `SingleChildScrollView` — below the photo, the name and
/// brand fields, the macro grid, the portion chips, the HP-Score bar and the
/// description — so on a phone it sat well past the fold. The result page
/// reads as a report, and a reader who sees no next step leaves: over 7 days
/// 22 devices reached `meal_analysis_succeeded` and 1 reached `meal_added`.
///
/// Mounted as [Scaffold.bottomNavigationBar] so the framework lays the body
/// out above it — the action is on screen from the first frame and it never
/// covers content.
class MealSaveBar extends StatelessWidget {
  /// Invoked on tap. Pass null to render the button disabled.
  final VoidCallback? onSave;

  /// Swaps the icon for a spinner and blocks further taps. Kept separate from
  /// a null [onSave] so "busy" and "not available" can look different.
  final bool saving;

  final String label;

  const MealSaveBar({
    super.key,
    required this.onSave,
    required this.label,
    this.saving = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: saving ? null : onSave,
              icon: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_rounded),
              label: Text(label),
            ),
          ),
        ),
      ),
    );
  }
}
