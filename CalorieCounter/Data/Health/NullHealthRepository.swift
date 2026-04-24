import Foundation

/// No-op HealthRepository used while the HealthKit capability entitlement is not yet active.
/// All write operations succeed silently; all reads return zero/nil.
public actor NullHealthRepository: HealthRepository {

    public init() {}

    public nonisolated var isAvailable: Bool { false }

    public func requestAuthorization() async throws {}

    public func authorizationStatus() async -> HealthAuthorizationStatus { .unavailable }

    public func sync(_ entry: LogEntry) async throws {}

    public func remove(entryID: UUID) async throws {}

    public func activeEnergyBurned(on day: Date) async throws -> Measurement<UnitEnergy> {
        .init(value: 0, unit: .kilocalories)
    }

    public func restingEnergyBurned(on day: Date) async throws -> Measurement<UnitEnergy> {
        .init(value: 0, unit: .kilocalories)
    }

    public func steps(on day: Date) async throws -> Int { 0 }

    public func bodyMass() async throws -> Measurement<UnitMass>? { nil }
}
