import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

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

  const CozyHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(gradient: colors.cozy.headerGlow),
      padding: const EdgeInsets.fromLTRB(24, 12, 20, 28),
      child: SafeArea(
        bottom: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: textTheme.displaySmall?.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      subtitle!,
                      style: textTheme.bodyLarge?.copyWith(
                        color: colors.cozy.bodyOnTint,
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (action != null) ...[const SizedBox(width: 12), action!],
          ],
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

  const CozyHeaderAction({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tint = colors.cozy.lilac;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: tint.surface,
        borderRadius: BorderRadius.circular(18),
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
