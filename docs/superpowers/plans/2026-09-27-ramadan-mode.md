# Ramadan Mode Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Opt-in Ramadan mode: sahur/iftar countdown and notifications, iftar–sahur water reminders, fasting calendar with a shareable summary.

**Architecture:** New `lib/features/ramadan/` module mirroring `lib/features/water/`: pure domain functions (calendar, times, schedule), SharedPreferences settings + one Drift table, a Riverpod controller that owns all Ramadan scheduling. The water controller only asks it which reminder times to use. Notifications go through `NotificationService` with new id ranges.

**Tech Stack:** Flutter, Riverpod 3, Drift (+ `drift_dev` schema tooling), `flutter_local_notifications`, `timezone`, `shared_preferences`, new: `adhan_dart`, `geolocator`; tests with `flutter_test` + `mocktail`.

**Spec:** `docs/superpowers/specs/2026-09-27-ramadan-mode-design.md`

## Global Constraints

- Ramadan 2027: first day `2027-02-08`, Eid `2027-03-09`, length 29. Offer window opens `2027-02-05`.
- Times: `adhan_dart`, `CalculationMethod.turkiye`; imsak = Fajr, iftar = Maghrib.
- **Safety rounding:** imsak is floored to the minute, iftar is ceiled to the minute. A shown/notified imsak must never be later, and an iftar never earlier, than the computed instant.
- Notification ids: sahur 3000–3006, iftar 3010–3016 (by day offset 0–6). Water stays 2000–2013, meal reminder 1001 untouched.
- Ramadan water slots obey the existing water reminder switch (`waterSettingsProvider.reminderEnabled`); the mode only changes *which* times are used.
- Water slots in Ramadan: `iftar + 30 min`, then every 2 h while `<= 23:30`; existing 2 h quiet gap and goal-met rules apply to today.
- Sahur offset: 30 / 45 / 60 min, default 45.
- Free, guests included. Fasting data is local only (Drift), owned like `water_logs`.
- Province names are not localised; all other copy goes into all 6 `.arb` files (`tr`, `en`, `ar`, `es`, `pt`, `zh`).
- Schema version becomes 6.

## Review Focus

1. **Wall clock between 00:00 and imsak** — countdown must say "Sahura" using *today's* imsak, not tomorrow's. Test in Task 7.
2. **Mode on during the offer window (5–7 Feb)** — no countdown card, no Ramadan notifications, normal water times. Test in Tasks 6 and 7.
3. **App first opened days after Eid** — mode switches off, Ramadan notifications cancelled, normal water times rescheduled. Test in Task 6.
4. **Mode on with no stored coordinates** (prefs partly cleared) — nothing scheduled, no crash, card shows "choose location". Test in Tasks 6 and 7.
5. **Rounding at the minute edge** — computed Maghrib 18:22:10 must show and notify 18:23; Fajr 06:17:50 must show 06:17. Test in Task 2.

---

### Task 1: Ramadan calendar

**Files:**
- Create: `lib/features/ramadan/domain/ramadan_calendar.dart`
- Test: `test/features/ramadan/ramadan_calendar_test.dart`

**Interfaces:**
- Produces:
  - `class RamadanPeriod { final DateTime firstDay; final DateTime eidDay; int get length; int get year => firstDay.year; }`
  - `final List<RamadanPeriod> ramadanPeriods`
  - `RamadanPeriod? currentRamadan(DateTime now)`
  - `RamadanPeriod? offerPeriod(DateTime now)` (from `firstDay - 3 days` to before `eidDay`)
  - `RamadanPeriod? latestPeriod(DateTime now)`
  - `int? ramadanDayIndex(DateTime now)` (1-based)
  - `String ramadanDayKey(DateTime d)` → `yyyy-MM-dd` (reuse `waterDayKey` if it already formats that way; re-export instead of duplicating)

- [ ] **Step 1: Write the failing tests**

