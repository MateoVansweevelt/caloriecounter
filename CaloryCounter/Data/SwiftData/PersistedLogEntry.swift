import Foundation
import SwiftData

/// SwiftData mirror of `LogEntry`. We store the full resolved `FoodItem` + `ConsumedNutrition`
/// as JSON blobs, keeping the schema tiny and insulating the persistence layer from future
/// domain-model evolution. This is intentional — the log is a historical record of *what the
/// user saw at the time they logged it*, and should not silently change if we later tweak
/// domain types or pull fresher data from Open Food Facts.
@Model
public final class PersistedLogEntry {
    @Attribute(.unique) public var id: UUID
    public var consumedAt: Date
    public var dayStart: Date
    public var mealSlotRaw: String
    public var note: String?
    public var foodData: Data
    public var servingData: Data

    public init(
        id: UUID,
        consumedAt: Date,
        dayStart: Date,
        mealSlotRaw: String,
        note: String?,
        foodData: Data,
        servingData: Data
    ) {
        self.id = id
        self.consumedAt = consumedAt
        self.dayStart = dayStart
        self.mealSlotRaw = mealSlotRaw
        self.note = note
        self.foodData = foodData
        self.servingData = servingData
    }
}

enum PersistedLogEntryMapping {
    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()

    static func make(from entry: LogEntry, calendar: Calendar = .current) throws -> PersistedLogEntry {
        let food = try encoder.encode(entry.food)
        let serving = try encoder.encode(entry.serving)
        return PersistedLogEntry(
            id: entry.id,
            consumedAt: entry.consumedAt,
            dayStart: calendar.startOfDay(for: entry.consumedAt),
            mealSlotRaw: entry.mealSlot.rawValue,
            note: entry.note,
            foodData: food,
            servingData: serving
        )
    }

    static func entry(from model: PersistedLogEntry) throws -> LogEntry {
        let food = try decoder.decode(FoodItem.self, from: model.foodData)
        let serving = try decoder.decode(Serving.self, from: model.servingData)
        let slot = MealSlot(rawValue: model.mealSlotRaw) ?? .inferred(at: model.consumedAt)
        return LogEntry(
            id: model.id,
            food: food,
            serving: serving,
            consumedAt: model.consumedAt,
            mealSlot: slot,
            note: model.note
        )
    }

    static func apply(_ entry: LogEntry, to model: PersistedLogEntry, calendar: Calendar = .current) throws {
        model.consumedAt = entry.consumedAt
        model.dayStart = calendar.startOfDay(for: entry.consumedAt)
        model.mealSlotRaw = entry.mealSlot.rawValue
        model.note = entry.note
        model.foodData = try encoder.encode(entry.food)
        model.servingData = try encoder.encode(entry.serving)
    }
}
