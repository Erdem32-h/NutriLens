# Intermittent Fasting Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Year-round opt-in fasting timer (16:8 / 18:6 / 20:4 / OMAD) with start/end, Meals-tab countdown card, target notification, meal-save warning, premium history/stats.

**Architecture:** New `lib/features/fasting/` folder mirroring `lib/features/ramadan/`. Sessions (including the active one, `endedAt == null`) live in a new Drift table `fasting_sessions` (schema v7); the chosen protocol lives in SharedPreferences. One `FastingController` is the only write path (DB → invalidate → notification → analytics).

**Tech Stack:** Flutter, Riverpod 3, Drift (+ `drift_dev` SchemaVerifier), flutter_local_notifications, GoRouter, ARB l10n (6 locales).

**Spec:** `docs/superpowers/specs/2026-09-28-intermittent-fasting-design.md`

## Global Constraints

- Protocol fast lengths: 16:8 = 960 min, 18:6 = 1080, 20:4 = 1200, OMAD = 1380. Default `16:8`.
- Notification id **4000**, channel id `fasting_reminder`, channel name `Oruç Hatırlatma`. Exact only if `canScheduleExact()`; body states the fast length, never a countdown.
- At most one active (`endedAt == null`) session per user.
- Blocked (start refused, entry points hidden) iff `ramadanSettings.enabled && currentRamadan(now) != null`. A running fast is never force-ended.
- Guests use `kGuestUserId`; everything works offline; no cloud sync.
- Free: timer, card, notification, meal warning, last fast summary. Premium (`isPremiumProvider`): streak, average, last-30 list.
- Every user-facing string in all 6 ARBs (`lib/l10n/app_{tr,en,ar,es,pt,zh}.arb`), then `flutter gen-l10n`.
- Analytics names: `if_fast_started {protocol}`, `if_fast_ended {completed, minutes, source}` (`source` ∈ `button`|`meal_save`), `if_protocol_changed {protocol}`, `if_history_paywall_tapped`.
- Notification failures never fail a write (try/catch + `debugPrint('[Fasting] …')`, like `RamadanController`).
- Test names Turkish-ASCII like existing tests is fine; follow neighbour files.

## Review Focus

1. Fast started before midnight / across DST — elapsed must use `DateTime` difference on absolute instants, streak buckets by **local** `endedAt` day via `DateTime.utc(y,m,d)` arithmetic. → Task 1 tests `streak_dst_gecesi_kopmaz`, `gece_yarisini_gecen_oruc_bitis_gunune_sayilir`.
2. App killed / device rebooted mid-fast — timer resumes from DB, notification re-armed on resume if target still in future. → Task 4 test `onResume_aktif_orucun_bildirimini_yeniden_kurar`.
3. Guest with an active fast signs into an account that also has one — account's active row wins, guest's is ended at migration time (kept as history, not deleted). → Task 2 test `reassignOwner_iki_aktif_varsa_hesabinki_kalir`.
4. Ending before target — confirmation dialog; ending counts `completed: false`. Ending after target never asks. → Task 6 widget test.
5. Protocol change during an active fast — refused (chips disabled; controller no-op). → Task 4 test `setProtocol_aktif_oruc_varken_degismez`.

---

### Task 1: Domain — protocol, session, stats

**Files:**
- Create: `lib/features/fasting/domain/fasting_protocol.dart`, `lib/features/fasting/domain/fasting_session.dart`, `lib/features/fasting/domain/fasting_stats.dart`
- Test: `test/features/fasting/fasting_domain_test.dart`

**Interfaces:**
- Produces:
  - `enum FastingProtocol { p16_8, p18_6, p20_4, omad }` with `int get fastMinutes`, `String get label` (`'16:8'`, `'18:6'`, `'20:4'`, `'OMAD'`), `static FastingProtocol fromLabel(String?)` (unknown/null → `p16_8`).
  - `class FastingSession { String id; String userId; DateTime startedAt; int targetMinutes; DateTime? endedAt; }` with `bool get isActive`, `Duration elapsed(DateTime now)` (uses `endedAt ?? now`), `Duration remaining(DateTime now)` (≥ 0), `double progress(DateTime now)` (clamped 0..1), `bool reachedTarget(DateTime now)`, `bool get isCompleted` (ended && elapsed ≥ target).
  - `int fastingStreak(List<FastingSession> sessions, DateTime now)`, `Duration? averageFastDuration(List<FastingSession> sessions)` (last 30 **completed**; null if none).

