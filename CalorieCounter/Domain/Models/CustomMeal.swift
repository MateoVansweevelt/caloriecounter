import Foundation

public struct MealIngredient: Identifiable, Hashable, Sendable, Codable {
    public var id: UUID
    public var food: FoodItem
    public var amount: Double

    public init(id: UUID = UUID(), food: FoodItem, amount: Double) {
        self.id = id
        self.food = food
        self.amount = amount
    }

    public var unit: String { food.facts.basis == .mass ? "g" : "ml" }

    public var serving: Serving {
        Serving(basis: food.facts.basis, amount: amount)
    }

    public var nutrition: ConsumedNutrition {
        food.facts.values(for: serving)
    }
}

public struct CustomMeal: Identifiable, Hashable, Sendable, Codable {
    public var id: UUID
    public var name: String
    public var ingredients: [MealIngredient]
    public var numberOfPortions: Int
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        ingredients: [MealIngredient] = [],
        numberOfPortions: Int = 1,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.ingredients = ingredients
        self.numberOfPortions = numberOfPortions
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public var totalNutrition: ConsumedNutrition {
        ingredients.reduce(.zero) { $0 + $1.nutrition }
    }

    public var nutritionPerPortion: ConsumedNutrition {
        guard numberOfPortions > 0 else { return .zero }
        let factor = 1.0 / Double(numberOfPortions)
        let total = totalNutrition
        return ConsumedNutrition(
            energy: total.energy * factor,
            macros: total.macros.scaled(by: factor),
            micros: total.micros.scaled(by: factor)
        )
    }

    public var totalGrams: Double {
        ingredients.reduce(0) { $0 + $1.amount }
    }

    /// Converts this meal to a `FoodItem` with per-100g nutrition so it can be logged
    /// using the standard FoodDetailView. The suggested serving is one portion.
    public func asFoodItem() -> FoodItem {
        let perPortion = nutritionPerPortion
        let gramsPerPortion = totalGrams / Double(max(numberOfPortions, 1))
        let per100factor = gramsPerPortion > 0 ? 100.0 / gramsPerPortion : 1.0

        let facts = NutritionFacts(
            basis: .mass,
            energy: perPortion.energy * per100factor,
            macros: perPortion.macros.scaled(by: per100factor),
            micros: perPortion.micros.scaled(by: per100factor)
        )

        return FoodItem(
            id: id,
            name: name,
            source: .userCreated,
            facts: facts,
            suggestedServings: [
                Serving(basis: .mass, amount: gramsPerPortion, label: "1 portion")
            ]
        )
    }
}
