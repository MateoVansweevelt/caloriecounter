import Foundation
import SwiftData
import Testing
@testable import CalorieCounter

@Suite("SwiftDataLogbookRepository")
@MainActor
struct SwiftDataLogbookRepositoryTests {

    private func makeContainer() throws -> ModelContainer {
        try AppModelContainer.make(inMemory: true)
    }

    private func makeFood() -> FoodItem {
        FoodItem(
            name: "Banana",
            source: .userCreated,
            facts: NutritionFacts(
                basis: .mass,
                energy: .init(value: 89, unit: .kilocalories),
                macros: Macros(
                    carbohydrates: .init(value: 23, unit: .grams),
                    protein: .init(value: 1.1, unit: .grams),
                    fat: .init(value: 0.3, unit: .grams)
                )
            )
        )
    }

    @Test("append then fetch returns the entry")
    func appendAndFetch() async throws {
        let container = try makeContainer()
        let repo = SwiftDataLogbookRepository(container: container)
        let entry = LogEntry(food: makeFood(), serving: .grams(120), consumedAt: .now, mealSlot: .lunch)
        try await repo.append(entry)

        let entries = try await repo.entries(on: .now)
        #expect(entries.count == 1)
        #expect(entries.first?.id == entry.id)
        #expect(entries.first?.food.name == "Banana")
    }

    @Test("delete removes the entry")
    func deleteRemoves() async throws {
        let container = try makeContainer()
        let repo = SwiftDataLogbookRepository(container: container)
        let entry = LogEntry(food: makeFood(), serving: .grams(100), consumedAt: .now, mealSlot: .snack)
        try await repo.append(entry)
        try await repo.delete(entryID: entry.id)

        let entries = try await repo.entries(on: .now)
        #expect(entries.isEmpty)
    }

    @Test("range query respects [start, end)")
    func rangeQuery() async throws {
        let container = try makeContainer()
        let repo = SwiftDataLogbookRepository(container: container)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        try await repo.append(LogEntry(food: makeFood(), serving: .grams(50), consumedAt: today, mealSlot: .breakfast))
        try await repo.append(LogEntry(food: makeFood(), serving: .grams(50), consumedAt: yesterday, mealSlot: .snack))

        let todaysEntries = try await repo.entries(on: today)
        #expect(todaysEntries.count == 1)
    }
}
