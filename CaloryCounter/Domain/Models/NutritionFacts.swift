import Foundation

/// Nutrition normalised to 100 g or 100 ml so scaling to any serving is a single multiplication.
public struct NutritionFacts: Hashable, Sendable, Codable {
    public var basis: ServingBasis
    public var energy: Measurement<UnitEnergy>
    public var macros: Macros
    public var micros: Micros

    public init(
        basis: ServingBasis,
        energy: Measurement<UnitEnergy>,
        macros: Macros = .zero,
        micros: Micros = .empty
    ) {
        self.basis = basis
        self.energy = energy
        self.macros = macros
        self.micros = micros
    }

    public static let zeroPerHundredGrams = NutritionFacts(
        basis: .mass,
        energy: .init(value: 0, unit: .kilocalories)
    )

    /// Produce the actual nutrition consumed for a given serving. `serving.basis` must match
    /// `self.basis`; mismatches raise a precondition because the caller should have converted
    /// volume-to-mass via density before reaching this point.
    public func values(for serving: Serving) -> ConsumedNutrition {
        precondition(serving.basis == basis, "serving basis must match nutrition basis")
        let factor = serving.factorPerHundred
        return ConsumedNutrition(
            energy: energy * factor,
            macros: macros.scaled(by: factor),
            micros: micros.scaled(by: factor)
        )
    }
}

/// The actual totals consumed for a logged entry (no per-100g assumption).
public struct ConsumedNutrition: Hashable, Sendable, Codable {
    public var energy: Measurement<UnitEnergy>
    public var macros: Macros
    public var micros: Micros

    public init(
        energy: Measurement<UnitEnergy> = .init(value: 0, unit: .kilocalories),
        macros: Macros = .zero,
        micros: Micros = .empty
    ) {
        self.energy = energy
        self.macros = macros
        self.micros = micros
    }

    public static let zero = ConsumedNutrition()

    public static func + (lhs: ConsumedNutrition, rhs: ConsumedNutrition) -> ConsumedNutrition {
        ConsumedNutrition(
            energy: lhs.energy + rhs.energy,
            macros: lhs.macros + rhs.macros,
            micros: lhs.micros + rhs.micros
        )
    }
}
