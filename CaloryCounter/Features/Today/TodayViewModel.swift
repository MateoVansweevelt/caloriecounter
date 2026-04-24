import Foundation
import SwiftUI
import WidgetKit

/// Hardcoded defaults for the POC. Surface these in Settings later.
public struct NutritionTargets: Sendable, Hashable {
    public var calories: Double = 2200
    public var carbsGrams: Double = 250
    public var proteinGrams: Double = 140
    public var fatGrams: Double = 70

    public static let `default` = NutritionTargets()
}

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
        let snapshot = CalorieSnapshot(
            consumedKcal: consumedKcal,
            targetKcal: targets.calories,
            dayStart: Calendar.current.startOfDay(for: day)
        )
        CalorieSnapshotStore.save(snapshot)
        WidgetCenter.shared.reloadTimelines(ofKind: CalorieWidgetKind.ring)
    }
}
