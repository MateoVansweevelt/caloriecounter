import WidgetKit
import SwiftUI

struct CalorieRingEntry: TimelineEntry {
    let date: Date
    let snapshot: CalorieSnapshot
    let isStale: Bool
}

struct CalorieRingProvider: TimelineProvider {
    func placeholder(in context: Context) -> CalorieRingEntry {
        CalorieRingEntry(date: .now, snapshot: .placeholder, isStale: false)
    }

    func getSnapshot(in context: Context, completion: @escaping (CalorieRingEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CalorieRingEntry>) -> Void) {
        let entry = currentEntry()
        // Refresh every 15 minutes so the "remaining" number stays fresh even if the
        // user hasn't re-opened the app. The app also force-reloads on every log.
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: .now) ?? .now.addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func currentEntry() -> CalorieRingEntry {
        let today = Calendar.current.startOfDay(for: .now)
        if let stored = CalorieSnapshotStore.load() {
            let isStale = stored.dayStart != today
            let snapshot = isStale
                ? CalorieSnapshot(consumedKcal: 0, targetKcal: stored.targetKcal, dayStart: today)
                : stored
            return CalorieRingEntry(date: .now, snapshot: snapshot, isStale: isStale)
        }
        return CalorieRingEntry(date: .now, snapshot: .placeholder, isStale: false)
    }
}

struct CalorieRingWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: CalorieWidgetKind.ring, provider: CalorieRingProvider()) { entry in
            CalorieRingWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    LinearGradient(
                        colors: [Color.accentColor.opacity(0.22), Color(.systemBackground)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
        }
        .configurationDisplayName("Calories left")
        .description("Today's calories vs your daily target.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct MacrosEntry: TimelineEntry {
    let date: Date
    let snapshot: MacroSnapshot
    let isStale: Bool
}

struct MacrosProvider: TimelineProvider {
    func placeholder(in context: Context) -> MacrosEntry {
        MacrosEntry(date: .now, snapshot: .placeholder, isStale: false)
    }

    func getSnapshot(in context: Context, completion: @escaping (MacrosEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MacrosEntry>) -> Void) {
        let entry = currentEntry()
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: .now) ?? .now.addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func currentEntry() -> MacrosEntry {
        let today = Calendar.current.startOfDay(for: .now)
        if let stored = MacroSnapshotStore.load() {
            let isStale = stored.dayStart != today
            let snapshot = isStale
                ? MacroSnapshot(
                    consumedCarbsGrams: 0,
                    consumedProteinGrams: 0,
                    consumedFatGrams: 0,
                    targetCarbsGrams: stored.targetCarbsGrams,
                    targetProteinGrams: stored.targetProteinGrams,
                    targetFatGrams: stored.targetFatGrams,
                    dayStart: today
                )
                : stored
            return MacrosEntry(date: .now, snapshot: snapshot, isStale: isStale)
        }
        return MacrosEntry(date: .now, snapshot: .placeholder, isStale: false)
    }
}

struct MacrosWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: CalorieWidgetKind.macros, provider: MacrosProvider()) { entry in
            MacrosWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    LinearGradient(
                        colors: [Color.accentColor.opacity(0.22), Color(.systemBackground)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
        }
        .configurationDisplayName("Macros")
        .description("Today's carbs, protein, and fat vs your targets.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct CalorieRingWidgetView: View {
    let entry: CalorieRingEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemMedium:
            mediumBody
        default:
            smallBody
        }
    }

    private var smallBody: some View {
        VStack(spacing: 6) {
            ring(size: 92, lineWidth: 10)
            Text("of \(Int(entry.snapshot.targetKcal)) kcal")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var mediumBody: some View {
        HStack(spacing: 16) {
            ring(size: 104, lineWidth: 12)
            VStack(alignment: .leading, spacing: 6) {
                Text("Calories today")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(Int(entry.snapshot.consumedKcal.rounded())) kcal")
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                    .monospacedDigit()
                Text("Target \(Int(entry.snapshot.targetKcal)) kcal")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }

    private func ring(size: CGFloat, lineWidth: CGFloat) -> some View {
        ZStack {
            Circle()
                .stroke(Color.accentColor.opacity(0.18), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: entry.snapshot.progress)
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 2) {
                Text("\(Int(entry.snapshot.remainingKcal.rounded()))")
                    .font(.system(.title2, design: .rounded).weight(.semibold))
                    .monospacedDigit()
                Text("left")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
    }
}

struct MacrosWidgetView: View {
    let entry: MacrosEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemMedium:
            HStack(spacing: 10) {
                macroRing(title: "Carbs", consumed: entry.snapshot.consumedCarbsGrams, target: entry.snapshot.targetCarbsGrams, tint: .orange)
                macroRing(title: "Protein", consumed: entry.snapshot.consumedProteinGrams, target: entry.snapshot.targetProteinGrams, tint: .pink)
                macroRing(title: "Fat", consumed: entry.snapshot.consumedFatGrams, target: entry.snapshot.targetFatGrams, tint: .yellow)
            }
        default:
            VStack(alignment: .leading, spacing: 8) {
                macroRow(title: "Carbs", consumed: entry.snapshot.consumedCarbsGrams, target: entry.snapshot.targetCarbsGrams, tint: .orange)
                macroRow(title: "Protein", consumed: entry.snapshot.consumedProteinGrams, target: entry.snapshot.targetProteinGrams, tint: .pink)
                macroRow(title: "Fat", consumed: entry.snapshot.consumedFatGrams, target: entry.snapshot.targetFatGrams, tint: .yellow)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func macroRing(title: String, consumed: Double, target: Double, tint: Color) -> some View {
        let progress = target > 0 ? min(1.0, consumed / target) : 0
        return VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(tint.opacity(0.18), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(tint, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(Int(consumed.rounded()))")
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .monospacedDigit()
            }
            .frame(width: 56, height: 56)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func macroRow(title: String, consumed: Double, target: Double, tint: Color) -> some View {
        let progress = target > 0 ? min(1.0, consumed / target) : 0
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.caption.weight(.semibold))
                Spacer()
                Text("\(Int(consumed.rounded())) / \(Int(target))g")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(tint.opacity(0.18))
                    Capsule()
                        .fill(tint)
                        .frame(width: proxy.size.width * progress)
                }
            }
            .frame(height: 7)
        }
    }
}

#Preview(as: .systemSmall) {
    CalorieRingWidget()
} timeline: {
    CalorieRingEntry(date: .now, snapshot: .placeholder, isStale: false)
    CalorieRingEntry(
        date: .now,
        snapshot: CalorieSnapshot(consumedKcal: 2100, targetKcal: 2200, dayStart: Calendar.current.startOfDay(for: .now)),
        isStale: false
    )
}

#Preview(as: .systemMedium) {
    CalorieRingWidget()
} timeline: {
    CalorieRingEntry(date: .now, snapshot: .placeholder, isStale: false)
}

#Preview(as: .systemSmall) {
    MacrosWidget()
} timeline: {
    MacrosEntry(date: .now, snapshot: .placeholder, isStale: false)
}

#Preview(as: .systemMedium) {
    MacrosWidget()
} timeline: {
    MacrosEntry(date: .now, snapshot: .placeholder, isStale: false)
}
