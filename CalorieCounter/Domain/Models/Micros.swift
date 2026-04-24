import Foundation

/// Keyed, extensible store of micronutrients. Adding a new one is a one-line enum case.
/// Values are stored in a type-erased `MicroValue` so a single map can hold both
/// mass-based (vitamins, minerals) and International-Unit-based micros.
public enum MicroKey: String, CaseIterable, Hashable, Sendable, Codable {
    // Minerals
    case sodium
    case potassium
    case calcium
    case iron
    case magnesium
    case zinc
    // Vitamins
    case vitaminA
    case vitaminC
    case vitaminD
    case vitaminE
    case vitaminB6
    case vitaminB12
    case folate

    public var displayName: String {
        switch self {
        case .sodium: "Sodium"
        case .potassium: "Potassium"
        case .calcium: "Calcium"
        case .iron: "Iron"
        case .magnesium: "Magnesium"
        case .zinc: "Zinc"
        case .vitaminA: "Vitamin A"
        case .vitaminC: "Vitamin C"
        case .vitaminD: "Vitamin D"
        case .vitaminE: "Vitamin E"
        case .vitaminB6: "Vitamin B6"
        case .vitaminB12: "Vitamin B12"
        case .folate: "Folate"
        }
    }
}

public struct MicroValue: Hashable, Sendable, Codable {
    /// Stored in grams for mass-based micros. IU-based micros are not expressed here yet —
    /// add a sibling case when we import data that needs it.
    public var mass: Measurement<UnitMass>

    public init(mass: Measurement<UnitMass>) {
        self.mass = mass
    }

    public static func milligrams(_ mg: Double) -> MicroValue {
        .init(mass: .init(value: mg, unit: .milligrams))
    }

    public static func micrograms(_ µg: Double) -> MicroValue {
        .init(mass: .init(value: µg, unit: .micrograms))
    }

    public func scaled(by factor: Double) -> MicroValue {
        .init(mass: mass * factor)
    }

    public static func + (lhs: MicroValue, rhs: MicroValue) -> MicroValue {
        .init(mass: lhs.mass + rhs.mass)
    }
}

public struct Micros: Hashable, Sendable, Codable {
    public var values: [MicroKey: MicroValue]

    public init(_ values: [MicroKey: MicroValue] = [:]) {
        self.values = values
    }

    public static let empty = Micros()

    public subscript(key: MicroKey) -> MicroValue? {
        get { values[key] }
        set { values[key] = newValue }
    }

    public func scaled(by factor: Double) -> Micros {
        Micros(values.mapValues { $0.scaled(by: factor) })
    }

    public static func + (lhs: Micros, rhs: Micros) -> Micros {
        var merged = lhs.values
        for (key, value) in rhs.values {
            merged[key] = merged[key].map { $0 + value } ?? value
        }
        return Micros(merged)
    }
}