```dart
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
});
```

- [ ] **Step 2: Run to see it fail** — `flutter test test/features/ramadan/ramadan_calendar_test.dart` → FAIL (file missing).
- [ ] **Step 3: Implement.** Day math via `DateTime.utc(y, m, d)` so DST never yields a 23 h day. Comment the Diyanet source on the 2027 entry.
- [ ] **Step 4: Run** → PASS.
- [ ] **Step 5: Commit** `feat(ramadan): add Ramadan 2027 calendar`

### Task 2: Fasting times and provinces

**Files:**
- Modify: `pubspec.yaml` (add `adhan_dart`, latest stable)
- Create: `lib/features/ramadan/domain/fasting_times.dart`
- Create: `lib/features/ramadan/domain/turkish_cities.dart`
- Test: `test/features/ramadan/fasting_times_test.dart`

**Interfaces:**
- Produces:
  - `typedef FastingTimes = ({DateTime imsak, DateTime iftar});` (local, whole minutes)
  - `FastingTimes fastingTimes(DateTime date, double lat, double lng)`
  - `DateTime floorToMinute(DateTime t)`, `DateTime ceilToMinute(DateTime t)` (top-level, tested directly)
  - `typedef TurkishCity = ({int plate, String name, double lat, double lng});`
  - `const List<TurkishCity> turkishCities` (81, sorted by Turkish collation of `name`)
  - `TurkishCity? cityByPlate(int plate)`

- [ ] **Step 1: Write the failing tests**

Reference values (Diyanet method via Aladhan `method=13`, `Europe/Istanbul`): Fajr/Maghrib — Ankara 08 Feb 2027 06:18 / 18:23, 08 Mar 2027 05:42 / 18:55; İstanbul 08 Feb 06:34 / 18:36; Van 08 Feb 05:36 / 17:43.

```dart
// Returned times are device-local, so assert in UTC (Turkey = UTC+3, no DST):
// 18:23 TRT == 15:23Z. |difference| <= 1 minute.
void expectNear(DateTime actual, int trtHour, int minute) {
  final expected = DateTime.utc(actual.toUtc().year, actual.toUtc().month,
      actual.toUtc().day, trtHour - 3, minute);
  expect(actual.toUtc().difference(expected).inMinutes.abs(), lessThanOrEqualTo(1));
}

test('Ankara day 1', () {
  final t = fastingTimes(DateTime(2027, 2, 8), 39.9334, 32.8597);
  expectNear(t.imsak, 6, 18);
  expectNear(t.iftar, 18, 23);
});
// + Ankara 8 Mar, İstanbul 8 Feb, Van 8 Feb with the values above.

test('rounding is on the safe side', () {
  expect(ceilToMinute(DateTime(2027, 2, 8, 18, 22, 10)), DateTime(2027, 2, 8, 18, 23));
  expect(ceilToMinute(DateTime(2027, 2, 8, 18, 23)), DateTime(2027, 2, 8, 18, 23));
  expect(floorToMinute(DateTime(2027, 2, 8, 6, 17, 50)), DateTime(2027, 2, 8, 6, 17));
});

test('81 provinces, unique plates 1..81', () {
  expect(turkishCities.map((c) => c.plate).toSet(), {for (var i = 1; i <= 81; i++) i});
  expect(cityByPlate(6)?.name, 'Ankara');
});
```

- [ ] **Step 2: Run** → FAIL.
- [ ] **Step 3: Implement.** `fastingTimes` builds `CalculationMethod.turkiye` parameters with rounding off, reads Fajr and Maghrib, converts `toLocal()`, then `floorToMinute(imsak)` / `ceilToMinute(iftar)`. Province coordinates: city-centre lat/lng for all 81 provinces.
- [ ] **Step 4: Run** → PASS. If any reference value is off by more than 1 min, check the `adhan_dart` Turkiye method adjustments before touching tolerances.
- [ ] **Step 5: Commit** `feat(ramadan): compute imsak and iftar with Diyanet method`

