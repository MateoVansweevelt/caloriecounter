import SwiftUI

/// Lets the user search or scan for a food item and specify how much of it to use.
/// Calls `onAdd` with the resulting `MealIngredient` and then dismisses itself.
struct IngredientPickerView: View {
    let onAdd: (MealIngredient) -> Void

    @Environment(\.dependencies) private var dependencies
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""
    @State private var searchModel: FoodSearchViewModel?
    @State private var recentFoods: [FoodItem] = []
    @State private var showingScanner = false
    @State private var selectedFood: FoodItem?

    var body: some View {
        NavigationStack {
            Group {
                if searchText.isEmpty {
                    emptyState
                } else if let model = searchModel {
                    searchResultsView(model: model)
                }
            }
            .navigationTitle("Add Ingredient")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Search foods…"
        )
        .onChange(of: searchText) { _, query in
            searchModel?.search(query: query)
        }
        .task {
            guard let deps = dependencies else { return }
            if searchModel == nil {
                searchModel = FoodSearchViewModel(nutrition: deps.nutritionProvider)
            }
            await loadRecentFoods(from: deps.logbook)
        }
        .sheet(isPresented: $showingScanner) {
            IngredientScannerView { food in
                selectedFood = food
            }
        }
        .sheet(item: $selectedFood) { food in
            IngredientAmountSheet(food: food) { ingredient in
                onAdd(ingredient)
                dismiss()
            }
        }
    }

    // MARK: - Recent foods

