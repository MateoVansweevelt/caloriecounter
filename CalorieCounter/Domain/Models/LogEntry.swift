import Foundation

/// A single item consumed by the user at a specific time. Stores a denormalised snapshot of the
/// food so the log stays stable even if the source data (e.g. Open Food Facts) later changes.
public struct LogEntry: Identifiable, Hashable, Sendable, Codable {
    public var id: UUID
    public var food: FoodItem
    public var serving: Serving
    public var consumedAt: Date
    public var mealSlot: MealSlot
    public var note: String?

    public init(
        id: UUID = UUID(),
        food: FoodItem,
        serving: Serving,
        consumedAt: Date = .now,
        mealSlot: MealSlot? = nil,
        note: String? = nil
    ) {
        self.id = id
        self.food = food
        self.serving = serving
        self.consumedAt = consumedAt
        self.mealSlot = mealSlot ?? .inferred(at: consumedAt)
        self.note = note
    }

    public var consumed: ConsumedNutrition {
        food.facts.values(for: serving)
    }
}

public enum DailyTotals {
    public static func totals(for entries: [LogEntry]) -> ConsumedNutrition {
        entries.reduce(.zero) { $0 + $1.consumed }
    }

    public static func grouped(by slot: [LogEntry]) -> [MealSlot: [LogEntry]] {
        Dictionary(grouping: slot, by: \.mealSlot)
    }
}
