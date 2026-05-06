import Foundation
import SwiftUI
import SwiftData
import Testing
@testable import CalorieCounter

@Suite("AppDependencies")
struct AppDependenciesTests {

    @Test("EnvironmentValues stores and retrieves dependencies")
    func environmentKeyStoresAndRetrieves() {
        var env = EnvironmentValues()
        #expect(env.dependencies == nil)

        let deps = AppDependencies(
            modelContainer: try! AppModelContainer.make(inMemory: true),
            nutritionProvider: FakeNutritionProvider(),
            logbook: FakeLogbookRepository(),
            health: NullHealthRepository(),
            meals: FakeMealRepository()
        )
        env.dependencies = deps
        // Reference equality since AppDependencies is a class
        #expect(env.dependencies === deps)
    }

    @Test("live() builds with NullHealthRepository and expected concrete services")
    func liveBuildsWithNullHealth() throws {
        let deps = try AppDependencies.live()
        let healthType = String(describing: type(of: deps.health))
        let nutritionType = String(describing: type(of: deps.nutritionProvider))
        let mealsType = String(describing: type(of: deps.meals))
        let logbookType = String(describing: type(of: deps.logbook))

        #expect(healthType.contains("NullHealthRepository"))
        #expect(nutritionType.contains("OpenFoodFactsClient"))
        #expect(mealsType.contains("SwiftDataMealRepository"))
        #expect(logbookType.contains("HealthSyncing"))
    }
}

// MARK: - Fakes

private actor FakeLogbookRepository: LogbookRepository {
    func append(_ entry: LogEntry) async throws {}
    func delete(entryID: UUID) async throws {}
    func update(_ entry: LogEntry) async throws {}
    func entries(on day: Date) async throws -> [LogEntry] { [] }
    func entries(from start: Date, to end: Date) async throws -> [LogEntry] { [] }
    func loggedDays(limit: Int) async throws -> [Date] { [] }
}

private actor FakeMealRepository: MealRepository {
    func all() async throws -> [CustomMeal] { [] }
    func save(_ meal: CustomMeal) async throws {}
    func delete(_ meal: CustomMeal) async throws {}
}

private actor FakeNutritionProvider: NutritionProvider {
    func lookup(barcode: String) async throws -> FoodItem? { nil }
    func search(query: String, limit: Int) async throws -> [FoodItem] { [] }
}
