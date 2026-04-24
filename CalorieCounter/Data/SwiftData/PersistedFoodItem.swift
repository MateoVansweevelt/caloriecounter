import Foundation
import SwiftData

/// Local cache of foods previously resolved from Open Food Facts, keyed by barcode.
/// Lets the Scan flow show offline results for repeat barcodes and avoids re-fetching.
@Model
public final class PersistedFoodItem {
    @Attribute(.unique) public var barcode: String
    public var cachedAt: Date
    public var foodData: Data

    public init(barcode: String, cachedAt: Date, foodData: Data) {
        self.barcode = barcode
        self.cachedAt = cachedAt
        self.foodData = foodData
    }
}

enum PersistedFoodItemMapping {
    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()

    static func make(barcode: String, food: FoodItem, at date: Date = .now) throws -> PersistedFoodItem {
        PersistedFoodItem(
            barcode: barcode,
            cachedAt: date,
            foodData: try encoder.encode(food)
        )
    }

    static func food(from model: PersistedFoodItem) throws -> FoodItem {
        try decoder.decode(FoodItem.self, from: model.foodData)
    }
}
