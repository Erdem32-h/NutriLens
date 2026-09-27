# Ramadan mode — design

Date: 2026-09-27 · Status: approved in chat, awaiting spec review

## Goal

Acquisition hook for Ramadan 2027 (8 Feb – 8 Mar 2027): a free, opt-in mode
that shows a sahur/iftar countdown, sends sahur and iftar notifications, moves
water reminders into the iftar–sahur window, and lets the user mark fasted
days and share a Ramadan summary card. Pairs with the existing halal check as
a differentiator no competitor (Yazio, Yuka, other "NutriLens" apps) offers.

Success = shipped to both stores before 5 Feb 2027 (offer window opens), works
fully offline once a location is chosen, never touches the meal reminder, and
survives guest → account migration and account deletion. Measured by installs
and day-7 retention during Ramadan versus the preceding 4 weeks.

## Decisions (from brainstorming)

| Topic | Decision |
|---|---|
| Time source | Computed on device with `adhan_dart`, `CalculationMethod.turkiye` (Diyanet) |
| Location | User picks one of 81 Turkish provinces (bundled lat/lng); "Use my location" option on top for users abroad (one-shot, coarse GPS) |
| Scope v1 | Countdown + sahur/iftar notifications; iftar–sahur water plan; fasting calendar + share card |
| Out of v1 | Home screen widget, calculation-method picker |
| Activation | Offer card from 3 days before Ramadan + switch on the Ramadan screen; auto-off on the first day of Eid; never forced |
| Price | Free, guests included |
| Ramadan dates | Hard-coded Diyanet table; 2027 only (2028 not yet published) |

## 1. Ramadan calendar

`lib/features/ramadan/domain/ramadan_calendar.dart`

```dart
class RamadanPeriod {
  final DateTime firstDay; // local date, first fasting day
  final DateTime eidDay;   // local date, first day of Eid (mode turns off)
  RamadanPeriod(this.firstDay, this.eidDay);
  int get length => _utc(eidDay).difference(_utc(firstDay)).inDays;
}

// Diyanet dini günler takvimi 2027: Ramazan 8 Şubat, bayram 9 Mart.
final ramadanPeriods = [RamadanPeriod(DateTime(2027, 2, 8), DateTime(2027, 3, 9))];
```

Day arithmetic (`length`, `ramadanDayIndex`) goes through
`DateTime.utc(y, m, d)` so a DST night abroad never yields a 23 h "day".

Functions, all taking an explicit `now` for tests:

- `RamadanPeriod? currentRamadan(DateTime now)` — period with
  `firstDay <= today < eidDay`.
- `RamadanPeriod? offerPeriod(DateTime now)` — period with
  `firstDay - 3 days <= today < eidDay`.
- `int? ramadanDayIndex(DateTime now)` — 1-based day inside the current
  period, else null.
- `RamadanPeriod? latestPeriod(DateTime now)` — most recent period whose
  `firstDay <= today`; used to keep the calendar viewable after Eid.

Length is 29 for 2027, so every UI uses `period.length`, never 30.

Adding a year = one line in `ramadanPeriods`, shipped in that year's release.

## 2. Fasting times

`lib/features/ramadan/domain/fasting_times.dart`

```dart
typedef FastingTimes = ({DateTime imsak, DateTime iftar});

FastingTimes fastingTimes(DateTime date, double lat, double lng);
```

- Only file that imports `adhan_dart`.
- `imsak` = Fajr, `iftar` = Maghrib, with `CalculationMethod.turkiye`
  parameters. Returned converted to local time (`toLocal()`), which matches
  the notification layer's `tz.local` handling.
- Known limit: GPS users in countries using Umm al-Qura or other methods
  may see a few minutes of drift. A method picker is out of v1.

`lib/features/ramadan/domain/turkish_cities.dart`: const list of 81
`({int plate, String name, double lat, double lng})`, plate code as id,
sorted by name. Province names are proper nouns and are not localised.

## 3. Data

### Preferences (SharedPreferences) — `RamadanSettingsStore`

`lib/features/ramadan/data/ramadan_settings_store.dart`, same shape as
`WaterSettingsStore`.

| Key | Type | Meaning |
|---|---|---|
| `ramadan_enabled` | bool | Mode on |
| `ramadan_location_plate` | int? | Chosen province, null when GPS is used |
| `ramadan_location_lat` / `_lng` | double? | Coordinates in use (province or GPS) |
| `ramadan_location_label` | String? | Shown on the card ("Ankara" or "Konumum") |
| `ramadan_sahur_offset_min` | int | 30 / 45 / 60, default 45 |
| `ramadan_offer_dismissed_year` | int? | Year the offer card was dismissed |

