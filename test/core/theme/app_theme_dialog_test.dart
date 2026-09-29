import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nutrilens/core/theme/app_colors.dart';
import 'package:nutrilens/core/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  // A default AlertDialog (no explicit styles) must be readable in both
  // themes: the title used to fall back to a dark colour on a dark surface.
  for (final entry in {
    'dark': (AppTheme.dark, AppColorsExtension.dark),
    'light': (AppTheme.light, AppColorsExtension.light),
  }.entries) {
    testWidgets('default AlertDialog title/content readable in ${entry.key}', (
      tester,
    ) async {
      final (theme, colors) = entry.value;
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: const Scaffold(
            body: AlertDialog(title: Text('Title'), content: Text('Body')),
          ),
        ),
      );

      Color? colorOf(String text) => tester
          .widget<RichText>(
            find.descendant(
              of: find.text(text),
              matching: find.byType(RichText),
            ),
          )
          .text
          .style
          ?.color;

      expect(colorOf('Title'), colors.textPrimary);
      expect(colorOf('Body'), colors.textSecondary);
      expect(
        tester.widget<Material>(find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(Material),
        ).first).color,
        colors.surfaceCard2,
      );
    });
  }
}
