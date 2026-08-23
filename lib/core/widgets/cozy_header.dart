import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/cozy_tokens.dart';

/// The oversized, warm page opener used at the top of each main tab.
///
/// Replaces `AppBar` on the tabs rather than restyling it: an AppBar caps
/// its title at a single dense line, and the whole point here is a title
/// that breathes, a sentence of context under it, and a colour wash behind
/// both. The wash is painted by this widget and fades to transparent at its
/// own bottom edge, so it stays a top-of-screen glow and needs no change to
/// the scaffold or the shell.
///
/// Meant to be the first item of the screen's scroll view — it scrolls away
/// with the content, which is what keeps small screens usable now that the
/// header is this tall.
class CozyHeader extends StatelessWidget {
  final String title;

  /// One short sentence under the title. Optional — a tab whose purpose is
  /// obvious from its title should not pad it out with filler.
  final String? subtitle;

  /// Sits at the top-right, opposite the title. Use [CozyHeaderAction] for
  /// the standard soft-chip look.
  final Widget? action;

  /// Renders a back chip above the title when set. A pushed screen needs one
  /// — this header replaces the AppBar that used to supply it for free.
  final VoidCallback? onBack;

  /// Colours the wash and the chips.
  ///
  /// A sub-screen passes the same tint its row wore on the screen that opened
  /// it, so tapping "Allergens" on a peach row opens a peach screen: the two
  /// read as one object expanding rather than as two unrelated pages. Null
  /// (the tabs) uses the palette's own multi-hue glow.
  final CozyTint? tint;

  const CozyHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
    this.onBack,
    this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    final gradient = tint == null
        ? colors.cozy.headerGlow
        : LinearGradient(
            colors: [tint!.surface, tint!.surface.withValues(alpha: 0)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          );

    // A 640dp-tall phone is still a large share of the Turkish market, and at
    // full size this header plus the nav chrome left barely a card and a half
    // of the meals list visible. Shrink the type and the padding there rather
    // than pushing the content off the first screen.
    final compact = MediaQuery.sizeOf(context).height < 700;

    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: (compact ? textTheme.headlineMedium : textTheme.displaySmall)
              ?.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w800,
                height: 1.1,
              ),
        ),
        if (subtitle != null) ...[
          SizedBox(height: compact ? 6 : 10),
          Text(
            subtitle!,
            style:
                (compact ? textTheme.bodyMedium : textTheme.bodyLarge)?.copyWith(
                  color: colors.cozy.bodyOnTint,
                  height: 1.35,
                ),
          ),
        ],
      ],
    );

    return Container(
      decoration: BoxDecoration(gradient: gradient),
      padding: compact
          ? const EdgeInsets.fromLTRB(20, 8, 16, 16)
          : const EdgeInsets.fromLTRB(24, 12, 20, 28),
      child: SafeArea(
        bottom: false,
        // With a back chip the title can no longer share its row — the chip
        // belongs on the leading edge, and a 38px title beside it leaves the
        // chip looking wedged in. It gets its own row above instead.
        child: onBack != null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CozyHeaderAction(
                        icon: Icons.arrow_back_rounded,
                        tooltip: MaterialLocalizations.of(
                          context,
                        ).backButtonTooltip,
                        onPressed: onBack!,
                        tint: tint,
                      ),
                      const Spacer(),
                      ?action,
                    ],
                  ),
                  SizedBox(height: compact ? 10 : 18),
                  titleBlock,
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: titleBlock),
                  if (action != null) ...[const SizedBox(width: 12), action!],
                ],
              ),
      ),
    );
  }
}

/// The same warm wash [CozyHeader] paints, for screens that cannot use the
/// header itself.
///
/// The auth flow is the case this exists for. Onboarding, login and register
/// are full-bleed layouts with their own chrome — no scroll view to put a
/// header at the top of — and each was painting its own circle of primary
/// green at 12-15% opacity. That was the pre-cozy look, so the first three
/// screens a new user ever sees were the last three that still wore it.
///
/// Sized as a fraction of the screen rather than a fixed height: the wash has
/// to fade out before the content starts, and where that is depends on the
/// device.
class CozyGlowBackdrop extends StatelessWidget {
  /// Share of the screen height the wash covers before it has fully faded.
  final double heightFactor;

  const CozyGlowBackdrop({super.key, this.heightFactor = 0.45});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        width: double.infinity,
        height: MediaQuery.sizeOf(context).height * heightFactor,
        child: DecoratedBox(
          decoration: BoxDecoration(gradient: context.colors.cozy.headerGlow),
        ),
      ),
    );
  }
}

/// The soft rounded-square chip that carries a header's single icon action.
class CozyHeaderAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  /// Read aloud by screen readers and shown as the long-press tooltip.
  final String tooltip;

  /// Defaults to lilac, which is what the tabs use. Sub-screens pass their
  /// own so the chip matches the wash behind it.
  final CozyTint? tint;

  const CozyHeaderAction({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tint = this.tint ?? colors.cozy.lilac;

    return Tooltip(
      message: tooltip,
      // Floating fill rather than the tint's own surface: on a sub-screen the
      // wash behind this chip IS that surface, and a chip the same colour as
      // its background is not a chip.
      child: Material(
        color: colors.cozy.floating,
        borderRadius: BorderRadius.circular(18),
        elevation: 0,
        shadowColor: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Icon(icon, size: 24, color: tint.ink),
          ),
        ),
      ),
    );
  }
}

/// The small heading that opens a group of cozy tiles ("Settings",
/// "Health Filters").
class CozySectionLabel extends StatelessWidget {
  final String label;

  const CozySectionLabel(this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: colors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
