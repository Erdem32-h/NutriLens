# Intermittent fasting mode — design

Date: 2026-09-28 · Status: approved in chat (scope questions), awaiting spec review

## Goal

A year-round, opt-in fasting timer: pick a protocol (16:8, 18:6, 20:4, OMAD),
start/end a fast with one tap, see a live countdown on the Meals tab, get one
notification when the target is reached, and get warned when saving a meal
mid-fast. History and stats are premium. Complements Ramadan mode (seasonal)
with a retention hook that works every day.

Success = start → end round trip works offline for guests and accounts,
survives app kill / reboot, guest → account migration and data deletion,
never overlaps Ramadan mode. Measured by `if_fast_started` / `if_fast_completed`
and day-7 retention of users with ≥1 completed fast.

## Decisions (from brainstorming)

| Topic | Decision |
|---|---|
| Core | Protocol + manual start/end + live countdown + target-reached notification |
| Protocols | 16:8, 18:6, 20:4, OMAD (23:1). No custom length in v1 |
| Ramadan | Separate feature folder. While Ramadan mode is on **and** inside Ramadan, IF entry points are hidden and start is blocked; an already-running fast keeps running |
| Price | Timer, card, notification, meal warning free (guests included). History list + streak + average duration premium |
| Meal link | Saving a meal during an active fast shows a warning dialog |
| Sync | Local only (Drift), like `fasting_days`. Cloud sync out of v1 |
| Out of v1 | Custom protocol, eating-window notification, home widget, weight link, charts |

## 1. Data

New Drift table `fasting_sessions` (schema **v6 → v7**), `lib/config/drift/tables/fasting_sessions_table.dart`:

| column | type | note |
|---|---|---|
| `id` | text PK | uuid |
| `userId` | text | `kGuestUserId` for guests |
| `startedAt` | datetime | |
| `targetMinutes` | int | from protocol at start (960 / 1080 / 1200 / 1380) |
| `endedAt` | datetime, nullable | null = active fast |

Invariant: at most one row with `endedAt == null` per user (enforced in the
datasource: `start` refuses when one exists). Active fast lives in the DB, not
prefs, so it survives kill/reboot and migrates with the account.

Migration step `if (from < 7 && to >= 7) m.createTable(fastingSessions)` +
schema dump + `SchemaVerifier` test, following the v6 pattern.

`lib/features/fasting/data/fasting_sessions_local_datasource.dart`:
`active(userId)`, `start(userId, startedAt, targetMinutes)`,
`end(id, endedAt)`, `recent(userId, limit)`, `reassignOwner(from, to)`
(guest active row dropped if the account already has an active one),
`deleteFor(userId)`, `countCompleted(userId)`.

Prefs (`IntermittentFastingSettingsStore`): `if_protocol` (default `16:8`).
Keys exposed for `UserDataDeletionService` like `RamadanSettingsStore.keys`.

## 2. Domain (`lib/features/fasting/domain/`)

- `enum FastingProtocol { p16_8, p18_6, p20_4, omad }` with `fastMinutes`,
  `label` (`16:8` …).
- `FastingSession` value class: `elapsed(now)`, `remaining(now)`,
  `progress(now)` (0..1, clamped), `reachedTarget(now)`, `isCompleted`
  (`endedAt - startedAt >= target`).
- `int streak(List<FastingSession> sessions, DateTime now)` — consecutive local
  days, ending today or yesterday, that have a completed fast (a fast counts on
  its `endedAt` day). Pure, unit-tested (DST, gaps, multiple fasts per day).
- `Duration? averageDuration(sessions)` over the last 30 completed.

## 3. State & controller

`lib/features/fasting/presentation/providers/fasting_provider.dart`

