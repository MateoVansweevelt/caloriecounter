import Foundation

public enum FoodSource: Hashable, Sendable, Codable {
    case openFoodFacts(barcode: String)
    case userCreated
    case imported(sourceID: String)
}

public struct FoodItem: Identifiable, Hashable, Sendable, Codable {
    public var id: UUID
    public var name: String
    public var brand: String?
    public var source: FoodSource
    public var imageURL: URL?
    public var facts: NutritionFacts
    public var suggestedServings: [Serving]

    public init(
        id: UUID = UUID(),
        name: String,
        brand: String? = nil,
        source: FoodSource,
        imageURL: URL? = nil,
        facts: NutritionFacts,
        suggestedServings: [Serving] = []
    ) {
        self.id = id
        self.name = name
        self.brand = brand
        self.source = source
        self.imageURL = imageURL
        self.facts = facts
        self.suggestedServings = suggestedServings
    }

    public var displayTitle: String {
        if let brand, !brand.isEmpty { return "\(brand) — \(name)" }
        return name
    }

    public var defaultServing: Serving {
        suggestedServings.first ?? .init(
            basis: facts.basis,
            amount: 100,
            label: facts.basis == .mass ? "100 g" : "100 ml"
        )
    }
}
