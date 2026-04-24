import Foundation
import SwiftData

public actor SwiftDataLogbookRepository: LogbookRepository {
    private let container: ModelContainer
    private let calendar: Calendar

    public init(container: ModelContainer, calendar: Calendar = .current) {
        self.container = container
        self.calendar = calendar
    }

    @MainActor
    private func context() -> ModelContext {
        ModelContext(container)
    }

    public func append(_ entry: LogEntry) async throws {
        try await perform { context in
            let model = try PersistedLogEntryMapping.make(from: entry, calendar: self.calendar)
            context.insert(model)
            try context.save()
        }
    }

    public func delete(entryID: UUID) async throws {
        try await perform { context in
            let predicate = #Predicate<PersistedLogEntry> { $0.id == entryID }
            let descriptor = FetchDescriptor<PersistedLogEntry>(predicate: predicate)
            if let existing = try context.fetch(descriptor).first {
                context.delete(existing)
                try context.save()
            }
        }
    }

    public func update(_ entry: LogEntry) async throws {
        try await perform { context in
            let id = entry.id
            let predicate = #Predicate<PersistedLogEntry> { $0.id == id }
            let descriptor = FetchDescriptor<PersistedLogEntry>(predicate: predicate)
            if let existing = try context.fetch(descriptor).first {
                try PersistedLogEntryMapping.apply(entry, to: existing, calendar: self.calendar)
                try context.save()
            } else {
                let model = try PersistedLogEntryMapping.make(from: entry, calendar: self.calendar)
                context.insert(model)
                try context.save()
            }
        }
    }

    public func entries(on day: Date) async throws -> [LogEntry] {
        let dayStart = calendar.startOfDay(for: day)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return [] }
        return try await entries(from: dayStart, to: dayEnd)
    }

    public func entries(from start: Date, to end: Date) async throws -> [LogEntry] {
        try await perform { context in
            let predicate = #Predicate<PersistedLogEntry> {
                $0.consumedAt >= start && $0.consumedAt < end
            }
            var descriptor = FetchDescriptor<PersistedLogEntry>(predicate: predicate)
            descriptor.sortBy = [SortDescriptor(\.consumedAt, order: .forward)]
            let models = try context.fetch(descriptor)
            return try models.map(PersistedLogEntryMapping.entry(from:))
        }
    }

    public func loggedDays(limit: Int) async throws -> [Date] {
        try await perform { context in
            var descriptor = FetchDescriptor<PersistedLogEntry>()
            descriptor.sortBy = [SortDescriptor(\.dayStart, order: .reverse)]
            let models = try context.fetch(descriptor)
            var seen: Set<Date> = []
            var result: [Date] = []
            for model in models where !seen.contains(model.dayStart) {
                seen.insert(model.dayStart)
                result.append(model.dayStart)
                if result.count >= limit { break }
            }
            return result
        }
    }

    private func perform<T: Sendable>(_ body: @Sendable @MainActor (ModelContext) throws -> T) async throws -> T {
        try await MainActor.run {
            let context = ModelContext(self.container)
            return try body(context)
        }
    }
}
