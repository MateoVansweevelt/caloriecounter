import Foundation

public enum NutritionLookupError: Error, Sendable {
    case notFound
    case network(underlying: String)
    case decoding(underlying: String)
    case cancelled
}

public protocol NutritionProvider: Sendable {
    /// Resolve a barcode to a `FoodItem`. Returns `nil` when the barcode is not known.
    func lookup(barcode: String) async throws -> FoodItem?

    /// Free-text search. Implementations may return an empty array when unsupported.
    func search(query: String, limit: Int) async throws -> [FoodItem]
}

public extension NutritionProvider {
    func search(query: String) async throws -> [FoodItem] {
        try await search(query: query, limit: 20)
    }
}
