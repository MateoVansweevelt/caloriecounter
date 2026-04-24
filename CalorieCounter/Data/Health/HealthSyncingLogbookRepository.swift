import Foundation

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
    }

    func delete(entryID: UUID) async throws {
        try await inner.delete(entryID: entryID)
        try? await health.remove(entryID: entryID)
    }

    func update(_ entry: LogEntry) async throws {
        try await inner.update(entry)
        try? await health.sync(entry)
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
}
