# NutriLens iOS Home Widget

WidgetKit extension that mirrors the in-app "Bugün" snapshot
(today's kcal + meal count + Tara CTA) to the iOS home screen and
lock-screen widget gallery.

## How the build wires it up

Because the project owner ships iOS via Codemagic (no Xcode locally),
the widget target is **not** committed to `Runner.xcodeproj`. Instead
the Codemagic `ios-testflight` workflow runs a Ruby script during the
build that adds the target programmatically:

```
ios/scripts/add_widget_target.rb
```

The script uses the `xcodeproj` gem (the same one CocoaPods uses) so
the modifications match Apple's project format exactly. It's
idempotent — re-running with the target already present is a no-op,
so iterating locally on a Mac after wiring it in via Xcode UI
continues to work fine.

What the script wires:

1. **`NutriLensHomeWidget` target** of type *App Extension*
2. **Build phases**: Sources (`NutriLensHomeWidget.swift`), Frameworks
   (`WidgetKit.framework`, `SwiftUI.framework`)
3. **Build settings**: bundle id, entitlements path, deployment target
   matching Runner, Swift 5.0, automatic codesigning
4. **Runner ⇨ widget dependency** + a *Embed Foundation Extensions*
   copy-files phase so the `.appex` is bundled into the host app
5. **Runner entitlements**: points at `Runner/Runner.entitlements`
   which declares the shared `group.app.nutrilens.ios` App Group

## One-time prerequisite: App Store Connect

Before the first Codemagic build with the widget, register the widget
Bundle ID in your developer portal — Codemagic needs a matching
provisioning profile to sign the extension.

1. https://developer.apple.com → **Certificates, Identifiers & Profiles**
2. **Identifiers** → **+** → App IDs → App
3. **Bundle ID** → Explicit: `app.nutrilens.ios.NutriLensHomeWidget`
4. **Description**: `NutriLens Widget`
5. **Capabilities**: scroll to **App Groups** → tick → **Configure** →
   tick `group.app.nutrilens.ios` (create it first via the App
   Groups identifier section if it doesn't exist yet) → save
6. **Register** the App ID.

After registration, the next `xcode-project use-profiles` step in the
Codemagic workflow auto-fetches the new profile through the App Store
Connect integration. No `bundle_identifier` change is needed in
`codemagic.yaml`; the CLI scans all targets in the workspace.

## How the data flow works

```
Flutter (HomeWidgetService)
   ├─ saveWidgetData('today_kcal', 1842)  ──► group.app.nutrilens.ios UserDefaults
   └─ updateWidget(iOSName: 'NutriLensHomeWidget')
                                                  │
                                                  ▼
       WidgetCenter.shared.reloadTimelines(ofKind:)
                                                  │
                                                  ▼
       Provider.getTimeline() → reads UserDefaults
                                                  │
                                                  ▼
       NutriLensHomeWidgetView renders the new entry
```

Tap on the widget → `widgetURL("nutrilens://widget/scan")` → iOS
launches the app with that URL → `HomeWidget.widgetClicked` stream in
`main.dart` routes to `/scanner`.

## If you ever want to commit the target to pbxproj (Mac access)

Once a teammate has Xcode access, the script's modifications can be
"baked in" so the build no longer mutates pbxproj on every run:

```bash
cd ios
ruby scripts/add_widget_target.rb Runner.xcodeproj
git add Runner.xcodeproj/project.pbxproj
git commit -m "iOS: bake widget target into pbxproj"
```

Then remove the `Add Widget Extension target to Runner.xcodeproj`
step from `codemagic.yaml`. The script being idempotent means it stays
safe even if accidentally re-run.

## Troubleshooting

- **Widget always shows 0 kcal**: App Group ID mismatch. Check both
  entitlements files contain exactly `group.app.nutrilens.ios` and
  match `HomeWidgetService._appGroupId` in the Flutter side.
- **Widget tap doesn't open the scanner**: URL scheme `nutrilens` is
  on the host app's `Info.plist` URL Types (added when `home_widget`
  is installed). Cold-launch handling lives in `main.dart` ::
  `_handleWidgetUri`.
- **Codemagic build fails with "no matching profile" for the widget**:
  forgot the App Store Connect Bundle ID registration above. Once
  added, Codemagic's next build picks it up.
- **Codemagic build fails at "Add Widget Extension target"**: rerun
  with `--verbose` and read the Ruby script output. Likeliest cause is
  a stale checkout where one of the source files
  (`NutriLensHomeWidget.swift`, `Info.plist`, `.entitlements`) is
  missing.
