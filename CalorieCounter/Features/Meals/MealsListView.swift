import SwiftUI

struct MealsListView: View {
    @Environment(\.dependencies) private var dependencies
    @State private var meals: [CustomMeal] = []
    @State private var isLoading = true
    @State private var showingCreate = false
    @State private var mealToEdit: CustomMeal?
    @State private var mealToLog: CustomMeal?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if meals.isEmpty {
                    emptyState
                } else {
                    mealsList
                }
            }
            .navigationTitle("My Meals")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingCreate = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .task { await loadMeals() }
        .sheet(isPresented: $showingCreate) {
            CreateMealView(meal: nil) { await loadMeals() }
        }
        .sheet(item: $mealToEdit) { meal in
            CreateMealView(meal: meal) { await loadMeals() }
        }
        .sheet(item: $mealToLog) { meal in
            MealLogView(meal: meal) {
                mealToLog = nil
            }
        }
    }

    // MARK: - Meals list

    private var mealsList: some View {
        List {
            ForEach(meals) { meal in
                Button { mealToLog = meal } label: {
                    MealRow(meal: meal)
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        Task { await delete(meal) }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    Button {
                        mealToEdit = meal
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .tint(.accentColor)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "fork.knife.circle")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
            Text("No Custom Meals Yet")
                .font(.title3.weight(.semibold))
            Text("Create a meal by combining ingredients — great for recipes you eat regularly.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button {
                showingCreate = true
            } label: {
                Label("Create First Meal", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.glassProminent)
            .tint(.accentColor)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Data

    private func loadMeals() async {
        guard let deps = dependencies else { return }
        isLoading = true
        meals = (try? await deps.meals.all()) ?? []
        isLoading = false
    }

    private func delete(_ meal: CustomMeal) async {
        guard let deps = dependencies else { return }
        try? await deps.meals.delete(meal)
        await loadMeals()
    }
}

// MARK: - Meal row

struct MealRow: View {
    let meal: CustomMeal

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.tint.opacity(0.12))
                    .frame(width: 48, height: 48)
                Image(systemName: "fork.knife")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(.tint)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(meal.name)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(meal.nutritionPerPortion.energy.converted(to: .kilocalories).value))")
                    .font(.headline.monospacedDigit())
                Text("kcal/portion")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Image(systemName: "chevron.right")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    private var subtitle: String {
        let count = meal.ingredients.count
        let portions = meal.numberOfPortions
        let ingredientText = count == 1 ? "1 ingredient" : "\(count) ingredients"
        let portionText = portions == 1 ? "1 portion" : "\(portions) portions"
        return "\(ingredientText) · \(portionText)"
    }
}

#Preview {
    MealsListView()
}
