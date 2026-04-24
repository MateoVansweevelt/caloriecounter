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
