import SwiftUI

struct AddFoodView: View {
    @Environment(\.dependencies) private var dependencies
    @State private var searchText = ""
    @State private var searchModel: FoodSearchViewModel?
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
            if searchModel == nil, let deps = dependencies {
                searchModel = FoodSearchViewModel(nutrition: deps.nutritionProvider)
            }
        }
        .sheet(isPresented: $showingScanner) {
            BarcodeScannerView()
        }
        .sheet(item: $presentedFood) { food in
            FoodDetailView(food: food) { presentedFood = nil }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        List {
            Section {
                Button { showingScanner = true } label: {
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
                .buttonStyle(.plain)
            } header: {
                Text("Quick Actions")
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Search results

    @ViewBuilder
    private func searchResultsView(model: FoodSearchViewModel) -> some View {
        if model.isLoading {
            List { }
                .overlay { ProgressView() }
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

// MARK: - Row

private struct FoodSearchRow: View {
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
