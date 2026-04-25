import Foundation

public protocol MealRepository: Sendable {
    func all() async throws -> [CustomMeal]
    func save(_ meal: CustomMeal) async throws
    func delete(_ meal: CustomMeal) async throws
}
