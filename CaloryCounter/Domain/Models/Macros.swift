import Foundation

public struct Macros: Hashable, Sendable, Codable {
    public var carbohydrates: Measurement<UnitMass>
    public var sugars: Measurement<UnitMass>?
    public var fiber: Measurement<UnitMass>?
    public var protein: Measurement<UnitMass>
    public var fat: Measurement<UnitMass>
    public var saturatedFat: Measurement<UnitMass>?
    public var salt: Measurement<UnitMass>?

    public init(
        carbohydrates: Measurement<UnitMass> = .zeroGrams,
        sugars: Measurement<UnitMass>? = nil,
        fiber: Measurement<UnitMass>? = nil,
        protein: Measurement<UnitMass> = .zeroGrams,
        fat: Measurement<UnitMass> = .zeroGrams,
        saturatedFat: Measurement<UnitMass>? = nil,
        salt: Measurement<UnitMass>? = nil
    ) {
        self.carbohydrates = carbohydrates
        self.sugars = sugars
        self.fiber = fiber
        self.protein = protein
        self.fat = fat
        self.saturatedFat = saturatedFat
        self.salt = salt
    }

    public static let zero = Macros()

    public func scaled(by factor: Double) -> Macros {
        Macros(
            carbohydrates: carbohydrates * factor,
            sugars: sugars.map { $0 * factor },
            fiber: fiber.map { $0 * factor },
            protein: protein * factor,
            fat: fat * factor,
            saturatedFat: saturatedFat.map { $0 * factor },
            salt: salt.map { $0 * factor }
        )
    }

    public static func + (lhs: Macros, rhs: Macros) -> Macros {
        Macros(
            carbohydrates: lhs.carbohydrates + rhs.carbohydrates,
            sugars: sumOptional(lhs.sugars, rhs.sugars),
            fiber: sumOptional(lhs.fiber, rhs.fiber),
            protein: lhs.protein + rhs.protein,
            fat: lhs.fat + rhs.fat,
            saturatedFat: sumOptional(lhs.saturatedFat, rhs.saturatedFat),
            salt: sumOptional(lhs.salt, rhs.salt)
        )
    }
}

extension Measurement where UnitType == UnitMass {
    public static var zeroGrams: Measurement<UnitMass> { .init(value: 0, unit: .grams) }
}

private func sumOptional(_ a: Measurement<UnitMass>?, _ b: Measurement<UnitMass>?) -> Measurement<UnitMass>? {
    switch (a, b) {
    case let (a?, b?): return a + b
    case let (a?, nil): return a
    case let (nil, b?): return b
    case (nil, nil): return nil
    }
}