Device-global, like water settings. Cleared by "delete my data" and account
deletion.

### Table `fasting_days` (Drift)

`lib/config/drift/tables/fasting_days_table.dart`

```dart
class FastingDays extends Table {
  TextColumn get userId => text()();
  TextColumn get day => text()(); // local yyyy-MM-dd
  @override
  Set<Column> get primaryKey => {userId, day};
}
```

A row means the user fasted that day; unchecking deletes the row. Guest rows
use `kGuestUserId`, exactly like `water_logs`.

Schema `5 → 6`: `onUpgrade` adds `if (from < 6) await m.createTable(fastingDays);`.
Migration test proves `water_logs` rows survive.

### Ownership

Follow `water_logs` in every path:

- `GuestMigrationService`: count guest fasting days alongside
  `waterDayCount` and reassign them to the new user id.
- `UserDataDeletionService` ("delete my data"), account deletion, sign-out:
  delete the user's `fasting_days` rows and clear `RamadanSettingsStore`,
  and cancel Ramadan notifications.

## 4. Scheduling

### Pure functions — `ramadan_schedule.dart`

```dart
List<DateTime> ramadanWaterTimes({
  required DateTime now,
  required FastingTimes today,
  required FastingTimes tomorrow,
  required DateTime? lastGlassAt,
  required int glassesToday,
  required int goal,
});
```

Per day: `iftar + 30 min`, then every 2 h while `<= 23:30` of that day. The
existing rules carry over unchanged: drop slots `<= now`, drop today's slots
inside `waterReminderGap` after the last glass, drop today's slots once the
goal is met. Tomorrow's slots are always included. Worst case (iftar 17:30)
is 4 slots/day → 8 total, inside the existing 14 water ids (2000–2013).

The "drink 2 glasses at sahur" nudge is part of the sahur notification body,
not a separate water slot.

```dart
List<({int id, DateTime at, RamadanNotificationKind kind})>
ramadanNotificationTimes({
  required DateTime now,
  required List<FastingTimes> nextDays, // today + 6
  required int sahurOffsetMin,
});
```

- Sahur: `imsak - sahurOffsetMin`, ids 3000–3006 by day offset.
- Iftar: `iftar`, ids 3010–3016 by day offset.
- Past times are skipped. Days on or after `eidDay` are excluded.

### Notification service

Add to `NotificationService`:

- `rescheduleRamadanNotifications(list, copy)` — cancels 3000–3006 and
  3010–3016, then schedules the list.
- `cancelRamadanNotifications()`.

Water keeps using `rescheduleWaterReminders`; only the list of times passed
in changes. Meal reminder id 1001 is never touched.

### Triggers

One `rescheduleRamadan()` in the Ramadan provider layer, called on:

- mode switched on/off, location changed, sahur offset changed;
- app resume, next to the existing `rescheduleReminders` call in
  `app_shell_screen.dart`;
- every water change (the water controller asks the Ramadan provider which
  time list to use: `ramadanWaterTimes` when the mode is on and
  `currentRamadan(now) != null`, else `waterReminderTimes`).

On resume, if the mode is on and `currentRamadan(now) == null` and
`now >= eidDay`, the mode switches itself off, Ramadan notifications are
cancelled, and normal water reminders are rescheduled.

Known limit: notifications are scheduled 7 days ahead; a user who does not
open the app for a week stops receiving them until the next open.

### Copy (6 locales)

- Sahur: title "Sahur vakti yaklaşıyor", body "İmsaka {min} dk kaldı.
  Sahurda 2 bardak su içmeyi unutma."
- Iftar: title "Hayırlı iftarlar", body "Orucunu bir bardak suyla aç."
- Ramadan water slots reuse the existing water reminder copy.

## 5. UI

### `RamadanOfferCard` (Meals tab, above `WaterCard`)

Shown when `offerPeriod(now) != null`, mode off, and
`offer_dismissed_year != period year`. Close button stores the year. The CTA
starts the enable flow.

### Enable flow

1. `CityPickerSheet`: "Use my location" row on top, then the 81 provinces
   with a search field. GPS: `geolocator` one-shot request with low
   accuracy. On permission denied or failure → stay on the sheet and show a
   snackbar asking to pick a province.
