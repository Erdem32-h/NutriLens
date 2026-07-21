import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/core/theme/app_theme.dart';
import 'package:nutrilens/core/widgets/app_tap_card.dart';

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
  testWidgets('invokes onTap and onLongPress', (tester) async {
    var taps = 0;
    var longPresses = 0;
    await tester.pumpWidget(
      _host(
        AppTapCard(
          onTap: () => taps++,
          onLongPress: () => longPresses++,
          child: const SizedBox(width: 200, height: 80),
        ),
      ),
    );

    await tester.tap(find.byType(AppTapCard));
    await tester.pumpAndSettle();
    expect(taps, 1);

    await tester.longPress(find.byType(AppTapCard));
    await tester.pumpAndSettle();
    expect(longPresses, 1);
  });

  testWidgets('paints the ink layer above the decoration', (tester) async {
    await tester.pumpWidget(
      _host(
        AppTapCard(
          decoration: const BoxDecoration(color: Color(0xFF123456)),
          onTap: () {},
          child: const SizedBox(width: 200, height: 80),
        ),
      ),
    );

    // Ordering matters: a splash drawn by the Material would be hidden if
    // the decoration painted on top of it, which is exactly what the old
    // GestureDetector-wrapping-a-Container arrangement did.
    final decorated = find.descendant(
      of: find.byType(AppTapCard),
      matching: find.byType(DecoratedBox),
    );
    expect(decorated, findsWidgets);
    expect(
      find.descendant(of: decorated.first, matching: find.byType(Material)),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Material>(
            find.descendant(
              of: decorated.first,
              matching: find.byType(Material),
            ),
          )
          .color,
      Colors.transparent,
    );
  });

  testWidgets('the ink well shares the card corner radius', (tester) async {
    final radius = BorderRadius.circular(20);
    await tester.pumpWidget(
      _host(
        AppTapCard(
          borderRadius: radius,
          onTap: () {},
          child: const SizedBox(width: 200, height: 80),
        ),
      ),
    );

    // A mismatched radius lets the splash bleed past the rounded corners.
    expect(tester.widget<InkWell>(find.byType(InkWell)).borderRadius, radius);
  });

  testWidgets('a non-interactive card exposes no button role', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(const AppTapCard(child: SizedBox(width: 200, height: 80))),
    );

    expect(find.byType(Semantics), findsWidgets);
    // Without a tap or long-press handler the card is decoration, so it
    // must not announce itself as a button.
    expect(
      tester.getSemantics(find.byType(AppTapCard)),
      isNot(matchesSemantics(isButton: true)),
    );
    handle.dispose();
  });

  testWidgets('drops the press scale under reduced motion', (tester) async {
    await tester.pumpWidget(
      _host(
        AppTapCard(onTap: () {}, child: const SizedBox(width: 200, height: 80)),
        disableAnimations: true,
      ),
    );

    expect(find.byType(AnimatedScale), findsNothing);
  });

  testWidgets('keeps the press scale when motion is allowed', (tester) async {
    await tester.pumpWidget(
      _host(
        AppTapCard(onTap: () {}, child: const SizedBox(width: 200, height: 80)),
      ),
    );

    expect(find.byType(AnimatedScale), findsOneWidget);
  });
}