### Task 3: Scheduling functions

**Files:**
- Create: `lib/features/ramadan/domain/ramadan_schedule.dart`
- Test: `test/features/ramadan/ramadan_schedule_test.dart`

**Interfaces:**
- Consumes: `FastingTimes` (Task 2), `waterReminderGap` from `water_reminder_schedule.dart`, `RamadanPeriod` (Task 1)
- Produces:
  - `List<DateTime> ramadanWaterTimes({required DateTime now, required FastingTimes today, required FastingTimes tomorrow, required DateTime? lastGlassAt, required int glassesToday, required int goal})`
  - `enum RamadanNotificationKind { sahur, iftar }`
  - `typedef RamadanNotification = ({int id, DateTime at, RamadanNotificationKind kind});`
  - `List<RamadanNotification> ramadanNotificationTimes({required DateTime now, required List<(DateTime day, FastingTimes times)> nextDays, required int sahurOffsetMin, required DateTime eidDay})`

- [ ] **Step 1: Write the failing tests**

```dart
final t = (imsak: DateTime(2027, 2, 8, 6, 18), iftar: DateTime(2027, 2, 8, 18, 23));
final t2 = (imsak: DateTime(2027, 2, 9, 6, 17), iftar: DateTime(2027, 2, 9, 18, 24));

test('slots: iftar+30 then every 2h up to 23:30', () {
  final r = ramadanWaterTimes(now: DateTime(2027, 2, 8, 12), today: t, tomorrow: t2,
      lastGlassAt: null, glassesToday: 0, goal: 10);
  expect(r.where((d) => d.day == 8), [
    DateTime(2027, 2, 8, 18, 53), DateTime(2027, 2, 8, 20, 53), DateTime(2027, 2, 8, 22, 53)]);
  expect(r.where((d) => d.day == 9).first, DateTime(2027, 2, 9, 18, 54));
});
test('quiet gap after a glass drops today slots inside 2h', () { /* lastGlassAt 20:00 → 20:53 dropped, 22:53 kept */ });
test('goal met drops today, keeps tomorrow', () { /* glassesToday: 10 */ });
test('never more than 14', () { /* iftar 17:00 both days → <= 14 */ });

test('notification ids and times', () {
  final n = ramadanNotificationTimes(now: DateTime(2027, 2, 8, 12),
      nextDays: [(DateTime(2027, 2, 8), t), (DateTime(2027, 2, 9), t2)],
      sahurOffsetMin: 45, eidDay: DateTime(2027, 3, 9));
  expect(n, containsAll([
    (id: 3010, at: DateTime(2027, 2, 8, 18, 23), kind: RamadanNotificationKind.iftar),
    (id: 3001, at: DateTime(2027, 2, 9, 5, 32), kind: RamadanNotificationKind.sahur),
    (id: 3011, at: DateTime(2027, 2, 9, 18, 24), kind: RamadanNotificationKind.iftar),
  ]));
  expect(n.any((x) => x.id == 3000), isFalse); // 05:33 today already passed
});
test('nothing on or after Eid', () { /* nextDays include 2027-03-09 → no entries for it */ });
```

- [ ] **Step 2: Run** → FAIL.
- [ ] **Step 3: Implement.** Build slots with the `DateTime(y, m, d, h, min)` constructor (never `add(Duration(days: 1))`), as `water_reminder_schedule.dart` does. Cap the water list at 14.
- [ ] **Step 4: Run** → PASS.
- [ ] **Step 5: Commit** `feat(ramadan): add sahur/iftar and water schedules`

### Task 4: Settings store, `fasting_days` table, schema v6