2. Notification permission via the existing `requestPermission()`, skipped
   when already granted. Denial still enables the mode.

### `RamadanCountdownCard` (Meals tab, above `WaterCard`, when mode on and inside Ramadan)

- Before iftar: "İftara 3 sa 12 dk", below it today's imsak and iftar times
  and the location label.
- After iftar: "Sahura 6 sa 40 dk", using tomorrow's imsak.
- "Bugün oruçluyum" checkbox bound to `fasting_days`.
- When notification permission is missing: a "Bildirimler kapalı — aç"
  link.
- Refreshes with a `Timer.periodic` of 1 minute, cancelled on dispose.
- Tap opens `RamadanScreen`.

### `RamadanScreen` (`/ramadan`, root navigator like `/water`)

- Grid of `period.length` days; fasted days filled, today outlined, future
  days disabled. Tapping a past or current day toggles it.
- Header: "{n}/{length} gün" and current streak (consecutive fasted days
  ending today or yesterday).
- Settings: mode switch, location row (opens `CityPickerSheet`), sahur
  offset choice (30/45/60).
- "Ramazan özetimi paylaş" → `RamadanShareCard`, rendered and shared with
  the same mechanism as `meal_share_card.dart`, colours from
  `share_card_palette.dart`. Content: fasted days, total water in litres
  over the period (from `water_logs`), NutriLens logo.
- After Eid the screen stays reachable from the profile until the next
  period's offer window, showing `latestPeriod`.

### Analytics

Add to `AnalyticsEvent`: `ramadan_offer_shown`, `ramadan_offer_dismissed`,
`ramadan_enabled` (param: `location_source` = `city` | `gps`),
`ramadan_day_marked`, `ramadan_summary_shared`.

## File layout

```
lib/features/ramadan/
  domain/ramadan_calendar.dart
  domain/fasting_times.dart
  domain/ramadan_schedule.dart
  domain/turkish_cities.dart
  data/ramadan_settings_store.dart
  data/fasting_days_local_datasource.dart
  presentation/providers/ramadan_provider.dart
  presentation/widgets/ramadan_offer_card.dart
  presentation/widgets/ramadan_countdown_card.dart
  presentation/widgets/city_picker_sheet.dart
  presentation/widgets/ramadan_share_card.dart
  presentation/screens/ramadan_screen.dart
lib/config/drift/tables/fasting_days_table.dart
```

Touched: `app_database.dart` (table + v6), `notification_service.dart`,
water provider (time list selection), `app_shell_screen.dart` (resume),
`meals_screen.dart` (cards), `app_router.dart` + `route_names.dart`,
`guest_migration_service.dart`, `user_data_deletion_service.dart`,
`analytics_event.dart`, 6 `.arb` files, `pubspec.yaml` (`adhan_dart`,
`geolocator`), `AndroidManifest.xml` (`ACCESS_COARSE_LOCATION`),
`ios/Runner/Info.plist` (`NSLocationWhenInUseUsageDescription`).

## Testing

Domain (pure):

- `fastingTimes`: Ankara, 8 Feb 2027 matches the Diyanet imsakiye within
  ±2 min for imsak and iftar.
- `currentRamadan` / `offerPeriod` / `ramadanDayIndex`: 4 Feb (none), 5 Feb
  (offer only), 8 Feb (day 1), 8 Mar (day 29), 9 Mar (none, Eid).
- `ramadanWaterTimes`: 23:30 cap, 2 h quiet gap after a glass, goal met
  drops today's slots, tomorrow always present, never more than 14.
- `ramadanNotificationTimes`: ids stable per day offset, past times
  skipped, nothing on or after Eid.

Widget:

- Offer card appears inside the window, disappears after dismiss for the
  same year.
- Countdown card says "İftara" before iftar and "Sahura" after.
- Checking "Bugün oruçluyum" fills today on `RamadanScreen`.
- GPS denied → snackbar, province list still usable.

Migration: v5 database with `water_logs` rows upgrades to v6, rows intact,
`fasting_days` empty.

Device: emulator clock set to 7 Feb 2027 evening and 8 Feb 2027; sahur and
iftar notifications actually fire, Turkish UI checked, share card image
checked.

## Out of scope

Home screen widget, calculation-method picker, Ramadan dates for 2028+,
syncing fasting days to Supabase, prayer times other than imsak and iftar,
premium gating.
