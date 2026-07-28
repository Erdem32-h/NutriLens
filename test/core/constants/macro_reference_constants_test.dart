import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/core/constants/macro_reference_constants.dart';

void main() {
  test('pay aralığın altındaysa low', () {
    expect(
      MacroReferenceConstants.levelFor(9.9, min: 10, max: 35),
      MacroLevel.low,
    );
  });

  test('pay aralığın içindeyse normal (sınırlar dahil)', () {
    expect(
      MacroReferenceConstants.levelFor(10, min: 10, max: 35),
      MacroLevel.normal,
    );
    expect(
      MacroReferenceConstants.levelFor(35, min: 10, max: 35),
      MacroLevel.normal,
    );
  });

  test('pay aralığın üstündeyse high', () {
    expect(
      MacroReferenceConstants.levelFor(35.1, min: 10, max: 35),
      MacroLevel.high,
    );
  });
}
