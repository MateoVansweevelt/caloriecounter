import Foundation

@Observable
@MainActor
final class LogbookViewModel {
    var selectedDay: Date = Calendar.current.startOfDay(for: .now)
    var entries: [LogEntry] = []
    var totals: ConsumedNutrition = .zero
    var errorMessage: String?

    private let logbook: any LogbookRepository

    init(logbook: any LogbookRepository) {
        self.logbook = logbook
    }

    func load() async {
        do {
            let entries = try await logbook.entries(on: selectedDay)
            self.entries = entries
            self.totals = DailyTotals.totals(for: entries)
            self.errorMessage = nil
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    func delete(_ entry: LogEntry) async {
        do {
            try await logbook.delete(entryID: entry.id)
            await load()
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    func update(_ entry: LogEntry) async {
        do {
            try await logbook.update(entry)
            await load()
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
}
