import 'package:flutter/material.dart';

/// A tappable card or list row with real press feedback.
///
/// The list surfaces — scan history, favourites, meals, settings rows —
/// were `GestureDetector`s wrapping a decorated `Container`, so tapping a
/// row produced no visual response whatsoever. On a list screen that is the
/// most-repeated interaction in the app, which made it the most-repeated
/// place the UI felt dead.
///
/// Getting a ripple to show over a decorated container takes a specific
/// arrangement: the decoration has to be painted *below* a transparent
/// [Material], because ink splashes are drawn by the Material and would
/// otherwise be hidden underneath the container's own background. The
/// [borderRadius] must be repeated on the Material, the [InkWell] and the
/// decoration, or the splash spills past the rounded corners.
///
/// Sits alongside [AppButton], which covers pill-shaped call-to-action
/// buttons; this one is for anything card- or row-shaped.
class AppTapCard extends StatefulWidget {
  /// The card's own visuals. Supply the padding here — this widget adds
  /// none, so existing layouts port over unchanged.
  final Widget child;

  /// Painted beneath the ink layer. Pass the same decoration the old
  /// Container used; its borderRadius should match [borderRadius].
  final BoxDecoration? decoration;

  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final BorderRadius borderRadius;

  /// Describes the row to assistive tech, e.g. the product name. Without
  /// it a screen reader falls back to reading every text fragment in the
  /// card in layout order.
  final String? semanticLabel;

  const AppTapCard({
    super.key,
    required this.child,
    this.decoration,
    this.onTap,
    this.onLongPress,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.semanticLabel,
  });

  @override
  State<AppTapCard> createState() => _AppTapCardState();
}

class _AppTapCardState extends State<AppTapCard> {
  bool _pressed = false;

  bool get _interactive => widget.onTap != null || widget.onLongPress != null;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    Widget card = DecoratedBox(
      decoration: widget.decoration ?? const BoxDecoration(),
      child: Material(
        color: Colors.transparent,
        borderRadius: widget.borderRadius,
        child: InkWell(
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          onHighlightChanged: _setPressed,
          borderRadius: widget.borderRadius,
          child: widget.child,
        ),
      ),
    );

    // Cards are large, so the press scale is far subtler than a button's —
    // enough to acknowledge the touch without the row appearing to jump.
    if (_interactive && !reduceMotion) {
      card = AnimatedScale(
        scale: _pressed ? 0.985 : 1,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: card,
      );
    }

    if (!_interactive) return card;

    return Semantics(button: true, label: widget.semanticLabel, child: card);
  }
}
