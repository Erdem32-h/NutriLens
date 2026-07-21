import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Visual weight of an [AppButton].
enum AppButtonVariant {
  /// Gradient fill. One per screen — this is the screen's single primary
  /// action.
  primary,

  /// Outlined surface. Everything that competes with, but must not
  /// outrank, the primary action.
  secondary,
}

/// The app's standard button.
///
/// Every button in NutriLens used to be a bare `GestureDetector` wrapping a
/// `Container`, which meant a tap produced no visual response at all — no
/// ripple, no press state, no disabled affordance, and nothing announced to
/// a screen reader. That absence is most of why the UI felt unresponsive:
/// the platform guidance is to acknowledge a touch within ~100ms, and these
/// acknowledged it never.
///
/// This widget covers the four things those call sites were missing:
///   * ripple + a slight press-in scale, so a tap is felt immediately;
///   * a 48dp minimum height, meeting the Material touch-target floor;
///   * a real loading state that also blocks re-entrant taps;
///   * a semantic button role with an enabled/disabled flag.
///
/// Motion is skipped when the platform reports reduced-motion, so the press
/// still registers (ripple + color) without the scale animation.
class AppButton extends StatefulWidget {
  final String label;

  /// Tapping is disabled whenever this is null or [isLoading] is true.
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool isLoading;

  /// Stretch to the parent's width. False sizes the button to its content,
  /// for use inside a centred column.
  final bool expand;

  /// Overrides the label for assistive tech. Only needed when the visible
  /// label is too terse to stand alone out of context.
  final String? semanticLabel;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.expand = true,
    this.semanticLabel,
  });

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null && !widget.isLoading;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isPrimary = widget.variant == AppButtonVariant.primary;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    // Disabled uses the flat card colour rather than a faded gradient: a
    // washed-out gradient still reads as "tappable, just pale", while a
    // change of surface reads as "off".
    final BoxDecoration decoration;
    if (!_enabled) {
      decoration = BoxDecoration(
        color: colors.surfaceCard2,
        borderRadius: BorderRadius.circular(50),
      );
    } else if (isPrimary) {
      decoration = BoxDecoration(
        gradient: colors.primaryGradient,
        borderRadius: BorderRadius.circular(50),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: _pressed ? 0.16 : 0.30),
            blurRadius: _pressed ? 10 : 20,
            offset: Offset(0, _pressed ? 4 : 8),
          ),
        ],
      );
    } else {
      decoration = BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: colors.border),
      );
    }

    // On the gradient the label sits on a light fill, so it stays black in
    // both themes; the secondary variant follows the theme's text colour.
    final Color foreground = !_enabled
        ? colors.textMuted
        : isPrimary
        ? Colors.black
        : colors.textPrimary;

    Widget content;
    if (widget.isLoading) {
      content = SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: colors.primary,
        ),
      );
    } else {
      content = Row(
        mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (widget.icon != null) ...[
            Icon(widget.icon, size: 20, color: foreground),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Text(
              widget.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: foreground,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      );
    }

    Widget button = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      height: 54,
      decoration: decoration,
      child: Material(
        // Transparent so the gradient/border above stays visible; the
        // Material is here purely to host the ink splash.
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(50),
        child: InkWell(
          onTap: _enabled ? widget.onPressed : null,
          onHighlightChanged: _setPressed,
          borderRadius: BorderRadius.circular(50),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Center(
              widthFactor: widget.expand ? null : 1,
              // The label is already carried by the Semantics node above;
              // leaving the Text visible to the reader would make the merged
              // node announce it twice.
              child: ExcludeSemantics(child: content),
            ),
          ),
        ),
      ),
    );

    if (!reduceMotion) {
      button = AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        child: button,
      );
    }

    // MergeSemantics folds the InkWell's tap/focus actions together with the
    // label and button role below into a single node. Collapsing this with
    // `excludeSemantics` instead would drop those actions on the floor: the
    // reader would announce "button" but expose nothing to activate.
    return MergeSemantics(
      child: Semantics(
        button: true,
        enabled: _enabled,
        label: widget.semanticLabel ?? widget.label,
        child: widget.expand
            ? SizedBox(width: double.infinity, child: button)
            : button,
      ),
    );
  }
}
