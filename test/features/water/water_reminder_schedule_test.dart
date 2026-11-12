import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/features/water/domain/water_reminder_schedule.dart';

List<String> _fmt(List<DateTime> times) => [
  for (final t in times)
    '${t.month}-${t.day} ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}',
];

const _tomorrowSep14 = ['9-14 10:00', '9-14 13:00', '9-14 16:00', '9-14 19:00'];

void main() {
  test('gunde en fazla 4 saat: 10, 13, 16, 19', () {
    expect(waterReminderHours, [10, 13, 16, 19]);
  });

  test('beklenen tempo: hedef 10 icin 2, 5, 7, 10 bardak', () {
    expect(
      [for (final h in waterReminderHours) expectedGlassesBy(h, 10)],
      [2, 5, 7, 10],
    );
    // Kucuk hedefte de son saat hedefin tamamini bekler.
    expect(expectedGlassesBy(19, 6), 6);
  });

  test('sabah hic su yokken bugunun 4 saati + yarinin 4 saati', () {
    final times = waterReminderTimes(
      now: DateTime(2026, 9, 13, 8),
      lastGlassAt: null,
      glassesToday: 0,
      goal: 10,
    );
    expect(_fmt(times), [
      '9-13 10:00',
      '9-13 13:00',
      '9-13 16:00',
      '9-13 19:00',
      ..._tomorrowSep14,
    ]);
  });

  test('tempoda olana o saatte hatirlatma kurulmaz', () {
    // 10:00'da beklenen 2 bardak; 2 icmis -> 10:00 atlanir, 13:00 kalir.
    final times = waterReminderTimes(
      now: DateTime(2026, 9, 13, 8),
      lastGlassAt: DateTime(2026, 9, 13, 7),
      glassesToday: 2,
      goal: 10,
    );
    expect(_fmt(times).take(3), ['9-13 13:00', '9-13 16:00', '9-13 19:00']);
  });

  test('tempodan ondeyse sadece geride kaldigi saat kalir', () {
    final times = waterReminderTimes(
      now: DateTime(2026, 9, 13, 9),
      lastGlassAt: DateTime(2026, 9, 13, 6),
      glassesToday: 7,
      goal: 10,
    );
    expect(_fmt(times), ['9-13 19:00', ..._tomorrowSep14]);
  });

  test('12:30da icilince 13:00 sessiz kalir, 16:00 kalir', () {
    final times = waterReminderTimes(
      now: DateTime(2026, 9, 13, 12, 30),
      lastGlassAt: DateTime(2026, 9, 13, 12, 30),
      glassesToday: 3,
      goal: 10,
    );
    expect(_fmt(times).take(2), ['9-13 16:00', '9-13 19:00']);
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
    expect(_fmt(times).first, '9-13 10:00');
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

  test('19:00dan sonra yalniz yarin', () {
    final times = waterReminderTimes(
      now: DateTime(2026, 9, 13, 19, 5),
      lastGlassAt: null,
      glassesToday: 2,
      goal: 10,
    );
    expect(_fmt(times), _tomorrowSep14);
  });

  test('yarindan sonrasi hic kurulmaz: uygulama acilmazsa bildirim biter', () {
    final times = waterReminderTimes(
      now: DateTime(2026, 9, 13, 8),
      lastGlassAt: null,
      glassesToday: 0,
      goal: 10,
    );
    expect(times.every((t) => t.day == 13 || t.day == 14), isTrue);
  });

  test('ay sonu gece yarisina yakin: yarin bir sonraki ayin 1i', () {
    final times = waterReminderTimes(
      now: DateTime(2026, 9, 30, 23, 50),
      lastGlassAt: null,
      glassesToday: 0,
      goal: 10,
    );
    expect(times, hasLength(4));
    expect(times.first, DateTime(2026, 10, 1, 10));
  });

  // DST test: only discriminates on hosts with EU DST (e.g. Europe/Berlin).
  // On fixed-offset timezones (e.g. Europe/Istanbul, UTC+3) this passes either way.
  // Wall-clock DateTime() construction in water_reminder_schedule.dart is the real guard.
  test('yaz saati gecis gecesi: yarinin saatleri hala 10-19', () {
    // 29 Mart 2026, AB'de saatler ileri alinir.
    final times = waterReminderTimes(
      now: DateTime(2026, 3, 28, 23, 30),
      lastGlassAt: null,
      glassesToday: 0,
      goal: 10,
    );
    expect(times.map((t) => t.hour), [10, 13, 16, 19]);
    expect(times.every((t) => t.day == 29), isTrue);
  });

  test('yil sonu: yarin bir sonraki yilin 1 Ocaki', () {
    final times = waterReminderTimes(
      now: DateTime(2026, 12, 31, 22),
      lastGlassAt: null,
      glassesToday: 0,
      goal: 10,
    );
    expect(times, hasLength(4));
    expect(times.first, DateTime(2027, 1, 1, 10));
  });
}
