import Foundation

/// Day-by-day weight projection using Mifflin–St Jeor BMR, PAL multipliers, and a fixed calorie intake.
/// Each step recomputes BMR from the new mass so the deficit narrows as you get lighter.
enum WeightLossForecastSimulator {

    /// Commonly used rule of thumb: ~7700 kcal ≈ 1 kg body fat.
    static let kilocaloriesPerKg: Double = 7700

    /// Upper bound on simulated days to avoid infinite loops.
    static let defaultMaxDays: Int = 365 * 20

    struct Series: Sendable {
        let activityLevel: UserProfile.ActivityLevel
        /// `(day, weightKg)`; day 0 is the starting weight; last point is the first day at or below target, a plateau, or `maxDays`.
        let points: [(day: Int, weightKg: Double)]
        let outcome: Outcome
    }

    enum Outcome: Sendable, Equatable {
        /// First day index where weight reached the target (after applying that day’s loss).
        case reachedTarget(days: Int)
        /// Energy balance stopped producing loss before the target was reached.
        case plateau(lastDay: Int, weightKg: Double)
        /// TDEE at day 0 is at or below calorie intake.
        case noDeficitAtStart
        /// Missing height, age, weights, or non-positive calorie target.
        case invalidInputs
        /// Target is not strictly below starting weight.
        case targetNotBelowCurrent
    }

    static func series(
        profile: UserProfile,
        targetWeightKg: Double,
        dailyCalorieIntake: Double,
        activityLevel: UserProfile.ActivityLevel,
        maxDays: Int = defaultMaxDays
    ) -> Series {
        guard
            dailyCalorieIntake > 0,
            targetWeightKg > 0,
            profile.heightCm > 0,
            let age = profile.age, age > 0,
            profile.weightKg > targetWeightKg
        else {
            if profile.weightKg <= targetWeightKg, profile.weightKg > 0, targetWeightKg > 0 {
                return Series(activityLevel: activityLevel, points: [(0, profile.weightKg)], outcome: .targetNotBelowCurrent)
            }
            return Series(activityLevel: activityLevel, points: [], outcome: .invalidInputs)
        }

        let mult = activityLevel.multiplier
        var w = profile.weightKg
        var points: [(Int, Double)] = [(0, w)]

        let p = UserProfile(
            heightCm: profile.heightCm,
            weightKg: w,
            birthDate: profile.birthDate,
            sex: profile.sex,
            activityLevel: .sedentary
        )

        guard let bmr0 = p.bmr(atWeightKg: w), bmr0 * mult > dailyCalorieIntake else {
            return Series(activityLevel: activityLevel, points: points, outcome: .noDeficitAtStart)
        }

        for day in 1...maxDays {
            guard w > targetWeightKg else { break }

            guard let bmr = p.bmr(atWeightKg: w) else {
                return Series(activityLevel: activityLevel, points: points, outcome: .invalidInputs)
            }

            let tdee = bmr * mult
            let deficit = tdee - dailyCalorieIntake

            if deficit <= 0 {
                points.append((day, w))
                return Series(activityLevel: activityLevel, points: points, outcome: .plateau(lastDay: day, weightKg: w))
            }

            let deltaKg = deficit / kilocaloriesPerKg
            let nextW = w - deltaKg

            if nextW <= targetWeightKg {
                w = targetWeightKg
                points.append((day, w))
                return Series(activityLevel: activityLevel, points: points, outcome: .reachedTarget(days: day))
            }

            w = nextW
            points.append((day, w))
        }

        if let last = points.last, last.1 <= targetWeightKg + 1e-9 {
            return Series(activityLevel: activityLevel, points: points, outcome: .reachedTarget(days: last.0))
        }

        let lastDay = points.last?.0 ?? 0
        return Series(activityLevel: activityLevel, points: points, outcome: .plateau(lastDay: lastDay, weightKg: w))
    }

    static func allActivitySeries(
        profile: UserProfile,
        targetWeightKg: Double,
        dailyCalorieIntake: Double,
        maxDays: Int = defaultMaxDays
    ) -> [Series] {
        UserProfile.ActivityLevel.allCases.map {
            series(
                profile: profile,
                targetWeightKg: targetWeightKg,
                dailyCalorieIntake: dailyCalorieIntake,
                activityLevel: $0,
                maxDays: maxDays
            )
        }
    }
}
