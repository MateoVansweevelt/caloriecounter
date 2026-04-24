import Foundation

public enum ServingBasis: String, Hashable, Sendable, Codable {
    case mass
    case volume
}

public struct Serving: Hashable, Sendable, Codable {
    public var basis: ServingBasis
    public var amount: Double
    public var label: String?

    public init(basis: ServingBasis, amount: Double, label: String? = nil) {
        self.basis = basis
        self.amount = amount
        self.label = label
    }

    public static func grams(_ g: Double, label: String? = nil) -> Serving {
        .init(basis: .mass, amount: g, label: label)
    }

    public static func millilitres(_ ml: Double, label: String? = nil) -> Serving {
        .init(basis: .volume, amount: ml, label: label)
    }

    public var formattedAmount: String {
        let unit = basis == .mass ? "g" : "ml"
        return "\(Int(amount.rounded())) \(unit)"
    }

    public var displayLabel: String {
        if let label, !label.isEmpty { return "\(label) · \(formattedAmount)" }
        return formattedAmount
    }

    /// Multiplier to apply to per-100g/ml nutrition facts.
    public var factorPerHundred: Double { amount / 100.0 }
}
