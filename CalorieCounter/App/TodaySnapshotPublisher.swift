import Foundation

/// Pushes the home-screen calorie ring widget to match the logbook + saved daily goal.
enum TodaySnapshotPublisher {
    static func refresh(logbook: any LogbookRepository) async {
        let day = Date.now
        let entries: [LogEntry]
        do {
            entries = try await logbook.entries(on: day)
        } catch {
            return
        }
        let totals = DailyTotals.totals(for: entries)
        let consumed = totals.energy.converted(to: .kilocalories).value
        let g = totals.macroGrams
        await CalorieSnapshotStore.publishTodayRing(
            consumedKcal: consumed,
            consumedCarbsG: g.carbs,
            consumedProteinG: g.protein,
            consumedFatG: g.fat,
            day: day
        )
    }

    /// Recomputes the snapshot then asks WidgetKit for a full timeline reload (use from Settings).
    static func forceSync(logbook: any LogbookRepository) async {
        await refresh(logbook: logbook)
        await CalorieSnapshotStore.reloadAllWidgetTimelines()
    }
}
