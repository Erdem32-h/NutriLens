// NutriLensHomeWidget — iOS WidgetKit extension.
//
// Mirrors today's meal & water snapshot pushed from Flutter via `home_widget`.
// Shared App Group `group.app.nutrilens.ios` bridges UserDefaults between
// Flutter and this extension.
//
// Tap behavior:
// - Tapping the widget body or "Tara" opens the app (`nutrilens://widget/scan`).
// - On iOS 17+, tapping "+1 Su" runs `AddWaterGlassIntent` in-process without
//   launching the app, updating UserDefaults and queueing the delta in
//   `pending_water_queue` so Flutter flushes it into Drift on next launch/resume.
// - On iOS <17, "+1 Su" falls back to `Link("nutrilens://widget/water-add")`.

import AppIntents
import SwiftUI
import WidgetKit

private let kAppGroup = "group.app.nutrilens.ios"
private let kWidgetKind = "NutriLensHomeWidget"
private let kKeyKcal = "today_kcal"
private let kKeyMealCount = "today_meal_count"
private let kKeyProteinPct = "today_protein_pct"
private let kKeyCarbPct = "today_carb_pct"
private let kKeyFatPct = "today_fat_pct"
private let kKeyWaterGlasses = "today_water_glasses"
private let kKeyWaterGoal = "today_water_goal"
private let kKeyWaterDay = "today_water_day"
private let kKeyPendingWaterQueue = "pending_water_queue"

private func todayDayKey() -> String {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: Date())
}

private func incrementPendingQueue(raw: String, dayKey: String) -> String {
    var counts: [String: Int] = [:]
    for entry in raw.split(separator: ",") {
        let parts = entry.trimmingCharacters(in: .whitespaces).split(separator: ":")
        guard parts.count == 2,
              let count = Int(parts[1].trimmingCharacters(in: .whitespaces)),
              count > 0 else { continue }
        let day = String(parts[0].trimmingCharacters(in: .whitespaces))
        if !day.isEmpty {
            counts[day, default: 0] += count
        }
    }
    counts[dayKey, default: 0] += 1
    return counts.keys.sorted().map { "\($0):\(counts[$0]!)" }.joined(separator: ",")
}

@available(iOS 17.0, *)
struct AddWaterGlassIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Water Glass"
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        if let defaults = UserDefaults(suiteName: kAppGroup) {
            let today = todayDayKey()
            let storedDay = defaults.string(forKey: kKeyWaterDay)
            let current = (storedDay == nil || storedDay == today)
                ? defaults.integer(forKey: kKeyWaterGlasses)
                : 0
            let nextGlasses = current + 1
            let pendingRaw = defaults.string(forKey: kKeyPendingWaterQueue) ?? ""
            let nextPending = incrementPendingQueue(raw: pendingRaw, dayKey: today)

            defaults.set(nextGlasses, forKey: kKeyWaterGlasses)
            defaults.set(today, forKey: kKeyWaterDay)
            defaults.set(nextPending, forKey: kKeyPendingWaterQueue)
        }
        WidgetCenter.shared.reloadTimelines(ofKind: kWidgetKind)
        return .result()
    }
}

struct NutriLensEntry: TimelineEntry {
    let date: Date
    let kcal: Int
    let mealCount: Int
    let proteinPct: Int
    let carbPct: Int
    let fatPct: Int
    let waterGlasses: Int
    let waterGoal: Int
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> NutriLensEntry {
        NutriLensEntry(date: Date(), kcal: 0, mealCount: 0, proteinPct: 0, carbPct: 0, fatPct: 0, waterGlasses: 0, waterGoal: 10)
    }

    func getSnapshot(in context: Context, completion: @escaping (NutriLensEntry) -> Void) {
        completion(readEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NutriLensEntry>) -> Void) {
        let entry = readEntry()
        let nextReload = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date().addingTimeInterval(3600)
        let timeline = Timeline(entries: [entry], policy: .after(nextReload))
        completion(timeline)
    }

    private func readEntry() -> NutriLensEntry {
        let defaults = UserDefaults(suiteName: kAppGroup)
        let kcal = defaults?.integer(forKey: kKeyKcal) ?? 0
        let count = defaults?.integer(forKey: kKeyMealCount) ?? 0
        let protein = defaults?.integer(forKey: kKeyProteinPct) ?? 0
        let carb = defaults?.integer(forKey: kKeyCarbPct) ?? 0
        let fat = defaults?.integer(forKey: kKeyFatPct) ?? 0
        let today = todayDayKey()
        let storedDay = defaults?.string(forKey: kKeyWaterDay)
        let water = (storedDay == nil || storedDay == today)
            ? (defaults?.integer(forKey: kKeyWaterGlasses) ?? 0)
            : 0
        let rawGoal = defaults?.integer(forKey: kKeyWaterGoal) ?? 10
        let goal = rawGoal > 0 ? rawGoal : 10
        return NutriLensEntry(date: Date(), kcal: kcal, mealCount: count, proteinPct: protein, carbPct: carb, fatPct: fat, waterGlasses: water, waterGoal: goal)
    }
}

