import Foundation

public enum UnitSystem: String, CaseIterable, Hashable, Sendable {
    case metric
    case imperial

    public var displayName: String {
        switch self {
        case .metric: "Metric"
        case .imperial: "Imperial"
        }
    }

    public static let storageKey = "unitSystem"

    /// Reads the user's current preference from UserDefaults. Defaults to `.metric`.
    public static var current: UnitSystem {
        let raw = UserDefaults.standard.string(forKey: storageKey) ?? ""
        return UnitSystem(rawValue: raw) ?? .metric
    }
}
