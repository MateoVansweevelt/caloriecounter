import Foundation

/// Lightweight summary of today's nutrition, shared between the iOS app, widget, and Watch
/// via an App Group UserDefaults suite. Kept small so extensions do not need SwiftData.
public struct CalorieSnapshot: Codable, Hashable, Sendable {
    public var consumedKcal: Double
    public var targetKcal: Double
    public var consumedCarbsG: Double
    public var consumedProteinG: Double
    public var consumedFatG: Double
    public var targetCarbsG: Double
    public var targetProteinG: Double
    public var targetFatG: Double
    public var dayStart: Date
    public var updatedAt: Date

    public var remainingKcal: Double { max(0, targetKcal - consumedKcal) }

    public var progress: Double {
        guard targetKcal > 0 else { return 0 }
        return min(1.0, consumedKcal / targetKcal)
    }

    public func macroRemaining(target: Double, consumed: Double) -> Double {
        guard target > 0 else { return 0 }
        return max(0, target - consumed)
    }

    public init(
        consumedKcal: Double,
        targetKcal: Double,
        consumedCarbsG: Double = 0,
        consumedProteinG: Double = 0,
        consumedFatG: Double = 0,
        targetCarbsG: Double = 0,
        targetProteinG: Double = 0,
        targetFatG: Double = 0,
        dayStart: Date,
        updatedAt: Date = .now
    ) {
        self.consumedKcal = consumedKcal
        self.targetKcal = targetKcal
        self.consumedCarbsG = consumedCarbsG
        self.consumedProteinG = consumedProteinG
        self.consumedFatG = consumedFatG
        self.targetCarbsG = targetCarbsG
        self.targetProteinG = targetProteinG
        self.targetFatG = targetFatG
        self.dayStart = dayStart
        self.updatedAt = updatedAt
    }

    public static let placeholder = CalorieSnapshot(
        consumedKcal: 1420,
        targetKcal: 2200,
        consumedCarbsG: 178,
        consumedProteinG: 92,
        consumedFatG: 48,
        targetCarbsG: 250,
        targetProteinG: 140,
        targetFatG: 70,
        dayStart: Calendar.current.startOfDay(for: .now)
    )

    private enum CodingKeys: String, CodingKey {
        case consumedKcal, targetKcal, dayStart, updatedAt
        case consumedCarbsG, consumedProteinG, consumedFatG
        case targetCarbsG, targetProteinG, targetFatG
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        consumedKcal = try c.decode(Double.self, forKey: .consumedKcal)
        targetKcal = try c.decode(Double.self, forKey: .targetKcal)
        dayStart = try c.decode(Date.self, forKey: .dayStart)
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? .now
        consumedCarbsG = try c.decodeIfPresent(Double.self, forKey: .consumedCarbsG) ?? 0
        consumedProteinG = try c.decodeIfPresent(Double.self, forKey: .consumedProteinG) ?? 0
        consumedFatG = try c.decodeIfPresent(Double.self, forKey: .consumedFatG) ?? 0
        targetCarbsG = try c.decodeIfPresent(Double.self, forKey: .targetCarbsG) ?? 0
        targetProteinG = try c.decodeIfPresent(Double.self, forKey: .targetProteinG) ?? 0
        targetFatG = try c.decodeIfPresent(Double.self, forKey: .targetFatG) ?? 0
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(consumedKcal, forKey: .consumedKcal)
        try c.encode(targetKcal, forKey: .targetKcal)
        try c.encode(dayStart, forKey: .dayStart)
        try c.encode(updatedAt, forKey: .updatedAt)
        try c.encode(consumedCarbsG, forKey: .consumedCarbsG)
        try c.encode(consumedProteinG, forKey: .consumedProteinG)
        try c.encode(consumedFatG, forKey: .consumedFatG)
        try c.encode(targetCarbsG, forKey: .targetCarbsG)
        try c.encode(targetProteinG, forKey: .targetProteinG)
        try c.encode(targetFatG, forKey: .targetFatG)
    }
}

public enum CalorieWidgetKind {
    public static let ring = "CalorieRingWidget"
    public static let macros = "MacrosWidget"
}

public enum CalorieSnapshotStore {
    /// Shared App Group identifier — must match every target’s App Groups capability
    /// (`CalorieCounter.entitlements`, `CalorieCounterWidget.entitlements`, Watch entitlements).
    public static let appGroupID = "group.mateovansweevelt.caloriecounter"

    private static let key = "today.calorieSnapshot"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    public static func save(_ snapshot: CalorieSnapshot) {
        guard let defaults else { return }
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: key)
    }

    public static func load() -> CalorieSnapshot? {
        guard let defaults, let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(CalorieSnapshot.self, from: data)
    }
}

public struct MacroSnapshot: Codable, Hashable, Sendable {
    public var consumedCarbsGrams: Double
    public var consumedProteinGrams: Double
    public var consumedFatGrams: Double
    public var targetCarbsGrams: Double
    public var targetProteinGrams: Double
    public var targetFatGrams: Double
    public var dayStart: Date
    public var updatedAt: Date

    public init(
        consumedCarbsGrams: Double,
        consumedProteinGrams: Double,
        consumedFatGrams: Double,
        targetCarbsGrams: Double,
        targetProteinGrams: Double,
        targetFatGrams: Double,
        dayStart: Date,
        updatedAt: Date = .now
    ) {
        self.consumedCarbsGrams = consumedCarbsGrams
        self.consumedProteinGrams = consumedProteinGrams
        self.consumedFatGrams = consumedFatGrams
        self.targetCarbsGrams = targetCarbsGrams
        self.targetProteinGrams = targetProteinGrams
        self.targetFatGrams = targetFatGrams
        self.dayStart = dayStart
        self.updatedAt = updatedAt
    }

    public static let placeholder = MacroSnapshot(
        consumedCarbsGrams: 120,
        consumedProteinGrams: 60,
        consumedFatGrams: 40,
        targetCarbsGrams: 250,
        targetProteinGrams: 140,
        targetFatGrams: 70,
        dayStart: Calendar.current.startOfDay(for: .now)
    )
}

public enum MacroSnapshotStore {
    private static let key = "today.macroSnapshot"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: CalorieSnapshotStore.appGroupID)
    }

    public static func save(_ snapshot: MacroSnapshot) {
        guard let defaults else { return }
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: key)
    }

    public static func load() -> MacroSnapshot? {
        guard let defaults, let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(MacroSnapshot.self, from: data)
    }
}