**Files:**
- Create: `lib/features/ramadan/data/ramadan_settings_store.dart`
- Create: `lib/config/drift/tables/fasting_days_table.dart`
- Create: `lib/features/ramadan/data/fasting_days_local_datasource.dart`
- Modify: `lib/config/drift/app_database.dart` (table list, `schemaVersion => 6`, `if (from < 6 && to >= 6) await m.createTable(fastingDays);`)
- Create: `drift_schemas/` v6 dump + `test/config/drift/generated_migrations/schema_v6.dart` via
  `dart run drift_dev schema dump lib/config/drift/app_database.dart drift_schemas/` and
  `dart run drift_dev schema generate drift_schemas/ test/config/drift/generated_migrations/`
- Test: `test/config/drift/migration_v6_test.dart`, `test/features/ramadan/fasting_days_local_datasource_test.dart`, `test/features/ramadan/ramadan_settings_store_test.dart`

**Interfaces:**
- Produces:
  - `class RamadanSettingsStore { RamadanSettingsStore(SharedPreferences); static const List<String> keys; bool get enabled; ({double lat, double lng, String label, int? plate})? get location; int get sahurOffsetMin; int? get offerDismissedYear; Future<void> setEnabled(bool); Future<void> setLocation({required double lat, required double lng, required String label, int? plate}); Future<void> setSahurOffsetMin(int); Future<void> dismissOffer(int year); }`
  - Keys exactly as the spec table: `ramadan_enabled`, `ramadan_location_plate`, `ramadan_location_lat`, `ramadan_location_lng`, `ramadan_location_label`, `ramadan_sahur_offset_min`, `ramadan_offer_dismissed_year`.
  - `abstract class FastingDaysLocalDataSource { Future<Set<String>> getDays(String userId, {required String from, required String toExclusive}); Future<void> setFasted(String userId, String day, bool fasted); Future<int> countDays(String userId); Future<void> reassignOwner({required String fromUserId, required String toUserId}); Future<void> deleteFor(String userId); }` + Drift implementation, shaped like `WaterLocalDataSource`.

- [ ] **Step 1: Write the failing tests**
  - Store: `location` is null unless lat, lng and label are all present; `sahurOffsetMin` defaults to 45.
  - Datasource: `setFasted(true)` twice keeps one row; `setFasted(false)` removes it; `reassignOwner` moves guest rows and merges without duplicate-key errors when the target already has the same day.
  - Migration (copy `migration_v5_test.dart`): v5 db with a `water_logs` row → migrate to 6 → row intact, `fasting_days` exists and is empty.
- [ ] **Step 2: Run** → FAIL.
- [ ] **Step 3: Implement** the three files and the database change; run `dart run build_runner build --delete-conflicting-outputs`, then the two schema commands.
- [ ] **Step 4: Run** `flutter test test/config/drift test/features/ramadan` → PASS.
- [ ] **Step 5: Commit** `feat(ramadan): store settings and fasting days (schema v6)`

### Task 5: Notification service

**Files:**
- Modify: `lib/core/services/notification_service.dart`
- Test: `test/core/services/notification_service_ramadan_test.dart` (mock `FlutterLocalNotificationsPlugin`; follow any existing notification service test in `test/core/services/`)

**Interfaces:**
- Consumes: `RamadanNotification`, `RamadanNotificationKind` (Task 3)
- Produces:
  - `Future<void> rescheduleRamadanNotifications({required List<RamadanNotification> items, required String sahurTitle, required String sahurBody, required String iftarTitle, required String iftarBody})`. `sahurBody` may contain `{min}`, which is replaced with the offset by the caller, not here.
  - `Future<void> cancelRamadanNotifications()` cancels ids 3000–3006 and 3010–3016.
  - New channel `ramadan_reminder` / `Ramazan Hatırlatma`, `Importance.high`.

