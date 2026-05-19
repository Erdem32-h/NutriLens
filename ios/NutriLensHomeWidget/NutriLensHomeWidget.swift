// NutriLensHomeWidget — iOS WidgetKit extension.
//
// Mirrors today's meal snapshot pushed from Flutter via the
// `home_widget` plugin. The shared App Group
// `group.app.nutrilens.ios` is the bridge: Flutter writes
// `today_kcal`, `today_meal_count` and `last_update_iso` keys into a
// suite-name UserDefaults backed by that group; the widget reads the
// same keys via `UserDefaults(suiteName:)`.
//
// To regenerate the timeline outside of an app-driven refresh, iOS
// runs the `Provider.getTimeline` method on a schedule it controls
// (typically every 1-2 hours; we hint with `.atEnd` + a 1-hour
// reload). App-driven refreshes are triggered by the Flutter call to
// `HomeWidget.updateWidget(iOSName: 'NutriLensHomeWidget')`.

import WidgetKit
import SwiftUI

private let kAppGroup = "group.app.nutrilens.ios"
private let kKeyKcal = "today_kcal"
private let kKeyMealCount = "today_meal_count"

struct NutriLensEntry: TimelineEntry {
    let date: Date
    let kcal: Int
    let mealCount: Int
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> NutriLensEntry {
        NutriLensEntry(date: Date(), kcal: 0, mealCount: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (NutriLensEntry) -> Void) {
        completion(readEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NutriLensEntry>) -> Void) {
        let entry = readEntry()
        // Ask iOS to reload us in roughly 1 hour. The Flutter side will
        // also trigger an immediate refresh on meal save / scan, which
        // bypasses this schedule.
        let nextReload = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date().addingTimeInterval(3600)
        let timeline = Timeline(entries: [entry], policy: .after(nextReload))
        completion(timeline)
    }

    private func readEntry() -> NutriLensEntry {
        let defaults = UserDefaults(suiteName: kAppGroup)
        let kcal = defaults?.integer(forKey: kKeyKcal) ?? 0
        let count = defaults?.integer(forKey: kKeyMealCount) ?? 0
        return NutriLensEntry(date: Date(), kcal: kcal, mealCount: count)
    }
}

struct NutriLensHomeWidgetView: View {
    var entry: Provider.Entry

    var body: some View {
        ZStack(alignment: .leading) {
            // Brand gradient — mirrors the in-app primaryGradient.
            LinearGradient(
                colors: [Color(red: 0.06, green: 0.18, blue: 0.12),
                         Color(red: 0.12, green: 0.50, blue: 0.33)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(alignment: .leading, spacing: 4) {
                Text("BUGÜN")
                    .font(.system(size: 11, weight: .medium))
                    .tracking(1.2)
                    .foregroundColor(Color.white.opacity(0.55))

                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(formatKcal(entry.kcal))
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                    Text("kcal")
                        .font(.system(size: 12))
                        .foregroundColor(Color.white.opacity(0.7))
                }

                Text("\(entry.mealCount) öğün · bugün")
                    .font(.system(size: 12))
                    .foregroundColor(Color.white.opacity(0.7))

                Spacer()

                // "Tara" button — wraps the deep-link URL the app picks
                // up via `HomeWidget.widgetClicked` to route to /scanner.
                Link(destination: URL(string: "nutrilens://widget/scan")!) {
                    HStack(spacing: 6) {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 13, weight: .bold))
                        Text("Tara")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(Color(red: 0.91, green: 0.97, blue: 0.94))
                    .foregroundColor(Color(red: 0.10, green: 0.10, blue: 0.10))
                    .cornerRadius(19)
                }
            }
            .padding(14)
        }
        .widgetURL(URL(string: "nutrilens://widget/scan"))
    }

    private func formatKcal(_ kcal: Int) -> String {
        guard kcal >= 1000 else { return "\(kcal)" }
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "tr_TR")
        return f.string(from: NSNumber(value: kcal)) ?? "\(kcal)"
    }
}

@main
struct NutriLensHomeWidget: Widget {
    let kind: String = "NutriLensHomeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if #available(iOS 17.0, *) {
                NutriLensHomeWidgetView(entry: entry)
                    .containerBackground(.clear, for: .widget)
            } else {
                NutriLensHomeWidgetView(entry: entry)
            }
        }
        .configurationDisplayName("NutriLens — Bugün")
        .description("Bugünkü kalori toplamı ve hızlı tarama.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
