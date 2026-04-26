import SwiftUI

struct AddFoodView: View {
    @Environment(\.dependencies) private var dependencies
    @State private var searchText = ""
    @State private var searchModel: FoodSearchViewModel?
    @State private var recentFoods: [FoodItem] = []
    @State private var presentedFood: FoodItem?
    @State private var showingScanner = false

    var body: some View {
        NavigationStack {
            Group {
                if searchText.isEmpty {
                    emptyState
                } else if let model = searchModel {
                    searchResultsView(model: model)
                }
            }
            .navigationTitle("Add Food")
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
            BarcodeScannerView()
        }
        .sheet(item: $presentedFood) { food in
            FoodDetailView(food: food) {
                presentedFood = nil
                if let deps = dependencies {
                    Task { await loadRecentFoods(from: deps.logbook) }
                }
            }
        }
    }

    // MARK: - Recent foods

    private func loadRecentFoods(from logbook: any LogbookRepository) async {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: .now) ?? .now
        let entries = (try? await logbook.entries(from: thirtyDaysAgo, to: .now)) ?? []
        // Deduplicate by food name, preserving most-recent-first order
        var seen = Set<String>()
        recentFoods = entries
            .sorted { $0.consumedAt > $1.consumedAt }
            .compactMap { entry -> FoodItem? in
                let key = entry.food.name.lowercased()
                guard seen.insert(key).inserted else { return nil }
                return entry.food
            }
            .prefix(8)
            .map { $0 }
    }

    // MARK: - Empty state

    @ViewBuilder
    private var emptyState: some View {
        if recentFoods.isEmpty {
            genuinelyEmptyState
        } else {
            List {
                scanBarcodeSection
                recentFoodsSection
            }
            .listStyle(.insetGrouped)
        }
    }

    private var scanBarcodeSection: some View {
        Section {
            Button { showingScanner = true } label: {
                scanBarcodeRow
            }
            .buttonStyle(.plain)
        }
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

    private var recentFoodsSection: some View {
        Section("Recent") {
            ForEach(recentFoods) { food in
                Button {
                    presentedFood = food
                } label: {
                    FoodSearchRow(food: food)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Truly empty state (no log history at all)

    private var genuinelyEmptyState: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Scan barcode card — consistent styling with the list card used when recent foods exist
                Button { showingScanner = true } label: {
                    scanBarcodeRow
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 12))
                .padding(.horizontal, 16)
                .padding(.top, 8)

                // Empty state centred in the remaining space
                VStack(spacing: 12) {
                    Text("🍽️").font(.system(size: 56))
                    Text("It's a food desert in here")
                        .font(.title3.weight(.semibold))
                    Text("Search above or scan a barcode —\nyour macros won't track themselves.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 40)
                .padding(.vertical, 80)
            }
        }
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
                Button {
                    presentedFood = food
                } label: {
                    FoodSearchRow(food: food)
                }
                .buttonStyle(.plain)
            }
            .listStyle(.insetGrouped)
        }
    }
}

// MARK: - Shared row

struct FoodSearchRow: View {
    let food: FoodItem

    var body: some View {
        HStack(spacing: 12) {
            foodThumbnail
            VStack(alignment: .leading, spacing: 2) {
                Text(food.name)
                    .font(.body)
                    .lineLimit(1)
                if let brand = food.brand {
                    Text(brand)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            Text("\(Int(food.facts.energy.converted(to: .kilocalories).value)) kcal")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var foodThumbnail: some View {
        Group {
            if let url = food.imageURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        placeholderIcon
                    }
                }
            } else {
                placeholderIcon
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(.rect(cornerRadius: 8))
    }

    private var placeholderIcon: some View {
        ZStack {
            Color.secondary.opacity(0.1)
            Image(systemName: "fork.knife")
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    AddFoodView()
}