- [ ] **Step 1: Failing test:** after `rescheduleRamadanNotifications` with 2 items, the plugin received 14 cancels and 2 `zonedSchedule` calls with ids 3001/3011; past items are skipped (same guard as water); ids 1001 and 2000–2013 are never cancelled.
- [ ] **Step 2: Run** → FAIL.
- [ ] **Step 3: Implement** (reuse `_ensureTimezone` and the past-time guard; `inexactAllowWhileIdle` is fine because it never fires early).
- [ ] **Step 4: Run** → PASS.
- [ ] **Step 5: Commit** `feat(ramadan): schedule sahur and iftar notifications`

### Task 6: Ramadan controller, water integration, resume, copy, analytics

**Files:**
- Create: `lib/features/ramadan/presentation/providers/ramadan_provider.dart`
- Modify: `lib/features/water/presentation/providers/water_provider.dart` (`rescheduleReminders` time selection only)
- Modify: `lib/features/app_shell/app_shell_screen.dart` (resume + launch: call `ramadanController.onResume(...)` next to the water call)
- Modify: `lib/core/analytics/analytics_event.dart` (in `FunnelEvents`, next to the water events): `ramadanOfferShown = 'ramadan_offer_shown'`, `ramadanOfferDismissed = 'ramadan_offer_dismissed'`, `ramadanEnabled = 'ramadan_enabled'`, `ramadanDayMarked = 'ramadan_day_marked'`, `ramadanSummaryShared = 'ramadan_summary_shared'`
- Modify: 6 `lib/l10n/app_*.arb` + regenerate (`flutter gen-l10n`)
- Test: `test/features/ramadan/ramadan_controller_test.dart`, extend `test/features/water/` reminder tests

**Interfaces:**
- Consumes: Tasks 1–5
- Produces:
  - `final ramadanClockProvider = Provider<DateTime Function()>((_) => DateTime.now);`
  - `final ramadanSettingsStoreProvider`, `final fastingDaysLocalDataSourceProvider`
  - `class RamadanState { bool enabled; ({double lat, double lng, String label, int? plate})? location; int sahurOffsetMin; int? offerDismissedYear; }` via `ramadanSettingsProvider` (Notifier, same pattern as `waterSettingsProvider`)
  - `final activeRamadanProvider = Provider<RamadanPeriod?>` → non-null only when enabled, location set, and `currentRamadan(now) != null`
  - `final fastingTodayProvider = Provider<FastingTimes?>` and `fastingTomorrowProvider` (null when no location)
  - `final fastingDaysProvider = FutureProvider<Set<String>>` (days of `latestPeriod`)
  - `typedef RamadanCopy = ({String sahurTitle, String sahurBody, String iftarTitle, String iftarBody});` and `RamadanCopy ramadanCopy(AppLocalizations l10n, int offsetMin)` in `lib/features/ramadan/presentation/ramadan_actions.dart`
  - `class RamadanController { Future<void> enable({required double lat, required double lng, required String label, int? plate, required String source /* 'city' | 'gps' */, required RamadanCopy copy, required WaterReminderCopy waterCopy}); Future<void> disable(WaterReminderCopy waterCopy); Future<void> setLocation(...same fields..., RamadanCopy copy, WaterReminderCopy waterCopy); Future<void> setSahurOffset(int min, RamadanCopy copy); Future<void> dismissOffer(int year); Future<void> setFasted(DateTime day, bool fasted); Future<void> reschedule(RamadanCopy copy); Future<void> onResume(RamadanCopy copy, WaterReminderCopy waterCopy); }` via `ramadanControllerProvider`
  - Water side: in `WaterController.rescheduleReminders`, when `activeRamadanProvider` and both fasting providers are non-null use `ramadanWaterTimes(...)`, else `waterReminderTimes(...)`. Nothing else in the water controller changes.
