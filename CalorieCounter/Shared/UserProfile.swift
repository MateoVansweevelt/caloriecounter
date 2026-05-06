import Foundation

struct UserProfile: Sendable {

    // MARK: - Enums

    enum BiologicalSex: String, CaseIterable, Sendable {
        case male, female, other

        var displayName: String {
            switch self {
            case .male:   "Male"
            case .female: "Female"
            case .other:  "Other"
            }
        }

        fileprivate var bmrOffset: Double {
            switch self {
            case .male:    5
            case .female: -161
            case .other:  -78    // midpoint of male/female offsets
            }
        }
    }

    enum ActivityLevel: String, CaseIterable, Sendable {
        case sedentary
        case lightlyActive
        case moderatelyActive
        case veryActive
        case extraActive

        var displayName: String {
            switch self {
            case .sedentary:        "Sedentary"
            case .lightlyActive:    "Lightly Active"
            case .moderatelyActive: "Moderately Active"
            case .veryActive:       "Very Active"
            case .extraActive:      "Extra Active"
            }
        }

        /// Short description shown as a subtitle beneath the display name.
        var subtitle: String {
            switch self {
            case .sedentary:        "Little or no exercise"
            case .lightlyActive:    "Exercise 1–3 days/week"
            case .moderatelyActive: "Exercise 3–5 days/week"
            case .veryActive:       "Exercise 6–7 days/week"
            case .extraActive:      "Physical job or twice-a-day training"
            }
        }

        var multiplier: Double {
            switch self {
            case .sedentary:        1.2
            case .lightlyActive:    1.375
            case .moderatelyActive: 1.55
            case .veryActive:       1.725
            case .extraActive:      1.9
            }
        }

        /// Longer copy for the weight-loss forecast screen (PAL categories are inherently fuzzy).
        var forecastExplanation: String {
            switch self {
            case .sedentary:
                "Mostly sitting or standing in place with little deliberate exercise. Think desk work, driving, or light housework with almost no cardio or strength training."
            case .lightlyActive:
                "You move regularly day to day and/or exercise lightly about one to three times per week. Examples include short walks, easy cycling, or a job where you are on your feet part of the day."
            case .moderatelyActive:
                "Structured exercise about three to five days per week at moderate intensity, or a fairly active job combined with occasional workouts. This is a common default for people who train most weekdays."
            case .veryActive:
                "Hard training most days of the week, long endurance sessions, or a physically demanding job plus regular workouts. Energy needs are much higher than a typical office routine."
            case .extraActive:
                "Very high daily output: competitive athletes, heavy manual labour, or twice-a-day training. This tier assumes you are rarely sedentary and recover between demanding sessions."
            }
        }
    }

    // MARK: - Stored properties
    // HealthKit swap: replace @AppStorage reads in Settings / Forecast with HKHealthStore queries.

    /// Height in centimetres. 0 means not set.
    /// HealthKit: HKQuantityTypeIdentifier.height
    var heightCm: Double

    /// Body mass in kilograms. 0 means not set.
    /// HealthKit: HKQuantityTypeIdentifier.bodyMass
    var weightKg: Double

    /// Date of birth. nil means not set.
    /// HealthKit: HKCharacteristicTypeIdentifier.dateOfBirth
    var birthDate: Date?

    /// HealthKit: HKCharacteristicTypeIdentifier.biologicalSex
    var sex: BiologicalSex

    var activityLevel: ActivityLevel

    // MARK: - Computed properties

    /// Age in whole years derived from birthDate, or nil when birthDate is unset.
    var age: Int? {
        guard let birthDate else { return nil }
        return Calendar.current.dateComponents([.year], from: birthDate, to: .now).year
    }

    /// Basal Metabolic Rate using the Mifflin–St Jeor equation.
    /// Returns nil when any required input is missing or zero.
    var bmr: Double? {
        guard let age, age > 0, heightCm > 0, weightKg > 0 else { return nil }
        return 10 * weightKg + 6.25 * heightCm - 5 * Double(age) + sex.bmrOffset
    }

    /// Total Daily Energy Expenditure = BMR × activity multiplier.
    var tdee: Double? {
        bmr.map { $0 * activityLevel.multiplier }
    }

    /// Mifflin–St Jeor BMR (kcal/day) for a hypothetical body mass using this profile’s height, age, and sex.
    func bmr(atWeightKg massKg: Double) -> Double? {
        guard let age, age > 0, heightCm > 0, massKg > 0 else { return nil }
        return 10 * massKg + 6.25 * heightCm - 5 * Double(age) + sex.bmrOffset
    }

    // MARK: - Storage keys

    enum StorageKey {
        /// Stored as `timeIntervalSince1970`; 0 means not set.
        static let birthDateEpoch = "userProfile.birthDateEpoch"
        static let heightCm       = "userProfile.heightCm"
        static let weightKg       = "userProfile.weightKg"
        /// Goal mass in kg; 0 means not set.
        static let targetWeightKg = "userProfile.targetWeightKg"
        static let sex            = "userProfile.sex"
        static let activityLevel  = "userProfile.activityLevel"
    }
}