- [ ] **Step 1: Write failing tests** — cases: protocol minutes 960/1080/1200/1380; `fromLabel('x') == p16_8`; `progress` clamps at 1.0 after target and 0 at start; `remaining` never negative; `isCompleted` false for ended-short and for active; streak = 3 for completed fasts ending today, yesterday, day-before; streak = 0 when last completed ended 2 days ago; streak counts yesterday-ended run when today has none; two fasts same day count once; `gece_yarisini_gecen_oruc_bitis_gunune_sayilir` (start 20:00 D, end 12:00 D+1 → counts D+1); `streak_dst_gecesi_kopmaz` (fasts ending 2026-03-28, 03-29, 03-30 in a DST-shift week → 3); incomplete fasts break nothing and count nothing; average of 960 and 1080 min = 1020 min.
- [ ] **Step 2:** `flutter test test/features/fasting/fasting_domain_test.dart` → FAIL (missing files).
- [ ] **Step 3:** Implement. Streak: set of local-day keys `DateTime.utc(e.year,e.month,e.day)` from completed sessions; walk back from today (or yesterday if today absent) by `Duration(days: 1)` on UTC dates.
- [ ] **Step 4:** Re-run → PASS.
- [ ] **Step 5:** Commit `feat(fasting): add protocol, session and streak domain`.

### Task 2: Drift table, v7 migration, datasource

**Files:**
- Create: `lib/config/drift/tables/fasting_sessions_table.dart`, `lib/features/fasting/data/fasting_sessions_local_datasource.dart`, `test/config/drift/migration_v7_test.dart`, `test/features/fasting/fasting_sessions_local_datasource_test.dart`
- Modify: `lib/config/drift/app_database.dart` (register table, `schemaVersion => 7`, step `if (from < 7 && to >= 7) await m.createTable(fastingSessions);`), `test/config/drift/migration_v6_test.dart` (its `schemaVersion == 6` assertion moves to the v7 test; keep its v5→v6 group)
- Generated: `drift_schemas/drift_schema_v7.json`, `test/config/drift/generated_migrations/schema_v7.dart` + `schema.dart`

**Interfaces:**
- Consumes: `FastingSession` (Task 1).
- Produces: `abstract interface class FastingSessionsLocalDataSource` + `FastingSessionsLocalDataSourceImpl(AppDatabase)`:
  - `Future<FastingSession?> active(String userId)`
  - `Future<FastingSession> start(String userId, {required DateTime startedAt, required int targetMinutes})` — throws `StateError` if an active one exists; id via `Uuid().v4()`.
  - `Future<void> end(String id, DateTime endedAt)`
  - `Future<List<FastingSession>> recent(String userId, {int limit = 30})` — ended only, newest `endedAt` first.
  - `Future<int> countCompleted(String userId)`
  - `Future<void> reassignOwner({required String fromUserId, required String toUserId})` — transaction; if both have an active row, guest's active row gets `endedAt = now` before moving.
  - `Future<void> deleteFor(String userId)`
- Table columns per spec §1: `id` text PK, `userId` text, `startedAt` dateTime, `targetMinutes` int, `endedAt` dateTime nullable.

- [ ] **Step 1: Write failing tests** — migration: `sema surumu 7`, v6→v7 `migrateAndValidate` passes, v6 `fasting_days` row survives and `fasting_sessions` empty+writable (copy v6 test shape). Datasource (in-memory `AppDatabase.forTesting(NativeDatabase.memory())`): start then `active` returns it; second `start` throws `StateError`; `end` → `active` null and `recent` has it; `recent` excludes active and is newest first; `countCompleted` ignores short fasts; `reassignOwner_iki_aktif_varsa_hesabinki_kalir`; guest rows gone after reassign; `deleteFor` only touches that user.
- [ ] **Step 2:** Run both test files → FAIL.
- [ ] **Step 3:** Add table + migration, run `dart run build_runner build --delete-conflicting-outputs`, then `dart run drift_dev schema dump lib/config/drift/app_database.dart drift_schemas/` and `dart run drift_dev schema generate drift_schemas/ test/config/drift/generated_migrations/`. Implement datasource.
- [ ] **Step 4:** `flutter test test/config/drift test/features/fasting` → PASS.
- [ ] **Step 5:** Commit `feat(fasting): add fasting_sessions table (schema v7) and datasource`.

### Task 3: Notifications

**Files:**
- Modify: `lib/core/services/notification_service.dart`
- Test: extend the existing notification service test in `test/core/services/` (same fake plugin it uses).

**Interfaces:**
- Produces: `Future<void> scheduleFastingTarget({required DateTime at, required String title, required String body})` (cancels id 4000 first; skips if `at` is past; exact vs inexact like Ramadan), `Future<void> cancelFastingTarget()`.

