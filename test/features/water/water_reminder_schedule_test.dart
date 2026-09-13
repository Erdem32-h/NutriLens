import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/features/water/domain/water_reminder_schedule.dart';

List<String> _fmt(List<DateTime> times) => [
  for (final t in times)
    '${t.month}-${t.day} ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}',
];

const _tomorrowSep14 = [
  '9-14 09:00', '9-14 11:00', '9-14 13:00', '9-14 15:00',
  '9-14 17:00', '9-14 19:00', '9-14 21:00',
];

void main() {
  test('sabah hic su yokken bugunun 7 saati + yarinin 7 saati', () {
    final times = waterReminderTimes(
      now: DateTime(2026, 9, 13, 8),
      lastGlassAt: null,
      glassesToday: 0,
      goal: 10,
    );
    expect(_fmt(times), [
      '9-13 09:00', '9-13 11:00', '9-13 13:00', '9-13 15:00',
      '9-13 17:00', '9-13 19:00', '9-13 21:00',
      ..._tomorrowSep14,
    ]);
  });

  test('10:30da icilince 11:00 atlanir, 13:00 kalir', () {
    final times = waterReminderTimes(
      now: DateTime(2026, 9, 13, 10, 30),
      lastGlassAt: DateTime(2026, 9, 13, 10, 30),
      glassesToday: 3,
      goal: 10,
    );
    expect(_fmt(times).take(2), ['9-13 13:00', '9-13 15:00']);
  });

  test('tam 11:00de icilince 13:00 kalir (sinir dahil)', () {
    final times = waterReminderTimes(
      now: DateTime(2026, 9, 13, 11),
      lastGlassAt: DateTime(2026, 9, 13, 11),
      glassesToday: 3,
      goal: 10,
    );
    expect(_fmt(times).first, '9-13 13:00');
  });

  test('dunku son bardak bugunu etkilemez', () {
    final times = waterReminderTimes(
      now: DateTime(2026, 9, 13, 8),
      lastGlassAt: DateTime(2026, 9, 12, 20),
      glassesToday: 0,
      goal: 10,
    );
    expect(_fmt(times).first, '9-13 09:00');
  });

  test('hedefe ulasildiysa yalniz yarin', () {
    final times = waterReminderTimes(
      now: DateTime(2026, 9, 13, 12),
      lastGlassAt: DateTime(2026, 9, 13, 11),
      glassesToday: 10,
      goal: 10,
    );
    expect(_fmt(times), _tomorrowSep14);
  });

  test('21:00ten sonra yalniz yarin', () {
    final times = waterReminderTimes(
      now: DateTime(2026, 9, 13, 21, 5),
      lastGlassAt: null,
      glassesToday: 2,
      goal: 10,
    );
    expect(_fmt(times), _tomorrowSep14);
  });

  test('ay sonu gece yarisina yakin: yarin bir sonraki ayin 1i', () {
    final times = waterReminderTimes(
      now: DateTime(2026, 9, 30, 23, 50),
      lastGlassAt: null,
      glassesToday: 0,
      goal: 10,
    );
    expect(times, hasLength(7));
    expect(times.first, DateTime(2026, 10, 1, 9));
  });

  test('yaz saati gecis gecesi: yarinin saatleri hala 09-21', () {
    // 29 Mart 2026, AB'de saatler ileri alinir.
    final times = waterReminderTimes(
      now: DateTime(2026, 3, 28, 23, 30),
      lastGlassAt: null,
      glassesToday: 0,
      goal: 10,
    );
    expect(times.map((t) => t.hour), [9, 11, 13, 15, 17, 19, 21]);
    expect(times.every((t) => t.day == 29), isTrue);
  });
}
