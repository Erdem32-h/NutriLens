import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/features/ramadan/domain/ramadan_schedule.dart';

void main() {
  final t = (imsak: DateTime(2027, 2, 8, 6, 18), iftar: DateTime(2027, 2, 8, 18, 23));
  final t2 = (imsak: DateTime(2027, 2, 9, 6, 17), iftar: DateTime(2027, 2, 9, 18, 24));

  group('ramadanWaterTimes', () {
    test('slots: iftar+30 then every 2h up to 23:30', () {
      final r = ramadanWaterTimes(
        now: DateTime(2027, 2, 8, 12),
        today: t,
        tomorrow: t2,
        lastGlassAt: null,
        glassesToday: 0,
        goal: 10,
      );
      expect(r.where((d) => d.day == 8), [
        DateTime(2027, 2, 8, 18, 53),
        DateTime(2027, 2, 8, 20, 53),
        DateTime(2027, 2, 8, 22, 53),
      ]);
      expect(r.where((d) => d.day == 9).first, DateTime(2027, 2, 9, 18, 54));
    });

    test('quiet gap after a glass drops today slots inside 2h', () {
      final r = ramadanWaterTimes(
        now: DateTime(2027, 2, 8, 20),
        today: t,
        tomorrow: t2,
        lastGlassAt: DateTime(2027, 2, 8, 20),
        glassesToday: 3,
        goal: 10,
      );
      expect(r.where((d) => d.day == 8), [DateTime(2027, 2, 8, 22, 53)]);
    });

    test('goal met drops today, keeps tomorrow', () {
      final r = ramadanWaterTimes(
        now: DateTime(2027, 2, 8, 12),
        today: t,
        tomorrow: t2,
        lastGlassAt: null,
        glassesToday: 10,
        goal: 10,
      );
      expect(r.where((d) => d.day == 8), isEmpty);
      expect(r.where((d) => d.day == 9), isNotEmpty);
    });

    test('never more than 14', () {
      final lateIftar = (
        imsak: DateTime(2027, 2, 8, 6, 18),
        iftar: DateTime(2027, 2, 8, 17),
      );
      final lateIftar2 = (
        imsak: DateTime(2027, 2, 9, 6, 17),
        iftar: DateTime(2027, 2, 9, 17),
      );
      final r = ramadanWaterTimes(
        now: DateTime(2027, 2, 8, 12),
        today: lateIftar,
        tomorrow: lateIftar2,
        lastGlassAt: null,
        glassesToday: 0,
        goal: 10,
      );
      expect(r.length, lessThanOrEqualTo(14));
    });
  });

  group('ramadanWaterTimes per-day mix', () {
    test('today not Ramadan (null): normal 09-21 hours today, Ramadan tomorrow', () {
      final r = ramadanWaterTimes(
        now: DateTime(2027, 2, 7, 20),
        today: null,
        tomorrow: t,
        lastGlassAt: null,
        glassesToday: 0,
        goal: 10,
      );
      expect(r, [
        DateTime(2027, 2, 7, 21),
        DateTime(2027, 2, 8, 18, 53),
        DateTime(2027, 2, 8, 20, 53),
        DateTime(2027, 2, 8, 22, 53),
      ]);
    });

    test('tomorrow not Ramadan (null, Eid): normal hours tomorrow', () {
      final r = ramadanWaterTimes(
        now: DateTime(2027, 2, 8, 12),
        today: t,
        tomorrow: null,
        lastGlassAt: null,
        glassesToday: 0,
        goal: 10,
      );
      expect(r.where((d) => d.day == 9), [
        for (final h in [9, 11, 13, 15, 17, 19, 21]) DateTime(2027, 2, 9, h),
      ]);
    });
  });

  group('ramadanNotificationTimes', () {
    test('notification ids and times', () {
      final n = ramadanNotificationTimes(
        now: DateTime(2027, 2, 8, 12),
        nextDays: [(DateTime(2027, 2, 8), t), (DateTime(2027, 2, 9), t2)],
        sahurOffsetMin: 45,
        firstDay: DateTime.utc(2027, 2, 8),
        eidDay: DateTime.utc(2027, 3, 9),
      );
      expect(n, containsAll([
        (
          id: 3010,
          at: DateTime(2027, 2, 8, 18, 23),
          kind: RamadanNotificationKind.iftar,
          imsakAt: null,
        ),
        (
          id: 3001,
          at: DateTime(2027, 2, 9, 5, 32),
          kind: RamadanNotificationKind.sahur,
          imsakAt: DateTime(2027, 2, 9, 6, 17),
        ),
        (
          id: 3011,
          at: DateTime(2027, 2, 9, 18, 24),
          kind: RamadanNotificationKind.iftar,
          imsakAt: null,
        ),
      ]));
      expect(n.any((x) => x.id == 3000), isFalse); // 05:33 today already passed
    });

    test('nothing on or after Eid', () {
      final n = ramadanNotificationTimes(
        now: DateTime(2027, 3, 8, 0),
        nextDays: [(DateTime(2027, 3, 9), t)],
        sahurOffsetMin: 45,
        firstDay: DateTime.utc(2027, 2, 8),
        eidDay: DateTime.utc(2027, 3, 9),
      );
      expect(n, isEmpty);
    });

    test('nothing before firstDay (offer window): 7 Feb skipped, 8 Feb kept', () {
      final t0 = (imsak: DateTime(2027, 2, 7, 6, 19), iftar: DateTime(2027, 2, 7, 18, 22));
      final n = ramadanNotificationTimes(
        now: DateTime(2027, 2, 7, 0, 30),
        nextDays: [(DateTime(2027, 2, 7), t0), (DateTime(2027, 2, 8), t)],
        sahurOffsetMin: 45,
        firstDay: DateTime.utc(2027, 2, 8),
        eidDay: DateTime.utc(2027, 3, 9),
      );
      expect(n.map((x) => x.id), [3001, 3011]);
    });
  });
}
