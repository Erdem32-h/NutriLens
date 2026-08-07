import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/core/theme/app_theme.dart';
import 'package:nutrilens/features/scanner/presentation/widgets/meal_save_bar.dart';

/// Mirrors how `FoodResultScreen` mounts the bar: a long scrolling body plus
/// the bar as `Scaffold.bottomNavigationBar`. The point of the widget is that
/// the save action does NOT live inside that scroll view.
Widget _screenWithBar({
  required VoidCallback? onSave,
  bool saving = false,
  ScrollController? controller,
  ThemeData? theme,
}) {
  return MaterialApp(
    theme: theme ?? AppTheme.light,
    home: Scaffold(
      body: SingleChildScrollView(
        controller: controller,
        // Taller than any phone, like the real result page.
        child: const SizedBox(height: 4000, child: Text('result body')),
      ),
      bottomNavigationBar: MealSaveBar(
        onSave: onSave,
        saving: saving,
        label: 'Öğünlerime kaydet',
      ),
    ),
  );
}

void main() {
  group('MealSaveBar', () {
    testWidgets('is on screen without scrolling, and stays there after '
        'scrolling to the bottom', (tester) async {
      final controller = ScrollController();
      await tester.pumpWidget(
        _screenWithBar(onSave: () {}, controller: controller),
      );

      // The regression this guards: the save CTA used to be the last child of
      // the scroll view, i.e. off screen until the user scrolled past the
      // whole report.
      final label = find.text('Öğünlerime kaydet');
      expect(label, findsOneWidget);

      final screen = tester.getSize(find.byType(MaterialApp));
      final barTop = tester.getTopLeft(find.byType(MealSaveBar)).dy;
      expect(
        barTop,
        lessThan(screen.height),
        reason: 'save bar must be within the viewport before any scrolling',
      );

      // And it is pinned: scrolling the body must not move it.
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pump();
      expect(tester.getTopLeft(find.byType(MealSaveBar)).dy, barTop);

      controller.dispose();
    });

    testWidgets('does not overlap the scrollable body', (tester) async {
      await tester.pumpWidget(_screenWithBar(onSave: () {}));

      // `bottomNavigationBar` makes the framework shrink the body rather than
      // paint the bar over it — a Stack/Positioned footer would have hidden
      // the last rows of the report instead.
      final bodyBottom = tester
          .getBottomLeft(find.byType(SingleChildScrollView))
          .dy;
      final barTop = tester.getTopLeft(find.byType(MealSaveBar)).dy;
      expect(bodyBottom, lessThanOrEqualTo(barTop));
    });

    testWidgets('fires onSave when tapped', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_screenWithBar(onSave: () => taps++));

      await tester.tap(find.byType(FilledButton));
      await tester.pump();

      expect(taps, 1);
    });

    testWidgets('while saving shows a spinner and swallows taps', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        _screenWithBar(onSave: () => taps++, saving: true),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.save_rounded), findsNothing);

      await tester.tap(find.byType(FilledButton));
      await tester.pump();

      // A second save would write a duplicate meal, so the busy state must
      // block the tap rather than merely look busy.
      expect(taps, 0);
    });

    testWidgets('renders disabled when onSave is null', (tester) async {
      await tester.pumpWidget(_screenWithBar(onSave: null));

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
    });

    // The bar paints its own surface and top border from the AppColors theme
    // extension, so a theme missing that extension would throw at build time
    // rather than degrade. The scanner is a dark-first screen; cover both.
    //
    // The themes are read inside the test bodies on purpose: touching
    // `AppTheme.*` while registering tests evaluates google_fonts outside a
    // test zone, which fails the whole file before a single test runs.
    testWidgets('builds under the light theme', (tester) async {
      await tester.pumpWidget(
        _screenWithBar(onSave: () {}, theme: AppTheme.light),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(MealSaveBar), findsOneWidget);
    });

    testWidgets('builds under the dark theme', (tester) async {
      await tester.pumpWidget(
        _screenWithBar(onSave: () {}, theme: AppTheme.dark),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(MealSaveBar), findsOneWidget);
    });
  });
}