- `.arb` keys (TR values; translate for en/ar/es/pt/zh):
  `ramadanOfferTitle` "Ramazan modu", `ramadanOfferBody` "Sahur ve iftar sayacı, iftar–sahur arası su hatırlatması.", `ramadanOfferCta` "Aç", `ramadanUntilIftar` "İftara {h} sa {m} dk", `ramadanUntilSahur` "Sahura {h} sa {m} dk", `ramadanImsakIftar` "İmsak {imsak} · İftar {iftar}", `ramadanFastingToday` "Bugün oruçluyum", `ramadanNotificationsOff` "Bildirimler kapalı — aç", `ramadanChooseLocation` "Konum seç", `ramadanUseMyLocation` "Konumumu kullan", `ramadanMyLocationLabel` "Konumum", `ramadanLocationFailed` "Konum alınamadı, listeden ilini seç.", `ramadanSearchCity` "İl ara", `ramadanTitle` "Ramazan", `ramadanDaysProgress` "{n}/{total} gün", `ramadanStreak` "{n} gün seri", `ramadanModeSwitch` "Ramazan modu", `ramadanSahurOffset` "Sahur hatırlatması", `ramadanMinutesBefore` "{min} dk önce", `ramadanShareSummary` "Ramazan özetimi paylaş", `ramadanShareFasted` "{n} gün oruç", `ramadanShareWater` "{liters} L su", `ramadanTimesDisclaimer` "Vakitler hesaplamadır; kendi imsakiyeni esas al.", `ramadanSahurTitle` "Sahur vakti yaklaşıyor", `ramadanSahurBody` "İmsaka {min} dk kaldı. Sahurda 2 bardak su içmeyi unutma.", `ramadanIftarTitle` "Hayırlı iftarlar", `ramadanIftarBody` "Orucunu bir bardak suyla aç."

- [ ] **Step 1: Write the failing tests** (ProviderContainer with in-memory db, mock prefs, mock `NotificationService`, fixed clocks for both `waterClockProvider` and `ramadanClockProvider`):
  - `enable` on 8 Feb 12:00 → `rescheduleRamadanNotifications` called with iftar 3010; water reminders rescheduled with Ramadan slots (first slot ≈ 18:53) when the water switch is on; tracks `ramadan_enabled` with `location_source`.
  - Water switch off + mode on → `cancelWaterReminders`, no water slots.
  - Enabled on 6 Feb (offer window) → `activeRamadanProvider` null, water uses `waterReminderTimes` (first slot 13:00 style), no Ramadan notifications scheduled (Review Focus 2).
  - `onResume` on 15 Mar with mode on → store `enabled == false`, `cancelRamadanNotifications` called, water rescheduled with normal times (Review Focus 3).
  - Mode on, location keys removed → `reschedule` schedules nothing and does not throw (Review Focus 4).
  - `disable` → cancels Ramadan ids and restores normal water times.
- [ ] **Step 2: Run** → FAIL.
- [ ] **Step 3: Implement.** Wrap `reschedule` in try/catch with `debugPrint('[Ramadan] ...')`, like water. `onResume` does the Eid auto-off first, then `reschedule`. `nextDays` = today + 6 days, times from `fastingTimes` with the stored coordinates.
- [ ] **Step 4: Run** `flutter test test/features/ramadan test/features/water` → PASS; `flutter analyze` clean.
- [ ] **Step 5: Commit** `feat(ramadan): add controller and switch water reminders to the iftar window`

### Task 7: Offer card, city picker, countdown card on the Meals tab

**Files:**
- Modify: `pubspec.yaml` (add `geolocator`), `android/app/src/main/AndroidManifest.xml` (`ACCESS_COARSE_LOCATION`), `ios/Runner/Info.plist` (`NSLocationWhenInUseUsageDescription`: "Sahur ve iftar vakitlerini bulunduğun yere göre hesaplamak için.")
- Create: `lib/features/ramadan/presentation/widgets/city_picker_sheet.dart`
- Create: `lib/features/ramadan/presentation/widgets/ramadan_offer_card.dart`
- Create: `lib/features/ramadan/presentation/widgets/ramadan_countdown_card.dart`
- Modify: `lib/features/meals/presentation/screens/meals_screen.dart:75` (offer card and countdown card above `WaterCard`)
- Test: `test/features/ramadan/ramadan_cards_test.dart` (+ a `pumpRamadanWidget` harness copied from `water_widget_harness.dart`, adding `ramadanClockProvider` and a `locationProvider` override)

