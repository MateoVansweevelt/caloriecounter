import Foundation
import Testing
@testable import CalorieCounter

@Suite("AppOpenStreak")
@MainActor
struct AppOpenStreakStoreTests {

    private func utcCalendar() -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }

    private func noon(on day: Int, month: Int, year: Int, calendar: Calendar) -> Date {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        comps.hour = 12
        return calendar.date(from: comps)!
    }

    @Test("First open sets streak to 1")
    func firstOpen() {
        var s = AppOpenStreakPersisted.empty
        let cal = utcCalendar()
        let now = noon(on: 5, month: 5, year: 2026, calendar: cal)
        s.applyOpen(at: now, calendar: cal)
        #expect(s.currentStreak == 1)
        #expect(s.longestStreak == 1)
        #expect(s.openDayEpochs.contains(cal.startOfDay(for: now).timeIntervalSince1970))
    }

    @Test("Same calendar day is idempotent for streak")
    func sameDayIdempotent() {
        var s = AppOpenStreakPersisted.empty
        let cal = utcCalendar()
        let morning = noon(on: 6, month: 5, year: 2026, calendar: cal)
        let evening = cal.date(byAdding: .hour, value: 10, to: morning)!
        s.applyOpen(at: morning, calendar: cal)
        s.applyOpen(at: evening, calendar: cal)
        #expect(s.currentStreak == 1)
        #expect(s.longestStreak == 1)
        #expect(s.openDayEpochs.count == 1)
    }

    @Test("Consecutive days increment streak")
    func consecutiveDays() {
        var s = AppOpenStreakPersisted.empty
        let cal = utcCalendar()
        let d1 = noon(on: 10, month: 5, year: 2026, calendar: cal)
        let d2 = noon(on: 11, month: 5, year: 2026, calendar: cal)
        s.applyOpen(at: d1, calendar: cal)
        s.applyOpen(at: d2, calendar: cal)
        #expect(s.currentStreak == 2)
        #expect(s.longestStreak == 2)
    }

    @Test("Gap resets streak to 1")
    func gapResets() {
        var s = AppOpenStreakPersisted.empty
        let cal = utcCalendar()
        let d1 = noon(on: 1, month: 5, year: 2026, calendar: cal)
        let d2 = noon(on: 2, month: 5, year: 2026, calendar: cal)
        let d4 = noon(on: 4, month: 5, year: 2026, calendar: cal)
        s.applyOpen(at: d1, calendar: cal)
        s.applyOpen(at: d2, calendar: cal)
        s.applyOpen(at: d4, calendar: cal)
        #expect(s.currentStreak == 1)
        #expect(s.longestStreak == 2)
    }

    @Test("Persistence round-trip via UserDefaults")
    func persistenceRoundTrip() {
        let suiteName = "AppOpenStreakStoreTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Could not create UserDefaults suite")
            return
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let cal = utcCalendar()
        let d1 = noon(on: 20, month: 6, year: 2026, calendar: cal)

        let store = AppOpenStreakStore(defaults: defaults)
        store.recordOpenIfNeeded(now: d1, calendar: cal)

        let store2 = AppOpenStreakStore(defaults: defaults)
        #expect(store2.currentStreak == 1)
        #expect(store2.longestStreak == 1)
        #expect(store2.openDayEpochs.contains(cal.startOfDay(for: d1).timeIntervalSince1970))
    }

    @Test("Heatmap marks opened days")
    func heatmapOpenedDays() {
        let cal = utcCalendar()
        let d = noon(on: 15, month: 7, year: 2026, calendar: cal)
        let epoch = cal.startOfDay(for: d).timeIntervalSince1970
        let model = ContributionHeatmapModel.buildLast53Weeks(now: d, calendar: cal, openDayEpochs: [epoch])
        let flat = model.cells.flatMap { $0 }
        let match = flat.first { cal.isDate($0.dayStart, inSameDayAs: d) }
        #expect(match != nil)
        #expect(match?.wasOpened == true)
        #expect(match?.isFuture == false)
    }

    @Test("Home heatmap: fixed week columns, spans prior months, ends on week of today")
    func homeHeatmapTrailingWeeksFilled() {
        let cal = utcCalendar()
        let d = noon(on: 15, month: 7, year: 2026, calendar: cal)
        let weekCount = 18
        let model = ContributionHeatmapModel.buildTrailingWeeksThroughToday(
            now: d,
            calendar: cal,
            openDayEpochs: [],
            weekCount: weekCount
        )
        #expect(model.cells.count == weekCount)
        guard let lastColumn = model.cells.last else {
            Issue.record("Expected week columns")
            return
        }
        let hasToday = lastColumn.contains { $0.isToday && cal.isDate($0.dayStart, inSameDayAs: d) }
        #expect(hasToday)
        let julyStart = cal.date(from: DateComponents(year: 2026, month: 7, day: 1))!
        let earliest = model.cells.first?.first?.dayStart
        #expect(earliest != nil)
        #expect(earliest! < julyStart)
    }
}
