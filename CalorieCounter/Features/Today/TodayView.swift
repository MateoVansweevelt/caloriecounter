import SwiftUI

struct TodayView: View {
    @Environment(\.dependencies) private var dependencies
    @State private var model: TodayViewModel?
    private let streakStore = AppOpenStreakStore.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                if let model {
                    content(model: model)
                } else {
                    ProgressView().padding(.top, 80)
                }
            }
            .contentMargins(.horizontal, 20, for: .scrollContent)
            .contentMargins(.vertical, 12, for: .scrollContent)
            .background(backgroundGradient)
            .navigationTitle("Today")
            .navigationBarTitleDisplayMode(.large)
            .onAppear { streakStore.reloadFromDefaults() }
        }
        .task {
            if model == nil, let deps = dependencies {
                model = TodayViewModel(logbook: deps.logbook)
            }
            await model?.load()
        }
    }

    @ViewBuilder
    private func content(model: TodayViewModel) -> some View {
        GlassEffectContainer(spacing: 16) {
            VStack(spacing: 16) {
                CalorieHeroCard(
                    consumedKcal: model.totals.energy.converted(to: .kilocalories).value,
                    targetKcal: model.targets.calories
                )

                streakCard

                HStack(spacing: 12) {
                    MacroRing(
                        title: "Carbs",
                        current: model.totals.macros.carbohydrates.converted(to: .grams).value,
                        target: model.targets.carbsGrams,
                        unit: "g",
                        tint: .orange
                    )
                    MacroRing(
                        title: "Protein",
                        current: model.totals.macros.protein.converted(to: .grams).value,
                        target: model.targets.proteinGrams,
                        unit: "g",
                        tint: .pink
                    )
                    MacroRing(
                        title: "Fat",
                        current: model.totals.macros.fat.converted(to: .grams).value,
                        target: model.targets.fatGrams,
                        unit: "g",
                        tint: .yellow
                    )
                }
                .frame(maxWidth: .infinity)

                mealsCard(model: model)
                microsCard(model: model)
            }
        }
    }

    private var streakCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "flame.fill")
                    .font(.title3)
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Daily opens")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(streakTitle)
                        .font(.headline)
                    Text(streakSubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }

            ScrollView(.horizontal, showsIndicators: true) {
                ContributionHeatmapView(
                    model: streakStore.heatmapModel(),
                    accessibilitySummary: ""
                )
                .accessibilityHidden(true)
            }

            HStack {
                streakLegendDot(color: Color.accentColor.opacity(0.85))
                Text("Opened")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 12)
                streakLegendDot(color: Color.secondary.opacity(0.22))
                Text("No open")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 12)
                streakLegendDot(color: Color.secondary.opacity(0.12))
                Text("Future")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(streakCardAccessibilityLabel))
    }

    private func streakLegendDot(color: Color) -> some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(color)
            .frame(width: 10, height: 10)
    }

    private var streakTitle: String {
        let n = streakStore.currentStreak
        if n <= 0 { return "Start your streak" }
        if n == 1 { return "1 day streak" }
        return "\(n) day streak"
    }

    private var streakSubtitle: String {
        streakStore.currentStreak > 0
            ? "Open the app daily to keep it going"
            : "Open the app daily to build your streak"
    }

    private var streakCardAccessibilityLabel: String {
        "\(streakTitle). \(streakSubtitle). \(streakStore.accessibilitySummary)"
    }

    private func mealsCard(model: TodayViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Meals").font(.headline)
            if model.entries.isEmpty {
                ContentUnavailableView(
                    "Nothing logged yet",
                    systemImage: "fork.knife",
                    description: Text("Tap Add Food to log your first item.")
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            } else {
                let visibleSlots = MealSlot.allCases.filter {
                    model.groupedBySlot[$0]?.isEmpty == false
                }
                ForEach(visibleSlots, id: \.self) { slot in
                    if let entries = model.groupedBySlot[slot], !entries.isEmpty {
                        if slot != visibleSlots.first {
                            Divider()
                        }
                        mealSection(slot: slot, entries: entries)
                    }
                }
            }
        }
        .padding(20)
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
    }

    private func mealSection(slot: MealSlot, entries: [LogEntry]) -> some View {
        let slotKcal = entries.reduce(0.0) { $0 + $1.consumed.energy.converted(to: .kilocalories).value }
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(slot.displayName, systemImage: slot.symbolName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(slotKcal.rounded())) kcal")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
            ForEach(entries) { entry in
                HStack {
                    VStack(alignment: .leading) {
                        Text(entry.food.displayTitle).lineLimit(1)
                        Text(entry.serving.displayLabel).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(UnitsFormatting.calories(entry.consumed.energy))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func microsCard(model: TodayViewModel) -> some View {
        let keys = MicroKey.allCases.filter { model.totals.micros[$0] != nil }
        return Group {
            if !keys.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Micronutrients").font(.headline)
                    ForEach(keys, id: \.self) { key in
                        if let value = model.totals.micros[key] {
                            MicroRow(key: key, value: value)
                        }
                    }
                }
                .padding(20)
                .glassEffect(.regular, in: .rect(cornerRadius: 24))
            }
        }
    }

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color.accentColor.opacity(0.25),
                Color(.systemGroupedBackground),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

#Preview {
    TodayView()
}