**Interfaces:**
- Consumes: Task 6 providers and controller
- Produces:
  - `final currentPositionProvider = Provider<Future<({double lat, double lng})?> Function()>` — wraps `geolocator` (permission request + `getCurrentPosition(locationSettings: LocationSettings(accuracy: LocationAccuracy.low))`), returns null on denial or error; overridable in tests.
  - `Future<({double lat, double lng, String label, int? plate, String source})?> showCityPicker(BuildContext context)`
  - `RamadanOfferCard`, `RamadanCountdownCard` (both `ConsumerWidget`/`ConsumerStatefulWidget`, no constructor params)

- [ ] **Step 1: Write the failing widget tests**
  - Clock 5 Feb, mode off → offer card visible, tracks `ramadan_offer_shown` once; close → gone, and still gone after rebuild with the same year.
  - Clock 4 Feb → no offer card.
  - Offer CTA → picker → tap "Ankara" → mode enabled with plate 6.
  - Picker "Konumumu kullan" with position override returning null → snackbar `ramadanLocationFailed`, sheet still open.
  - Mode on, clock 8 Feb 12:00 (Ankara) → "İftara 6 sa 23 dk".
  - Clock 8 Feb 20:00 → "Sahura …" using 9 Feb imsak; clock 9 Feb 02:00 → "Sahura 4 sa 17 dk" using 9 Feb imsak 06:17 (Review Focus 1).
  - Clock 6 Feb, mode on → no countdown card (Review Focus 2).
  - Mode on, no location → card shows `ramadanChooseLocation` (Review Focus 4).
  - Tapping "Bugün oruçluyum" → datasource has today's key, tracks `ramadan_day_marked`.
- [ ] **Step 2: Run** → FAIL.
- [ ] **Step 3: Implement.** Countdown refreshes with `Timer.periodic(const Duration(minutes: 1))`, cancelled in `dispose`. Countdown target: before today's iftar → iftar; otherwise the next imsak strictly after `now` (today's if `now` is before it, else tomorrow's). Show `ramadanTimesDisclaimer` in small muted text. Styling: `cozyCardDecoration` with a tint distinct from water's `sky`.
- [ ] **Step 4: Run** → PASS; also run `test/features/meals` (it pumps `MealsScreen`).
- [ ] **Step 5: Commit** `feat(ramadan): add offer, city picker and countdown cards`

### Task 8: Ramadan screen, route, share card

**Files:**
- Create: `lib/features/ramadan/presentation/screens/ramadan_screen.dart`
- Create: `lib/features/ramadan/presentation/widgets/ramadan_share_card.dart`
- Modify: `lib/config/router/route_names.dart` (`static const String ramadan = 'ramadan';`), `lib/config/router/app_router.dart` (`/ramadan`, root navigator, same as `/water`)
- Modify: `lib/features/profile/presentation/screens/profile_screen.dart` (a "Ramazan" row, visible while `latestPeriod(now) != null` and before the next `offerPeriod` starts; with only 2027 in the table this means from 8 Feb 2027 on)
- Test: `test/features/ramadan/ramadan_screen_test.dart`

**Interfaces:**
- Consumes: Task 6 providers/controller, `ShareService.captureAndShare(context:, card:, logicalSize:, pixelRatio:, fileName:, caption:)`, `share_card_palette.dart`, `WaterLocalDataSource.getRange`
- Produces:
  - `int fastingStreak(Set<String> days, DateTime today)` (top-level in `ramadan_screen.dart` or a small domain file) — consecutive fasted days ending today, or yesterday if today is not marked.
  - `RamadanShareCard({required int fasted, required int total, required double liters})`

