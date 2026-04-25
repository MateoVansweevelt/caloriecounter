import SwiftUI

struct CreateMealView: View {
    let meal: CustomMeal?
    let onSaved: () async -> Void

    @Environment(\.dependencies) private var dependencies
    @Environment(\.dismiss) private var dismiss

    @State private var model: CreateMealViewModel?
    @State private var showingIngredientPicker = false
    @FocusState private var nameFocused: Bool

    var body: some View {
        NavigationStack {
            Group {
                if let model {
                    content(model: model)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle(meal == nil ? "New Meal" : "Edit Meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if let model {
                        saveButton(model: model)
                    }
                }
            }
        }
        .task {
            if model == nil, let deps = dependencies {
                model = CreateMealViewModel(meal: meal, mealRepo: deps.meals)
            }
        }
        .sheet(isPresented: $showingIngredientPicker) {
            if let model {
                IngredientPickerView { ingredient in
                    model.addIngredient(ingredient)
                }
            }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private func content(model: CreateMealViewModel) -> some View {
        ScrollView {
            GlassEffectContainer(spacing: 16) {
                VStack(spacing: 16) {
                    nameCard(model: model)
                    ingredientsCard(model: model)
                    portionsCard(model: model)
                    if !model.ingredients.isEmpty {
                        nutritionCard(model: model)
                    }
                }
                .padding(20)
            }
        }
        .background(background)
    }

    // MARK: - Name

    private func nameCard(model: CreateMealViewModel) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Meal Name").font(.headline)
            TextField("e.g. Chicken & Rice Bowl", text: Binding(
                get: { model.name },
                set: { model.name = $0 }
            ))
            .textFieldStyle(.plain)
            .font(.body)
            .focused($nameFocused)
            .submitLabel(.done)
        }
        .padding(20)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
    }

    // MARK: - Ingredients

    private func ingredientsCard(model: CreateMealViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Ingredients").font(.headline)
                Spacer()
                Button {
                    nameFocused = false
                    showingIngredientPicker = true
                } label: {
                    Label("Add", systemImage: "plus")
                        .font(.subheadline.weight(.medium))
                }
                .buttonStyle(.glass)
            }

            if model.ingredients.isEmpty {
                emptyIngredientsHint
            } else {
                ForEach(model.ingredients) { ingredient in
                    IngredientRow(
                        ingredient: ingredient,
                        onAmountChange: { model.updateAmount($0, for: ingredient) },
                        onDelete: {
                            if let idx = model.ingredients.firstIndex(where: { $0.id == ingredient.id }) {
                                model.removeIngredients(at: IndexSet(integer: idx))
                            }
                        }
                    )
                    if ingredient.id != model.ingredients.last?.id {
                        Divider()
                    }
                }
            }
        }
        .padding(20)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
    }

    private var emptyIngredientsHint: some View {
        HStack(spacing: 12) {
            Image(systemName: "plus.circle.dashed")
                .font(.title2)
                .foregroundStyle(.tertiary)
            Text("Tap Add to search or scan ingredients")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }

    // MARK: - Portions

    private func portionsCard(model: CreateMealViewModel) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Portions this makes").font(.headline)
                Text("Nutrition per portion is divided by this")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Stepper(
                value: Binding(
                    get: { model.numberOfPortions },
                    set: { model.numberOfPortions = max(1, $0) }
                ),
                in: 1...50
            ) {
                Text("\(model.numberOfPortions)")
                    .font(.title3.weight(.semibold).monospacedDigit())
                    .frame(minWidth: 28, alignment: .trailing)
            }
        }
        .padding(20)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
    }

    // MARK: - Nutrition preview

    private func nutritionCard(model: CreateMealViewModel) -> some View {
        let n = model.nutritionPerPortion
        return VStack(alignment: .leading, spacing: 10) {
            Text("Per Portion").font(.headline)
            HStack {
                VStack(alignment: .leading) {
                    Text(UnitsFormatting.calories(n.energy))
                        .font(.system(.title, design: .rounded).weight(.semibold))
                        .monospacedDigit()
                    Text("per portion").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            Divider()
            macroLine(title: "Carbs", value: n.macros.carbohydrates)
            macroLine(title: "Protein", value: n.macros.protein)
            macroLine(title: "Fat", value: n.macros.fat)
            if let fiber = n.macros.fiber { macroLine(title: "Fiber", value: fiber) }
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

    // MARK: - Save button

    private func saveButton(model: CreateMealViewModel) -> some View {
        Button {
            Task {
                if await model.save() {
                    await onSaved()
                    dismiss()
                }
            }
        } label: {
            if model.isSaving {
                ProgressView().controlSize(.small)
            } else {
                Text("Save")
            }
        }
        .disabled(!model.isValid || model.isSaving)
    }

    // MARK: - Background

    private var background: some View {
        LinearGradient(
            colors: [Color.accentColor.opacity(0.15), Color(.systemGroupedBackground)],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

// MARK: - Ingredient row

struct IngredientRow: View {
    let ingredient: MealIngredient
    let onAmountChange: (Double) -> Void
    let onDelete: (() -> Void)?

    @State private var rawAmount: String

    init(
        ingredient: MealIngredient,
        onAmountChange: @escaping (Double) -> Void,
        onDelete: (() -> Void)? = nil
    ) {
        self.ingredient = ingredient
        self.onAmountChange = onAmountChange
        self.onDelete = onDelete
        self._rawAmount = State(initialValue: "\(Int(ingredient.amount))")
    }

    var body: some View {
        HStack(spacing: 12) {
            if let onDelete {
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "minus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(ingredient.food.name)
                    .font(.body)
                    .lineLimit(1)
                if let brand = ingredient.food.brand {
                    Text(brand)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)

            HStack(spacing: 4) {
                Button {
                    let current = Double(rawAmount) ?? ingredient.amount
                    let next = max(1, current - 10)
                    rawAmount = "\(Int(next))"
                    onAmountChange(next)
                } label: {
                    Image(systemName: "minus").frame(width: 24, height: 24)
                }
                .buttonStyle(.glass)

                TextField("g", text: $rawAmount)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .monospacedDigit()
                    .frame(width: 54)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(.thinMaterial, in: .rect(cornerRadius: 8))
                    .onChange(of: rawAmount) { _, val in
                        if let d = Double(val) { onAmountChange(d) }
                    }

                Button {
                    let current = Double(rawAmount) ?? ingredient.amount
                    let next = current + 10
                    rawAmount = "\(Int(next))"
                    onAmountChange(next)
                } label: {
                    Image(systemName: "plus").frame(width: 24, height: 24)
                }
                .buttonStyle(.glass)

                Text(ingredient.unit)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(width: 20, alignment: .leading)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    CreateMealView(meal: nil) {}
}
