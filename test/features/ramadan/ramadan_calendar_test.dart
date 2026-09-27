import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/features/ramadan/domain/ramadan_calendar.dart';

void main() {
  group('RamadanCalendar', () {
    test('2027 period length is 29', () {
      expect(ramadanPeriods.single.length, 29);
    });

    test('window boundaries', () {
      expect(offerPeriod(DateTime(2027, 2, 4, 23, 59)), isNull);
      expect(offerPeriod(DateTime(2027, 2, 5)), isNotNull);
      expect(currentRamadan(DateTime(2027, 2, 7, 23)), isNull);
      expect(ramadanDayIndex(DateTime(2027, 2, 8, 0, 1)), 1);
      expect(ramadanDayIndex(DateTime(2027, 3, 8, 23)), 29);
      expect(currentRamadan(DateTime(2027, 3, 9)), isNull);
      expect(offerPeriod(DateTime(2027, 3, 9)), isNull);
      expect(latestPeriod(DateTime(2027, 6, 1))?.year, 2027);
      expect(latestPeriod(DateTime(2026, 12, 1)), isNull);
      expect(latestPeriod(DateTime(2027, 2, 10))?.year, 2027);
      expect(latestPeriod(DateTime(2027, 2, 7)), isNull);
    });
  });
}
