import Foundation
import Testing
@testable import CalorieCounter

@Suite("CustomMeal")
struct CustomMealTests {

    @Test("basis is .volume when all ingredients are volume-based")
    func basisWhenAllVolumeIsVolume() {
        let volFood1 = makeFood(basis: .volume, kcalPer100: 40)
        let volFood2 = makeFood(basis: .volume, kcalPer100: 20)
        let ing1 = MealIngredient(food: volFood1, amount: 100)
        let ing2 = MealIngredient(food: volFood2, amount: 50)
        let meal = CustomMeal(name: "Smoothie", ingredients: [ing1, ing2], numberOfPortions: 1)
        #expect(meal.basis == .volume)
    }

    @Test("basis is .mass for mixed or empty meals")
    func basisWhenMixedDefaultsToMass() {
        let volFood = makeFood(basis: .volume, kcalPer100: 40)
        let massFood = makeFood(basis: .mass, kcalPer100: 100)
        let mixed = CustomMeal(
            name: "Mixed",
            ingredients: [MealIngredient(food: volFood, amount: 100), MealIngredient(food: massFood, amount: 100)],
            numberOfPortions: 1
        )
        #expect(mixed.basis == .mass)

        let empty = CustomMeal(name: "Empty", ingredients: [], numberOfPortions: 1)
        #expect(empty.basis == .mass)
    }

    @Test("total and per-portion nutrition are computed correctly")
    func totalAndPerPortionNutrition() {
        // 100g at 100 kcal/100g -> 100 kcal
        let f1 = makeFood(basis: .mass, kcalPer100: 100)
        // 200g at 50 kcal/100g -> 100 kcal
        let f2 = makeFood(basis: .mass, kcalPer100: 50)
        let ing1 = MealIngredient(food: f1, amount: 100)
        let ing2 = MealIngredient(food: f2, amount: 200)
        let meal = CustomMeal(name: "Combo", ingredients: [ing1, ing2], numberOfPortions: 3)

        let total = meal.totalNutrition.energy.converted(to: .kilocalories).value
        #expect(abs(total - 200) < 0.001)

        let perPortion = meal.nutritionPerPortion.energy.converted(to: .kilocalories).value
        #expect(abs(perPortion - (200.0 / 3.0)) < 0.01)
    }

    @Test("per-portion is zero when numberOfPortions == 0")
    func perPortionWhenZeroPortionsIsZero() {
        let f = makeFood(basis: .mass, kcalPer100: 100)
        let meal = CustomMeal(name: "One", ingredients: [MealIngredient(food: f, amount: 100)], numberOfPortions: 0)
        let kcal = meal.nutritionPerPortion.energy.converted(to: .kilocalories).value
        #expect(kcal == 0)
    }

    @Test("asFoodItem produces per-100 facts and a suggested 1-portion serving")
    func asFoodItemProducesPer100FactsAndSuggestedPortion() {
        // 200g at 100 kcal/100g, 2 portions -> each portion 100g, per-100 facts should be 100 kcal
        let f = makeFood(basis: .mass, kcalPer100: 100)
        let meal = CustomMeal(name: "Meal", ingredients: [MealIngredient(food: f, amount: 200)], numberOfPortions: 2)
        let item = meal.asFoodItem()

        #expect(item.facts.basis == .mass)
        let kcal = item.facts.energy.converted(to: .kilocalories).value
        #expect(abs(kcal - 100) < 0.001)
        #expect(item.suggestedServings.contains { $0.amount == 100 && $0.label == "1 portion" })
    }

    // MARK: - Helpers

    private func makeFood(basis: ServingBasis, kcalPer100: Double) -> FoodItem {
        let macros = Macros(
            carbohydrates: .init(value: 0, unit: .grams),
            protein: .init(value: 0, unit: .grams),
            fat: .init(value: 0, unit: .grams)
        )
        let facts = NutritionFacts(
            basis: basis,
            energy: .init(value: kcalPer100, unit: .kilocalories),
            macros: macros
        )
        return FoodItem(name: "Food", source: .userCreated, facts: facts)
    }
}