- [ ] **Step 1: Write the failing tests**
  - Grid shows 29 cells (keys `ramadan-day-1`…`ramadan-day-29`); on 10 Feb, cells 4+ are disabled; tapping cell 1 toggles it.
  - Header shows "2/29 gün" after marking 2 days.
  - `fastingStreak({'2027-02-08','2027-02-09'}, DateTime(2027,2,10))` = 2; with `'2027-02-10'` added = 3; `({'2027-02-08'}, DateTime(2027,2,10))` = 0.
  - Mode switch off → `disable` called; sahur offset chip 60 → `setSahurOffset(60, ...)`.
  - Share button calls `ShareService.captureAndShare` (mocked) with `fileName` `nutrilens-ramadan-2027.png`, tracks `ramadan_summary_shared`; liters = sum of `glasses × 200 ml` over the period's `water_logs`.
- [ ] **Step 2: Run** → FAIL.
- [ ] **Step 3: Implement.** Share card at 360×640 logical, pixel ratio 3.0; content: fasted days, liters, NutriLens logo (reuse the asset `meal_share_card.dart` uses).
- [ ] **Step 4: Run** → PASS.
- [ ] **Step 5: Commit** `feat(ramadan): add Ramadan screen and summary share card`

### Task 9: Ownership: guest migration, data deletion, sign-out

**Files:**
- Modify: `lib/core/session/guest_migration_service.dart` (`fastingDayCount` in the summary, included in `isEmpty`; reassign and delete next to `_waterDs` at lines 71, 105, 147)
- Modify: `lib/features/profile/data/services/user_data_deletion_service.dart` (`_db.fastingDays` next to `_db.waterLogs` at line 212; `cancelRamadanNotifications` callback next to `_cancelWaterReminders`; `RamadanSettingsStore.keys` next to `WaterSettingsStore.keys` at line 233) and its provider
- Modify: `lib/features/auth/presentation/providers/auth_provider.dart:130` (cancel Ramadan notifications on sign-out, same try/catch)
- Test: extend the existing tests for these three files

- [ ] **Step 1: Failing tests:** guest with 2 fasting days → summary not empty, migrate → rows belong to the new user; delete-my-data → `fasting_days` empty, Ramadan keys removed, Ramadan cancel called; sign-out → Ramadan cancel called.
- [ ] **Step 2: Run** → FAIL.
- [ ] **Step 3: Implement** by mirroring every water line.
- [ ] **Step 4: Run** `flutter test` (full suite) → PASS; `flutter analyze` clean.
- [ ] **Step 5: Commit** `feat(ramadan): include fasting data in migration and deletion`

### Task 10: Device verification and handoff

- [ ] **Step 1:** Debug build on the Android emulator, Turkish locale. Set the emulator clock to 5 Feb 2027 → offer card; enable with "Ankara"; screenshot.
- [ ] **Step 2:** Clock 8 Feb 2027 18:15 → countdown shows iftar 18:23; wait for the iftar notification to arrive; screenshot. Then clock 9 Feb 05:25 → sahur notification (offset 45 → 05:32 for 06:17 imsak) arrives.
- [ ] **Step 3:** "Konumumu kullan" with emulator location set to Berlin → label "Konumum", times plausible for Berlin.
- [ ] **Step 4:** Mark 3 days, share → the image renders correctly in the share sheet preview.
- [ ] **Step 5:** Clock 10 Mar 2027 → card gone, water reminders back to 09–21.
- [ ] **Step 6:** Before release (January 2027): compare Ankara, İstanbul and Van times for 8 Feb and 8 Mar with the published Diyanet imsakiye; any difference over 1 min blocks release.
- [ ] **Step 7:** Update the vault handoff (`wiki/05-ai-handoff.md`, overwrite "Son Oturum") and add a decisions-log entry; run `graphify update .`.
