import Foundation

struct NutritionTargets: Sendable, Hashable {
    var calories: Double
    var carbsGrams: Double
    var proteinGrams: Double
    var fatGrams: Double

    init(
        calories: Double = 2200,
        carbsGrams: Double = 250,
        proteinGrams: Double = 140,
        fatGrams: Double = 70
    ) {
        self.calories = calories
        self.carbsGrams = carbsGrams
        self.proteinGrams = proteinGrams
        self.fatGrams = fatGrams
    }

    static let `default` = NutritionTargets()

    enum StorageKey {
        static let calories     = "nutritionTargets.calories"
        static let carbsGrams   = "nutritionTargets.carbsGrams"
        static let proteinGrams = "nutritionTargets.proteinGrams"
        static let fatGrams     = "nutritionTargets.fatGrams"
    }

    /// Loads persisted targets from UserDefaults, falling back to defaults for any value
    /// that is missing or invalid (≤ 0).
    static func fromUserDefaults(_ defaults: UserDefaults = .standard) -> NutritionTargets {
        func load(_ key: String, fallback: Double) -> Double {
            let v = defaults.double(forKey: key)
            return v > 0 ? v : fallback
        }
        let d = NutritionTargets.default
        return NutritionTargets(
            calories:     load(StorageKey.calories,     fallback: d.calories),
            carbsGrams:   load(StorageKey.carbsGrams,   fallback: d.carbsGrams),
            proteinGrams: load(StorageKey.proteinGrams, fallback: d.proteinGrams),
            fatGrams:     load(StorageKey.fatGrams,     fallback: d.fatGrams)
        )
    }
}
