import Foundation
import Observation

// MARK: - Persisted model (testable transitions)

struct AppOpenStreakPersisted: Equatable, Sendable {
    /// Last calendar day for which streak rules were applied (`startOfDay`).
    var lastStreakProcessedDayEpoch: TimeInterval?
    var currentStreak: Int
    var longestStreak: Int
    /// Unique `startOfDay` instants (seconds since 1970) when the app became active.
    var openDayEpochs: Set<TimeInterval>

    static let empty = AppOpenStreakPersisted(
        lastStreakProcessedDayEpoch: nil,
        currentStreak: 0,
        longestStreak: 0,
        openDayEpochs: []
    )

    /// Records an app-open for `now`: updates the open-day set and streak counters.
    /// Idempotent for streak when called again the same calendar day.
    mutating func applyOpen(at now: Date, calendar: Calendar) {
        let dayStart = calendar.startOfDay(for: now)
        let epoch = dayStart.timeIntervalSince1970
        openDayEpochs.insert(epoch)
        pruneOpenDays(keepingFrom: now, calendar: calendar)

        if lastStreakProcessedDayEpoch == epoch {
            return
        }

        if let lastEpoch = lastStreakProcessedDayEpoch {
            let lastStart = Date(timeIntervalSince1970: lastEpoch)
            let lastDayStart = calendar.startOfDay(for: lastStart)
            if let expectedNext = calendar.date(byAdding: .day, value: 1, to: lastDayStart),
               calendar.isDate(expectedNext, inSameDayAs: dayStart) {
                currentStreak += 1
            } else {
                currentStreak = 1
            }
        } else {
            currentStreak = 1
        }

        longestStreak = max(longestStreak, currentStreak)
        lastStreakProcessedDayEpoch = epoch
    }

    /// Drops open days older than `weeksToKeep` weeks before `now` to cap storage.
    mutating func pruneOpenDays(keepingFrom now: Date, calendar: Calendar, weeksToKeep: Int = 60) {
        guard let cutoff = calendar.date(byAdding: .weekOfYear, value: -weeksToKeep, to: calendar.startOfDay(for: now)) else {
            return
        }
        let cutoffEpoch = cutoff.timeIntervalSince1970
        openDayEpochs = Set(openDayEpochs.filter { $0 >= cutoffEpoch })
    }
}

// MARK: - Heatmap model

struct ContributionHeatmapCell: Identifiable, Equatable, Sendable {
    var id: String { "\(weekIndex)-\(weekdayIndex)" }
    let weekIndex: Int
    let weekdayIndex: Int
    let dayStart: Date
    let wasOpened: Bool
    let isFuture: Bool
}

struct ContributionHeatmapModel: Equatable, Sendable {
    /// Column-major alignment with GitHub: `cells[col][row]` where `col` is week (oldest → newest).
    let cells: [[ContributionHeatmapCell]]
    /// Short month labels for columns where the month changes (index = week column).
    let monthLabels: [Int: String]

    static func build(
        now: Date = .now,
        calendar: Calendar = .current,
        openDayEpochs: Set<TimeInterval>,
        weekCount: Int = 53
    ) -> ContributionHeatmapModel {
        let today = calendar.startOfDay(for: now)
        guard let endWeekInterval = calendar.dateInterval(of: .weekOfYear, for: today) else {
            return ContributionHeatmapModel(cells: [], monthLabels: [:])
        }
        let endWeekStart = endWeekInterval.start
        guard let gridOrigin = calendar.date(byAdding: .weekOfYear, value: -(weekCount - 1), to: endWeekStart) else {
            return ContributionHeatmapModel(cells: [], monthLabels: [:])
        }

        var columns: [[ContributionHeatmapCell]] = []
        var monthLabels: [Int: String] = [:]
        var previousMonth: Int?

        for weekIndex in 0..<weekCount {
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: weekIndex, to: gridOrigin) else { continue }
            var column: [ContributionHeatmapCell] = []
            for weekdayIndex in 0..<7 {
                guard let day = calendar.date(byAdding: .day, value: weekdayIndex, to: weekStart) else { continue }
                let dayStart = calendar.startOfDay(for: day)
                let epoch = dayStart.timeIntervalSince1970
                let isFuture = dayStart > today
                let opened = openDayEpochs.contains(epoch)
                column.append(
                    ContributionHeatmapCell(
                        weekIndex: weekIndex,
                        weekdayIndex: weekdayIndex,
                        dayStart: dayStart,
                        wasOpened: opened,
                        isFuture: isFuture
                    )
                )
            }
            if let firstDay = column.first?.dayStart {
                let month = calendar.component(.month, from: firstDay)
                if month != previousMonth {
                    let sym = calendar.shortMonthSymbols[max(0, min(11, month - 1))]
                    monthLabels[weekIndex] = sym
                    previousMonth = month
                }
            }
            columns.append(column)
        }

