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
}

public enum CalorieSnapshotStore {
    /// Shared App Group identifier. Must be enabled on the app and widget targets.
    public static let appGroupID = "group.com.caloriecounter.shared"

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
