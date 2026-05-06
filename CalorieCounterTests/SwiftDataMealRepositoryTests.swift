import Foundation
import SwiftData
import Testing
@testable import CalorieCounter

@Suite("SwiftDataMealRepository")
@MainActor
struct SwiftDataMealRepository_NewTests {

    private func makeContainer() throws -> ModelContainer {
        try AppModelContainer.make(inMemory: true)
    }

    private func makeMeal(name: String, numberOfPortions: Int, updatedAt: Date) -> CustomMeal {
        let facts = NutritionFacts(
            basis: .mass,
            energy: .init(value: 100, unit: .kilocalories),
            macros: Macros(
                carbohydrates: .init(value: 0, unit: .grams),
                protein: .init(value: 0, unit: .grams),
                fat: .init(value: 0, unit: .grams)
            )
        )
        let ingredient = MealIngredient(food: FoodItem(name: "X", source: .userCreated, facts: facts), amount: 100)
        return CustomMeal(name: name, ingredients: [ingredient], numberOfPortions: numberOfPortions, createdAt: .distantPast, updatedAt: updatedAt)
    }

    @Test("save then all() returns meals sorted by updatedAt descending")
    func saveThenAllReturnsSavedInReverseUpdatedAt() async throws {
        let container = try makeContainer()
        let repo = SwiftDataMealRepository(container: container)
        let older = makeMeal(name: "A", numberOfPortions: 1, updatedAt: Date(timeIntervalSince1970: 1000))
        let newer = makeMeal(name: "B", numberOfPortions: 2, updatedAt: Date(timeIntervalSince1970: 2000))

        try await repo.save(older)
        try await repo.save(newer)

        let all = try await repo.all()
        #expect(all.map { $0.name } == ["B", "A"])
    }

    @Test("save upserts existing meal by id")
    func saveUpsertsExisting() async throws {
        let container = try makeContainer()
        let repo = SwiftDataMealRepository(container: container)
        var meal = makeMeal(name: "Orig", numberOfPortions: 1, updatedAt: Date(timeIntervalSince1970: 1000))

        try await repo.save(meal)

        meal.name = "Edited"
        meal.numberOfPortions = 3
        meal.updatedAt = Date(timeIntervalSince1970: 3000)

        try await repo.save(meal)

        let all = try await repo.all()
        #expect(all.count == 1)
        #expect(all.first?.name == "Edited")
        #expect(all.first?.numberOfPortions == 3)
    }

    @Test("delete removes the meal")
    func deleteRemovesMeal() async throws {
        let container = try makeContainer()
        let repo = SwiftDataMealRepository(container: container)
        let meal = makeMeal(name: "ToDelete", numberOfPortions: 1, updatedAt: Date(timeIntervalSince1970: 1000))

        try await repo.save(meal)
        try await repo.delete(meal)

        let all = try await repo.all()
        #expect(all.isEmpty)
    }
}
