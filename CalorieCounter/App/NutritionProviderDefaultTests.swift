import Foundation
import Testing
@testable import CalorieCounter

@Suite("NutritionProvider Defaults")
actor NutritionProviderDefaultTests {

    actor StubProvider: NutritionProvider {
        private(set) var lastLimit: Int?
        func lookup(barcode: String) async throws -> FoodItem? { nil }
        func search(query: String, limit: Int) async throws -> [FoodItem] {
            lastLimit = limit
            return []
        }
    }

    @Test("default search(query:) uses limit 20")
    func defaultLimitIs20() async throws {
        let provider = StubProvider()
        _ = try await provider.search(query: "hello")
        let limit = await provider.lastLimit
        #expect(limit == 20)
    }
}
