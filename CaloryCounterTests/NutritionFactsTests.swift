import Foundation
import Testing
@testable import CaloryCounter

@Suite("NutritionFacts aggregation")
struct NutritionFactsTests {

    @Test("scaling per-100g facts by serving multiplies every field")
    func scalingPer100g() {
        let facts = NutritionFacts(
            basis: .mass,
            energy: .init(value: 200, unit: .kilocalories),
            macros: Macros(
                carbohydrates: .init(value: 20, unit: .grams),
                protein: .init(value: 10, unit: .grams),
                fat: .init(value: 5, unit: .grams)
            )
        )
        let consumed = facts.values(for: .grams(50))
        #expect(consumed.energy.converted(to: .kilocalories).value == 100)
        #expect(consumed.macros.carbohydrates.converted(to: .grams).value == 10)
        #expect(consumed.macros.protein.converted(to: .grams).value == 5)
        #expect(consumed.macros.fat.converted(to: .grams).value == 2.5)
    }

    @Test("daily totals sum across mixed entries")
    func dailyTotalsSum() {
        let apple = FoodItem(
            name: "Apple",
            source: .userCreated,
            facts: NutritionFacts(
                basis: .mass,
                energy: .init(value: 52, unit: .kilocalories),
                macros: Macros(
                    carbohydrates: .init(value: 14, unit: .grams),
                    protein: .init(value: 0.3, unit: .grams),
                    fat: .init(value: 0.2, unit: .grams)
                )
            )
        )
        let cola = FoodItem(
            name: "Cola",
            source: .userCreated,
            facts: NutritionFacts(
                basis: .volume,
                energy: .init(value: 42, unit: .kilocalories),
                macros: Macros(
                    carbohydrates: .init(value: 10.6, unit: .grams),
                    protein: .zeroGrams,
                    fat: .zeroGrams
                )
            )
        )
        let entries = [
            LogEntry(food: apple, serving: .grams(150), consumedAt: .now),
            LogEntry(food: cola, serving: .millilitres(330), consumedAt: .now),
        ]
        let totals = DailyTotals.totals(for: entries)
        let kcal = totals.energy.converted(to: .kilocalories).value
        #expect(abs(kcal - (78.0 + 138.6)) < 0.01)
    }

    @Test("meal inference maps hour-of-day to the right slot")
    func mealInference() {
        let cal = Calendar(identifier: .gregorian)
        func at(_ hour: Int) -> Date {
            cal.date(from: DateComponents(year: 2026, month: 4, day: 23, hour: hour))!
        }
        #expect(MealSlot.inferred(at: at(7)) == .breakfast)
        #expect(MealSlot.inferred(at: at(13)) == .lunch)
        #expect(MealSlot.inferred(at: at(19)) == .dinner)
        #expect(MealSlot.inferred(at: at(23)) == .snack)
    }
}
