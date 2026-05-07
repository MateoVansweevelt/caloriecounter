import SwiftUI

/// Glance-friendly view: calorie budget, macro headroom, and how fresh the phone snapshot is.
struct TodayWatchRootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var snapshot: CalorieSnapshot?
    @State private var tick = Date()

    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                if let snap = resolvedSnapshot {
                    calorieSection(snap)
                    if snap.targetProteinG > 0 || snap.targetCarbsG > 0 || snap.targetFatG > 0 {
                        macroSection(snap)
                    }
                    Text("Updated \(snap.updatedAt.formatted(.relative(presentation: .named)))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    ContentUnavailableView(
                        "Open CalorieCounter",
                        systemImage: "iphone",
                        description: Text("Log a meal on your iPhone to sync today’s budget here.")
                    )
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("Today")
        .onAppear(perform: reload)
        .onReceive(timer) { tick = $0 }
        .onChange(of: tick) { _, _ in reload() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { reload() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .calorieSnapshotUpdatedFromPhone)) { _ in
            reload()
        }
    }

    private var resolvedSnapshot: CalorieSnapshot? {
        guard let stored = snapshot ?? CalorieSnapshotStore.load() else { return nil }
        let today = Calendar.current.startOfDay(for: tick)
        if stored.dayStart != today {
            return CalorieSnapshot(
                consumedKcal: 0,
                targetKcal: stored.targetKcal,
                consumedCarbsG: 0,
                consumedProteinG: 0,
                consumedFatG: 0,
                targetCarbsG: stored.targetCarbsG,
                targetProteinG: stored.targetProteinG,
                targetFatG: stored.targetFatG,
                dayStart: today,
                updatedAt: stored.updatedAt
            )
        }
        return stored
    }

    private func reload() {
        snapshot = CalorieSnapshotStore.load()
    }

    private func calorieSection(_ snap: CalorieSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(Int(snap.remainingKcal.rounded()))")
                    .font(.system(.title, design: .rounded).weight(.semibold))
                    .monospacedDigit()
                Text("kcal left")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: min(1, snap.progress))
                .tint(.orange)
            HStack {
                Text("\(Int(snap.consumedKcal.rounded())) / \(Int(snap.targetKcal))")
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
        }
    }

    private func macroSection(_ snap: CalorieSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Macros")
                .font(.caption)
                .foregroundStyle(.secondary)
            macroRow(
                "P",
                left: snap.macroRemaining(target: snap.targetProteinG, consumed: snap.consumedProteinG),
                target: snap.targetProteinG,
                consumed: snap.consumedProteinG
            )
            macroRow(
                "C",
                left: snap.macroRemaining(target: snap.targetCarbsG, consumed: snap.consumedCarbsG),
                target: snap.targetCarbsG,
                consumed: snap.consumedCarbsG
            )
            macroRow(
                "F",
                left: snap.macroRemaining(target: snap.targetFatG, consumed: snap.consumedFatG),
                target: snap.targetFatG,
                consumed: snap.consumedFatG
            )
        }
    }

    private func macroRow(_ label: String, left: Double, target: Double, consumed: Double) -> some View {
        HStack {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 14, alignment: .leading)
            if target > 0 {
                Text("\(Int(left.rounded())) g left")
                    .font(.caption2)
                    .monospacedDigit()
                Spacer(minLength: 0)
                Text("\(Int(consumed.rounded()))/\(Int(target))")
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(.tertiary)
            } else {
                Text("—")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

#Preview {
    TodayWatchRootView()
}
