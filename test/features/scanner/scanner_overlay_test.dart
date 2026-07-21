import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/core/theme/app_theme.dart';
import 'package:nutrilens/features/scanner/presentation/widgets/scanner_overlay.dart';

/// Reproduces the scanner screen's stacking order: content first, decorative
/// overlays painted on top of it.
Widget _stackedOverContent(Widget overlay, VoidCallback onTap) {
  return MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(
      body: Stack(
        children: [
          Center(
            child: ElevatedButton(
              onPressed: onTap,
              child: const Text('Enter Barcode Manually'),
            ),
          ),
          overlay,
        ],
      ),
    ),
  );
}

void main() {
  // Both overlays are full-screen and sit above everything the scanner
  // screen draws. ScannerOverlay in particular is a Stack of decorated
  // Containers, which are hit-testable — so without IgnorePointer it
  // silently ate every tap underneath. That is what made the "Enter
  // barcode manually" button on the camera-permission-denied screen
  // visible but impossible to press.
  testWidgets('ScannerOverlay does not absorb taps meant for content below',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _stackedOverContent(const ScannerOverlay(), () => taps++),
    );

    await tester.tap(find.byType(ElevatedButton), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(taps, 1);
  });

  testWidgets('ScannerOverlayBorder does not absorb taps either',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _stackedOverContent(const ScannerOverlayBorder(), () => taps++),
    );

    await tester.tap(find.byType(ElevatedButton), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(taps, 1);
  });
}
