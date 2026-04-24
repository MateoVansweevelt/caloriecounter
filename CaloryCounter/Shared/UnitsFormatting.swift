import Foundation

enum UnitsFormatting {
    static func calories(_ energy: Measurement<UnitEnergy>) -> String {
        let kcal = energy.converted(to: .kilocalories)
        return "\(Int(kcal.value.rounded())) kcal"
    }

    static func grams(_ mass: Measurement<UnitMass>, system: UnitSystem = .current) -> String {
        switch system {
        case .metric:
            return metricMass(mass)
        case .imperial:
            return imperialMass(mass)
        }
    }

    private static func metricMass(_ mass: Measurement<UnitMass>) -> String {
        let grams = mass.converted(to: .grams).value
        if grams < 1 {
            let mg = mass.converted(to: .milligrams).value
            return String(format: "%.0f mg", mg)
        }
        if grams < 10 {
            return String(format: "%.1f g", grams)
        }
        return "\(Int(grams.rounded())) g"
    }

    private static func imperialMass(_ mass: Measurement<UnitMass>) -> String {
        let grams = mass.converted(to: .grams).value
        if grams < 1 {
            let mg = mass.converted(to: .milligrams).value
            return String(format: "%.0f mg", mg)
        }
        let ounces = mass.converted(to: .ounces).value
        if ounces < 16 {
            return String(format: "%.2f oz", ounces)
        }
        let pounds = mass.converted(to: .pounds).value
        return String(format: "%.2f lb", pounds)
    }
}