- `fastingClockProvider` (test seam, like `ramadanClockProvider`).
- `activeFastProvider` — `FutureProvider<FastingSession?>`.
- `fastingHistoryProvider` — last 30 sessions (read only when premium).
- `fastingProtocolProvider` — Notifier over the settings store.
- `fastingBlockedByRamadanProvider` — `ramadan.enabled && currentRamadan(now) != null`.
- `FastingController` — single write path:
  - `start(copy)`: guard blocked/active, request notification permission once
    (same try/catch as Ramadan), insert row, schedule target notification,
    track `if_fast_started {protocol}`.
  - `end({source})`: set `endedAt = now`, cancel notification, track
    `if_fast_ended {completed, minutes, source}` (`source`: `button` | `meal_save`).
  - `setProtocol(p)`: only when no active fast.
  - `onResume(copy)`: invalidate providers, re-arm the notification if the
    fast is active and target is in the future (covers reboot / permission change).

Countdown ticks via a 1 s `Stream.periodic` inside the card widget only, not
in providers.

## 4. Notifications

`NotificationService.scheduleFastingTarget(at, title, body)` /
`cancelFastingTarget()`: id **4000**, channel `fasting_reminder`
("Oruç Hatırlatma"). Exact when `canScheduleExact()`, else inexact — body
states the fast length ("16 saatlik orucunu tamamladın"), never a countdown, so
a late delivery stays true. Cancelled on end, logout
(`auth_provider`), data deletion. Hooked into `AppShellScreen` resume next to
`_ensureRamadanState`.

## 5. UI

- **Profile** → new settings row "Aralıklı Oruç" (always visible unless
  blocked by Ramadan) → `/fasting`.
- **`FastingScreen`** (`/fasting`): protocol chips (disabled during a fast),
  big ring progress + elapsed / remaining, Start / End button, "Son oruç"
  summary (free). Premium section: streak, average, last 30 list; for free
  users a blurred teaser with "Premium ile gör" → `/paywall`
  (`paywallShown {source: fasting_history}`).
- **Meals tab** `FastingCard` (between Ramadan cards and `WaterCard`):
  visible only while a fast is active — ring, remaining time, End button.
  After target reached: "Hedefe ulaştın 🎉 — orucu bitir".
- **End confirmation** when ending before target: "Hedefe X kaldı, yine de
  bitir?".
- **Meal warning** (`food_result_screen._saveMeal`, the only new-meal path):
  when a fast is active, dialog before saving —
  "Oruçtasın (14 sa 20 dk). Bu öğünü kaydetmek orucunu bitirir."
  Buttons: `Vazgeç` / `Orucu bitir ve kaydet`. Confirm ends the fast
  (`source: meal_save`) then saves. Editing an existing meal never warns.

## 6. Cross-cutting

- Guest migration: `GuestMigrationService` reassigns `fasting_sessions`; the
  prompt counts completed fasts together with fasting days.
- Data deletion: `deleteFor`, prefs keys, `cancelFastingTarget`.
- l10n: all strings in 6 ARB files (tr/en source, ar/es/pt/zh translated).
- Analytics: `if_fast_started`, `if_fast_ended`, `if_protocol_changed`,
  `if_history_paywall_tapped` in `FunnelEvents`.

## 7. Tests

- Domain: protocol minutes, progress/remaining clamps, `streak`, `averageDuration`.
- Datasource (in-memory Drift): single-active invariant, `reassignOwner`
  conflict, `deleteFor`.
- Migration v6 → v7 `SchemaVerifier`.
- Controller: start blocked during Ramadan, start twice refused, end cancels
  notification, `onResume` re-arms (fake `NotificationService`).
- Widget: card hidden without active fast; meal-save dialog shown only
  during a fast; premium section gated.
- Device check: start fast, kill app, reopen → timer continues; target
  notification fires (short debug protocol not shipped — use clock seam).

## Risks

- Exact-alarm denial → notification may be late; body wording covers it.
- Drift schema bump touches every install — covered by migration test.
- Scope creep: charts, custom protocol, eating-window reminders stay out.
