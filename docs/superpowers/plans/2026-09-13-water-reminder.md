# Water Counter + Reminder Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Daily water counter (glasses of 200 ml) with goal, 7-day history and optional 2-hourly reminders, free for everyone including guests.

**Architecture:** One Drift row per `(userId, day)` in a new `water_logs` table (schema v5). Pure functions compute the goal and the reminder times; `NotificationService` only arms/cancels. A small `WaterController` (Riverpod `Provider`) is the single write path: it updates Drift, invalidates read providers, tracks analytics and reschedules reminders. UI is a card on the Meals tab plus a `/water` screen.

**Tech Stack:** Flutter, Riverpod 3 (`flutter_riverpod ^3.3.1`), Drift (+ `drift_dev` schema tooling), `flutter_local_notifications 22.0.1`, `timezone`, `shared_preferences`, `intl`, `mocktail`.

**Spec:** `docs/superpowers/specs/2026-09-13-water-reminder-design.md`

## Global Constraints

- 1 glass = 200 ml (`kGlassMl = 200`).
- Default goal 10 glasses; weight-based suggestion `round(weightKg × 35 / 200)` clamped to 6–16.
- Manual goal range 1–20.
- Reminder slots 09, 11, 13, 15, 17, 19, 21 local; skip slots `< lastGlassAt + 2h` on the same day; no slots today when `glasses >= goal`; always all 7 tomorrow; max 14.
- Water notification ids 2000–2013 only. Never cancel or reuse 1001 (meal reminder).
- Reminder default off. Enabling requests OS permission; denied → stays off.
- Free for all users, guests included. No Supabase / network changes.
- Drift: `schemaVersion` 5; `createTable(waterLogs)` guarded `from < 5 && to >= 5`.
- All new user-facing strings in all 6 ARB files (tr template, en, es, pt, ar, zh).
- Run `flutter analyze --no-pub` and the touched tests before every commit. `dart format` only the files you changed.
- Commit messages: conventional type, end with `Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>`.

## File Map

Create:

| File | Responsibility |
|---|---|
| `lib/config/drift/tables/water_logs_table.dart` | Drift table definition |
| `lib/features/water/domain/water_day.dart` | `WaterDay` entity + `waterDayKey()` |
| `lib/features/water/domain/water_goal.dart` | goal constants + `suggestedWaterGoal()` |
| `lib/features/water/domain/water_reminder_schedule.dart` | `waterReminderTimes()` pure function |
| `lib/features/water/data/datasources/water_local_datasource.dart` | Drift CRUD, reassign, delete |
| `lib/features/water/data/water_settings_store.dart` | SharedPreferences keys (goal, reminder, prompt) |
| `lib/features/water/presentation/providers/water_provider.dart` | read providers, settings notifier, `WaterController` |
| `lib/features/water/presentation/water_actions.dart` | context-bound UI flows (add/remove glass, toggle reminder, snackbars) |
| `lib/features/water/presentation/widgets/water_card.dart` | Meals tab card |
| `lib/features/water/presentation/screens/water_screen.dart` | `/water` screen incl. 7-day chart |
| `drift_schemas/drift_schema_v5.json`, `test/config/drift/generated_migrations/schema_v5.dart` | generated |
| `test/config/drift/migration_v5_test.dart` | v4 → v5 migration |
| `test/features/water/*` | tests listed per task |

Modify: `lib/config/drift/app_database.dart`, `lib/core/services/notification_service.dart`, `lib/core/analytics/analytics_event.dart`, `lib/core/session/guest_migration_service.dart`, `lib/features/auth/presentation/widgets/guest_migration_prompt_sheet.dart`, `lib/features/auth/presentation/providers/auth_provider.dart`, `lib/features/profile/data/services/user_data_deletion_service.dart`, `lib/features/profile/presentation/providers/user_data_deletion_provider.dart`, `lib/features/meals/presentation/screens/meals_screen.dart`, `lib/features/app_shell/app_shell_screen.dart`, `lib/config/router/app_router.dart`, `lib/config/router/route_names.dart`, 6 ARB files, `test/config/drift/migration_v4_test.dart`, `test/core/session/guest_migration_service_test.dart`, `test/features/profile/data/services/user_data_deletion_service_test.dart`, spec file (two corrections, Task 1 and Task 5).

---

### Task 1: `water_logs` table and schema v5 migration

**Files:**
- Create: `lib/config/drift/tables/water_logs_table.dart`
- Modify: `lib/config/drift/app_database.dart`
- Generate: `lib/config/drift/app_database.g.dart`, `drift_schemas/drift_schema_v5.json`, `test/config/drift/generated_migrations/schema_v5.dart`, `test/config/drift/generated_migrations/schema.dart`
- Create test: `test/config/drift/migration_v5_test.dart`
- Modify test: `test/config/drift/migration_v4_test.dart`
- Modify: `docs/superpowers/specs/2026-09-13-water-reminder-design.md`

**Interfaces:**
- Produces: `AppDatabase.waterLogs` table, data class `WaterLog { userId, day, glasses, goalGlasses, lastGlassAt }`, companion `WaterLogsCompanion` (`WaterLogsCompanion.insert(userId:, day:, goalGlasses:, glasses: Value<int>, lastGlassAt: Value<DateTime?>)`).

- [ ] **Step 1: Write the table**

`lib/config/drift/tables/water_logs_table.dart`:

```dart
import 'package:drift/drift.dart';

/// Günlük su sayacı — kullanıcı + gün başına tek satır.
///
/// `day` yerel tarih (`yyyy-MM-dd`). `goalGlasses` o günün hedefinin kopyası:
/// hedef sonradan değişse de geçmiş bir günün "hedefe ulaşıldı mı" sonucu
/// değişmesin. Misafirde `userId == kGuestUserId`.
class WaterLogs extends Table {
  TextColumn get userId => text()();
  TextColumn get day => text()();
  IntColumn get glasses => integer().withDefault(const Constant(0))();
  IntColumn get goalGlasses => integer()();
  DateTimeColumn get lastGlassAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {userId, day};
}
```

- [ ] **Step 2: Register table, bump version, add guarded migration step**

In `lib/config/drift/app_database.dart`:

Add import after `import 'tables/user_metrics_table.dart';`:

```dart
import 'tables/water_logs_table.dart';
```

Add `WaterLogs,` after `UserMetrics,` in the `@DriftDatabase(tables: [...])` list.

Change `int get schemaVersion => 4;` to `int get schemaVersion => 5;`.

Append inside `onUpgrade`, after the `if (from < 4) { ... }` block:

```dart
        // `to` guard: SchemaVerifier replays older steps with `to` pinned to
        // the version under test (e.g. 3 → 4). Without it, the v3→v4 test
        // would also get this table and fail validation.
        if (from < 5 && to >= 5) {
          await m.createTable(waterLogs);
        }
```

- [ ] **Step 3: Generate code and schema snapshots**

Run:

```bash
dart run build_runner build --delete-conflicting-outputs
dart run drift_dev schema dump lib/config/drift/app_database.dart drift_schemas/
dart run drift_dev schema generate drift_schemas/ test/config/drift/generated_migrations/
```

Expected: `drift_schemas/drift_schema_v5.json` and `test/config/drift/generated_migrations/schema_v5.dart` exist; `schema.dart` now lists `versions = const [3, 4, 5]`.

- [ ] **Step 4: Write the migration test**

`test/config/drift/migration_v5_test.dart`:

```dart
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/config/drift/app_database.dart';

import 'generated_migrations/schema.dart';
import 'generated_migrations/schema_v4.dart' as v4;

void main() {
  test('sema surumu 5', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    expect(db.schemaVersion, 5);
    expect(await db.select(db.waterLogs).get(), isEmpty);
  });

  group('v4 -> v5 migration (drift SchemaVerifier)', () {
    late SchemaVerifier verifier;

    setUpAll(() {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      verifier = SchemaVerifier(GeneratedHelper());
    });

    test('v4ten v5e yukseltme SchemaMismatch atmadan tamamlanir', () async {
      final connection = await verifier.startAt(4);
      final db = AppDatabase.forTesting(connection);
      addTearDown(db.close);

      await verifier.migrateAndValidate(db, 5);
    });

    test('v4 verisi korunur, water_logs bos ve yazilabilir gelir', () async {
      final schema = await verifier.schemaAt(4);
      addTearDown(schema.close);

      final oldDb = v4.DatabaseAtV4(schema.newConnection());
      await oldDb.into(oldDb.userMetrics).insert(
            v4.UserMetricsCompanion.insert(
              userId: 'guest',
              sex: 'female',
              birthYear: 1990,
              heightCm: 165,
              weightKg: 60,
              activityLevel: 'moderate',
              updatedAt: DateTime(2026, 9, 1).millisecondsSinceEpoch ~/ 1000,
            ),
          );
      await oldDb.close();

      final db = AppDatabase.forTesting(schema.newConnection());
      addTearDown(db.close);
      await verifier.migrateAndValidate(db, 5);

      expect((await db.select(db.userMetrics).get()).single.userId, 'guest');
      await db.into(db.waterLogs).insert(
            WaterLogsCompanion.insert(
              userId: 'guest',
              day: '2026-09-13',
              goalGlasses: 10,
            ),
          );
      final row = await db.select(db.waterLogs).getSingle();
      expect(row.glasses, 0);
      expect(row.lastGlassAt, isNull);
    });
  });
}
```

If `v4.UserMetricsCompanion.insert` has different parameter types in the generated file, match the generated signature (`schema_v4.dart`) — do not edit the generated file.

- [ ] **Step 5: Remove the stale version assertion from the v4 test**

In `test/config/drift/migration_v4_test.dart` delete this test (the v5 file now owns the version check):

```dart
  test('sema surumu 4', () {
    expect(db.schemaVersion, 4);
  });
```

- [ ] **Step 6: Run drift tests**

Run: `flutter test --no-pub test/config/drift/`
Expected: all pass (v1→v2 hand-rolled path, v3→v4, v4→v5).

- [ ] **Step 7: Correct the spec's migration line**

In the spec, replace

```
- `schemaVersion` 4 → 5; `onUpgrade`: `if (from < 5) await m.createTable(waterLogs);`.
```

with

```
- `schemaVersion` 4 → 5; `onUpgrade`: `if (from < 5 && to >= 5) await m.createTable(waterLogs);`
  (`to` guard keeps SchemaVerifier's v3→v4 replay valid).
```

- [ ] **Step 8: Analyze and commit**

```bash
flutter analyze --no-pub
git add lib/config/drift drift_schemas test/config/drift docs/superpowers/specs/2026-09-13-water-reminder-design.md
git commit -m "feat(water): water_logs tablosu ve sema v5 migration

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 2: Goal calculation and day entity

**Files:**
- Create: `lib/features/water/domain/water_goal.dart`
- Create: `lib/features/water/domain/water_day.dart`
- Test: `test/features/water/water_goal_test.dart`

**Interfaces:**
- Produces:
  - `const int kGlassMl = 200; const int kDefaultWaterGoalGlasses = 10; const int kMinGoalGlasses = 1; const int kMaxGoalGlasses = 20;`
  - `int suggestedWaterGoal(double? weightKg)`
  - `String waterDayKey(DateTime local)` → `'2026-09-03'`
  - `class WaterDay { final String day; final int glasses; final int goalGlasses; final DateTime? lastGlassAt; bool get goalMet; }`

- [ ] **Step 1: Write the failing test**

`test/features/water/water_goal_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/features/water/domain/water_day.dart';
import 'package:nutrilens/features/water/domain/water_goal.dart';

