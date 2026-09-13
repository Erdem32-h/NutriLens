# Water intake counter + reminder — design

Date: 2026-09-13 · Status: approved in chat, awaiting spec review

## Goal

Give every user (guests included, free) a daily water counter with a goal, a
7-day history, and optional reminders every two hours. Secondary aim: a reason
to open the app several times a day, which multiplies the moments where the
registration CTA can appear. Success = feature works fully offline, survives
guest → account migration and account deletion, and never disturbs the
existing meal reminder.

## Decisions (from brainstorming)

| Topic | Decision |
|---|---|
| History | Per-day history kept locally (Drift) |
| Unit | Glasses, 1 glass = 200 ml |
| Default goal | 10 glasses (2 L); with profile weight: `round(weightKg × 35 / 200)`, clamped 6–16 |
| Manual goal | Stepper, 1–20 glasses |
| Reminders | Fixed slots 09–21 every 2 h, skip slots within 2 h of last glass, stop when goal met |
| Placement | Card on Meals tab under the daily calorie card; tap opens a water screen |
| Access | Free for everyone, guests included |

## 1. Data

### Table `water_logs` (Drift)

| Column | Type | Notes |
|---|---|---|
| `userId` | text | `kGuestUserId` for guests |
| `day` | text | local date `yyyy-MM-dd` |
| `glasses` | int | never negative |
| `goalGlasses` | int | goal snapshot for that day |
| `lastGlassAt` | dateTime, nullable | set only when a glass is added |

Primary key `(userId, day)`.

- `goalGlasses` is snapshotted so later goal changes do not rewrite whether a
  past day was met. The snapshot is written when the row is created and
  refreshed whenever the goal changes on that same day.
- `schemaVersion` 4 → 5; `onUpgrade`: `if (from < 5 && to >= 5) await m.createTable(waterLogs);`
  (`to` guard keeps SchemaVerifier's v3→v4 replay valid).
  No `addColumn` targets this table, so the createTable trap does not apply.
  Generate `drift_schemas/drift_schema_v5.json` and the matching
  `test/config/drift/generated_migrations/schema_v5.dart`.

### Ownership

- `GuestMigrationService`: re-key guest `water_logs` rows to the new user id.
  On a `(userId, day)` conflict the account's existing row wins (same rule as
  `user_metrics`), guest row is deleted so it cannot leak to a later guest.
  `GuestDataSummary.isEmpty` must account for water rows.
- `UserDataDeletionService.deleteLocalUserData`: delete `water_logs` rows for
  the user inside the existing transaction.

### Preferences (SharedPreferences, device-global)

- `water_goal_glasses` (int, absent → derived from weight or 10)
- `water_reminder_enabled` (bool, default false)
- `water_reminder_prompt_shown` (bool, one-shot discovery snackbar)

Cleared together with health filter keys in `_clearLocalProfilePreferences`
(same "only if current user" guard).

### Rules

- Add glass: upsert today's row, `glasses + 1`, `lastGlassAt = now`.
- Remove glass: `max(glasses − 1, 0)`; `lastGlassAt` unchanged.
- Day key always from local `DateTime.now()`.

## 2. Reminder scheduling

### Pure function

`List<DateTime> waterReminderTimes({now, lastGlassAt, glassesToday, goal})`
in `lib/features/water/domain/water_reminder_schedule.dart`:

- Slots: 09, 11, 13, 15, 17, 19, 21 local.
- Today: slots strictly after `now`; none if `glassesToday >= goal`; drop a
  slot `s` when `lastGlassAt` is today and `s < lastGlassAt + 2h`.
- Tomorrow: all 7 slots.
- Max 14 results. Returned as wall-clock times; the service converts them with
  `tz.local`, so DST days keep 09:00 meaning 09:00.

### Notification service

`NotificationService.rescheduleWaterReminders({times, title, body})`:

- Cancels ids 2000–2013, skips any time no longer in the future, and arms the
  rest with contiguous ids from 2000 (max 14) — never 1001.
