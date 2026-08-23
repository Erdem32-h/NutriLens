import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/core/theme/app_colors.dart';
import 'package:nutrilens/core/theme/cozy_tokens.dart';

void main() {
  group('CozyPalette', () {
    test('byIndex cycles through all five tints and wraps', () {
      const palette = CozyPalette.lightPalette;

      expect(palette.all, hasLength(5));
      for (var i = 0; i < palette.all.length; i++) {
        expect(palette.byIndex(i), same(palette.all[i]));
      }
      // The wrap is the whole point: lists are built from data of unknown
      // length, and an out-of-range read would throw on the 6th row.
      expect(palette.byIndex(5), same(palette.lilac));
      expect(palette.byIndex(12), same(palette.byIndex(2)));
    });

    test('lerp returns each end exactly at t=0 and t=1', () {
      final at0 = CozyPalette.lerp(
        CozyPalette.lightPalette,
        CozyPalette.darkPalette,
        0,
      );
      final at1 = CozyPalette.lerp(
        CozyPalette.lightPalette,
        CozyPalette.darkPalette,
        1,
      );

      expect(at0.mint.surface, CozyPalette.lightPalette.mint.surface);
      expect(at1.mint.surface, CozyPalette.darkPalette.mint.surface);
      expect(at1.floating, CozyPalette.darkPalette.floating);
      expect(at1.bodyOnTint, CozyPalette.darkPalette.bodyOnTint);
    });

    test('lerp moves every field, not just the tints', () {
      // A field left out of lerp() silently freezes at the "from" value for
      // the whole theme animation — the failure looks like a rendering bug
      // rather than a missing line, so pin each one.
      final mid = CozyPalette.lerp(
        CozyPalette.lightPalette,
        CozyPalette.darkPalette,
        0.5,
      );

      expect(mid.floating, isNot(CozyPalette.lightPalette.floating));
      expect(mid.bodyOnTint, isNot(CozyPalette.lightPalette.bodyOnTint));
      expect(mid.rose.ink, isNot(CozyPalette.lightPalette.rose.ink));
      expect(
        mid.headerGlow.colors.first,
        isNot(CozyPalette.lightPalette.headerGlow.colors.first),
      );
    });
  });

  group('AppColorsExtension', () {
    test('carries the cozy palette through lerp', () {
      final lerped =
          AppColorsExtension.light.lerp(AppColorsExtension.dark, 1)
              as AppColorsExtension;

      expect(lerped.cozy.peach.surface, CozyPalette.darkPalette.peach.surface);
    });

    test('carries the cozy palette through copyWith', () {
      final copied =
          AppColorsExtension.light.copyWith(primary: const Color(0xFF000000))
              as AppColorsExtension;

      expect(copied.cozy.sky.ink, AppColorsExtension.light.cozy.sky.ink);
    });

    test('light and dark define distinct tints', () {
      // Guards against a copy-paste that points both themes at one palette,
      // which would make dark mode render light pastel cards.
      expect(
        AppColorsExtension.light.cozy.lilac.surface,
        isNot(AppColorsExtension.dark.cozy.lilac.surface),
      );
    });
  });
}
