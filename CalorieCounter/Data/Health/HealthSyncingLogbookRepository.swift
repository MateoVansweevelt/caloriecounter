import Foundation
import WidgetKit

/// Wraps any LogbookRepository and mirrors every mutation to a HealthRepository.
/// Health sync failures are swallowed so they never prevent food from being logged.
actor HealthSyncingLogbookRepository: LogbookRepository {

    private let inner: any LogbookRepository
    private let health: any HealthRepository

    init(inner: any LogbookRepository, health: any HealthRepository) {
        self.inner = inner
        self.health = health
    }

    func append(_ entry: LogEntry) async throws {
        try await inner.append(entry)
        try? await health.sync(entry)
        await publishTodaySnapshot()
    }

    func delete(entryID: UUID) async throws {
        try await inner.delete(entryID: entryID)
        try? await health.remove(entryID: entryID)
        await publishTodaySnapshot()
    }

    func update(_ entry: LogEntry) async throws {
        try await inner.update(entry)
        try? await health.sync(entry)
        await publishTodaySnapshot()
    }

    func entries(on day: Date) async throws -> [LogEntry] {
        try await inner.entries(on: day)
    }

    func entries(from start: Date, to end: Date) async throws -> [LogEntry] {
        try await inner.entries(from: start, to: end)
    }

    func loggedDays(limit: Int) async throws -> [Date] {
        try await inner.loggedDays(limit: limit)
    }

    private func publishTodaySnapshot() async {
        let today = Date.now
        guard let entries = try? await inner.entries(on: today) else { return }
        let totals = DailyTotals.totals(for: entries)
        let snapshot = CalorieSnapshot(
            consumedKcal: totals.energy.converted(to: .kilocalories).value,
            targetKcal: NutritionTargets.default.calories,
            dayStart: Calendar.current.startOfDay(for: today)
        )
        CalorieSnapshotStore.save(snapshot)
        WidgetCenter.shared.reloadTimelines(ofKind: CalorieWidgetKind.ring)
    }
}