- [ ] **Step 1:** Tests: schedules id 4000 on channel `fasting_reminder`; past `at` schedules nothing; cancel removes 4000.
- [ ] **Step 2:** Run → FAIL. **Step 3:** Implement. **Step 4:** Run → PASS.
- [ ] **Step 5:** Commit `feat(fasting): schedule target-reached notification`.

### Task 4: Settings store, providers, controller, cross-cutting hooks

**Files:**
- Create: `lib/features/fasting/data/fasting_settings_store.dart`, `lib/features/fasting/presentation/providers/fasting_provider.dart`, `lib/features/fasting/presentation/fasting_actions.dart`
- Modify: `lib/core/analytics/analytics_event.dart` (4 events), `lib/features/app_shell/app_shell_screen.dart` (call `fastingControllerProvider.onResume` beside `_ensureRamadanState`), `lib/features/auth/presentation/providers/auth_provider.dart` (cancel on logout, same try/catch), `lib/features/profile/data/services/user_data_deletion_service.dart` + its provider (delete `fastingSessions` rows, `FastingSettingsStore.keys`, optional `cancelFastingNotifications` callback), `lib/core/session/guest_migration_service.dart` (+ `completedFastCount` in summary, `reassignOwner`, guest `deleteFor`), `lib/features/auth/presentation/widgets/guest_migration_prompt_sheet.dart` (show count via new plural ARB key `completedFastCountUnit`)
- Test: `test/features/fasting/fasting_controller_test.dart`, `test/features/fasting/fasting_settings_store_test.dart`, extend existing guest-migration and deletion tests.

**Interfaces:**
- Consumes: Tasks 1–3.
- Produces:
  - `FastingSettingsStore(SharedPreferences)`: `FastingProtocol get protocol`, `Future<void> setProtocol(FastingProtocol)`, `static const keys = ['if_protocol']`.
  - Providers: `fastingSettingsStoreProvider`, `fastingSessionsLocalDataSourceProvider`, `fastingClockProvider` (`Provider<DateTime Function()>`), `fastingProtocolProvider` (`NotifierProvider<FastingProtocolNotifier, FastingProtocol>`), `activeFastProvider` (`FutureProvider<FastingSession?>`), `fastingHistoryProvider` (`FutureProvider<List<FastingSession>>`, `recent(limit: 30)`), `fastingBlockedByRamadanProvider` (`Provider<bool>`), `fastingControllerProvider`.
  - `typedef FastingCopy = ({String title, String Function(int hours) body});` `FastingCopy fastingCopy(AppLocalizations l10n)` in `fasting_actions.dart`.
  - `FastingController`: `Future<bool> start(FastingCopy copy)` (false when blocked / active exists / no user), `Future<void> end({required String source})`, `Future<void> setProtocol(FastingProtocol p)`, `Future<void> onResume(FastingCopy copy)`.

- [ ] **Step 1:** Controller tests with `ProviderContainer` overrides (in-memory DB, fake `NotificationService` as in `test/features/ramadan/ramadan_controller_test.dart`, fixed clock): start inserts + schedules at `startedAt + target`; `start_ramazanda_reddedilir` (Ramadan enabled, clock 2027-02-10) returns false, no row; start twice → second false; `end` cancels 4000 and tracks `completed` correctly; `setProtocol_aktif_oruc_varken_degismez`; `onResume_aktif_orucun_bildirimini_yeniden_kurar`; `onResume` with target passed schedules nothing. Store test: default `p16_8`, round-trip. Guest migration: count + reassign. Deletion: rows + key removed.
- [ ] **Step 2:** Run → FAIL. **Step 3:** Implement. **Step 4:** `flutter test test/features/fasting test/core test/features/profile test/features/auth` → PASS.
- [ ] **Step 5:** Commit `feat(fasting): add controller and wire migration, deletion, logout, resume`.

### Task 5: l10n

**Files:** Modify the 6 ARBs; regenerate `lib/l10n/generated/`.

