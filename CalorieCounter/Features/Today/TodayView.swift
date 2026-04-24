import SwiftUI

struct TodayView: View {
    @Environment(\.dependencies) private var dependencies
    @State private var model: TodayViewModel?

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

                mealsCard(model: model)
                microsCard(model: model)
            }
        }
    }

    private func mealsCard(model: TodayViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Meals").font(.headline)
            if model.entries.isEmpty {
                ContentUnavailableView(
                    "Nothing logged yet",
                    systemImage: "fork.knife",
                    description: Text("Tap the Scan tab to add your first item.")
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            } else {
                ForEach(MealSlot.allCases, id: \.self) { slot in
                    if let entries = model.groupedBySlot[slot], !entries.isEmpty {
                        mealSection(slot: slot, entries: entries)
                    }
                }
            }
        }
        .padding(20)
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
    }

    private func mealSection(slot: MealSlot, entries: [LogEntry]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(slot.displayName, systemImage: slot.symbolName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
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
