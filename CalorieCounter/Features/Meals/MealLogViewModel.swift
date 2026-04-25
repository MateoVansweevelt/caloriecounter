import Foundation

@MainActor
@Observable
final class MealLogViewModel {
    let meal: CustomMeal
    var portions: Int = 1
    var consumedAt: Date = .now
    var mealSlot: MealSlot = .inferred(at: .now)
    var note: String = ""
    var isSaving = false

    private let logbook: any LogbookRepository

    init(meal: CustomMeal, logbook: any LogbookRepository) {
        self.meal = meal
        self.logbook = logbook
    }

    var nutritionForPortions: ConsumedNutrition {
        guard portions > 0 else { return .zero }
        let factor = Double(portions)
        let perPortion = meal.nutritionPerPortion
        return ConsumedNutrition(
            energy: perPortion.energy * factor,
            macros: perPortion.macros.scaled(by: factor),
            micros: perPortion.micros.scaled(by: factor)
        )
    }

    func save() async -> Bool {
        isSaving = true
        defer { isSaving = false }

        let foodItem = meal.asFoodItem()
        let amountPerPortion = meal.totalAmount / Double(max(meal.numberOfPortions, 1))
        let totalAmount = amountPerPortion * Double(portions)
        let serving = Serving(
            basis: meal.basis,
            amount: totalAmount,
            label: portions == 1 ? "1 portion" : "\(portions) portions"
        )

        let entry = LogEntry(
            food: foodItem,
            serving: serving,
            consumedAt: consumedAt,
            mealSlot: mealSlot,
            note: note.isEmpty ? nil : note
        )

        do {
            try await logbook.append(entry)
            return true
        } catch {
            return false
        }
    }
}
