import Foundation
import WidgetKit

extension CalorieSnapshotStore {
    /// Writes today's summary to the App Group and asks the system to reload the widget.
    /// Uses the same calorie target source as the Today screen (`NutritionTargets.fromUserDefaults()`).
    @MainActor
    public static func publishTodayRing(
        consumedKcal: Double,
        consumedCarbsG: Double,
        consumedProteinG: Double,
        consumedFatG: Double,
        day: Date = .now
    ) {
        let targets = NutritionTargets.fromUserDefaults()
        let snapshot = CalorieSnapshot(
            consumedKcal: consumedKcal,
            targetKcal: targets.calories,
            consumedCarbsG: consumedCarbsG,
            consumedProteinG: consumedProteinG,
            consumedFatG: consumedFatG,
            targetCarbsG: targets.carbsGrams,
            targetProteinG: targets.proteinGrams,
            targetFatG: targets.fatGrams,
            dayStart: Calendar.current.startOfDay(for: day),
            updatedAt: .now
        )
        save(snapshot)
        WidgetCenter.shared.reloadTimelines(ofKind: CalorieWidgetKind.ring)
    }

    /// Stronger refresh for manual “sync” actions (reloads all widget timelines for this app extension).
    @MainActor
    public static func reloadAllWidgetTimelines() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}
