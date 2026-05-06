import Foundation
import SwiftData
import Testing
@testable import CalorieCounter

@Suite("PersistedMealMapping")
@MainActor
struct PersistedMealMappingTests {

    @Test("make(from:) then meal(from:) round-trips fields and ingredients")
    func makeFromMealAndRoundTrip() throws {
        let created = Date(timeIntervalSince1970: 1_700_000_000)
        let updated = Date(timeIntervalSince1970: 1_700_000_100)
        let meal = CustomMeal(
            id: UUID(),
            name: "Pasta",
            ingredients: [
                makeIngredient(name: "Noodles", kcalPer100: 150, amount: 100),
                makeIngredient(name: "Sauce", kcalPer100: 50, amount: 200)
            ],
            numberOfPortions: 2,
            createdAt: created,
            updatedAt: updated
        )

        let model = try PersistedMealMapping.make(from: meal)
        let roundTrip = try PersistedMealMapping.meal(from: model)

        #expect(roundTrip.id == meal.id)
        #expect(roundTrip.name == meal.name)
        #expect(roundTrip.numberOfPortions == meal.numberOfPortions)
        #expect(roundTrip.createdAt == created)
        #expect(roundTrip.updatedAt == updated)
        #expect(roundTrip.ingredients == meal.ingredients)
    }

    @Test("apply updates mutable fields and preserves identity and createdAt")
    func applyUpdatesFields() throws {
        let created = Date(timeIntervalSince1970: 1_700_000_000)
        let updated1 = Date(timeIntervalSince1970: 1_700_000_100)
        let updated2 = Date(timeIntervalSince1970: 1_700_000_200)
        let original = CustomMeal(
            id: UUID(),
            name: "Original",
            ingredients: [makeIngredient(name: "A", kcalPer100: 100, amount: 100)],
            numberOfPortions: 1,
            createdAt: created,
            updatedAt: updated1
        )
        let model = try PersistedMealMapping.make(from: original)

        let edited = CustomMeal(
            id: original.id,
            name: "Edited",
            ingredients: [makeIngredient(name: "B", kcalPer100: 200, amount: 50)],
            numberOfPortions: 3,
            createdAt: created,
            updatedAt: updated2
        )

        try PersistedMealMapping.apply(edited, to: model)

        #expect(model.id == original.id)
        #expect(model.name == "Edited")
        #expect(model.numberOfPortions == 3)
        #expect(model.createdAt == created)
        #expect(model.updatedAt == updated2)

        let decoded = try PersistedMealMapping.meal(from: model)
        #expect(decoded.ingredients == edited.ingredients)
    }

    // MARK: - Helpers

    private func makeIngredient(name: String, kcalPer100: Double, amount: Double) -> MealIngredient {
        let facts = NutritionFacts(
            basis: .mass,
            energy: .init(value: kcalPer100, unit: .kilocalories),
            macros: Macros(
                carbohydrates: .init(value: 0, unit: .grams),
                protein: .init(value: 0, unit: .grams),
                fat: .init(value: 0, unit: .grams)
            )
        )
        let food = FoodItem(name: name, source: .userCreated, facts: facts)
        return MealIngredient(food: food, amount: amount)
    }
}