- Arms one-shot `zonedSchedule` per time, `AndroidScheduleMode.inexactAllowWhileIdle`,
  channel `water_reminder`.
- `cancelWaterReminders()` for disabled / signed-out / deleted.
- `requestPermission()` changes to return `Future<bool>` (granted). Android:
  `requestNotificationsPermission()` result; iOS: `requestPermissions(...)` result.
  Existing caller ignores the value.

### Triggers (all go through one `rescheduleWater()` in the water provider layer)

- App launch (`AppShellScreen`, next to the meal reminder re-arm).
- Glass added / removed, goal changed, reminder toggled.
- Reminder disabled or `effectiveUserId == null` → cancel.
- Account deletion → cancel.

### Permission and discovery

- Turning the switch on requests permission; denied → switch stays off,
  snackbar explains.
- First-ever +1 tap: one-shot snackbar "2 saatte bir hatırlatayım mı?" with
  action "Aç" that runs the same enable flow.

### Copy (6 locales)

Title "Su içme zamanı", body "Bir bardak su iç, bugünkü hedefine yaklaş."
Static — counts would go stale in pre-scheduled notifications.

### Known limit

If the app is not opened for two consecutive days, reminders stop after
tomorrow's slots and resume on next launch. Same limit as the meal reminder.

## 3. UI

### `WaterCard` (Meals tab, below `_DailyTargetSummary`)

- "💧 4 / 10 bardak", linear progress.
- Large "+1 bardak" button, small "−" icon button (disabled at 0).
- Goal met: completed colour + "Günlük hedefe ulaştın".
- Tap → `/water`.

### `WaterScreen` (`/water`, root navigator like `/meal-detail`)

- Today's counter, large, with + / −.
- Last 7 days bar chart, plain Flutter widgets (no new package); met days full
  colour, others muted; weekday labels.
- Goal row: "10 bardak (2 L)" with − / + (1–20); "Kiloma göre ayarla" when
  metrics exist.
- Reminder switch, subtitle "09:00–21:00 arası, 2 saatte bir".
- Semantics labels on buttons, ≥ 48 dp touch targets, RTL-safe layout.

### Analytics

`FunnelEvents.waterGlassAdded = 'water_glass_added'`,
`FunnelEvents.waterReminderEnabled = 'water_reminder_enabled'`. No properties
beyond what existing events carry.

## File layout

New:

- `lib/config/drift/tables/water_logs_table.dart`
- `lib/features/water/data/datasources/water_local_datasource.dart`
- `lib/features/water/domain/water_goal.dart`
- `lib/features/water/domain/water_reminder_schedule.dart`
- `lib/features/water/presentation/providers/water_provider.dart`
- `lib/features/water/presentation/widgets/water_card.dart`
- `lib/features/water/presentation/screens/water_screen.dart`

Changed: `app_database.dart`, `notification_service.dart`,
`app_shell_screen.dart`, `meals_screen.dart`, router + `route_names.dart`,
`guest_migration_service.dart`, `user_data_deletion_service.dart`,
`analytics_event.dart`, 6 ARB files.

## Testing

- `water_goal_test`: with/without weight, clamps at 6 and 16, 200 ml rounding.
- `water_reminder_schedule_test`: morning with no glass; glass at 10:30 skips
  11:00; goal met → only tomorrow; after 21:00 → only tomorrow; near midnight;
  DST transition day.
- `water_local_datasource_test` (in-memory Drift): no negatives, user isolation,
  goal snapshot, reassign owner with conflict.
- Migration: `SchemaVerifier` v4 → v5; existing v1 hand-rolled path still
  reaches v5.
- Guest migration + deletion tests extended with `water_logs`.
- Widget: card +1 / −1 / goal-met; screen switch stays off when permission denied.
- Manual: emulator/device screenshot of card and screen (none attached on
  2026-09-13 — owner verifies on device).

## Out of scope

Cloud sync, custom glass sizes, custom reminder windows, notification actions
("+1 from notification"), streaks.