Keys (tr source text; en mirrors; ar/es/pt/zh translated): `fastingTitle` "Aralıklı Oruç", `fastingSubtitle` "16:8 ve diğer protokollerle oruç sayacı", `fastingStart` "Orucu başlat", `fastingEnd` "Orucu bitir", `fastingElapsed` "Geçen: {time}", `fastingRemaining` "Kalan: {time}", `fastingGoalReached` "Hedefe ulaştın 🎉", `fastingEndEarlyTitle` "Orucu erken bitir?", `fastingEndEarlyBody` "Hedefe {time} kaldı. Yine de bitirilsin mi?", `fastingNotificationTitle` "Oruç tamamlandı", `fastingNotificationBody` "{hours} saatlik orucunu tamamladın.", `fastingBlockedByRamadan` "Ramazan modu açıkken aralıklı oruç duraklatılır.", `fastingLastFast` "Son oruç: {time}", `fastingStreak` "{count} gün seri", `fastingAverage` "Ortalama: {time}", `fastingHistory` "Son oruçlar", `fastingPremiumTeaser` "Seri ve geçmiş Premium ile", `fastingMealWarningTitle` "Oruçtasın", `fastingMealWarningBody` "{time} oldu. Bu öğünü kaydetmek orucunu bitirir.", `fastingMealWarningConfirm` "Orucu bitir ve kaydet", `completedFastCountUnit` plural "{count} oruç". Reuse existing cancel string for "Vazgeç".

- [ ] **Step 1:** Add keys, `flutter gen-l10n`, `flutter analyze lib/l10n` → no issues. Existing l10n key-parity test (if present under `test/`) passes.
- [ ] **Step 2:** Commit `feat(fasting): add fasting strings in 6 locales`.

(Task 5 may run before Task 4 if Task 4 needs `fastingCopy`; order is 1 → 2 → 3 → 5 → 4 → 6 → 7.)

### Task 6: Screen, card, route, profile row

**Files:**
- Create: `lib/features/fasting/presentation/screens/fasting_screen.dart`, `lib/features/fasting/presentation/widgets/fasting_card.dart`, `lib/features/fasting/presentation/widgets/fasting_ring.dart` (shared progress ring)
- Modify: `lib/config/router/route_names.dart` (`fasting`), `lib/config/router/app_router.dart` (`/fasting`), `lib/features/meals/presentation/screens/meals_screen.dart` (`FastingCard` sliver after `RamadanCountdownCard`, before `WaterCard`), `lib/features/profile/presentation/screens/profile_screen.dart` (row after Ramadan block, hidden when blocked, icon `Icons.timer_outlined`, tint `cozy.mint` or nearest existing)
- Test: `test/features/fasting/fasting_ui_test.dart` (harness like `ramadan_widget_harness.dart`)

- Screen: protocol `ChoiceChip`s (disabled while active), `FastingRing`, elapsed/remaining, Start/End button, last-fast line (free). Premium section: streak/average/list when `isPremiumProvider`; else blurred teaser → `context.push('/paywall')` + `if_history_paywall_tapped` + `paywallShown {source: fasting_history}`. Blocked → info text, Start disabled.
- Card: renders `SizedBox.shrink()` unless active fast; 1 s `Stream.periodic` only inside widget; after target shows `fastingGoalReached`.
- End before target → `AlertDialog` (`fastingEndEarlyTitle/Body`); after target ends directly.

- [ ] **Step 1:** Widget tests: card hidden with no active fast; card shows remaining with active fast; end-early dialog shown before target, not after; free user sees teaser, premium sees streak; blocked shows info and disabled Start; profile row hidden when blocked.
- [ ] **Step 2:** Run → FAIL. **Step 3:** Implement. **Step 4:** Run → PASS.
- [ ] **Step 5:** Commit `feat(fasting): add fasting screen, meals card and profile entry`.

### Task 7: Meal-save warning + full verification

**Files:**
- Modify: `lib/features/scanner/presentation/screens/food_result_screen.dart` (`_saveMeal`, before `setState(() => _saving = true)`)
- Test: extend the existing food result screen test (or `test/features/fasting/fasting_meal_warning_test.dart`)

- Behaviour: if `activeFastProvider` has a session → dialog `fastingMealWarningTitle/Body/Confirm` + cancel. Cancel → return without saving. Confirm → `fastingController.end(source: 'meal_save')` then continue normal save. No fast → no dialog. `meal_edit_screen` untouched.

- [ ] **Step 1:** Tests: no dialog without fast; cancel keeps fast and saves nothing; confirm ends fast (`completed` per elapsed) and saves meal.
- [ ] **Step 2:** Run → FAIL. **Step 3:** Implement. **Step 4:** Run → PASS.
- [ ] **Step 5:** `flutter analyze` → No issues; `flutter test` → all pass (baseline 849 + new).
- [ ] **Step 6:** Device check on emulator: start 16:8, kill app, reopen → timer continues; meal-save dialog appears; screenshots.
- [ ] **Step 7:** Commit `feat(fasting): warn before saving a meal during a fast`; `graphify update .`; update vault handoff.
