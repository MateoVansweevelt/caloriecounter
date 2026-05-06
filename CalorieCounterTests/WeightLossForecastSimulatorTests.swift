import Foundation
import Testing
@testable import CalorieCounter

@Suite("Weight loss forecast simulation")
struct WeightLossForecastSimulatorTests {

    @Test("weight decreases monotonically until target when there is a sustained deficit")
    func monotonicLoss() {
        let birth = Calendar.current.date(byAdding: .year, value: -32, to: Date())!
        let profile = UserProfile(
            heightCm: 178,
            weightKg: 92,
            birthDate: birth,
            sex: .male,
            activityLevel: .moderatelyActive
        )
        let series = WeightLossForecastSimulator.series(
            profile: profile,
            targetWeightKg: 88,
            dailyCalorieIntake: 1900,
            activityLevel: .moderatelyActive
        )
        #expect(series.points.first?.1 == 92)
        #expect(series.points.last?.1 == 88)
        var previous = series.points[0].1
        for (_, w) in series.points.dropFirst() {
            #expect(w <= previous + 1e-6)
            previous = w
        }
    }

    @Test("very high intake yields no deficit at start")
    func noDeficit() {
        let birth = Calendar.current.date(byAdding: .year, value: -28, to: Date())!
        let profile = UserProfile(
            heightCm: 170,
            weightKg: 70,
            birthDate: birth,
            sex: .female,
            activityLevel: .sedentary
        )
        let series = WeightLossForecastSimulator.series(
            profile: profile,
            targetWeightKg: 60,
            dailyCalorieIntake: 10_000,
            activityLevel: .sedentary
        )
        #expect(series.outcome == .noDeficitAtStart)
    }

    @Test("target not below current is flagged")
    func targetNotBelow() {
        let birth = Calendar.current.date(byAdding: .year, value: -25, to: Date())!
        let profile = UserProfile(
            heightCm: 175,
            weightKg: 70,
            birthDate: birth,
            sex: .other,
            activityLevel: .lightlyActive
        )
        let series = WeightLossForecastSimulator.series(
            profile: profile,
            targetWeightKg: 70,
            dailyCalorieIntake: 1800,
            activityLevel: .lightlyActive
        )
        #expect(series.outcome == .targetNotBelowCurrent)
    }
}