void main() {
  group('suggestedWaterGoal', () {
    test('kilo yoksa varsayilan 10 bardak', () {
      expect(suggestedWaterGoal(null), 10);
      expect(suggestedWaterGoal(0), 10);
    });

    test('kilo x 35 ml / 200 ml, en yakin bardaga yuvarlanir', () {
      expect(suggestedWaterGoal(70), 12); // 12.25
      expect(suggestedWaterGoal(60), 11); // 10.5
      expect(suggestedWaterGoal(80), 14);
    });

    test('6-16 bardak araligina sikistirilir', () {
      expect(suggestedWaterGoal(30), 6); // 5.25
      expect(suggestedWaterGoal(120), 16); // 21
    });
  });

  group('waterDayKey', () {
    test('sifir dolgulu yyyy-MM-dd', () {
      expect(waterDayKey(DateTime(2026, 9, 3, 23, 59)), '2026-09-03');
      expect(waterDayKey(DateTime(2026, 12, 31)), '2026-12-31');
    });
  });

  test('goalMet hedefe esit veya ustunde', () {
    expect(const WaterDay(day: 'd', glasses: 9, goalGlasses: 10).goalMet, false);
    expect(const WaterDay(day: 'd', glasses: 10, goalGlasses: 10).goalMet, true);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test --no-pub test/features/water/water_goal_test.dart`
Expected: FAIL — `water_day.dart` / `water_goal.dart` not found.

- [ ] **Step 3: Implement**

`lib/features/water/domain/water_goal.dart`:

```dart
/// One glass on the counter.
const int kGlassMl = 200;

const int kDefaultWaterGoalGlasses = 10;

/// Bounds for the manual goal stepper.
const int kMinGoalGlasses = 1;
const int kMaxGoalGlasses = 20;

const double _mlPerKg = 35;
const int _minSuggested = 6;
const int _maxSuggested = 16;

/// Goal suggestion from body weight; default when weight is unknown.
int suggestedWaterGoal(double? weightKg) {
  if (weightKg == null || weightKg <= 0) return kDefaultWaterGoalGlasses;
  final glasses = (weightKg * _mlPerKg / kGlassMl).round();
  return glasses.clamp(_minSuggested, _maxSuggested);
}
```

`lib/features/water/domain/water_day.dart`:

```dart
/// Local calendar day as stored in `water_logs.day`.
String waterDayKey(DateTime local) {
  final y = local.year.toString().padLeft(4, '0');
  final m = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

class WaterDay {
  final String day;
  final int glasses;

  /// Goal as it was on [day] — see `WaterLogs.goalGlasses`.
  final int goalGlasses;
  final DateTime? lastGlassAt;

  const WaterDay({
    required this.day,
    required this.glasses,
    required this.goalGlasses,
    this.lastGlassAt,
  });

  bool get goalMet => glasses >= goalGlasses;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test --no-pub test/features/water/water_goal_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/water/domain test/features/water/water_goal_test.dart
git commit -m "feat(water): hedef hesabi ve gun modeli

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 3: Reminder time calculation

**Files:**
- Create: `lib/features/water/domain/water_reminder_schedule.dart`
- Test: `test/features/water/water_reminder_schedule_test.dart`

**Interfaces:**
- Produces: `List<DateTime> waterReminderTimes({required DateTime now, required DateTime? lastGlassAt, required int glassesToday, required int goal})` — local wall-clock `DateTime`s, ascending, length ≤ 14. `const waterReminderHours = [9, 11, 13, 15, 17, 19, 21];`

- [ ] **Step 1: Write the failing test**

`test/features/water/water_reminder_schedule_test.dart`:

```dart
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test --no-pub test/features/water/water_reminder_schedule_test.dart`
Expected: FAIL — file not found.

- [ ] **Step 3: Implement**

`lib/features/water/domain/water_reminder_schedule.dart`:

```dart
const waterReminderHours = [9, 11, 13, 15, 17, 19, 21];

/// Minimum quiet time after a glass before the next reminder slot.
const waterReminderGap = Duration(hours: 2);

/// Reminder times for today (remaining) and tomorrow (all slots).
///
/// Wall-clock values built with the `DateTime` constructor — never
/// `add(Duration(days: 1))` — so a DST night still yields 09:00..21:00.
/// The notification layer converts them to `tz.local`.
List<DateTime> waterReminderTimes({
  required DateTime now,
  required DateTime? lastGlassAt,
  required int glassesToday,
  required int goal,
}) {
  final lastToday = lastGlassAt != null &&
      lastGlassAt.year == now.year &&
      lastGlassAt.month == now.month &&
      lastGlassAt.day == now.day;
  final quietUntil = lastToday ? lastGlassAt.add(waterReminderGap) : null;

  final today = <DateTime>[
    if (glassesToday < goal)
      for (final hour in waterReminderHours)
        DateTime(now.year, now.month, now.day, hour),
  ].where((slot) {
    if (!slot.isAfter(now)) return false;
    return quietUntil == null || !slot.isBefore(quietUntil);
  });

  final tomorrow = [
    for (final hour in waterReminderHours)
      DateTime(now.year, now.month, now.day + 1, hour),
  ];

  return [...today, ...tomorrow];
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test --no-pub test/features/water/water_reminder_schedule_test.dart`
Expected: PASS (8 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/water/domain/water_reminder_schedule.dart test/features/water/water_reminder_schedule_test.dart
git commit -m "feat(water): hatirlatma saatleri hesabi

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 4: Water local datasource

**Files:**
- Create: `lib/features/water/data/datasources/water_local_datasource.dart`
- Test: `test/features/water/water_local_datasource_test.dart`

**Interfaces:**
- Consumes: `AppDatabase.waterLogs`, `WaterLogsCompanion`, `WaterLog` (Task 1); `WaterDay`, `waterDayKey` (Task 2).
- Produces:

```dart
abstract interface class WaterLocalDataSource {
  Future<WaterDay?> getDay(String userId, String day);
  Future<WaterDay> addGlass({required String userId, required DateTime now, required int goal});
  Future<WaterDay> removeGlass({required String userId, required DateTime now, required int goal});
  Future<void> setGoalForDay({required String userId, required String day, required int goal});
  Future<List<WaterDay>> getRange({required String userId, required String fromDay, required String toDay});
  Future<int> countDays(String userId);
  Future<void> reassignOwner({required String fromUserId, required String toUserId});
  Future<void> deleteFor(String userId);
}
final class WaterLocalDataSourceImpl implements WaterLocalDataSource { const WaterLocalDataSourceImpl(AppDatabase db); }
```

- [ ] **Step 1: Write the failing test**

`test/features/water/water_local_datasource_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/config/drift/app_database.dart';
import 'package:nutrilens/features/water/data/datasources/water_local_datasource.dart';

void main() {
  late AppDatabase db;
  late WaterLocalDataSource ds;
  final morning = DateTime(2026, 9, 13, 9, 15);
  final noon = DateTime(2026, 9, 13, 12);

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    ds = WaterLocalDataSourceImpl(db);
  });
  tearDown(() => db.close());

  test('ilk bardak satiri hedefle olusturur', () async {
    final day = await ds.addGlass(userId: 'u1', now: morning, goal: 10);
    expect(day.day, '2026-09-13');
    expect(day.glasses, 1);
    expect(day.goalGlasses, 10);
    expect(day.lastGlassAt, morning);
  });

  test('sonraki bardak sayar ve lastGlassAt gunceller, hedef degismez', () async {
    await ds.addGlass(userId: 'u1', now: morning, goal: 10);
    final day = await ds.addGlass(userId: 'u1', now: noon, goal: 12);
    expect(day.glasses, 2);
    expect(day.goalGlasses, 10);
    expect(day.lastGlassAt, noon);
  });

  test('cikarma sifirin altina inmez ve lastGlassAt degismez', () async {
    await ds.addGlass(userId: 'u1', now: morning, goal: 10);
    await ds.removeGlass(userId: 'u1', now: noon, goal: 10);
    final day = await ds.removeGlass(userId: 'u1', now: noon, goal: 10);
    expect(day.glasses, 0);
    expect(day.lastGlassAt, morning);
  });

  test('satir yokken cikarma yazmadan sifir doner', () async {
    final day = await ds.removeGlass(userId: 'u1', now: noon, goal: 10);
    expect(day.glasses, 0);
    expect(await db.select(db.waterLogs).get(), isEmpty);
  });

  test('kullanicilar birbirinin gununu gormez', () async {
    await ds.addGlass(userId: 'u1', now: morning, goal: 10);
    expect(await ds.getDay('u2', '2026-09-13'), isNull);
  });

  test('setGoalForDay yalniz var olan satiri gunceller', () async {
    await ds.setGoalForDay(userId: 'u1', day: '2026-09-13', goal: 8);
    expect(await ds.getDay('u1', '2026-09-13'), isNull);
    await ds.addGlass(userId: 'u1', now: morning, goal: 10);
    await ds.setGoalForDay(userId: 'u1', day: '2026-09-13', goal: 8);
    expect((await ds.getDay('u1', '2026-09-13'))!.goalGlasses, 8);
  });

  test('getRange araliktaki gunleri artan sirada doner', () async {
    for (final d in [11, 13, 9]) {
      await ds.addGlass(userId: 'u1', now: DateTime(2026, 9, d, 10), goal: 10);
    }
    await ds.addGlass(userId: 'u2', now: DateTime(2026, 9, 12, 10), goal: 10);
    final days = await ds.getRange(
      userId: 'u1',
      fromDay: '2026-09-10',
      toDay: '2026-09-13',
    );
    expect(days.map((d) => d.day), ['2026-09-11', '2026-09-13']);
    expect(await ds.countDays('u1'), 3);
  });

  test('reassignOwner cakisan gunde hesabinkini korur, misafiri siler', () async {
    await ds.addGlass(userId: 'guest', now: DateTime(2026, 9, 12, 10), goal: 10);
    await ds.addGlass(userId: 'guest', now: morning, goal: 10);
    await ds.addGlass(userId: 'guest', now: noon, goal: 10);
    await ds.addGlass(userId: 'u1', now: morning, goal: 6);

    await ds.reassignOwner(fromUserId: 'guest', toUserId: 'u1');

    expect(await ds.countDays('guest'), 0);
    expect((await ds.getDay('u1', '2026-09-12'))!.glasses, 1);
    final conflict = (await ds.getDay('u1', '2026-09-13'))!;
    expect(conflict.glasses, 1);
    expect(conflict.goalGlasses, 6);
  });

  test('deleteFor yalniz o kullaniciyi siler', () async {
    await ds.addGlass(userId: 'u1', now: morning, goal: 10);
    await ds.addGlass(userId: 'u2', now: morning, goal: 10);
    await ds.deleteFor('u1');
    expect(await ds.countDays('u1'), 0);
    expect(await ds.countDays('u2'), 1);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test --no-pub test/features/water/water_local_datasource_test.dart`
Expected: FAIL — file not found.

- [ ] **Step 3: Implement**

`lib/features/water/data/datasources/water_local_datasource.dart`:

```dart
import 'package:drift/drift.dart';

import '../../../../config/drift/app_database.dart';
import '../../domain/water_day.dart';

abstract interface class WaterLocalDataSource {
  Future<WaterDay?> getDay(String userId, String day);

  /// Upserts today's row: +1 glass, `lastGlassAt = now`. [goal] is only
  /// written when the row is created.
  Future<WaterDay> addGlass({
    required String userId,
    required DateTime now,
    required int goal,
  });

  /// −1 glass, floored at 0. Never creates a row.
  Future<WaterDay> removeGlass({
    required String userId,
    required DateTime now,
    required int goal,
  });

  /// Refreshes the goal snapshot of an existing row; no-op without a row.
  Future<void> setGoalForDay({
    required String userId,
    required String day,
    required int goal,
  });

  /// Inclusive `yyyy-MM-dd` range, ascending. Missing days are absent.
  Future<List<WaterDay>> getRange({
    required String userId,
    required String fromDay,
    required String toDay,
  });

  Future<int> countDays(String userId);

  /// Guest → account. On a same-day conflict the account's row wins; guest
  /// rows are always deleted so they cannot leak to a later guest.
  Future<void> reassignOwner({
    required String fromUserId,
    required String toUserId,
  });

  Future<void> deleteFor(String userId);
}

final class WaterLocalDataSourceImpl implements WaterLocalDataSource {
  final AppDatabase _db;

  const WaterLocalDataSourceImpl(this._db);

  WaterDay _toEntity(WaterLog row) => WaterDay(
    day: row.day,
    glasses: row.glasses,
    goalGlasses: row.goalGlasses,
    lastGlassAt: row.lastGlassAt,
  );

  Expression<bool> _isDay($WaterLogsTable t, String userId, String day) =>
      t.userId.equals(userId) & t.day.equals(day);

  @override
  Future<WaterDay?> getDay(String userId, String day) async {
    final row = await (_db.select(
      _db.waterLogs,
    )..where((t) => _isDay(t, userId, day))).getSingleOrNull();
    return row == null ? null : _toEntity(row);
  }

  @override
  Future<WaterDay> addGlass({
    required String userId,
    required DateTime now,
    required int goal,
  }) {
    final day = waterDayKey(now);
    return _db.transaction(() async {
      final existing = await getDay(userId, day);
      if (existing == null) {
        await _db
            .into(_db.waterLogs)
            .insert(
              WaterLogsCompanion.insert(
                userId: userId,
                day: day,
                glasses: const Value(1),
                goalGlasses: goal,
                lastGlassAt: Value(now),
              ),
            );
      } else {
        await (_db.update(
          _db.waterLogs,
        )..where((t) => _isDay(t, userId, day))).write(
          WaterLogsCompanion(
            glasses: Value(existing.glasses + 1),
            lastGlassAt: Value(now),
          ),
        );
      }
      return (await getDay(userId, day))!;
    });
  }

  @override
  Future<WaterDay> removeGlass({
    required String userId,
    required DateTime now,
    required int goal,
  }) {
    final day = waterDayKey(now);
    return _db.transaction(() async {
      final existing = await getDay(userId, day);
      if (existing == null) {
        return WaterDay(day: day, glasses: 0, goalGlasses: goal);
      }
      if (existing.glasses == 0) return existing;
      await (_db.update(_db.waterLogs)..where((t) => _isDay(t, userId, day)))
          .write(WaterLogsCompanion(glasses: Value(existing.glasses - 1)));
      return (await getDay(userId, day))!;
    });
  }

  @override
  Future<void> setGoalForDay({
    required String userId,
    required String day,
    required int goal,
  }) async {
    await (_db.update(_db.waterLogs)..where((t) => _isDay(t, userId, day)))
        .write(WaterLogsCompanion(goalGlasses: Value(goal)));
  }

  @override
  Future<List<WaterDay>> getRange({
    required String userId,
    required String fromDay,
    required String toDay,
  }) async {
    final rows =
        await (_db.select(_db.waterLogs)
              ..where(
                (t) =>
                    t.userId.equals(userId) &
                    t.day.isBetweenValues(fromDay, toDay),
              )
              ..orderBy([(t) => OrderingTerm.asc(t.day)]))
            .get();
    return rows.map(_toEntity).toList();
  }

  @override
  Future<int> countDays(String userId) async {
    final rows = await (_db.select(
      _db.waterLogs,
    )..where((t) => t.userId.equals(userId))).get();
    return rows.length;
  }

  @override
  Future<void> reassignOwner({
    required String fromUserId,
    required String toUserId,
  }) {
    return _db.transaction(() async {
      final guestRows = await (_db.select(
        _db.waterLogs,
      )..where((t) => t.userId.equals(fromUserId))).get();
      for (final row in guestRows) {
        await _db
            .into(_db.waterLogs)
            .insert(
              row.copyWith(userId: toUserId),
              mode: InsertMode.insertOrIgnore,
            );
      }
      await deleteFor(fromUserId);
    });
  }

  @override
  Future<void> deleteFor(String userId) async {
    await (_db.delete(
      _db.waterLogs,
    )..where((t) => t.userId.equals(userId))).go();
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test --no-pub test/features/water/water_local_datasource_test.dart`
Expected: PASS (9 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/water/data test/features/water/water_local_datasource_test.dart
git commit -m "feat(water): yerel su kaydi veri kaynagi

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 5: Notification service — water reminders and permission result

**Files:**
- Modify: `lib/core/services/notification_service.dart`
- Test: `test/core/services/notification_service_water_test.dart`
- Modify: `docs/superpowers/specs/2026-09-13-water-reminder-design.md`

**Interfaces:**
- Produces:
  - `Future<void> rescheduleWaterReminders({required List<DateTime> times, required String title, required String body})` — cancels ids 2000–2013, arms `times[i]` as id `2000 + i` (first 14 only).
  - `Future<void> cancelWaterReminders()`
  - `Future<bool> requestPermission()` (was `Future<void>`)

- [ ] **Step 1: Write the failing test**

`test/core/services/notification_service_water_test.dart`:

```dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nutrilens/core/services/notification_service.dart';
import 'package:timezone/timezone.dart' as tz;

class _MockPlugin extends Mock implements FlutterLocalNotificationsPlugin {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockPlugin plugin;
  late NotificationService service;

  setUpAll(() {
    registerFallbackValue(tz.TZDateTime.utc(2026));
    registerFallbackValue(const NotificationDetails());
    registerFallbackValue(AndroidScheduleMode.inexactAllowWhileIdle);
  });

  setUp(() {
    plugin = _MockPlugin();
    when(() => plugin.cancel(id: any(named: 'id'))).thenAnswer((_) async {});
    when(
      () => plugin.zonedSchedule(
        id: any(named: 'id'),
        title: any(named: 'title'),
        body: any(named: 'body'),
        scheduledDate: any(named: 'scheduledDate'),
        notificationDetails: any(named: 'notificationDetails'),
        androidScheduleMode: any(named: 'androidScheduleMode'),
      ),
    ).thenAnswer((_) async {});
    service = NotificationService(plugin);
  });

  test('once 2000-2013 iptal edilir, ogun hatirlatmasina (1001) dokunulmaz',
      () async {
    await service.rescheduleWaterReminders(
      times: const [],
      title: 't',
      body: 'b',
    );
    for (var id = 2000; id <= 2013; id++) {
      verify(() => plugin.cancel(id: id)).called(1);
    }
    verifyNever(() => plugin.cancel(id: 1001));
    verifyNever(
      () => plugin.zonedSchedule(
        id: any(named: 'id'),
        title: any(named: 'title'),
        body: any(named: 'body'),
        scheduledDate: any(named: 'scheduledDate'),
        notificationDetails: any(named: 'notificationDetails'),
        androidScheduleMode: any(named: 'androidScheduleMode'),
      ),
    );
  });

  test('her zaman sirali id ile kurulur, duvar saati korunur', () async {
    await service.rescheduleWaterReminders(
      times: [DateTime(2026, 9, 13, 13), DateTime(2026, 9, 14, 9)],
      title: 'Su içme zamanı',
      body: 'b',
    );
    final captured = verify(
      () => plugin.zonedSchedule(
        id: captureAny(named: 'id'),
        title: 'Su içme zamanı',
        body: 'b',
        scheduledDate: captureAny(named: 'scheduledDate'),
        notificationDetails: any(named: 'notificationDetails'),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      ),
    ).captured;
    expect(captured[0], 2000);
    expect((captured[1] as tz.TZDateTime).hour, 13);
    expect(captured[2], 2001);
    expect((captured[3] as tz.TZDateTime).day, 14);
  });

  test('14ten fazla zaman verilirse yalniz ilk 14 kurulur', () async {
    await service.rescheduleWaterReminders(
      times: [for (var h = 0; h < 20; h++) DateTime(2026, 9, 13, h)],
      title: 't',
      body: 'b',
    );
    verify(
      () => plugin.zonedSchedule(
        id: any(named: 'id'),
        title: any(named: 'title'),
        body: any(named: 'body'),
        scheduledDate: any(named: 'scheduledDate'),
        notificationDetails: any(named: 'notificationDetails'),
        androidScheduleMode: any(named: 'androidScheduleMode'),
      ),
    ).called(14);
  });

  test('cancelWaterReminders yalniz su idlerini iptal eder', () async {
    await service.cancelWaterReminders();
    verify(() => plugin.cancel(id: any(named: 'id'))).called(14);
    verifyNever(() => plugin.cancel(id: 1001));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test --no-pub test/core/services/notification_service_water_test.dart`
Expected: FAIL — `rescheduleWaterReminders` / `cancelWaterReminders` not defined.

- [ ] **Step 3: Implement**

In `lib/core/services/notification_service.dart`:

Add constants under `static const _channelName = 'Öğün Hatırlatma';`:

```dart
  static const _waterChannelId = 'water_reminder';
  static const _waterChannelName = 'Su Hatırlatma';
  static const _waterBaseId = 2000;

  /// Today's remaining slots + tomorrow's 7 (see `waterReminderTimes`).
  static const _waterMaxCount = 14;
```

Replace the whole `requestPermission` method with:

```dart
  /// Requests OS notification permission and reports whether it is granted.
  /// Both platforms show their system dialog at most once per install
  /// regardless of call count — callers still gate this behind their own
  /// one-shot flag (see `NotificationPromptStore`) so the ask happens at a
  /// deliberate moment rather than on every app launch.
  Future<bool> requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    return await ios?.requestPermissions(alert: true, badge: true, sound: true) ??
        false;
  }
```

Add after `rescheduleDailyReminder` (before the closing `}` of the class):

```dart
  /// Replaces every pending water reminder with [times] (wall-clock, local).
  /// Ids are sequential from 2000 so a shorter list never leaves stale
  /// reminders behind — all 14 ids are cancelled first.
  Future<void> rescheduleWaterReminders({
    required List<DateTime> times,
    required String title,
    required String body,
  }) async {
    await cancelWaterReminders();
    if (times.isEmpty) return;

    await _ensureTimezone();
    final count = times.length < _waterMaxCount ? times.length : _waterMaxCount;
    for (var i = 0; i < count; i++) {
      final t = times[i];
      await _plugin.zonedSchedule(
        id: _waterBaseId + i,
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime(
          tz.local,
          t.year,
          t.month,
          t.day,
          t.hour,
          t.minute,
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _waterChannelId,
            _waterChannelName,
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
    }
  }

  Future<void> cancelWaterReminders() async {
    for (var i = 0; i < _waterMaxCount; i++) {
      await _plugin.cancel(id: _waterBaseId + i);
    }
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test --no-pub test/core/services/notification_service_water_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Correct the spec's id line**

In the spec replace

```
- Cancels ids 2000–2006 (today) and 2010–2016 (tomorrow) only — never 1001.
```

with

```
- Cancels ids 2000–2013 and arms `times[i]` as id `2000 + i` (sequential, max
  14) — never 1001.
```

- [ ] **Step 6: Analyze and commit**

```bash
flutter analyze --no-pub
git add lib/core/services/notification_service.dart test/core/services/notification_service_water_test.dart docs/superpowers/specs/2026-09-13-water-reminder-design.md
git commit -m "feat(water): su hatirlatma bildirimleri ve izin sonucu

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 6: Settings store, analytics events, providers and controller

**Files:**
- Create: `lib/features/water/data/water_settings_store.dart`
- Modify: `lib/core/analytics/analytics_event.dart`
- Create: `lib/features/water/presentation/providers/water_provider.dart`
- Test: `test/features/water/water_settings_store_test.dart`
- Test: `test/features/water/water_controller_test.dart`

**Interfaces:**
- Consumes: Tasks 2–5; `appDatabaseProvider` (`lib/features/product/presentation/providers/product_provider.dart`), `sharedPreferencesProvider` (`lib/core/providers/locale_provider.dart`), `effectiveUserIdProvider` (`lib/core/session/app_session.dart`), `userMetricsProvider` (`lib/features/profile/presentation/providers/user_metrics_provider.dart`), `analyticsServiceProvider` (`lib/core/analytics/analytics_provider.dart`), `notificationServiceProvider`.
- Produces:
  - `class WaterSettingsStore { static const keys; int? get goal; Future<void> setGoal(int); bool get reminderEnabled; Future<void> setReminderEnabled(bool); bool get promptShown; Future<void> markPromptShown(); }`
  - `FunnelEvents.waterGlassAdded = 'water_glass_added'`, `FunnelEvents.waterReminderEnabled = 'water_reminder_enabled'`
  - `typedef WaterReminderCopy = ({String title, String body});`
  - Providers: `waterLocalDataSourceProvider`, `waterSettingsStoreProvider`, `waterClockProvider` (`Provider<DateTime Function()>`), `waterSettingsProvider` (`NotifierProvider<WaterSettingsNotifier, WaterSettings>`), `waterGoalProvider` (`Provider<int>`), `waterTodayProvider` (`FutureProvider<WaterDay>`), `waterWeekProvider` (`FutureProvider<List<WaterDay>>`, 7 items oldest → today), `waterControllerProvider` (`Provider<WaterController>`).
  - `WaterController`: `Future<WaterDay?> addGlass(WaterReminderCopy)`, `Future<WaterDay?> removeGlass(WaterReminderCopy)`, `Future<void> setGoal(int glasses, WaterReminderCopy)`, `Future<bool> setReminderEnabled(bool enabled, WaterReminderCopy)` (false only when permission denied), `Future<void> rescheduleReminders(WaterReminderCopy)`.

- [ ] **Step 1: Write the settings store test**

`test/features/water/water_settings_store_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/features/water/data/water_settings_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late WaterSettingsStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = WaterSettingsStore(await SharedPreferences.getInstance());
  });

  test('varsayilanlar: hedef yok, hatirlatma kapali, soru sorulmadi', () {
    expect(store.goal, isNull);
    expect(store.reminderEnabled, isFalse);
    expect(store.promptShown, isFalse);
  });

  test('hedef 1-20 araligina sikistirilarak kaydedilir', () async {
    await store.setGoal(25);
    expect(store.goal, 20);
    await store.setGoal(0);
    expect(store.goal, 1);
  });

  test('hatirlatma ve soru bayragi kalici', () async {
    await store.setReminderEnabled(true);
    await store.markPromptShown();
    expect(store.reminderEnabled, isTrue);
    expect(store.promptShown, isTrue);
  });

  test('keys tum su tercihlerini listeler', () {
    expect(WaterSettingsStore.keys, [
      'water_goal_glasses',
      'water_reminder_enabled',
      'water_reminder_prompt_shown',
    ]);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test --no-pub test/features/water/water_settings_store_test.dart`
Expected: FAIL — file not found.

- [ ] **Step 3: Implement the store**

`lib/features/water/data/water_settings_store.dart`:

```dart
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/water_goal.dart';

/// Device-global water preferences. Cleared on "delete my data" together
/// with health filters (see `UserDataDeletionService`).
class WaterSettingsStore {
  static const _goalKey = 'water_goal_glasses';
  static const _reminderKey = 'water_reminder_enabled';
  static const _promptShownKey = 'water_reminder_prompt_shown';
  static const keys = [_goalKey, _reminderKey, _promptShownKey];

  final SharedPreferences _prefs;

  const WaterSettingsStore(this._prefs);

  /// Null → no manual goal; the weight-based suggestion applies.
  int? get goal => _prefs.getInt(_goalKey);

  Future<void> setGoal(int glasses) =>
      _prefs.setInt(_goalKey, glasses.clamp(kMinGoalGlasses, kMaxGoalGlasses));

  bool get reminderEnabled => _prefs.getBool(_reminderKey) ?? false;

  Future<void> setReminderEnabled(bool enabled) =>
      _prefs.setBool(_reminderKey, enabled);

  bool get promptShown => _prefs.getBool(_promptShownKey) ?? false;

  Future<void> markPromptShown() => _prefs.setBool(_promptShownKey, true);
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test --no-pub test/features/water/water_settings_store_test.dart`
Expected: PASS.

- [ ] **Step 5: Add analytics events**

In `lib/core/analytics/analytics_event.dart`, directly after `static const comparisonShared = 'comparison_shared';` add:

```dart

  // --- Water ----------------------------------------------------------
  /// Not funnel steps — engagement signal for the water counter.
  static const waterGlassAdded = 'water_glass_added';
  static const waterReminderEnabled = 'water_reminder_enabled';
```

- [ ] **Step 6: Write the controller test**

`test/features/water/water_controller_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nutrilens/config/drift/app_database.dart';
import 'package:nutrilens/core/analytics/analytics_event.dart';
import 'package:nutrilens/core/analytics/analytics_provider.dart';
import 'package:nutrilens/core/analytics/analytics_service.dart';
import 'package:nutrilens/core/providers/locale_provider.dart';
import 'package:nutrilens/core/services/notification_service.dart';
import 'package:nutrilens/core/session/app_session.dart';
import 'package:nutrilens/features/product/presentation/providers/product_provider.dart';
import 'package:nutrilens/features/water/presentation/providers/water_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockNotifications extends Mock implements NotificationService {}

class _RecordingAnalytics extends AnalyticsService {
  _RecordingAnalytics()
    : super(
        client: null,
        deviceId: null,
        prefs: null,
        enabled: false,
        flushInterval: Duration.zero,
      );

  final names = <String>[];

  @override
  void track(String name, {Map<String, Object?> props = const {}}) =>
      names.add(name);
}

const WaterReminderCopy _copy = (title: 't', body: 'b');

void main() {
  late AppDatabase db;
  late _MockNotifications notifications;
  late _RecordingAnalytics analytics;
  late DateTime now;

  setUpAll(() => registerFallbackValue(<DateTime>[]));

  Future<ProviderContainer> makeContainer({
    String? userId = 'user-1',
    bool permission = true,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    when(() => notifications.requestPermission())
        .thenAnswer((_) async => permission);
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(prefs),
        effectiveUserIdProvider.overrideWithValue(userId),
        notificationServiceProvider.overrideWithValue(notifications),
        analyticsServiceProvider.overrideWithValue(analytics),
        waterClockProvider.overrideWithValue(() => now),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    notifications = _MockNotifications();
    analytics = _RecordingAnalytics();
    now = DateTime(2026, 9, 13, 10, 30);
    when(() => notifications.cancelWaterReminders()).thenAnswer((_) async {});
    when(
      () => notifications.rescheduleWaterReminders(
        times: any(named: 'times'),
        title: any(named: 'title'),
        body: any(named: 'body'),
      ),
    ).thenAnswer((_) async {});
  });
  tearDown(() => db.close());

  test('bardak ekler, analitik yollar; hatirlatma kapaliyken iptal eder',
      () async {
    final c = await makeContainer();

    final day = await c.read(waterControllerProvider).addGlass(_copy);

    expect(day!.glasses, 1);
    expect((await c.read(waterTodayProvider.future)).glasses, 1);
    expect(analytics.names, [FunnelEvents.waterGlassAdded]);
    verify(() => notifications.cancelWaterReminders()).called(1);
    verifyNever(
      () => notifications.rescheduleWaterReminders(
        times: any(named: 'times'),
        title: any(named: 'title'),
        body: any(named: 'body'),
      ),
    );
  });

  test('hatirlatma acikken 10:30 bardagi 11:00i atlatir', () async {
    final c = await makeContainer();
    final controller = c.read(waterControllerProvider);

    expect(await controller.setReminderEnabled(true, _copy), isTrue);
    await controller.addGlass(_copy);

    final times = verify(
      () => notifications.rescheduleWaterReminders(
        times: captureAny(named: 'times'),
        title: 't',
        body: 'b',
      ),
    ).captured.last as List<DateTime>;
    expect(times.first, DateTime(2026, 9, 13, 13));
    expect(c.read(waterSettingsProvider).reminderEnabled, isTrue);
    expect(analytics.names, contains(FunnelEvents.waterReminderEnabled));
  });

  test('izin reddedilirse false doner ve kapali kalir', () async {
    final c = await makeContainer(permission: false);

    final ok = await c
        .read(waterControllerProvider)
        .setReminderEnabled(true, _copy);

    expect(ok, isFalse);
    expect(c.read(waterSettingsProvider).reminderEnabled, isFalse);
  });

  test('cikarma 0in altina inmez', () async {
    final c = await makeContainer();
    final day = await c.read(waterControllerProvider).removeGlass(_copy);
    expect(day!.glasses, 0);
  });

  test('hedef degisince bugunun satiri ve waterGoalProvider guncellenir',
      () async {
    final c = await makeContainer();
    final controller = c.read(waterControllerProvider);
    await controller.addGlass(_copy);

    await controller.setGoal(8, _copy);

    expect(c.read(waterGoalProvider), 8);
    expect((await c.read(waterTodayProvider.future)).goalGlasses, 8);
  });

  test('kilo yoksa hedef 10', () async {
    final c = await makeContainer();
    expect(await c.read(waterMetricsWeightProvider.future), isNull);
    expect(c.read(waterGoalProvider), 10);
  });

  test('hafta 7 gun doner, eksik gunler 0 bardak', () async {
    final c = await makeContainer();
    await c.read(waterControllerProvider).addGlass(_copy);

    final week = await c.read(waterWeekProvider.future);

    expect(week.map((d) => d.day), [
      '2026-09-07', '2026-09-08', '2026-09-09', '2026-09-10',
      '2026-09-11', '2026-09-12', '2026-09-13',
    ]);
    expect(week.last.glasses, 1);
    expect(week.first.glasses, 0);
  });

  test('oturum yoksa yazmaz ve hatirlatmalari iptal eder', () async {
    final c = await makeContainer(userId: null);

    final day = await c.read(waterControllerProvider).addGlass(_copy);

    expect(day, isNull);
    expect(await db.select(db.waterLogs).get(), isEmpty);
    verify(() => notifications.cancelWaterReminders()).called(1);
  });
}
```

The `kilo yoksa hedef 10` test awaits `waterMetricsWeightProvider` (defined in Step 8) so `waterGoalProvider` reads a settled value.

- [ ] **Step 7: Run to verify it fails**

Run: `flutter test --no-pub test/features/water/water_controller_test.dart`
Expected: FAIL — `water_provider.dart` not found.

- [ ] **Step 8: Implement providers and controller**

`lib/features/water/presentation/providers/water_provider.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/analytics/analytics_event.dart';
import '../../../../core/analytics/analytics_provider.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/session/app_session.dart';
import '../../../product/presentation/providers/product_provider.dart';
import '../../../profile/presentation/providers/user_metrics_provider.dart';
import '../../data/datasources/water_local_datasource.dart';
import '../../data/water_settings_store.dart';
import '../../domain/water_day.dart';
import '../../domain/water_goal.dart';
import '../../domain/water_reminder_schedule.dart';

/// Notification text, resolved by the caller from `context.l10n`.
typedef WaterReminderCopy = ({String title, String body});

final waterLocalDataSourceProvider = Provider<WaterLocalDataSource>(
  (ref) => WaterLocalDataSourceImpl(ref.watch(appDatabaseProvider)),
);

final waterSettingsStoreProvider = Provider<WaterSettingsStore>(
  (ref) => WaterSettingsStore(ref.watch(sharedPreferencesProvider)),
);

/// Test seam for "now".
final waterClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

class WaterSettings {
  final int? customGoal;
  final bool reminderEnabled;

  const WaterSettings({required this.customGoal, required this.reminderEnabled});
}

class WaterSettingsNotifier extends Notifier<WaterSettings> {
  WaterSettingsStore get _store => ref.read(waterSettingsStoreProvider);

  @override
  WaterSettings build() {
    final store = ref.watch(waterSettingsStoreProvider);
    return WaterSettings(
      customGoal: store.goal,
      reminderEnabled: store.reminderEnabled,
    );
  }

  Future<void> setGoal(int glasses) async {
    await _store.setGoal(glasses);
    state = WaterSettings(
      customGoal: _store.goal,
      reminderEnabled: state.reminderEnabled,
    );
  }

  Future<void> setReminderEnabled(bool enabled) async {
    await _store.setReminderEnabled(enabled);
    state = WaterSettings(customGoal: state.customGoal, reminderEnabled: enabled);
  }
}

final waterSettingsProvider =
    NotifierProvider<WaterSettingsNotifier, WaterSettings>(
      WaterSettingsNotifier.new,
    );

/// Profile weight, or null. Separate so tests can await the metrics load.
final waterMetricsWeightProvider = FutureProvider<double?>((ref) async {
  final metrics = await ref.watch(userMetricsProvider.future);
  return metrics?.weightKg;
});

final waterGoalProvider = Provider<int>((ref) {
  final custom = ref.watch(waterSettingsProvider).customGoal;
  if (custom != null) return custom;
  return suggestedWaterGoal(ref.watch(waterMetricsWeightProvider).value);
});

final waterTodayProvider = FutureProvider<WaterDay>((ref) async {
  final userId = ref.watch(effectiveUserIdProvider);
  final goal = ref.watch(waterGoalProvider);
  final key = waterDayKey(ref.watch(waterClockProvider)());
  if (userId == null) return WaterDay(day: key, glasses: 0, goalGlasses: goal);
  final row = await ref.watch(waterLocalDataSourceProvider).getDay(userId, key);
  return row ?? WaterDay(day: key, glasses: 0, goalGlasses: goal);
});

final waterWeekProvider = FutureProvider<List<WaterDay>>((ref) async {
  final userId = ref.watch(effectiveUserIdProvider);
  final goal = ref.watch(waterGoalProvider);
  final now = ref.watch(waterClockProvider)();
  final keys = [
    for (var i = 6; i >= 0; i--)
      waterDayKey(DateTime(now.year, now.month, now.day - i)),
  ];
  final rows = userId == null
      ? const <WaterDay>[]
      : await ref
            .watch(waterLocalDataSourceProvider)
            .getRange(userId: userId, fromDay: keys.first, toDay: keys.last);
  final byDay = {for (final row in rows) row.day: row};
  return [
    for (final key in keys)
      byDay[key] ?? WaterDay(day: key, glasses: 0, goalGlasses: goal),
  ];
});

/// Single write path for water data: Drift → invalidate → analytics →
/// reminders. Reminder failures never fail the write.
class WaterController {
  final Ref _ref;

  WaterController(this._ref);

  WaterLocalDataSource get _ds => _ref.read(waterLocalDataSourceProvider);
  NotificationService get _notifications =>
      _ref.read(notificationServiceProvider);
  DateTime _now() => _ref.read(waterClockProvider)();

  void _invalidate() {
    _ref.invalidate(waterTodayProvider);
    _ref.invalidate(waterWeekProvider);
  }

  Future<WaterDay?> addGlass(WaterReminderCopy copy) async {
    final userId = _ref.read(effectiveUserIdProvider);
    if (userId == null) {
      await rescheduleReminders(copy);
      return null;
    }
    final day = await _ds.addGlass(
      userId: userId,
      now: _now(),
      goal: _ref.read(waterGoalProvider),
    );
    _invalidate();
    _ref.read(analyticsServiceProvider).track(FunnelEvents.waterGlassAdded);
    await rescheduleReminders(copy);
    return day;
  }

  Future<WaterDay?> removeGlass(WaterReminderCopy copy) async {
    final userId = _ref.read(effectiveUserIdProvider);
    if (userId == null) return null;
    final day = await _ds.removeGlass(
      userId: userId,
      now: _now(),
      goal: _ref.read(waterGoalProvider),
    );
    _invalidate();
    await rescheduleReminders(copy);
    return day;
  }

  Future<void> setGoal(int glasses, WaterReminderCopy copy) async {
    await _ref.read(waterSettingsProvider.notifier).setGoal(glasses);
    final userId = _ref.read(effectiveUserIdProvider);
    if (userId != null) {
      await _ds.setGoalForDay(
        userId: userId,
        day: waterDayKey(_now()),
        goal: _ref.read(waterGoalProvider),
      );
    }
    _invalidate();
    await rescheduleReminders(copy);
  }

  /// False only when the OS permission was denied.
  Future<bool> setReminderEnabled(bool enabled, WaterReminderCopy copy) async {
    final settings = _ref.read(waterSettingsProvider.notifier);
    if (!enabled) {
      await settings.setReminderEnabled(false);
      await rescheduleReminders(copy);
      return true;
    }
    if (!await _notifications.requestPermission()) return false;
    await settings.setReminderEnabled(true);
    _ref.read(analyticsServiceProvider).track(FunnelEvents.waterReminderEnabled);
    await rescheduleReminders(copy);
    return true;
  }

  Future<void> rescheduleReminders(WaterReminderCopy copy) async {
    try {
      final userId = _ref.read(effectiveUserIdProvider);
      if (userId == null || !_ref.read(waterSettingsProvider).reminderEnabled) {
        await _notifications.cancelWaterReminders();
        return;
      }
      final now = _now();
      final goal = _ref.read(waterGoalProvider);
      final today = await _ds.getDay(userId, waterDayKey(now));
      await _notifications.rescheduleWaterReminders(
        times: waterReminderTimes(
          now: now,
          lastGlassAt: today?.lastGlassAt,
          glassesToday: today?.glasses ?? 0,
          goal: goal,
        ),
        title: copy.title,
        body: copy.body,
      );
    } catch (e) {
      debugPrint('[Water] reminder reschedule failed: $e');
    }
  }
}

final waterControllerProvider = Provider<WaterController>(WaterController.new);
```

- [ ] **Step 9: Run to verify it passes**

Run: `flutter test --no-pub test/features/water/`
Expected: PASS (all water tests so far).

If `userMetricsProvider` fails inside the container because a transitive provider is not overridden, add the missing override the error names (e.g. `currentUserProvider.overrideWithValue(null)`) to `makeContainer` — do not change production code for it.

- [ ] **Step 10: Analyze and commit**

```bash
flutter analyze --no-pub
git add lib/features/water lib/core/analytics/analytics_event.dart test/features/water
git commit -m "feat(water): ayarlar, providerlar ve WaterController

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 7: Localized strings

**Files:**
- Modify: `lib/l10n/app_tr.arb`, `app_en.arb`, `app_es.arb`, `app_pt.arb`, `app_ar.arb`, `app_zh.arb`
- Generate: `lib/l10n/generated/*`

**Interfaces:**
- Produces (on `AppLocalizations`): `waterTitle`, `waterGlassesProgress(int count, int goal)`, `waterAddGlass`, `waterRemoveGlass`, `waterGoalReached`, `waterLast7Days`, `waterDailyGoal`, `waterGoalValue(int glasses, String liters)`, `waterDecreaseGoal`, `waterIncreaseGoal`, `waterGoalFromWeight`, `waterReminderSwitch`, `waterReminderSchedule`, `waterReminderPrompt`, `waterReminderEnable`, `waterPermissionDenied`, `waterReminderTitle`, `waterReminderBody`, `waterDayCountUnit(int count)`.

- [ ] **Step 1: Add keys to every ARB file**

Insert before the final `}` of each file (add a comma to the previous last entry). Placeholder metadata goes in every file, same as `dailyCalorieSummary`.

Shared metadata block (identical in all 6 files, placed after the corresponding keys):

```json
  "@waterGlassesProgress": {
    "placeholders": {
      "count": { "type": "int" },
      "goal": { "type": "int" }
    }
  },
  "@waterGoalValue": {
    "placeholders": {
      "glasses": { "type": "int" },
      "liters": { "type": "String" }
    }
  },
  "@waterDayCountUnit": {
    "placeholders": {
      "count": { "type": "int" }
    }
  }
```

Values:

| key | tr | en | es | pt | ar | zh |
|---|---|---|---|---|---|---|
| waterTitle | Su | Water | Agua | Água | الماء | 喝水 |
| waterGlassesProgress | {count} / {goal} bardak | {count} / {goal} glasses | {count} / {goal} vasos | {count} / {goal} copos | {count} / {goal} أكواب | {count} / {goal} 杯 |
| waterAddGlass | +1 bardak | +1 glass | +1 vaso | +1 copo | +1 كوب | +1 杯 |
| waterRemoveGlass | Bir bardak çıkar | Remove a glass | Quitar un vaso | Remover um copo | إزالة كوب | 减少一杯 |
| waterGoalReached | Günlük hedefe ulaştın | Daily goal reached | Meta diaria alcanzada | Meta diária atingida | تم بلوغ الهدف اليومي | 已达成今日目标 |
| waterLast7Days | Son 7 gün | Last 7 days | Últimos 7 días | Últimos 7 dias | آخر 7 أيام | 最近 7 天 |
| waterDailyGoal | Günlük hedef | Daily goal | Meta diaria | Meta diária | الهدف اليومي | 每日目标 |
| waterGoalValue | {glasses} bardak ({liters} L) | {glasses} glasses ({liters} L) | {glasses} vasos ({liters} L) | {glasses} copos ({liters} L) | {glasses} أكواب ({liters} لتر) | {glasses} 杯（{liters} 升） |
| waterDecreaseGoal | Hedefi azalt | Decrease goal | Reducir meta | Diminuir meta | خفض الهدف | 降低目标 |
| waterIncreaseGoal | Hedefi artır | Increase goal | Aumentar meta | Aumentar meta | رفع الهدف | 提高目标 |
| waterGoalFromWeight | Kiloma göre ayarla | Set from my weight | Ajustar según mi peso | Ajustar pelo meu peso | اضبط حسب وزني | 按体重设置 |
| waterReminderSwitch | Su hatırlatıcısı | Water reminders | Recordatorios de agua | Lembretes de água | تذكيرات شرب الماء | 喝水提醒 |
| waterReminderSchedule | 09:00–21:00 arası, 2 saatte bir | Every 2 hours, 09:00–21:00 | Cada 2 horas, 09:00–21:00 | A cada 2 horas, 09:00–21:00 | كل ساعتين، 09:00–21:00 | 09:00–21:00，每 2 小时 |
| waterReminderPrompt | 2 saatte bir hatırlatayım mı? | Remind you every 2 hours? | ¿Te lo recuerdo cada 2 horas? | Quer um lembrete a cada 2 horas? | هل أذكّرك كل ساعتين؟ | 每 2 小时提醒你？ |
| waterReminderEnable | Aç | Turn on | Activar | Ativar | تفعيل | 开启 |
| waterPermissionDenied | Bildirim izni verilmedi. Ayarlardan açabilirsin. | Notifications are off. You can allow them in Settings. | Las notificaciones están desactivadas. Puedes permitirlas en Ajustes. | As notificações estão desativadas. Você pode permitir nos Ajustes. | الإشعارات متوقفة. يمكنك السماح بها من الإعدادات. | 通知已关闭，可在设置中开启。 |
| waterReminderTitle | Su içme zamanı | Time for water | Hora de beber agua | Hora de beber água | حان وقت شرب الماء | 该喝水了 |
| waterReminderBody | Bir bardak su iç, bugünkü hedefine yaklaş. | Have a glass of water and get closer to today's goal. | Bebe un vaso de agua y acércate a tu meta de hoy. | Beba um copo de água e chegue mais perto da meta de hoje. | اشرب كوب ماء واقترب من هدف اليوم. | 喝一杯水，离今天的目标更近一步。 |
| waterDayCountUnit | {count} günlük su kaydı | {count} days of water logs | {count} días de registro de agua | {count} dias de registro de água | سجل ماء لـ {count} يوم | {count} 天饮水记录 |

- [ ] **Step 2: Generate and analyze**

Run:

```bash
flutter gen-l10n
flutter analyze --no-pub
```

Expected: generation succeeds (the "delete l10n.yaml to use arguments" line is informational), analyze clean.

- [ ] **Step 3: Commit**

```bash
git add lib/l10n
git commit -m "feat(water): su sayaci metinleri (6 dil)

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 8: Data ownership — guest migration, deletion, sign-out

**Files:**
- Modify: `lib/core/session/guest_migration_service.dart`
- Modify: `lib/features/auth/presentation/widgets/guest_migration_prompt_sheet.dart`
- Modify: `lib/features/profile/data/services/user_data_deletion_service.dart`
- Modify: `lib/features/profile/presentation/providers/user_data_deletion_provider.dart`
- Modify: `lib/features/auth/presentation/providers/auth_provider.dart`
- Modify tests: `test/core/session/guest_migration_service_test.dart`, `test/features/profile/data/services/user_data_deletion_service_test.dart`

**Interfaces:**
- Consumes: `WaterLocalDataSource`, `waterLocalDataSourceProvider`, `WaterSettingsStore.keys`, `NotificationService.cancelWaterReminders`, `waterDayCountUnit`.
- Produces: `GuestMigrationService({..., required WaterLocalDataSource waterDs})`; `GuestDataSummary.waterDayCount` (default 0, included in `isEmpty`); `UserDataDeletionService({..., Future<void> Function()? cancelWaterReminders})`.

- [ ] **Step 1: Write failing guest migration tests**

In `test/core/session/guest_migration_service_test.dart`:

Add import:

```dart
import 'package:nutrilens/features/water/data/datasources/water_local_datasource.dart';
```

Add `late WaterLocalDataSource waterDs;` next to `metricsDs`, and in `setUp` before `service = ...`:

```dart
    waterDs = WaterLocalDataSourceImpl(db);
```

and pass `waterDs: waterDs,` to the `GuestMigrationService(...)` constructor.

Append tests inside `main()`:

```dart
  test('inspectPending su gunlerini sayar ve bos saymaz', () async {
    await waterDs.addGlass(
      userId: kGuestUserId,
      now: DateTime(2026, 9, 13, 10),
      goal: 10,
    );
    final summary = await service.inspectPending();
    expect(summary.waterDayCount, 1);
    expect(summary.isEmpty, isFalse);
  });

  test('migrate su kayitlarini yeni hesaba tasir', () async {
    await waterDs.addGlass(
      userId: kGuestUserId,
      now: DateTime(2026, 9, 13, 10),
      goal: 10,
    );
    await service.migrate(newUserId: 'user-1');
    expect(await waterDs.countDays(kGuestUserId), 0);
    expect((await waterDs.getDay('user-1', '2026-09-13'))!.glasses, 1);
  });

  test('discard misafirin su kayitlarini siler', () async {
    await waterDs.addGlass(
      userId: kGuestUserId,
      now: DateTime(2026, 9, 13, 10),
      goal: 10,
    );
    await service.discard();
    expect(await waterDs.countDays(kGuestUserId), 0);
  });
```

If `migrate` calls `_supabase.from(...)` only when scans exist, no extra stubbing is needed (no scans inserted here).

- [ ] **Step 2: Write failing deletion tests**

In `test/features/profile/data/services/user_data_deletion_service_test.dart`:

Add to `SharedPreferences.setMockInitialValues({...})` in `setUp`:

```dart
      'water_goal_glasses': 12,
      'water_reminder_enabled': true,
      'water_reminder_prompt_shown': true,
```

Add `var cancelledReminders = 0;` above `setUp` (reset to 0 inside `setUp`) and pass to the service:

```dart
      cancelWaterReminders: () async => cancelledReminders++,
```

Append tests:

```dart
  test('local cleanup removes water logs, prefs and pending reminders',
      () async {
    for (final id in ['user-1', 'user-2']) {
      await db
          .into(db.waterLogs)
          .insert(
            WaterLogsCompanion.insert(
              userId: id,
              day: '2026-09-13',
              goalGlasses: 10,
            ),
          );
    }
    await service.deleteLocalUserData('user-1');
    expect((await db.select(db.waterLogs).get()).single.userId, 'user-2');
    expect(prefs.getInt('water_goal_glasses'), isNull);
    expect(prefs.getBool('water_reminder_enabled'), isNull);
    expect(prefs.getBool('water_reminder_prompt_shown'), isNull);
    expect(cancelledReminders, 1);
  });

  test('resumed deletion of another account keeps current user reminders',
      () async {
    final other = UserDataDeletionService(
      db: db,
      remoteStore: remote,
      preferences: prefs,
      currentUserId: () => 'user-2',
      cancelWaterReminders: () async => cancelledReminders++,
    );
    await other.deleteLocalUserData('user-1');
    expect(cancelledReminders, 0);
    expect(prefs.getBool('water_reminder_enabled'), isTrue);
  });
```

- [ ] **Step 3: Run to verify they fail**

Run: `flutter test --no-pub test/core/session/guest_migration_service_test.dart test/features/profile/data/services/user_data_deletion_service_test.dart`
Expected: compile FAIL — `waterDs`, `waterDayCount`, `cancelWaterReminders` not defined.

- [ ] **Step 4: Implement guest migration changes**

In `lib/core/session/guest_migration_service.dart`:

Add imports:

```dart
import '../../features/water/data/datasources/water_local_datasource.dart';
import '../../features/water/presentation/providers/water_provider.dart';
```

`GuestDataSummary`: add field + constructor param + `isEmpty`:

```dart
  /// Days with a water log. Local-only data, but still the guest's — counts
  /// toward "is there anything to move", same reasoning as [hasMetrics].
  final int waterDayCount;
```

constructor: add `this.waterDayCount = 0,` after `required this.hasMetrics,`.

`isEmpty`:

```dart
  bool get isEmpty =>
      scanCount == 0 && mealCount == 0 && !hasMetrics && waterDayCount == 0;
```

`GuestMigrationService`: add field `final WaterLocalDataSource _waterDs;`, constructor param `required WaterLocalDataSource waterDs,` and initializer `_waterDs = waterDs,`.

`inspectPending`: add `final waterDays = await _waterDs.countDays(kGuestUserId);` and `waterDayCount: waterDays,` in the returned summary.

`migrate`: after the `_metricsDs.reassignOwner(...)` call add:

```dart
    await _waterDs.reassignOwner(
      fromUserId: kGuestUserId,
      toUserId: newUserId,
    );
```

and add `water_logs` to the step 1 doc comment list.

`discard`: after `await _metricsDs.deleteFor(kGuestUserId);` add:

```dart
    await _waterDs.deleteFor(kGuestUserId);
```

Provider: add `waterDs: ref.watch(waterLocalDataSourceProvider),`.

In `lib/features/auth/presentation/widgets/guest_migration_prompt_sheet.dart`, extend `parts`:

```dart
      if (summary.waterDayCount > 0)
        l10n.waterDayCountUnit(summary.waterDayCount),
```

- [ ] **Step 5: Implement deletion changes**

In `lib/features/profile/data/services/user_data_deletion_service.dart`:

Add import:

```dart
import '../../../water/data/water_settings_store.dart';
```

Add field and constructor param:

```dart
  final Future<void> Function()? _cancelWaterReminders;
```

```dart
    Future<void> Function()? cancelWaterReminders,
```

```dart
       _cancelWaterReminders = cancelWaterReminders;
```

(replace the trailing `;` of `_currentUserId = currentUserId;` with `,`).

Inside the `_db.transaction` of `deleteLocalUserData`, after the `userMetrics` delete:

```dart
      await (_db.delete(
        _db.waterLogs,
      )..where((table) => table.userId.equals(userId))).go();
```

Replace the guarded block at the end with:

```dart
    if (currentId == null || currentId == userId) {
      await _clearLocalProfilePreferences();
      await _cancelWaterReminders?.call();
    }
```

In `_clearLocalProfilePreferences` change the loop to:

```dart
    for (final key in [..._healthFilterKeys, ...WaterSettingsStore.keys]) {
      await _preferences.remove(key);
    }
```

In `lib/features/profile/presentation/providers/user_data_deletion_provider.dart` add import `import '../../../../core/services/notification_service.dart';` and pass:

```dart
    cancelWaterReminders: ref.watch(notificationServiceProvider).cancelWaterReminders,
```

- [ ] **Step 6: Cancel reminders on sign-out**

In `lib/features/auth/presentation/providers/auth_provider.dart` add `import '../../../../core/services/notification_service.dart';` and `import 'package:flutter/foundation.dart';` (if `debugPrint` is not already available), then at the start of `signOut()`:

```dart
    // Pending water reminders belong to the account that is leaving.
    try {
      await ref.read(notificationServiceProvider).cancelWaterReminders();
    } catch (e) {
      debugPrint('[Auth] water reminder cancel failed: $e');
    }
```

- [ ] **Step 7: Run to verify they pass**

Run: `flutter test --no-pub test/core/session/ test/features/profile/ test/features/auth/`
Expected: PASS (existing `post_auth_flow_test` still compiles because `waterDayCount` is optional).

- [ ] **Step 8: Analyze and commit**

```bash
flutter analyze --no-pub
git add lib/core/session lib/features/auth lib/features/profile test/core/session test/features/profile
git commit -m "feat(water): misafir tasima, hesap silme ve cikista su verisi

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 9: UI actions and Meals tab card

**Files:**
- Create: `lib/features/water/presentation/water_actions.dart`
- Create: `lib/features/water/presentation/widgets/water_card.dart`
- Modify: `lib/features/meals/presentation/screens/meals_screen.dart`
- Modify: `lib/config/router/route_names.dart` (add name used by the card)
- Create test helper: `test/features/water/water_widget_harness.dart`
- Test: `test/features/water/water_card_test.dart`

**Interfaces:**
- Consumes: Task 6 providers/controller, Task 7 strings.
- Produces: `WaterReminderCopy waterReminderCopy(AppLocalizations l10n)`, `Future<void> addWaterGlass(BuildContext, WidgetRef)`, `Future<void> removeWaterGlass(BuildContext, WidgetRef)`, `Future<void> setWaterReminder(BuildContext, WidgetRef, bool enabled)`; `WaterCard` widget; `RouteNames.water = 'water'`; test helper `pumpWaterWidget(...)`.

- [ ] **Step 1: Write the test harness**

`test/features/water/water_widget_harness.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nutrilens/config/drift/app_database.dart';
import 'package:nutrilens/core/analytics/analytics_provider.dart';
import 'package:nutrilens/core/analytics/analytics_service.dart';
import 'package:nutrilens/core/providers/locale_provider.dart';
import 'package:nutrilens/core/services/notification_service.dart';
import 'package:nutrilens/core/session/app_session.dart';
import 'package:nutrilens/core/theme/app_theme.dart';
import 'package:nutrilens/features/product/presentation/providers/product_provider.dart';
import 'package:nutrilens/features/water/presentation/providers/water_provider.dart';
import 'package:nutrilens/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockNotificationService extends Mock implements NotificationService {}

class SilentAnalytics extends AnalyticsService {
  SilentAnalytics()
    : super(
        client: null,
        deviceId: null,
        prefs: null,
        enabled: false,
        flushInterval: Duration.zero,
      );

  @override
  void track(String name, {Map<String, Object?> props = const {}}) {}
}

class WaterHarness {
  final AppDatabase db;
  final SharedPreferences prefs;
  final MockNotificationService notifications;

  const WaterHarness(this.db, this.prefs, this.notifications);
}

Future<WaterHarness> pumpWaterWidget(
  WidgetTester tester,
  Widget child, {
  bool permissionGranted = true,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(db.close);

  registerFallbackValue(<DateTime>[]);
  final notifications = MockNotificationService();
  when(() => notifications.requestPermission())
      .thenAnswer((_) async => permissionGranted);
  when(() => notifications.cancelWaterReminders()).thenAnswer((_) async {});
  when(
    () => notifications.rescheduleWaterReminders(
      times: any(named: 'times'),
      title: any(named: 'title'),
      body: any(named: 'body'),
    ),
  ).thenAnswer((_) async {});

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(prefs),
        effectiveUserIdProvider.overrideWithValue('user-1'),
        notificationServiceProvider.overrideWithValue(notifications),
        analyticsServiceProvider.overrideWithValue(SilentAnalytics()),
        waterClockProvider.overrideWithValue(
          () => DateTime(2026, 9, 13, 10, 30),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return WaterHarness(db, prefs, notifications);
}
```

- [ ] **Step 2: Write the failing card test**

`test/features/water/water_card_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nutrilens/features/water/presentation/providers/water_provider.dart';
import 'package:nutrilens/features/water/presentation/widgets/water_card.dart';

import 'water_widget_harness.dart';

void main() {
  testWidgets('baslangicta 0 / 10, eksi pasif', (tester) async {
    await pumpWaterWidget(tester, const WaterCard());

    expect(find.text('0 / 10 bardak'), findsOneWidget);
    final minus = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.remove_rounded),
    );
    expect(minus.onPressed, isNull);
  });

  testWidgets('+1 sayar, ilk seferde hatirlatma sorusu cikar', (tester) async {
    await pumpWaterWidget(tester, const WaterCard());

    await tester.tap(find.text('+1 bardak'));
    await tester.pumpAndSettle();

    expect(find.text('1 / 10 bardak'), findsOneWidget);
    expect(find.text('2 saatte bir hatırlatayım mı?'), findsOneWidget);
  });

  testWidgets('soru ikinci bardakta tekrar cikmaz', (tester) async {
    final h = await pumpWaterWidget(tester, const WaterCard());
    await h.prefs.setBool('water_reminder_prompt_shown', true);

    await tester.tap(find.text('+1 bardak'));
    await tester.pumpAndSettle();

    expect(find.text('2 saatte bir hatırlatayım mı?'), findsNothing);
  });

  testWidgets('soru aksiyonu izin ister ve hatirlatmayi kurar', (tester) async {
    final h = await pumpWaterWidget(tester, const WaterCard());

    await tester.tap(find.text('+1 bardak'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aç'));
    await tester.pumpAndSettle();

    verify(() => h.notifications.requestPermission()).called(1);
    expect(h.prefs.getBool('water_reminder_enabled'), isTrue);
  });

  testWidgets('eksi bir bardak geri alir', (tester) async {
    await pumpWaterWidget(tester, const WaterCard());
    await tester.tap(find.text('+1 bardak'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Bir bardak çıkar'));
    await tester.pumpAndSettle();

    expect(find.text('0 / 10 bardak'), findsOneWidget);
  });

  testWidgets('hedefe ulasinca mesaj gorunur', (tester) async {
    await pumpWaterWidget(tester, const WaterCard());
    final container = ProviderScope.containerOf(
      tester.element(find.byType(WaterCard)),
    );
    await container
        .read(waterControllerProvider)
        .setGoal(1, (title: 't', body: 'b'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('+1 bardak'));
    await tester.pumpAndSettle();

    expect(find.text('Günlük hedefe ulaştın'), findsOneWidget);
  });
}
```

- [ ] **Step 3: Run to verify it fails**

Run: `flutter test --no-pub test/features/water/water_card_test.dart`
Expected: FAIL — `water_card.dart` not found.

- [ ] **Step 4: Add the route name**

In `lib/config/router/route_names.dart`, under `static const String mealDetail = 'mealDetail';` add:

```dart

  // Water
  static const String water = 'water';
```

- [ ] **Step 5: Implement actions**

`lib/features/water/presentation/water_actions.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/extensions/l10n_extension.dart';
import '../../../l10n/generated/app_localizations.dart';
import 'providers/water_provider.dart';

WaterReminderCopy waterReminderCopy(AppLocalizations l10n) =>
    (title: l10n.waterReminderTitle, body: l10n.waterReminderBody);

Future<void> addWaterGlass(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  await ref.read(waterControllerProvider).addGlass(waterReminderCopy(l10n));

  // One-shot discovery: the switch lives on the water screen, which most
  // users never open before the habit forms.
  final store = ref.read(waterSettingsStoreProvider);
  if (ref.read(waterSettingsProvider).reminderEnabled || store.promptShown) {
    return;
  }
  await store.markPromptShown();
  if (!context.mounted) return;
  messenger.showSnackBar(
    SnackBar(
      content: Text(l10n.waterReminderPrompt),
      action: SnackBarAction(
        label: l10n.waterReminderEnable,
        onPressed: () => setWaterReminder(context, ref, true),
      ),
    ),
  );
}

Future<void> removeWaterGlass(BuildContext context, WidgetRef ref) async {
  await ref
      .read(waterControllerProvider)
      .removeGlass(waterReminderCopy(context.l10n));
}

Future<void> setWaterReminder(
  BuildContext context,
  WidgetRef ref,
  bool enabled,
) async {
  if (!context.mounted) return;
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final ok = await ref
      .read(waterControllerProvider)
      .setReminderEnabled(enabled, waterReminderCopy(l10n));
  if (!ok) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.waterPermissionDenied)));
  }
}
```

- [ ] **Step 6: Implement the card**

`lib/features/water/presentation/widgets/water_card.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/router/route_names.dart';
import '../../../../core/extensions/l10n_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_tap_card.dart';
import '../../../../core/widgets/cozy_tile.dart';
import '../providers/water_provider.dart';
import '../water_actions.dart';

class WaterCard extends ConsumerWidget {
  const WaterCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = context.l10n;
    final tint = colors.cozy.sky;
    final goal = ref.watch(waterGoalProvider);
    final glasses = ref.watch(waterTodayProvider).value?.glasses ?? 0;
    final met = glasses >= goal;

    return AppTapCard(
      onTap: () => context.pushNamed(RouteNames.water),
      semanticLabel: l10n.waterTitle,
      borderRadius: BorderRadius.circular(24),
      decoration: cozyCardDecoration(context).copyWith(color: tint.surface),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.water_drop_rounded, color: tint.ink),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.waterGlassesProgress(glasses, goal),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: goal <= 0 ? 0 : (glasses / goal).clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: colors.border,
                color: met ? colors.primary : tint.ink,
              ),
            ),
            if (met) ...[
              const SizedBox(height: 6),
              Text(
                l10n.waterGoalReached,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.primary,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: l10n.waterRemoveGlass,
                  onPressed: glasses > 0
                      ? () => removeWaterGlass(context, ref)
                      : null,
                  icon: const Icon(Icons.remove_rounded),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () => addWaterGlass(context, ref),
                  icon: const Icon(Icons.add_rounded),
                  label: Text(l10n.waterAddGlass),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 7: Place the card on the Meals tab**

In `lib/features/meals/presentation/screens/meals_screen.dart` add import:

```dart
import '../../../water/presentation/widgets/water_card.dart';
```

After the `_DailyTargetSummary` sliver:

```dart
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 18),
                child: _DailyTargetSummary(),
              ),
            ),
```

insert:

```dart
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 18),
                child: WaterCard(),
              ),
            ),
```

- [ ] **Step 8: Run to verify it passes**

Run: `flutter test --no-pub test/features/water/water_card_test.dart test/features/meals/`
Expected: PASS. If an existing meals screen test now fails because `WaterCard` needs an override it lacks (e.g. `sharedPreferencesProvider`), add that override to that test's `ProviderScope` — the card must stay in the tree.

- [ ] **Step 9: Analyze and commit**

```bash
flutter analyze --no-pub
git add lib/features/water lib/features/meals/presentation/screens/meals_screen.dart lib/config/router/route_names.dart test/features/water test/features/meals
git commit -m "feat(water): Ogunlerim sekmesinde su karti

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 10: Water screen and route

**Files:**
- Create: `lib/features/water/presentation/screens/water_screen.dart`
- Modify: `lib/config/router/app_router.dart`
- Test: `test/features/water/water_screen_test.dart`

**Interfaces:**
- Consumes: Tasks 2, 6, 7, 9 (`water_actions.dart`, harness).
- Produces: `WaterScreen` at `/water` (name `RouteNames.water`, root navigator).

- [ ] **Step 1: Write the failing test**

`test/features/water/water_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/features/water/presentation/screens/water_screen.dart';

import 'water_widget_harness.dart';

Finder _bars() => find.byWidgetPredicate(
  (w) => w.key is ValueKey<String> &&
      (w.key! as ValueKey<String>).value.startsWith('water-bar-'),
);

void main() {
  testWidgets('7 gunluk grafik ve varsayilan hedef', (tester) async {
    await pumpWaterWidget(tester, const WaterScreen());

    expect(_bars(), findsNWidgets(7));
    expect(find.text('10 bardak (2 L)'), findsOneWidget);
    expect(find.text('Kiloma göre ayarla'), findsNothing);
  });

  testWidgets('hedef artirilinca litre de guncellenir', (tester) async {
    await pumpWaterWidget(tester, const WaterScreen());

    await tester.tap(find.byTooltip('Hedefi artır'));
    await tester.pumpAndSettle();

    expect(find.text('11 bardak (2,2 L)'), findsOneWidget);
  });

  testWidgets('bugun eklenen bardak grafikte son cubuga yansir',
      (tester) async {
    await pumpWaterWidget(tester, const WaterScreen());

    await tester.tap(find.text('+1 bardak'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('water-bar-2026-09-13')), findsOneWidget);
    expect(find.text('1 / 10 bardak'), findsOneWidget);
  });

  testWidgets('izin reddedilince anahtar kapali kalir ve mesaj cikar',
      (tester) async {
    await pumpWaterWidget(
      tester,
      const WaterScreen(),
      permissionGranted: false,
    );

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    expect(
      find.text('Bildirim izni verilmedi. Ayarlardan açabilirsin.'),
      findsOneWidget,
    );
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test --no-pub test/features/water/water_screen_test.dart`
Expected: FAIL — `water_screen.dart` not found.

- [ ] **Step 3: Implement the screen**

`lib/features/water/presentation/screens/water_screen.dart`:

```dart
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/extensions/l10n_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/water_day.dart';
import '../../domain/water_goal.dart';
import '../providers/water_provider.dart';
import '../water_actions.dart';

class WaterScreen extends ConsumerWidget {
  const WaterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final goal = ref.watch(waterGoalProvider);
    final glasses = ref.watch(waterTodayProvider).value?.glasses ?? 0;
    final week = ref.watch(waterWeekProvider).value ?? const <WaterDay>[];
    final reminderEnabled = ref.watch(waterSettingsProvider).reminderEnabled;
    final weight = ref.watch(waterMetricsWeightProvider).value;
    final liters = NumberFormat('#0.#', locale).format(goal * kGlassMl / 1000);
    final copy = waterReminderCopy(l10n);
    final controller = ref.read(waterControllerProvider);
    final sectionStyle = TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w700,
      color: colors.textPrimary,
    );

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(l10n.waterTitle),
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Center(
            child: Text(
              l10n.waterGlassesProgress(glasses, goal),
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: colors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.outlined(
                tooltip: l10n.waterRemoveGlass,
                onPressed: glasses > 0
                    ? () => removeWaterGlass(context, ref)
                    : null,
                icon: const Icon(Icons.remove_rounded),
              ),
              const SizedBox(width: 16),
              FilledButton.icon(
                onPressed: () => addWaterGlass(context, ref),
                icon: const Icon(Icons.add_rounded),
                label: Text(l10n.waterAddGlass),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Text(l10n.waterLast7Days, style: sectionStyle),
          const SizedBox(height: 12),
          _WeekChart(days: week),
          const SizedBox(height: 28),
          Text(l10n.waterDailyGoal, style: sectionStyle),
          const SizedBox(height: 4),
          Row(
            children: [
              IconButton(
                tooltip: l10n.waterDecreaseGoal,
                onPressed: goal > kMinGoalGlasses
                    ? () => controller.setGoal(goal - 1, copy)
                    : null,
                icon: const Icon(Icons.remove_rounded),
              ),
              Expanded(
                child: Text(
                  l10n.waterGoalValue(goal, liters),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: colors.textPrimary),
                ),
              ),
              IconButton(
                tooltip: l10n.waterIncreaseGoal,
                onPressed: goal < kMaxGoalGlasses
                    ? () => controller.setGoal(goal + 1, copy)
                    : null,
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          if (weight != null)
            Center(
              child: TextButton(
                onPressed: () =>
                    controller.setGoal(suggestedWaterGoal(weight), copy),
                child: Text(l10n.waterGoalFromWeight),
              ),
            ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.waterReminderSwitch),
            subtitle: Text(l10n.waterReminderSchedule),
            value: reminderEnabled,
            onChanged: (value) => setWaterReminder(context, ref, value),
          ),
        ],
      ),
    );
  }
}

class _WeekChart extends StatelessWidget {
  final List<WaterDay> days;

  const _WeekChart({required this.days});

  static const _barMaxHeight = 90.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final ink = colors.cozy.sky.ink;
    final maxValue = days.fold<int>(
      1,
      (m, d) => math.max(m, math.max(d.glasses, d.goalGlasses)),
    );
    final labelStyle = TextStyle(fontSize: 11, color: colors.textMuted);

    return SizedBox(
      height: 140,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final day in days)
            Expanded(
              child: Semantics(
                label:
                    '${DateFormat.EEEE(locale).format(DateTime.parse(day.day))}: '
                    '${l10n.waterGlassesProgress(day.glasses, day.goalGlasses)}',
                excludeSemantics: true,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text('${day.glasses}', style: labelStyle),
                      const SizedBox(height: 4),
                      Container(
                        key: ValueKey('water-bar-${day.day}'),
                        height: _barMaxHeight * day.glasses / maxValue,
                        decoration: BoxDecoration(
                          color: day.goalMet ? ink : ink.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        DateFormat.E(locale).format(DateTime.parse(day.day)),
                        style: labelStyle,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Register the route**

In `lib/config/router/app_router.dart` add import:

```dart
import '../../features/water/presentation/screens/water_screen.dart';
```

After the `/meal-detail` `GoRoute(...)` entry add:

```dart
      GoRoute(
        path: '/water',
        name: RouteNames.water,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const WaterScreen(),
      ),
```

- [ ] **Step 5: Run to verify it passes**

Run: `flutter test --no-pub test/features/water/`
Expected: PASS.

- [ ] **Step 6: Analyze and commit**

```bash
flutter analyze --no-pub
git add lib/features/water/presentation/screens lib/config/router/app_router.dart test/features/water/water_screen_test.dart
git commit -m "feat(water): su ekrani, 7 gunluk grafik ve /water rotasi

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 11: Re-arm on launch and final verification

**Files:**
- Modify: `lib/features/app_shell/app_shell_screen.dart`
- Update: `C:/Users/m_fat/OneDrive/Belgeler/Obsidian Vault/NutriLens/wiki/05-ai-handoff.md`

**Interfaces:**
- Consumes: `waterControllerProvider.rescheduleReminders`, `waterReminderCopy`.

- [ ] **Step 1: Re-arm water reminders on launch**

In `lib/features/app_shell/app_shell_screen.dart` add imports:

```dart
import '../water/presentation/providers/water_provider.dart';
import '../water/presentation/water_actions.dart';
```

In `initState`, change the post-frame callback to:

```dart
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureDailyReminder();
      _ensureWaterReminders();
    });
```

Add below `_ensureDailyReminder`:

```dart
  /// Tomorrow's water slots are the only ones armed ahead, so every launch
  /// re-arms them. Disabled or signed-out → cancels. Never throws.
  Future<void> _ensureWaterReminders() async {
    if (!mounted) return;
    await ref
        .read(waterControllerProvider)
        .rescheduleReminders(waterReminderCopy(context.l10n));
  }
```

- [ ] **Step 2: Full verification**

Run:

```bash
flutter analyze --no-pub
flutter test --no-pub
flutter build apk --debug
```

Expected: analyze clean; all tests pass (679 before this plan + new water tests); debug APK builds (no new native plugin, but the notification channel change touches Android — see memory `android-build-plugin-gate`).

Format check on files this plan created or changed (not generated files):

```bash
dart format --set-exit-if-changed lib/features/water test/features/water lib/config/drift/tables/water_logs_table.dart lib/config/drift/app_database.dart lib/core/services/notification_service.dart test/core/services/notification_service_water_test.dart test/config/drift/migration_v5_test.dart
```

Expected: exit 0. Otherwise format only those files and commit as `style(water): format`.

- [ ] **Step 3: Device check (owner)**

With an emulator or device attached (`flutter devices`), run the app the usual way for local development (`flutter run`).

Check: Meals tab card renders under calorie card; +1 shows snackbar once; `/water` screen chart, goal stepper, switch; dark theme; Arabic (RTL). Set device time to 08:55 with reminder on and confirm a notification at ~09:00 on the "Su Hatırlatma" channel. If no device is attached, record in the handoff that this is pending.

- [ ] **Step 4: Update knowledge files**

Run `graphify update .`

In `05-ai-handoff.md` replace the "Son Oturum" section heading and bullets with a 2026-09-13 entry: HP puanı artık 0-100 gösterimde (commit `659f6d7`); su sayacı + hatırlatıcı eklendi (spec + plan paths, Drift schema v5, reminder ids 2000–2013, device check status).

- [ ] **Step 5: Commit**

```bash
git add lib/features/app_shell/app_shell_screen.dart
git commit -m "feat(water): uygulama acilisinda su hatirlatmalarini yeniden kur

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Spec Coverage Check

| Spec item | Task |
|---|---|
| `water_logs` table, PK, goal snapshot, v5 migration | 1, 4 |
| Ownership: guest migration (conflict rule, isEmpty), deletion | 8 |
| Preferences keys + cleared on deletion | 6, 8 |
| Add/remove rules, local day key | 2, 4 |
| Goal default / weight / manual range | 2, 6, 10 |
| `waterReminderTimes` rules, DST | 3 |
| NotificationService reschedule/cancel, ids, channel, permission bool | 5 |
| Triggers: launch, add/remove, goal, toggle, signed-out, deletion | 6, 8, 11 |
| Permission denied → off + snackbar; first +1 discovery snackbar | 9, 10 |
| Copy in 6 locales | 7 |
| WaterCard on Meals tab | 9 |
| WaterScreen: counter, 7-day chart, goal row, weight button, switch, semantics | 10 |
| Analytics events | 6 |
| Tests listed in spec | 1–10 |
| Manual device check | 11 |
