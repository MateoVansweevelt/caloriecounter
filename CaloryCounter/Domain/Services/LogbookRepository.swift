import Foundation

public protocol LogbookRepository: Sendable {
    func append(_ entry: LogEntry) async throws
    func delete(entryID: UUID) async throws
    func update(_ entry: LogEntry) async throws

    /// All entries whose `consumedAt` falls on the given day (calendar-local).
    func entries(on day: Date) async throws -> [LogEntry]

    /// All entries in a half-open [start, end) range, sorted ascending by `consumedAt`.
    func entries(from start: Date, to end: Date) async throws -> [LogEntry]

    /// Days (calendar-local midnights) for which at least one entry exists, newest first.
    func loggedDays(limit: Int) async throws -> [Date]
}
