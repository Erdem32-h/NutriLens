import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/features/ramadan/domain/fasting_times.dart';
import 'package:nutrilens/features/ramadan/domain/turkish_cities.dart';

// Returned times are device-local, so assert in UTC (Turkey = UTC+3, no DST):
// 18:23 TRT == 15:23Z. |difference| <= 1 minute.
void expectNear(DateTime actual, int trtHour, int minute) {
  final expected = DateTime.utc(actual.toUtc().year, actual.toUtc().month,
      actual.toUtc().day, trtHour - 3, minute);
  expect(actual.toUtc().difference(expected).inMinutes.abs(), lessThanOrEqualTo(1));
}

void main() {
  group('fastingTimes', () {
    test('Ankara day 1', () {
      final t = fastingTimes(DateTime(2027, 2, 8), 39.9334, 32.8597);
      expectNear(t.imsak, 6, 18);
      expectNear(t.iftar, 18, 23);
    });

    test('Ankara later in Ramadan', () {
      final t = fastingTimes(DateTime(2027, 3, 8), 39.9334, 32.8597);
      expectNear(t.imsak, 5, 42);
      expectNear(t.iftar, 18, 55);
    });

    test('İstanbul day 1', () {
      final t = fastingTimes(DateTime(2027, 2, 8), 41.0082, 28.9784);
      expectNear(t.imsak, 6, 34);
      expectNear(t.iftar, 18, 36);
    });

    test('Van day 1', () {
      final t = fastingTimes(DateTime(2027, 2, 8), 38.4891, 43.4089);
      expectNear(t.imsak, 5, 36);
      expectNear(t.iftar, 17, 43);
    });

    test('rounding is on the safe side', () {
      expect(ceilToMinute(DateTime(2027, 2, 8, 18, 22, 10)), DateTime(2027, 2, 8, 18, 23));
      expect(ceilToMinute(DateTime(2027, 2, 8, 18, 23)), DateTime(2027, 2, 8, 18, 23));
      expect(floorToMinute(DateTime(2027, 2, 8, 6, 17, 50)), DateTime(2027, 2, 8, 6, 17));
    });
  });

  group('turkishCities', () {
    test('81 provinces, unique plates 1..81', () {
      expect(turkishCities.map((c) => c.plate).toSet(), {for (var i = 1; i <= 81; i++) i});
      expect(cityByPlate(6)?.name, 'Ankara');
    });
  });
}
