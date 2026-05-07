import Foundation

/// Lightweight summary of today's nutrition, shared between the iOS app, widget, and Watch
/// via the App Group **container** (JSON files). Kept small so extensions do not need SwiftData.
/// UserDefaults in app groups is avoided on watchOS to reduce `CFPrefsPlistSource` / cfprefsd warnings and read failures.
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

    private static let legacyDefaultsKey = "today.calorieSnapshot"
    private static let calorieFilename = "SharedCalorieSnapshot.json"

    private static var groupContainerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
    }

    private static var calorieFileURL: URL? {
        groupContainerURL?.appendingPathComponent(calorieFilename, isDirectory: false)
    }

    private static var legacyDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    public static func save(_ snapshot: CalorieSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        if let url = calorieFileURL {
            do {
                try data.write(to: url, options: [.atomic])
                return
            } catch {
                // Fall through to UserDefaults when the container is unavailable (e.g. mis-provisioned).
            }
        }
        legacyDefaults?.set(data, forKey: legacyDefaultsKey)
    }

    public static func load() -> CalorieSnapshot? {
        if let url = calorieFileURL, let data = try? Data(contentsOf: url), !data.isEmpty {
            if let decoded = try? JSONDecoder().decode(CalorieSnapshot.self, from: data) {
                return decoded
            }
        }
        guard let defaults = legacyDefaults, let data = defaults.data(forKey: legacyDefaultsKey), !data.isEmpty else { return nil }
        guard let decoded = try? JSONDecoder().decode(CalorieSnapshot.self, from: data) else { return nil }
        if let url = calorieFileURL { try? data.write(to: url, options: [.atomic]) }
        return decoded
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
    private static let legacyDefaultsKey = "today.macroSnapshot"
    private static let macroFilename = "SharedMacroSnapshot.json"

    private static var macroFileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: CalorieSnapshotStore.appGroupID)?
            .appendingPathComponent(macroFilename, isDirectory: false)
    }

    private static var legacyDefaults: UserDefaults? {
        UserDefaults(suiteName: CalorieSnapshotStore.appGroupID)
    }

    public static func save(_ snapshot: MacroSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        if let url = macroFileURL {
            do {
                try data.write(to: url, options: [.atomic])
                return
            } catch {
            }
        }
        legacyDefaults?.set(data, forKey: legacyDefaultsKey)
    }

    public static func load() -> MacroSnapshot? {
        if let url = macroFileURL, let data = try? Data(contentsOf: url), !data.isEmpty {
            if let decoded = try? JSONDecoder().decode(MacroSnapshot.self, from: data) {
                return decoded
            }
        }
        guard let defaults = legacyDefaults, let data = defaults.data(forKey: legacyDefaultsKey), !data.isEmpty else { return nil }
        guard let decoded = try? JSONDecoder().decode(MacroSnapshot.self, from: data) else { return nil }
        if let url = macroFileURL { try? data.write(to: url, options: [.atomic]) }
        return decoded
    }
}
