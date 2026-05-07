import Foundation

/// Lightweight summary of today's calories, shared between the app and the widget
/// via an App Group UserDefaults suite. Kept intentionally small so the widget
/// doesn't need to pull in SwiftData.
public struct CalorieSnapshot: Codable, Hashable, Sendable {
    public var consumedKcal: Double
    public var targetKcal: Double
    public var dayStart: Date
    public var updatedAt: Date

    public var remainingKcal: Double { max(0, targetKcal - consumedKcal) }

    public var progress: Double {
        guard targetKcal > 0 else { return 0 }
        return min(1.0, consumedKcal / targetKcal)
    }

    public init(consumedKcal: Double, targetKcal: Double, dayStart: Date, updatedAt: Date = .now) {
        self.consumedKcal = consumedKcal
        self.targetKcal = targetKcal
        self.dayStart = dayStart
        self.updatedAt = updatedAt
    }

    public static let placeholder = CalorieSnapshot(
        consumedKcal: 1420,
        targetKcal: 2200,
        dayStart: Calendar.current.startOfDay(for: .now)
    )
}

public enum CalorieWidgetKind {
    public static let ring = "CalorieRingWidget"
    public static let macros = "MacrosWidget"
}

public enum CalorieSnapshotStore {
    /// Shared App Group identifier. Must be enabled on the app and widget targets.
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
