import Foundation
import Testing
@testable import CalorieCounter

@Suite("DailyTotals grouping")
struct DailyTotalsGroupingTests {

    @Test("groups entries by MealSlot and handles empty input")
    func groupsByMealSlot() {
        let food = FoodItem(
            name: "X",
            source: .userCreated,
            facts: NutritionFacts(
                basis: .mass,
                energy: .init(value: 100, unit: .kilocalories),
                macros: Macros(
                    carbohydrates: .init(value: 0, unit: .grams),
                    protein: .init(value: 0, unit: .grams),
                    fat: .init(value: 0, unit: .grams)
                )
            )
        )
        let now = Date()
        let entries: [LogEntry] = [
            LogEntry(food: food, serving: .grams(10), consumedAt: now, mealSlot: .breakfast),
            LogEntry(food: food, serving: .grams(20), consumedAt: now, mealSlot: .lunch),
            LogEntry(food: food, serving: .grams(30), consumedAt: now, mealSlot: .dinner),
            LogEntry(food: food, serving: .grams(5), consumedAt: now, mealSlot: .snack)
        ]

        let grouped = DailyTotals.grouped(by: entries)
        #expect(grouped.keys.contains(.breakfast))
        #expect(grouped.keys.contains(.lunch))
        #expect(grouped.keys.contains(.dinner))
        #expect(grouped.keys.contains(.snack))
        #expect(grouped[.breakfast]?.count == 1)
        #expect(grouped[.lunch]?.count == 1)
        #expect(grouped[.dinner]?.count == 1)
        #expect(grouped[.snack]?.count == 1)

        let empty: [LogEntry] = []
        let groupedEmpty = DailyTotals.grouped(by: empty)
        #expect(groupedEmpty.isEmpty)
    }
}
