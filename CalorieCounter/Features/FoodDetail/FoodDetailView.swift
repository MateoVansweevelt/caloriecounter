import SwiftUI

struct FoodDetailView: View {
    let food: FoodItem
    let onLogged: () -> Void

    @Environment(\.dependencies) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @State private var model: FoodDetailViewModel?

    var body: some View {
        NavigationStack {
            ZStack {
                if let model {
                    content(model: model)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Log food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .task {
            if model == nil, let deps = dependencies {
                model = FoodDetailViewModel(
                    food: food,
                    logbook: deps.logbook
                )
            }
        }
    }

    @ViewBuilder
    private func content(model: FoodDetailViewModel) -> some View {
        ScrollView {
            GlassEffectContainer(spacing: 16) {
                VStack(spacing: 16) {
                    header(model: model)
                    servingCard(model: model)
                    nutritionCard(model: model)
                    metaCard(model: model)
                    logButton(model: model)
                }
                .padding(20)
            }
        }
        .background(background)
    }

    private func header(model: FoodDetailViewModel) -> some View {
        HStack(spacing: 16) {
            AsyncImage(url: food.imageURL) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    ZStack {
                        Color.secondary.opacity(0.1)
                        Image(systemName: "fork.knife")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(width: 72, height: 72)
            .clipShape(.rect(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 4) {
                Text(food.name).font(.title3.bold())
                if let brand = food.brand { Text(brand).foregroundStyle(.secondary) }
            }
            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
    }

    private func servingCard(model: FoodDetailViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Serving").font(.headline)
            if !food.suggestedServings.isEmpty {
                Picker("Suggested", selection: Binding(
                    get: { model.selectedServing },
                    set: { newValue in
                        model.selectedServing = newValue
                        model.customAmount = newValue.amount
                    }
                )) {
                    ForEach(food.suggestedServings, id: \.self) { serving in
                        Text(serving.displayLabel).tag(serving)
                    }
                }
                .pickerStyle(.segmented)
            }
            amountRow(model: model)
        }
        .padding(20)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
    }

    private func amountRow(model: FoodDetailViewModel) -> some View {
        HStack(spacing: 12) {
            Text("Amount")
            Spacer()
            Button { model.decrementAmount() } label: {
                Image(systemName: "minus")
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.glass)

            TextField(
                "Amount",
                value: Binding(
                    get: { model.displayAmount },
                    set: { model.displayAmount = $0 }
                ),
                format: .number.precision(.fractionLength(0...2))
            )
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.center)
            .monospacedDigit()
            .frame(minWidth: 72)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(.thinMaterial, in: .rect(cornerRadius: 10))

            Button { model.incrementAmount() } label: {
                Image(systemName: "plus")
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.glass)

            Picker("Unit", selection: Binding(
                get: { model.displayUnit },
                set: { model.displayUnit = $0 }
            )) {
                ForEach(model.availableDisplayUnits, id: \.self) { unit in
                    Text(unit.symbol).tag(unit)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
        }
    }

    private func nutritionCard(model: FoodDetailViewModel) -> some View {
        let c = model.consumed
        return VStack(alignment: .leading, spacing: 10) {
            Text("Nutrition").font(.headline)
            HStack {
                VStack(alignment: .leading) {
                    Text(UnitsFormatting.calories(c.energy))
                        .font(.system(.title, design: .rounded).weight(.semibold))
                        .monospacedDigit()
                    Text("for this serving").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            Divider()
            macroLine(title: "Carbs", value: c.macros.carbohydrates)
            macroLine(title: "Protein", value: c.macros.protein)
            macroLine(title: "Fat", value: c.macros.fat)
            if let fiber = c.macros.fiber { macroLine(title: "Fiber", value: fiber) }
            if let sugars = c.macros.sugars { macroLine(title: "Sugars", value: sugars) }
        }
        .padding(20)
        .glassEffect(.regular.tint(.accentColor.opacity(0.12)), in: .rect(cornerRadius: 22))
    }

    private func macroLine(title: String, value: Measurement<UnitMass>) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(UnitsFormatting.grams(value)).monospacedDigit()
        }
    }

    private func metaCard(model: FoodDetailViewModel) -> some View {
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
            .textFieldStyle(.plain)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.thinMaterial, in: .rect(cornerRadius: 10))
        }
        .padding(20)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
    }

    private func logButton(model: FoodDetailViewModel) -> some View {
        Button {
            Task {
                if await model.save() {
                    onLogged()
                    dismiss()
                }
            }
        } label: {
            if model.isSaving {
                ProgressView().controlSize(.small)
                    .padding(.vertical, 4)
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

    private var background: some View {
        LinearGradient(
            colors: [Color.accentColor.opacity(0.2), Color(.systemGroupedBackground)],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}
