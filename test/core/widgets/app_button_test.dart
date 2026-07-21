import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/core/theme/app_theme.dart';
import 'package:nutrilens/core/widgets/app_button.dart';

/// Wraps the button in the app's real theme — [AppButton] reads colours from
/// AppColorsExtension, so a bare MaterialApp would throw on the null check.
Widget _host(Widget child, {bool disableAnimations = false}) {
  return MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(
      body: MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: Center(child: child),
      ),
    ),
  );
}

void main() {
  testWidgets('invokes onPressed when tapped', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _host(AppButton(label: 'Tara', onPressed: () => taps++)),
    );

    await tester.tap(find.byType(AppButton));
    await tester.pumpAndSettle();

    expect(taps, 1);
  });

  testWidgets('shows an ink response on press', (tester) async {
    await tester.pumpWidget(_host(AppButton(label: 'Tara', onPressed: () {})));

    // The whole point of this widget: a tap must produce visible feedback.
    // InkWell is what supplies it, and it must be wired to a live callback —
    // an InkWell with a null onTap renders no splash.
    final inkWell = tester.widget<InkWell>(find.byType(InkWell));
    expect(inkWell.onTap, isNotNull);
  });

  testWidgets('a null onPressed disables the ink response', (tester) async {
    await tester.pumpWidget(
      _host(const AppButton(label: 'Tara', onPressed: null)),
    );

    final inkWell = tester.widget<InkWell>(find.byType(InkWell));
    expect(inkWell.onTap, isNull);
  });

  testWidgets('loading swaps the label for a spinner and blocks taps', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      _host(AppButton(label: 'Tara', isLoading: true, onPressed: () => taps++)),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Tara'), findsNothing);

    await tester.tap(find.byType(AppButton));
    await tester.pump();

    // A double-tap during an in-flight request was previously possible
    // because the old GestureDetector kept its callback while loading.
    expect(taps, 0);
  });

  testWidgets('meets the 48dp minimum touch target', (tester) async {
    await tester.pumpWidget(_host(AppButton(label: 'Tara', onPressed: () {})));

    final size = tester.getSize(find.byType(InkWell));
    expect(size.height, greaterThanOrEqualTo(48));
  });

  testWidgets('exposes an enabled button to assistive tech', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host(AppButton(label: 'Tara', onPressed: () {})));

    expect(
      tester.getSemantics(find.byType(AppButton)),
      matchesSemantics(
        label: 'Tara',
        isButton: true,
        isEnabled: true,
        hasEnabledState: true,
        isFocusable: true,
        // The node must carry the tap action itself. Collapsing the tree
        // with excludeSemantics produced a labelled button with no way to
        // activate it, which this assertion is here to catch.
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('drops the press scale when reduced motion is on', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        AppButton(label: 'Tara', onPressed: () {}),
        disableAnimations: true,
      ),
    );

    // AnimatedScale is the only motion in the widget; under reduced-motion
    // the press must still register (ripple) without the scale.
    expect(find.byType(AnimatedScale), findsNothing);
  });

  testWidgets('keeps the press scale when motion is allowed', (tester) async {
    await tester.pumpWidget(_host(AppButton(label: 'Tara', onPressed: () {})));

    expect(find.byType(AnimatedScale), findsOneWidget);
  });
}
