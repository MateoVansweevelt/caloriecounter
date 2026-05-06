import Foundation
import Testing
@testable import CalorieCounter

@Suite("NullHealthRepository")
struct NullHealthRepositoryTests {

    @Test("availability and authorization state")
    func availabilityAndAuthorization() async {
        let repo = NullHealthRepository()
        #expect(repo.isAvailable == false)
        let status = await repo.authorizationStatus()
        #expect(status == .unavailable)
    }

    @Test("writes and removals do not throw")
    func writesAndRemovalsNoThrow() async throws {
        let repo = NullHealthRepository()
        try await repo.requestAuthorization()
        try await repo.sync(dummyLogEntry())
        try await repo.remove(entryID: UUID())
    }

    @Test("reads return zero values or nil")
    func readsReturnZero() async throws {
        let repo = NullHealthRepository()
        let day = Date(timeIntervalSince1970: 1_700_000_000)
        let active = try await repo.activeEnergyBurned(on: day).converted(to: .kilocalories).value
        let resting = try await repo.restingEnergyBurned(on: day).converted(to: .kilocalories).value
        let steps = try await repo.steps(on: day)
        let mass = try await repo.bodyMass()
        #expect(active == 0)
        #expect(resting == 0)
        #expect(steps == 0)
        #expect(mass == nil)
    }

    // MARK: - Helpers

    private func dummyLogEntry() -> LogEntry {
        let facts = NutritionFacts(
            basis: .mass,
            energy: .init(value: 100, unit: .kilocalories),
            macros: Macros(
                carbohydrates: .init(value: 0, unit: .grams),
                protein: .init(value: 0, unit: .grams),
                fat: .init(value: 0, unit: .grams)
            )
        )
        let food = FoodItem(name: "X", source: .userCreated, facts: facts)
        return LogEntry(food: food, serving: .grams(100), consumedAt: .now, mealSlot: .snack)
    }
}
