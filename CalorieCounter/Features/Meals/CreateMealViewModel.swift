import Foundation

@MainActor
@Observable
final class CreateMealViewModel {
    var name: String
    var ingredients: [MealIngredient]
    var numberOfPortions: Int
    var isSaving = false
    var basisConflictAlert: String?

    private let existing: CustomMeal?
    private let mealRepo: any MealRepository

    init(meal: CustomMeal?, mealRepo: any MealRepository) {
        self.existing = meal
        self.mealRepo = mealRepo
        self.name = meal?.name ?? ""
        self.ingredients = meal?.ingredients ?? []
        self.numberOfPortions = meal?.numberOfPortions ?? 1
    }

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !ingredients.isEmpty
    }

    var nutritionPerPortion: ConsumedNutrition {
        guard numberOfPortions > 0 else { return .zero }
        let factor = 1.0 / Double(numberOfPortions)
        let total = ingredients.reduce(ConsumedNutrition.zero) { $0 + $1.nutrition }
        return ConsumedNutrition(
            energy: total.energy * factor,
            macros: total.macros.scaled(by: factor),
            micros: total.micros.scaled(by: factor)
        )
    }

    func addIngredient(_ ingredient: MealIngredient) {
        if let existing = ingredients.first,
           existing.food.facts.basis != ingredient.food.facts.basis {
            let existingUnit = existing.food.facts.basis == .mass ? "grams (g)" : "millilitres (ml)"
            let newUnit = ingredient.food.facts.basis == .mass ? "grams (g)" : "millilitres (ml)"
            basisConflictAlert = "\"\(ingredient.food.name)\" is measured in \(newUnit), but this meal already uses \(existingUnit). Mixing units isn't supported — convert all ingredients to the same unit or create separate meals."
            return
        }
        ingredients.append(ingredient)
    }

    func removeIngredients(at offsets: IndexSet) {
        ingredients.remove(atOffsets: offsets)
    }

    func updateAmount(_ amount: Double, for ingredient: MealIngredient) {
        guard let idx = ingredients.firstIndex(where: { $0.id == ingredient.id }) else { return }
        ingredients[idx].amount = max(1, amount)
    }

    func save() async -> Bool {
        guard isValid else { return false }
        isSaving = true
        defer { isSaving = false }

        var meal = existing ?? CustomMeal(name: name)
        meal.name = name.trimmingCharacters(in: .whitespaces)
        meal.ingredients = ingredients
        meal.numberOfPortions = numberOfPortions
        meal.updatedAt = .now

        do {
            try await mealRepo.save(meal)
            return true
        } catch {
            return false
        }
    }
}