    private func loadRecentFoods(from logbook: any LogbookRepository) async {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: .now) ?? .now
        let entries = (try? await logbook.entries(from: thirtyDaysAgo, to: .now)) ?? []
        var seen = Set<String>()
        recentFoods = entries
            .sorted { $0.consumedAt > $1.consumedAt }
            .compactMap { entry -> FoodItem? in
                let key = entry.food.name.lowercased()
                guard seen.insert(key).inserted else { return nil }
                return entry.food
            }
            .prefix(12)
            .map { $0 }
    }

    // MARK: - Empty state

    @ViewBuilder
    private var emptyState: some View {
        List {
            Section {
                Button { showingScanner = true } label: {
                    scanBarcodeRow
                }
                .buttonStyle(.plain)
            }

            if !recentFoods.isEmpty {
                Section("Recent") {
                    ForEach(recentFoods) { food in
                        Button { selectedFood = food } label: {
                            FoodSearchRow(food: food)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var scanBarcodeRow: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(.tint.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: "barcode.viewfinder")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.tint)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Scan Barcode")
                    .font(.body)
                    .foregroundStyle(.primary)
                Text("Point at any product barcode")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Search results

    @ViewBuilder
    private func searchResultsView(model: FoodSearchViewModel) -> some View {
        if model.isLoading {
            List { }.overlay { ProgressView() }
        } else if let error = model.errorMessage {
            ContentUnavailableView(
                "Search Failed",
                systemImage: "exclamationmark.triangle",
                description: Text(error)
            )
        } else if model.results.isEmpty {
            ContentUnavailableView.search(text: searchText)
        } else {
            List(model.results) { food in
                Button { selectedFood = food } label: {
                    FoodSearchRow(food: food)
                }
                .buttonStyle(.plain)
            }
            .listStyle(.insetGrouped)
        }
    }
}

// MARK: - Ingredient scanner (wraps BarcodeScannerView with a callback instead of FoodDetailView)

struct IngredientScannerView: View {
    let onFood: (FoodItem) -> Void

    @Environment(\.dependencies) private var dependencies
    @Environment(\.dismiss) private var dismiss

    @State private var model: ScanViewModel?
    @State private var manualBarcode = ""
    @State private var showingManualEntry = false
    @FocusState private var manualFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                if let model {
                    scannerBody(model: model)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Scan Barcode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task {
            if model == nil, let deps = dependencies {
                model = ScanViewModel(nutrition: deps.nutritionProvider)
            }
        }
        .onChange(of: model?.state) { _, newState in
            if case let .resolved(item) = newState {
                onFood(item)
                dismiss()
            }
        }
    }

    @ViewBuilder
    private func scannerBody(model: ScanViewModel) -> some View {
        if ScannerAvailability.isAvailable {
            ZStack {
                DataScannerRepresentable(
                    onBarcode: { model.handle(barcode: $0) },
                    isScanning: Binding(get: { model.isScanning }, set: { model.isScanning = $0 })
                )
                .ignoresSafeArea()
                cameraOverlay(model: model)
            }
        } else {
            simulatorFallback(model: model)
        }
    }

    private func cameraOverlay(model: ScanViewModel) -> some View {
        VStack {
            Spacer()
            VStack(spacing: 12) {
                if showingManualEntry {
                    manualEntryPanel(model: model)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                HStack(spacing: 12) {
                    statusChip(for: model)
                    if case .idle = model.state, !showingManualEntry {
                        Button {
                            withAnimation(.spring(duration: 0.3)) { showingManualEntry = true }
                            manualFocused = true
                        } label: {
                            Image(systemName: "keyboard").padding(12)
                        }
                        .glassEffect(.regular, in: .circle)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .animation(.spring(duration: 0.3), value: showingManualEntry)
        .animation(.spring(duration: 0.3), value: model.state == .idle)
    }

    private func manualEntryPanel(model: ScanViewModel) -> some View {
        HStack(spacing: 10) {
            TextField("Barcode number", text: $manualBarcode)
                .keyboardType(.numberPad)
                .textFieldStyle(.plain)
                .focused($manualFocused)
            if !manualBarcode.isEmpty {
                Button("Look up") {
                    let trimmed = manualBarcode.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { return }
                    model.handle(barcode: trimmed)
                    withAnimation { showingManualEntry = false }
                    manualBarcode = ""
                }
                .buttonStyle(.glassProminent)
            }
            Button {
                withAnimation(.spring(duration: 0.3)) { showingManualEntry = false }
                manualBarcode = ""
                manualFocused = false
            } label: {
                Image(systemName: "xmark").padding(10)
            }
            .glassEffect(.regular, in: .circle)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .glassEffect(.regular, in: .capsule)
    }

    @ViewBuilder
    private func statusChip(for model: ScanViewModel) -> some View {
        switch model.state {
        case .idle:
            Label("Point at a barcode", systemImage: "viewfinder")
                .labelStyle(.titleAndIcon)
                .padding(.horizontal, 20).padding(.vertical, 12)
                .glassEffect(.regular, in: .capsule)
        case .looking(let barcode):
            HStack(spacing: 10) {
                ProgressView().controlSize(.small)
                Text("Looking up \(barcode)…")
            }
            .padding(.horizontal, 20).padding(.vertical, 12)
            .glassEffect(.regular, in: .capsule)
        case .notFound(let barcode):
            HStack(spacing: 10) {
                Image(systemName: "questionmark.circle.fill")
                Text("No record for \(barcode)")
                Button("Retry") { model.reset() }.buttonStyle(.glass)
            }
            .padding(.horizontal, 20).padding(.vertical, 12)
            .glassEffect(.regular, in: .capsule)
        case .failed(let message):
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                Text(message).lineLimit(2)
                Button("Retry") { model.reset() }.buttonStyle(.glass)
            }
            .padding(.horizontal, 20).padding(.vertical, 12)
            .glassEffect(.regular.tint(.red.opacity(0.2)), in: .capsule)
        case .resolved:
            EmptyView()
        }
    }

    private func simulatorFallback(model: ScanViewModel) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Image(systemName: "barcode.viewfinder")
                        .font(.system(size: 56))
                        .foregroundStyle(.tint)
                    Text("Camera Not Available")
                        .font(.headline)
                    Text("Enter a barcode number to look up a product.")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 10) {
                    TextField("e.g. 5449000000996", text: $manualBarcode)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numberPad)
                    Button("Look up") {
                        let trimmed = manualBarcode.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        model.handle(barcode: trimmed)
                        manualBarcode = ""
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(manualBarcode.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                statusChip(for: model).frame(maxWidth: .infinity)
            }
            .padding(24)
        }
        .glassEffect(.regular, in: .rect(cornerRadius: 28))
        .padding(20)
    }
}

// MARK: - Amount entry sheet

struct IngredientAmountSheet: View {
    let food: FoodItem
    let onAdd: (MealIngredient) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var amount: Double = 100

    private var unit: String { food.facts.basis == .mass ? "g" : "ml" }

    var body: some View {
        NavigationStack {
            ScrollView {
                GlassEffectContainer(spacing: 16) {
                    VStack(spacing: 16) {
                        foodHeader
                        amountCard
                        nutritionPreview
                        addButton
                    }
                    .padding(20)
                }
            }
            .background(background)
            .navigationTitle("Set Amount")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var foodHeader: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(.tint.opacity(0.1))
                    .frame(width: 72, height: 72)
                if let url = food.imageURL {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Image(systemName: "fork.knife")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 72, height: 72)
                    .clipShape(.rect(cornerRadius: 14))
                } else {
                    Image(systemName: "fork.knife")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(food.name).font(.title3.bold()).lineLimit(2)
                if let brand = food.brand {
                    Text(brand).foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
    }

    private var amountCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Amount").font(.headline)
            HStack(spacing: 12) {
                Button {
                    amount = max(1, amount - 10)
                } label: {
                    Image(systemName: "minus").frame(width: 28, height: 28)
                }
                .buttonStyle(.glass)

                TextField("Amount", value: $amount, format: .number.precision(.fractionLength(0...1)))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .monospacedDigit()
                    .frame(minWidth: 80)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(.thinMaterial, in: .rect(cornerRadius: 10))

                Button {
                    amount += 10
                } label: {
                    Image(systemName: "plus").frame(width: 28, height: 28)
                }
                .buttonStyle(.glass)

                Text(unit)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 24, alignment: .leading)

                Spacer()
            }

            if !food.suggestedServings.isEmpty {
                Divider()
                Text("Quick amounts")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(food.suggestedServings, id: \.self) { serving in
                            Button {
                                amount = serving.amount
                            } label: {
                                Text(serving.displayLabel)
                                    .font(.caption.weight(.medium))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                            }
                            .buttonStyle(.glass)
                        }
                    }
                }
            }
        }
        .padding(20)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
    }

    private var nutritionPreview: some View {
        let serving = Serving(basis: food.facts.basis, amount: max(1, amount))
        let n = food.facts.values(for: serving)
        return VStack(alignment: .leading, spacing: 10) {
            Text("Nutrition").font(.headline)
            HStack {
                Text(UnitsFormatting.calories(n.energy))
                    .font(.system(.title2, design: .rounded).weight(.semibold))
                    .monospacedDigit()
                Spacer()
            }
            Divider()
            macroLine(title: "Carbs", value: n.macros.carbohydrates)
            macroLine(title: "Protein", value: n.macros.protein)
            macroLine(title: "Fat", value: n.macros.fat)
        }
        .padding(20)
        .glassEffect(.regular.tint(.accentColor.opacity(0.10)), in: .rect(cornerRadius: 22))
    }

    private func macroLine(title: String, value: Measurement<UnitMass>) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(UnitsFormatting.grams(value)).monospacedDigit()
        }
    }

    private var addButton: some View {
        Button {
            let ingredient = MealIngredient(food: food, amount: max(1, amount))
            onAdd(ingredient)
            dismiss()
        } label: {
            Label("Add to Meal", systemImage: "plus.circle.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }
        .buttonStyle(.glassProminent)
        .controlSize(.large)
        .tint(.accentColor)
        .padding(.top, 4)
    }

    private var background: some View {
        LinearGradient(
            colors: [Color.accentColor.opacity(0.15), Color(.systemGroupedBackground)],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}