        return ContributionHeatmapModel(cells: columns, monthLabels: monthLabels)
    }

    var activeDaysInWindow: Int {
        cells.flatMap { $0 }.filter { !$0.isFuture && $0.wasOpened }.count
    }
}

// MARK: - Store

enum AppOpenStreakStorageKey {
    static let lastProcessed = "appOpenStreak.lastStreakProcessedDayEpoch"
    static let current = "appOpenStreak.current"
    static let longest = "appOpenStreak.longest"
    static let openDaysJSON = "appOpenStreak.openDaysJSON"
}

@MainActor
@Observable
final class AppOpenStreakStore {
    static let shared = AppOpenStreakStore()

    private let defaults: UserDefaults

    private(set) var currentStreak: Int = 0
    private(set) var longestStreak: Int = 0
    private(set) var openDayEpochs: Set<TimeInterval> = []

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        reloadFromDefaults()
    }

    func reloadFromDefaults() {
        let s = Self.load(from: defaults)
        currentStreak = s.currentStreak
        longestStreak = s.longestStreak
        openDayEpochs = s.openDayEpochs
    }

    func recordOpenIfNeeded(now: Date = .now, calendar: Calendar = .current) {
        var s = Self.load(from: defaults)
        s.applyOpen(at: now, calendar: calendar)
        Self.save(s, to: defaults)
        currentStreak = s.currentStreak
        longestStreak = s.longestStreak
        openDayEpochs = s.openDayEpochs
    }

    func heatmapModel(now: Date = .now, calendar: Calendar = .current) -> ContributionHeatmapModel {
        ContributionHeatmapModel.build(now: now, calendar: calendar, openDayEpochs: openDayEpochs)
    }

    var accessibilitySummary: String {
        let windowDays = heatmapModel().activeDaysInWindow
        return "Current streak \(currentStreak) days, longest \(longestStreak) days, \(windowDays) active days in the last year."
    }

    private static func load(from defaults: UserDefaults) -> AppOpenStreakPersisted {
        let last = defaults.object(forKey: AppOpenStreakStorageKey.lastProcessed) as? TimeInterval
        let current = max(0, defaults.integer(forKey: AppOpenStreakStorageKey.current))
        let longest = max(0, defaults.integer(forKey: AppOpenStreakStorageKey.longest))
        let data = defaults.data(forKey: AppOpenStreakStorageKey.openDaysJSON)
        let epochs: Set<TimeInterval>
        if let data, let arr = try? JSONDecoder().decode([TimeInterval].self, from: data) {
            epochs = Set(arr)
        } else {
            epochs = []
        }
        return AppOpenStreakPersisted(
            lastStreakProcessedDayEpoch: last,
            currentStreak: current,
            longestStreak: longest,
            openDayEpochs: epochs
        )
    }

    private static func save(_ s: AppOpenStreakPersisted, to defaults: UserDefaults) {
        if let last = s.lastStreakProcessedDayEpoch {
            defaults.set(last, forKey: AppOpenStreakStorageKey.lastProcessed)
        } else {
            defaults.removeObject(forKey: AppOpenStreakStorageKey.lastProcessed)
        }
        defaults.set(s.currentStreak, forKey: AppOpenStreakStorageKey.current)
        defaults.set(s.longestStreak, forKey: AppOpenStreakStorageKey.longest)
        if let data = try? JSONEncoder().encode(Array(s.openDayEpochs).sorted()) {
            defaults.set(data, forKey: AppOpenStreakStorageKey.openDaysJSON)
        }
    }
}
