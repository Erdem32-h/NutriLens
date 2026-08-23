import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/cozy_tokens.dart';
import 'app_tap_card.dart';

/// The neutral card skin for content lists — scan history, favourites, meal
/// rows.
///
/// Deliberately untinted: the five tints carry *meaning* on the settings
/// screens, and spending them on a list of products would turn a colour
/// language into wallpaper. What makes these cozy instead is the geometry —
/// a wide corner radius and a soft drop shadow in place of the old hairline
/// border, so a row reads as a card resting on the page rather than a cell
/// ruled off from its neighbours.
BoxDecoration cozyCardDecoration(BuildContext context) {
  final colors = context.colors;
  return BoxDecoration(
    color: colors.cozy.floating,
    borderRadius: BorderRadius.circular(24),
    boxShadow: [
      BoxShadow(
        color: colors.textPrimary.withValues(alpha: 0.06),
        blurRadius: 18,
        offset: const Offset(0, 6),
      ),
    ],
  );
}

/// The round counterpart of [cozyCardDecoration] — the big illustration
/// circle an empty state puts its icon in, and the step badge on the metrics
/// wizard. Same reasoning: a soft shadow instead of a hairline ring.
BoxDecoration cozyCircleDecoration(BuildContext context) {
  final colors = context.colors;
  return BoxDecoration(
    color: colors.cozy.floating,
    shape: BoxShape.circle,
    boxShadow: [
      BoxShadow(
        color: colors.textPrimary.withValues(alpha: 0.06),
        blurRadius: 18,
        offset: const Offset(0, 6),
      ),
    ],
  );
}

/// A settings/navigation row on a tinted card, with a raised icon chip.
///
/// Built on [AppTapCard] so the press feedback stays identical to every
/// other tappable surface in the app — the cozy look is a skin over that
/// behaviour, not a second implementation of it.
class CozyTile extends StatelessWidget {
  /// Which accent this row wears. Pick by meaning where one exists
  /// (warnings peach, chemistry rose) and by [CozyPalette.byIndex] for rows
  /// generated from data.
  final CozyTint tint;

  final IconData icon;
  final String title;
  final String? subtitle;

  /// Short status shown as a pill before the chevron — "System", "English",
  /// "63 types". Omit for a row with nothing to report.
  final String? value;

  /// Replaces the value pill entirely when a row needs a real control (a
  /// switch, a spinner) instead of a status word.
  final Widget? trailing;

  final VoidCallback? onTap;

  const CozyTile({
    super.key,
    required this.tint,
    required this.icon,
    required this.title,
    this.subtitle,
    this.value,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: AppTapCard(
        onTap: onTap,
        semanticLabel: subtitle == null ? title : '$title. $subtitle',
        borderRadius: BorderRadius.circular(24),
        decoration: BoxDecoration(
          color: tint.surface,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Row(
            children: [
              CozyIconChip(icon: icon, tint: tint),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: textTheme.titleMedium?.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: textTheme.bodyMedium?.copyWith(
                          color: colors.cozy.bodyOnTint,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null)
                trailing!
              else if (value != null) ...[
                const SizedBox(width: 12),
                CozyValuePill(value!, tint: tint),
              ],
              if (onTap != null) ...[
                const SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded, color: tint.ink, size: 24),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The status pill on the right of a [CozyTile].
class CozyValuePill extends StatelessWidget {
  final String value;
  final CozyTint tint;

  const CozyValuePill(this.value, {super.key, required this.tint});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        // The pill has to lift off a fill that is already tinted, so it
        // borrows the neutral floating fill rather than a lighter tint —
        // two tints of one hue stacked read as a printing error.
        color: colors.cozy.floating,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        value,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: tint.ink,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// The raised circular icon holder. Its shadow is what makes the row read as
/// soft-and-physical rather than flat-and-coloured.
///
/// Public because rows that cannot be a [CozyTile] — ones carrying a real
/// control, like the analytics switch — still have to wear the same chip, and
/// a second hand-rolled copy is how the two drift apart.
class CozyIconChip extends StatelessWidget {
  final IconData icon;
  final CozyTint tint;

  const CozyIconChip({super.key, required this.icon, required this.tint});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: colors.cozy.floating,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: tint.ink.withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(icon, color: tint.ink, size: 26),
    );
  }
}

/// A full-width tinted banner — the "create an account" prompt and the like.
/// Same skin as [CozyTile] but with the emphasis on the message rather than
/// on a status value.
class CozyBanner extends StatelessWidget {
  final CozyTint tint;
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  const CozyBanner({
    super.key,
    required this.tint,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: AppTapCard(
        onTap: onTap,
        semanticLabel: subtitle == null ? title : '$title. $subtitle',
        borderRadius: BorderRadius.circular(24),
        decoration: BoxDecoration(
          color: tint.surface,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Row(
            children: [
              CozyIconChip(icon: icon, tint: tint),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: textTheme.titleMedium?.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: textTheme.bodyMedium?.copyWith(
                          color: colors.cozy.bodyOnTint,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: tint.ink,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: colors.cozy.floating,
                    size: 20,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