private struct MacroRow: View {
    let label: String
    let pct: Int
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Text("\(label) %\(pct)")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(Color.white.opacity(0.85))
                .frame(width: 40, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.14))
                    Capsule()
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat(min(max(pct, 0), 100)) / 100)
                }
            }
            .frame(height: 4)
        }
    }
}

struct NutriLensHomeWidgetView: View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    private var waterProgress: CGFloat {
        guard entry.waterGoal > 0 else { return 0 }
        return min(max(CGFloat(entry.waterGlasses) / CGFloat(entry.waterGoal), 0), 1)
    }

    var body: some View {
        ZStack(alignment: .leading) {
            LinearGradient(
                colors: [
                    Color(red: 0.043, green: 0.149, blue: 0.098), // #0B2619
                    Color(red: 0.075, green: 0.259, blue: 0.173), // #13422C
                    Color(red: 0.110, green: 0.420, blue: 0.275), // #1C6B46
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(alignment: .leading, spacing: 6) {
                // Header: BUGÜN + meal pill
                HStack {
                    Text("BUGÜN")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.1)
                        .foregroundColor(Color.white.opacity(0.6))
                    Spacer()
                    Text("\(entry.mealCount) öğün")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Color.white.opacity(0.9))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.14))
                        .clipShape(Capsule())
                }

                // Hero kcal
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(formatKcal(entry.kcal))
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("kcal")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color.white.opacity(0.72))
                }

                // Glass stats panel
                VStack(spacing: 5) {
                    HStack(spacing: 6) {
                        Text("💧 \(entry.waterGlasses)/\(entry.waterGoal)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color(red: 0.878, green: 0.949, blue: 0.996))
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.16))
                                Capsule()
                                    .fill(Color(red: 0.220, green: 0.741, blue: 0.973)) // #38BDF8
                                    .frame(width: geo.size.width * waterProgress)
                            }
                        }
                        .frame(height: 5)
                    }

                    if family == .systemMedium {
                        VStack(spacing: 3) {
                            MacroRow(label: "P", pct: entry.proteinPct,
                                     color: Color(red: 0.506, green: 0.549, blue: 0.973)) // #818CF8
                            MacroRow(label: "K", pct: entry.carbPct,
                                     color: Color(red: 0.984, green: 0.749, blue: 0.141)) // #FBBF24
                            MacroRow(label: "Y", pct: entry.fatPct,
                                     color: Color(red: 0.957, green: 0.447, blue: 0.714)) // #F472B6
                        }
                        .padding(.top, 2)
                    }
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 7)
                .background(Color.white.opacity(0.09))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.11), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))

                Spacer(minLength: 2)

                // Action pills: Tara (opens app) + +1 Su (in-place on iOS 17+)
                HStack(spacing: 7) {
                    Link(destination: URL(string: "nutrilens://widget/scan")!) {
                        HStack(spacing: 4) {
                            Image(systemName: "camera.viewfinder")
                                .font(.system(size: 12, weight: .bold))
                            Text("Tara")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(Color(red: 0.949, green: 0.984, blue: 0.965)) // #F2FBF6
                        .foregroundColor(Color(red: 0.059, green: 0.180, blue: 0.118)) // #0F2E1E
                        .clipShape(Capsule())
                    }

                    waterAddButton
                }
            }
            .padding(14)
        }
        .widgetURL(URL(string: "nutrilens://widget/scan"))
    }

    @ViewBuilder
    private var waterAddButton: some View {
        let label = HStack(spacing: 3) {
            Image(systemName: "drop.fill")
                .font(.system(size: 11, weight: .bold))
            Text(family == .systemSmall ? "+1" : "+1 Su")
                .font(.system(size: 13, weight: .bold))
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(Color(red: 0.839, green: 0.933, blue: 1.0)) // #D6EEFF
        .foregroundColor(Color(red: 0.047, green: 0.290, blue: 0.431)) // #0C4A6E
        .clipShape(Capsule())

        if #available(iOS 17.0, *) {
            Button(intent: AddWaterGlassIntent()) {
                label
            }
            .buttonStyle(.plain)
        } else {
            Link(destination: URL(string: "nutrilens://widget/water-add")!) {
                label
            }
        }
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
    let kind: String = kWidgetKind

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
        .description("Bugünkü kalori, su takibi ve hızlı tarama.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
