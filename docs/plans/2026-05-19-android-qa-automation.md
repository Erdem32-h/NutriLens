# Android QA Automation Plan

## Principle

Automate repeatable evidence, not the illusion of total coverage. Unit and widget
tests own deterministic boundaries; emulator smoke owns Android wiring, startup,
logs, screenshots, and focused performance snapshots; real-device sandbox tests
still own payment-store truth.

## Current entry points

- `flutter test` covers deterministic service, parser, DTO, widget, and provider behavior.
- `tools/qa/android_qa_matrix.json` defines the release QA suites and p0 scenarios.
- `scripts/android_qa_smoke.ps1` builds, installs, launches, and captures Android artifacts.
- `flutter test test/qa/android_qa_matrix_test.dart` guards the QA matrix itself.

## First release matrix

| Area | Automation | Notes |
| --- | --- | --- |
| Free scan limit | Emulator + account fixture/manual | Requires controlled auth and scan state. |
| Rewarded ad bonus | Widget regression + emulator/manual | Sheet behavior is covered for grant, cancel, and denial; AdMob delivery still needs test ad readiness. |
| Purchase premium | Real device sandbox | Store purchase cannot be fully trusted on generic emulator. |
| Restore purchase | Real device sandbox | Same store sandbox dependency. |
| Webhook delay | Unit regression | `localPremium` bypasses the scan RPC so RevenueCat can unlock before the Supabase webhook catches up. |
| Offline premium fallback | Unit regression + emulator network toggle | Unit covers local premium fallback; full launch behavior still needs a premium fixture account. |
| Startup/log smoke | PowerShell adb script | Captures launch, UI tree, screenshot, logs, crash buffer. |
| Performance smoke | PowerShell adb script | Adds `gfxinfo` and `meminfo` snapshots. |

## Commands

```powershell
flutter test test/qa/android_qa_matrix_test.dart
.\scripts\android_qa_smoke.ps1 -CapturePerformance
.\scripts\android_qa_smoke.ps1 -Serial emulator-5554 -BuildMode debug -CapturePerformance
.\scripts\android_qa_smoke.ps1 -BuildMode release -UninstallFirst -CapturePerformance
.\scripts\android_qa_smoke.ps1 -BuildMode release -NavigateTabs -CapturePerformance
```

`-NavigateTabs` requires an already-authenticated app session. Do not combine it
with `-UninstallFirst` unless the script is extended with a test-account login
step.

## Next increment

Add `integration_test/` flows for the two highest-value Android paths:

1. Cold launch to scanner/paywall/scan-limit surfaces with fakeable services.
2. Meal photo analysis save path with fixture AI response and local Drift assertion.
