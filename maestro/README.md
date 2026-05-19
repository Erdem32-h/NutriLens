# NutriLens Maestro E2E flows

Black-box UI tests that run on a real (or emulated) device against an
installed APK/IPA. Maestro is the right tool because it:

- Drives the app from outside (no instrumentation hooks needed)
- Reads `text:` / `id:` / `index:` selectors
- Has built-in retries + screenshots on failure
- Runs in CI headless

## Local run

```bash
# 1. Install Maestro CLI once
#    Windows (recommended): scoop install maestro
#    macOS:  curl -fsSL "https://get.maestro.mobile.dev" | bash

# 2. Start an Android emulator and install a debug build
flutter run --debug    # leave it running OR install once, then close `flutter run`

# 3. Run a flow
maestro test maestro/flows/00-launch.yaml

# 4. Run the whole suite (sequential, ~3-5 min)
maestro test maestro/flows
```

## Flow naming

`NN-<name>.yaml` — numeric prefix controls execution order when the
whole folder is invoked. Keep dependencies linear (login flow before
anything that needs auth).

## What's covered

| Flow | Coverage |
|---|---|
| 00-launch | Cold launch reaches Meals tab without crash |
| 10-navigation | Bottom-nav tabs all open without crashing |
| 20-paywall-visibility | Paywall renders Privacy + Terms + price; doesn't actually purchase |
| 30-profile-data-wipe | "Tüm Verilerimi Sil" → confirm → toast |

## What's intentionally NOT covered

| Out of scope | Why |
|---|---|
| Barcode camera scan | Requires printed barcode in front of emulator camera, flaky |
| Meal photo AI analysis | Costs real Anthropic API calls, slow + non-deterministic |
| Real subscription purchase | Sandbox-only on real devices, not worth automation cost |
| Sign-up + email verification | Needs mailbox poll; we pre-seed test accounts instead |

## CI (Codemagic)

A `Maestro smoke` workflow in `codemagic.yaml` boots an emulator,
installs the debug APK, and runs the flows. See the `android-maestro`
workflow definition. The flows fail fast and upload screenshots from
`~/.maestro/tests/<run>/` as build artifacts.
