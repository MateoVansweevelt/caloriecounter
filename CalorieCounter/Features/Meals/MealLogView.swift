import SwiftUI

struct MealLogView: View {
    let meal: CustomMeal
    let onLogged: () -> Void

    @Environment(\.dependencies) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @State private var model: MealLogViewModel?

    var body: some View {
        NavigationStack {
            ZStack {
                if let model {
                    content(model: model)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Log Meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .task {
            if model == nil, let deps = dependencies {
                model = MealLogViewModel(meal: meal, logbook: deps.logbook)
            }
        }
    }

    @ViewBuilder
    private func content(model: MealLogViewModel) -> some View {
        ScrollView {
            GlassEffectContainer(spacing: 16) {
                VStack(spacing: 16) {
                    header
                    portionsCard(model: model)
                    nutritionCard(model: model)
                    metaCard(model: model)
                    logButton(model: model)
                }
                .padding(20)
            }
        }
        .background(background)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(.tint.opacity(0.1))
                    .frame(width: 72, height: 72)
                Image(systemName: "fork.knife")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(.tint)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(meal.name).font(.title3.bold()).lineLimit(2)
                Text(ingredientSummary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
    }

    private var ingredientSummary: String {
        let count = meal.ingredients.count
        return count == 1 ? "1 ingredient" : "\(count) ingredients"
    }

    // MARK: - Portions

    private func portionsCard(model: MealLogViewModel) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Portions").font(.headline)
                Text("Each portion is \(portionWeight(model: model))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Stepper(
                value: Binding(
                    get: { model.portions },
                    set: { model.portions = max(1, $0) }
                ),
                in: 1...20
            ) {
                Text("\(model.portions)")
                    .font(.title3.weight(.semibold).monospacedDigit())
                    .frame(minWidth: 28, alignment: .trailing)
            }
        }
        .padding(20)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
    }

    private func portionWeight(model: MealLogViewModel) -> String {
        let g = meal.totalGrams / Double(max(meal.numberOfPortions, 1))
        return "\(Int(g.rounded()))g"
    }

    // MARK: - Nutrition

    private func nutritionCard(model: MealLogViewModel) -> some View {
        let n = model.nutritionForPortions
        return VStack(alignment: .leading, spacing: 10) {
            Text("Will log").font(.headline)
            HStack {
                VStack(alignment: .leading) {
                    Text(UnitsFormatting.calories(n.energy))
                        .font(.system(.title, design: .rounded).weight(.semibold))
                        .monospacedDigit()
                    Text(model.portions == 1 ? "for 1 portion" : "for \(model.portions) portions")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            Divider()
            macroLine(title: "Carbs", value: n.macros.carbohydrates)
            macroLine(title: "Protein", value: n.macros.protein)
            macroLine(title: "Fat", value: n.macros.fat)
            if let fiber = n.macros.fiber { macroLine(title: "Fiber", value: fiber) }
            if let sugars = n.macros.sugars { macroLine(title: "Sugars", value: sugars) }
        }
        .padding(20)
        .glassEffect(.regular.tint(.accentColor.opacity(0.12)), in: .rect(cornerRadius: 22))
        .animation(.spring(duration: 0.25), value: model.portions)
    }

    private func macroLine(title: String, value: Measurement<UnitMass>) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(UnitsFormatting.grams(value)).monospacedDigit()
        }
    }

    // MARK: - Meta

    private func metaCard(model: MealLogViewModel) -> some View {
        VStack(spacing: 12) {
            DatePicker("When", selection: Binding(
                get: { model.consumedAt },
                set: { model.consumedAt = $0 }
            ))
            Picker("Meal", selection: Binding(
                get: { model.mealSlot },
                set: { model.mealSlot = $0 }
            )) {
                ForEach(MealSlot.allCases, id: \.self) { slot in
                    Label(slot.displayName, systemImage: slot.symbolName).tag(slot)
                }
            }
            TextField("Note", text: Binding(
                get: { model.note },
                set: { model.note = $0 }
            ), axis: .vertical)
            .textFieldStyle(.roundedBorder)
        }
        .padding(20)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
    }

    // MARK: - Log button

    private func logButton(model: MealLogViewModel) -> some View {
        Button {
            Task {
                if await model.save() {
                    onLogged()
                    dismiss()
                }
            }
        } label: {
            if model.isSaving {
                ProgressView().controlSize(.small).padding(.vertical, 4)
            } else {
                Label("Log it", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
        }
        .buttonStyle(.glassProminent)
        .controlSize(.large)
        .tint(.accentColor)
        .disabled(model.isSaving)
        .padding(.top, 4)
    }

    // MARK: - Background

    private var background: some View {
        LinearGradient(
            colors: [Color.accentColor.opacity(0.2), Color(.systemGroupedBackground)],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

#Preview {
    MealLogView(meal: CustomMeal(
        name: "Chicken & Rice Bowl",
        ingredients: [],
        numberOfPortions: 4
    )) {}
}
