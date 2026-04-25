import Foundation
import SwiftData

@Model
public final class PersistedMeal {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var ingredientsData: Data
    public var numberOfPortions: Int
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID,
        name: String,
        ingredientsData: Data,
        numberOfPortions: Int,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.name = name
        self.ingredientsData = ingredientsData
        self.numberOfPortions = numberOfPortions
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

enum PersistedMealMapping {
    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()

    static func make(from meal: CustomMeal) throws -> PersistedMeal {
        let data = try encoder.encode(meal.ingredients)
        return PersistedMeal(
            id: meal.id,
            name: meal.name,
            ingredientsData: data,
            numberOfPortions: meal.numberOfPortions,
            createdAt: meal.createdAt,
            updatedAt: meal.updatedAt
        )
    }

    static func meal(from model: PersistedMeal) throws -> CustomMeal {
        let ingredients = try decoder.decode([MealIngredient].self, from: model.ingredientsData)
        return CustomMeal(
            id: model.id,
            name: model.name,
            ingredients: ingredients,
            numberOfPortions: model.numberOfPortions,
            createdAt: model.createdAt,
            updatedAt: model.updatedAt
        )
    }

    static func apply(_ meal: CustomMeal, to model: PersistedMeal) throws {
        model.name = meal.name
        model.ingredientsData = try encoder.encode(meal.ingredients)
        model.numberOfPortions = meal.numberOfPortions
        model.updatedAt = meal.updatedAt
    }
}
