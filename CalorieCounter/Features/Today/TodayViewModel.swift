import Foundation
import SwiftUI

@Observable
@MainActor
final class TodayViewModel {
    var entries: [LogEntry] = []
    var totals: ConsumedNutrition = .zero
    var groupedBySlot: [MealSlot: [LogEntry]] = [:]
    var errorMessage: String?
    var targets: NutritionTargets = .default

    private let logbook: any LogbookRepository

    init(logbook: any LogbookRepository) {
        self.logbook = logbook
    }

    func load(day: Date = .now) async {
        // Refresh targets from UserDefaults on every load so changes made in
        // Settings are picked up whenever the user navigates back to Today.
        targets = NutritionTargets.fromUserDefaults()
        do {
            let entries = try await logbook.entries(on: day)
            self.entries = entries
            self.totals = DailyTotals.totals(for: entries)
            self.groupedBySlot = DailyTotals.grouped(by: entries)
            self.errorMessage = nil
            publishSnapshot(day: day)
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    private func publishSnapshot(day: Date) {
        let consumedKcal = totals.energy.converted(to: .kilocalories).value
        let g = totals.macroGrams
        CalorieSnapshotStore.publishTodayRing(
            consumedKcal: consumedKcal,
            consumedCarbsG: g.carbs,
            consumedProteinG: g.protein,
            consumedFatG: g.fat,
            day: day
        )
    }
}
