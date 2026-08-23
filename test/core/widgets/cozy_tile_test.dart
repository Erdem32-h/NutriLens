import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/core/theme/app_colors.dart';
import 'package:nutrilens/core/theme/app_theme.dart';
import 'package:nutrilens/core/widgets/cozy_header.dart';
import 'package:nutrilens/core/widgets/cozy_tile.dart';

Widget _host(Widget child, {Size size = const Size(400, 800)}) {
  return MaterialApp(
    theme: AppTheme.light,
    home: MediaQuery(
      data: MediaQueryData(size: size),
      child: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

void main() {
  group('CozyTile', () {
    testWidgets('shows the value pill only when a value is given', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          CozyTile(
            tint: AppColorsExtension.light.cozy.sky,
            icon: Icons.language_rounded,
            title: 'Language',
            subtitle: 'Set your preferred language',
            value: 'English',
            onTap: () {},
          ),
        ),
      );

      expect(find.text('English'), findsOneWidget);
      expect(find.byType(CozyValuePill), findsOneWidget);

      await tester.pumpWidget(
        _host(
          CozyTile(
            tint: AppColorsExtension.light.cozy.sky,
            icon: Icons.language_rounded,
            title: 'Language',
            subtitle: 'Set your preferred language',
            onTap: () {},
          ),
        ),
      );

      expect(find.byType(CozyValuePill), findsNothing);
      // The descriptive line is the row's whole point after the redesign —
      // it used to be squeezed into the pill and ellipsised away.
      expect(find.text('Set your preferred language'), findsOneWidget);
    });

    testWidgets('omits the chevron when the row does not navigate', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          CozyTile(
            tint: AppColorsExtension.light.cozy.mint,
            icon: Icons.star,
            title: 'Premium active',
            subtitle: 'Unlimited scans',
          ),
        ),
      );

      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
    });

    testWidgets('trailing replaces the value pill entirely', (tester) async {
      await tester.pumpWidget(
        _host(
          CozyTile(
            tint: AppColorsExtension.light.cozy.rose,
            icon: Icons.science_rounded,
            title: 'Chemicals',
            value: 'Active',
            trailing: const Icon(Icons.toggle_on),
          ),
        ),
      );

      expect(find.byIcon(Icons.toggle_on), findsOneWidget);
      expect(find.byType(CozyValuePill), findsNothing);
    });

    testWidgets('reports the row to assistive tech as title plus subtitle', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          CozyTile(
            tint: AppColorsExtension.light.cozy.peach,
            icon: Icons.warning_amber_rounded,
            title: 'Allergens',
            subtitle: '63 allergen types',
            onTap: () {},
          ),
        ),
      );

      // Asserted on the Semantics widget rather than the rendered semantics
      // tree: the label is what AppTapCard is handed, and that hand-off is
      // the part this widget owns.
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label == 'Allergens. 63 allergen types',
        ),
        findsOneWidget,
      );
    });
  });

  group('CozyHeader', () {
    testWidgets('renders a back chip only when onBack is supplied', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const CozyHeader(title: 'Profile', subtitle: 'Personalize')),
      );
      expect(find.byIcon(Icons.arrow_back_rounded), findsNothing);

      await tester.pumpWidget(
        _host(CozyHeader(title: 'Allergens', onBack: () {})),
      );
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    });

    testWidgets('back chip invokes onBack', (tester) async {
      var backs = 0;
      await tester.pumpWidget(
        _host(CozyHeader(title: 'Allergens', onBack: () => backs++)),
      );

      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();

      expect(backs, 1);
    });

    testWidgets('shrinks its type on a short screen', (tester) async {
      // 640dp-tall phones are a real share of the install base; at full size
      // the header plus the nav chrome left almost no content on screen.
      await tester.pumpWidget(
        _host(
          const CozyHeader(title: 'My Meals', subtitle: 'Today'),
          size: const Size(360, 640),
        ),
      );
      final small = tester.widget<Text>(find.text('My Meals')).style!.fontSize!;

      await tester.pumpWidget(
        _host(
          const CozyHeader(title: 'My Meals', subtitle: 'Today'),
          size: const Size(400, 900),
        ),
      );
      final large = tester.widget<Text>(find.text('My Meals')).style!.fontSize!;

      expect(small, lessThan(large));
    });
  });
}
