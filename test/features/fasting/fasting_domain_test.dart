import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/features/fasting/domain/fasting_protocol.dart';
import 'package:nutrilens/features/fasting/domain/fasting_session.dart';
import 'package:nutrilens/features/fasting/domain/fasting_stats.dart';

FastingSession _session({
  required DateTime startedAt,
  required int targetMinutes,
  DateTime? endedAt,
  String id = 's',
}) =>
    FastingSession(
      id: id,
      userId: 'u',
      startedAt: startedAt,
      targetMinutes: targetMinutes,
      endedAt: endedAt,
    );

void main() {
  group('FastingProtocol', () {
    test('fastMinutes per protocol', () {
      expect(FastingProtocol.p16_8.fastMinutes, 960);
      expect(FastingProtocol.p18_6.fastMinutes, 1080);
      expect(FastingProtocol.p20_4.fastMinutes, 1200);
      expect(FastingProtocol.omad.fastMinutes, 1380);
    });

    test('label per protocol', () {
      expect(FastingProtocol.p16_8.label, '16:8');
      expect(FastingProtocol.p18_6.label, '18:6');
      expect(FastingProtocol.p20_4.label, '20:4');
      expect(FastingProtocol.omad.label, 'OMAD');
    });

    test('fromLabel parses known labels and falls back to 16:8 for unknown/null', () {
      expect(FastingProtocol.fromLabel('18:6'), FastingProtocol.p18_6);
      expect(FastingProtocol.fromLabel('20:4'), FastingProtocol.p20_4);
      expect(FastingProtocol.fromLabel('OMAD'), FastingProtocol.omad);
      expect(FastingProtocol.fromLabel('x'), FastingProtocol.p16_8);
      expect(FastingProtocol.fromLabel(null), FastingProtocol.p16_8);
    });
  });

  group('FastingSession', () {
    test('progress clamps at 1.0 after target and 0 at start', () {
      final start = DateTime(2026, 1, 1, 8);
      final session = _session(startedAt: start, targetMinutes: 960);
      expect(session.progress(start), 0.0);
      expect(session.progress(start.add(const Duration(hours: 16))), 1.0);
      expect(session.progress(start.add(const Duration(hours: 20))), 1.0);
    });

    test('remaining never negative', () {
      final start = DateTime(2026, 1, 1, 8);
      final session = _session(startedAt: start, targetMinutes: 960);
      expect(
        session.remaining(start.add(const Duration(hours: 20))),
        Duration.zero,
      );
      expect(
        session.remaining(start),
        const Duration(hours: 16),
      );
    });

    test('isCompleted false for ended-short fast', () {
      final start = DateTime(2026, 1, 1, 8);
      final session = _session(
        startedAt: start,
        targetMinutes: 960,
        endedAt: start.add(const Duration(hours: 10)),
      );
      expect(session.isCompleted, isFalse);
    });

    test('isCompleted false for active fast', () {
      final start = DateTime(2026, 1, 1, 8);
      final session = _session(startedAt: start, targetMinutes: 960);
      expect(session.isCompleted, isFalse);
      expect(session.isActive, isTrue);
    });

    test('isCompleted true when elapsed reaches target', () {
      final start = DateTime(2026, 1, 1, 8);
      final session = _session(
        startedAt: start,
        targetMinutes: 960,
        endedAt: start.add(const Duration(hours: 16)),
      );
      expect(session.isCompleted, isTrue);
    });
  });

  group('fastingStreak', () {
    test('completed fasts ending today, yesterday, day-before => 3', () {
      final now = DateTime(2026, 3, 10, 20);
      final sessions = [
        _session(
          id: 'a',
          startedAt: DateTime(2026, 3, 8),
          targetMinutes: 960,
          endedAt: DateTime(2026, 3, 8, 16),
        ),
        _session(
          id: 'b',
          startedAt: DateTime(2026, 3, 9),
          targetMinutes: 960,
          endedAt: DateTime(2026, 3, 9, 16),
        ),
        _session(
          id: 'c',
          startedAt: DateTime(2026, 3, 10),
          targetMinutes: 960,
          endedAt: DateTime(2026, 3, 10, 16),
        ),
      ];
      expect(fastingStreak(sessions, now), 3);
    });

    test('last completed ended 2 days ago => streak 0', () {
      final now = DateTime(2026, 3, 10, 20);
      final sessions = [
        _session(
          startedAt: DateTime(2026, 3, 8),
          targetMinutes: 960,
          endedAt: DateTime(2026, 3, 8, 16),
        ),
      ];
      expect(fastingStreak(sessions, now), 0);
    });

    test('counts yesterday-ended run when today has none', () {
      final now = DateTime(2026, 3, 10, 9);
      final sessions = [
        _session(
          id: 'a',
          startedAt: DateTime(2026, 3, 8),
          targetMinutes: 960,
          endedAt: DateTime(2026, 3, 8, 16),
        ),
        _session(
          id: 'b',
          startedAt: DateTime(2026, 3, 9),
          targetMinutes: 960,
          endedAt: DateTime(2026, 3, 9, 16),
        ),
      ];
      expect(fastingStreak(sessions, now), 2);
    });

    test('two fasts ending the same day count once', () {
      final now = DateTime(2026, 3, 10, 20);
      final sessions = [
        _session(
          id: 'a',
          startedAt: DateTime(2026, 3, 10),
          targetMinutes: 960,
          endedAt: DateTime(2026, 3, 10, 16),
        ),
        _session(
          id: 'b',
          startedAt: DateTime(2026, 3, 10, 17),
          targetMinutes: 960,
          endedAt: DateTime(2026, 3, 10, 18),
        ),
      ];
      // second session is short (1h) so it is not completed, and should not
      // add a second day even if it were.
      expect(fastingStreak(sessions, now), 1);
    });

    test('gece_yarisini_gecen_oruc_bitis_gunune_sayilir', () {
      // Starts 20:00 on day D, ends 12:00 on D+1 (16h = target). "now" is two
      // days after D so D+1 is "yesterday" — this only passes if the streak
      // keys off endedAt, not startedAt.
      final sessions = [
        _session(
          startedAt: DateTime(2026, 3, 9, 20),
          targetMinutes: 960,
          endedAt: DateTime(2026, 3, 10, 12),
        ),
      ];
      final now = DateTime(2026, 3, 11, 9);
      expect(fastingStreak(sessions, now), 1);
    });

    test('streak_dst_gecesi_kopmaz', () {
      // 2026-03-29 is the EU spring-forward DST night; the streak must not
      // break just because that local day is 23h long.
      final now = DateTime(2026, 3, 30, 20);
      final sessions = [
        _session(
          id: 'a',
          startedAt: DateTime(2026, 3, 28),
          targetMinutes: 960,
          endedAt: DateTime(2026, 3, 28, 16),
        ),
        _session(
          id: 'b',
          startedAt: DateTime(2026, 3, 29),
          targetMinutes: 960,
          endedAt: DateTime(2026, 3, 29, 16),
        ),
        _session(
          id: 'c',
          startedAt: DateTime(2026, 3, 30),
          targetMinutes: 960,
          endedAt: DateTime(2026, 3, 30, 16),
        ),
      ];
      expect(fastingStreak(sessions, now), 3);
    });

    test('incomplete fasts break nothing and count nothing', () {
      final now = DateTime(2026, 3, 10, 20);
      final sessions = [
        _session(
          id: 'a',
          startedAt: DateTime(2026, 3, 8),
          targetMinutes: 960,
          endedAt: DateTime(2026, 3, 8, 16),
        ),
        // Ended short on the day in between — must not break the streak.
        _session(
          id: 'short',
          startedAt: DateTime(2026, 3, 9),
          targetMinutes: 960,
          endedAt: DateTime(2026, 3, 9, 2),
        ),
        // Still active — must not crash or count.
        _session(
          id: 'active',
          startedAt: DateTime(2026, 3, 9, 8),
          targetMinutes: 960,
        ),
        _session(
          id: 'b',
          startedAt: DateTime(2026, 3, 9, 4),
          targetMinutes: 960,
          endedAt: DateTime(2026, 3, 9, 20),
        ),
        _session(
          id: 'c',
          startedAt: DateTime(2026, 3, 10),
          targetMinutes: 960,
          endedAt: DateTime(2026, 3, 10, 16),
        ),
      ];
      expect(fastingStreak(sessions, now), 3);
    });
  });

  group('averageFastDuration', () {
    test('returns null when there are no completed sessions', () {
      expect(averageFastDuration(const []), isNull);
      expect(
        averageFastDuration([
          _session(startedAt: DateTime(2026, 3, 10), targetMinutes: 960),
        ]),
        isNull,
      );
    });

    test('average of 960 and 1080 min = 1020 min', () {
      final sessions = [
        _session(
          id: 'a',
          startedAt: DateTime(2026, 3, 8),
          targetMinutes: 960,
          endedAt: DateTime(2026, 3, 8).add(const Duration(minutes: 960)),
        ),
        _session(
          id: 'b',
          startedAt: DateTime(2026, 3, 9),
          targetMinutes: 1080,
          endedAt: DateTime(2026, 3, 9).add(const Duration(minutes: 1080)),
        ),
      ];
      expect(averageFastDuration(sessions), const Duration(minutes: 1020));
    });
  });
}
