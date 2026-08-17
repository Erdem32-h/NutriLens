import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// The weights `AppTypography` asks google_fonts for.
///
/// 600/700/800 come from the explicit `_jakarta(...)` calls; 400 and 500 come
/// from the Material defaults that `plusJakartaSansTextTheme()` re-styles.
/// Names follow google_fonts' own `<Family>-<Weight>` convention — it locates
/// a bundled font by scanning the asset manifest for a path ending in exactly
/// this string, so these are matched by file name, not by content.
const _requiredFontFiles = <String>[
  'PlusJakartaSans-Regular.ttf',
  'PlusJakartaSans-Medium.ttf',
  'PlusJakartaSans-SemiBold.ttf',
  'PlusJakartaSans-Bold.ttf',
  'PlusJakartaSans-ExtraBold.ttf',
];

void main() {
  // Sentry NUTRILENS-5: while these were fetched at runtime, every user
  // without a working connection to fonts.gstatic.com on a cold start got an
  // error and the fallback font. `allowRuntimeFetching = false` in main.dart
  // removes the network path entirely, which means a missing or renamed file
  // here is no longer a degraded font — it is a hard failure at startup.
  group('bundled fonts', () {
    for (final name in _requiredFontFiles) {
      test('$name ships in assets/fonts', () {
        final file = File('assets/fonts/$name');
        expect(
          file.existsSync(),
          isTrue,
          reason:
              'google_fonts matches bundled fonts by file name. Without '
              '$name the app has no way to render that weight offline.',
        );
        // A truncated or LFS-pointer file passes existsSync but renders
        // nothing; the real files are ~63 KB each.
        expect(file.lengthSync(), greaterThan(50000));
      });
    }

    testWidgets('every weight resolves without touching the network', (
      tester,
    ) async {
      // The end of the chain the two checks above only approximate: this
      // runs google_fonts' real asset-manifest lookup against the real
      // bundle, with fetching off, so a filename that no longer matches its
      // `<Family>-<Weight>` convention fails here rather than on a user's
      // phone at startup.
      final previous = GoogleFonts.config.allowRuntimeFetching;
      GoogleFonts.config.allowRuntimeFetching = false;
      addTearDown(() => GoogleFonts.config.allowRuntimeFetching = previous);

      for (final weight in const [
        FontWeight.w400,
        FontWeight.w500,
        FontWeight.w600,
        FontWeight.w700,
        FontWeight.w800,
      ]) {
        GoogleFonts.plusJakartaSans(fontWeight: weight);
      }

      await expectLater(GoogleFonts.pendingFonts(), completes);
    });

    test('the font folder is declared as an asset', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(
        pubspec.contains('- assets/fonts/'),
        isTrue,
        reason:
            'Files on disk are invisible to google_fonts unless the folder is '
            'in the asset manifest.',
      );
    });
  });
}
