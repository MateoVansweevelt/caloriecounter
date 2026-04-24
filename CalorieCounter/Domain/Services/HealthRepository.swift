import Foundation

public enum HealthAuthorizationStatus: Sendable {
    case notDetermined
    case authorized
    case denied
    /// Device does not support HealthKit (iPad without HK, simulator, etc.)
    case unavailable
}

/// Abstracts all HealthKit interactions so the rest of the app stays framework-free.
///
/// Nutrition writes are driven by the logbook: every append/update/delete on a LogEntry
/// should be mirrored here. Activity and body reads are used by the Today dashboard to
/// surface net calories and personalised goals.
///
/// Current live implementation: NullHealthRepository (no-op).
/// Switch to HealthKitRepository in AppDependencies once the HealthKit capability
/// entitlement is added to the project (requires a paid Apple Developer account).
public protocol HealthRepository: Sendable {

    /// Whether HealthKit is supported and data is available on this device.
    var isAvailable: Bool { get }

    /// Request read/write authorization for all health types this app uses.
    /// Safe to call multiple times; HealthKit de-dupes the prompt.
    func requestAuthorization() async throws

    /// Aggregate authorization state, derived from the most representative type.
    func authorizationStatus() async -> HealthAuthorizationStatus

    // MARK: - Nutrition (write)

    /// Write (or replace) the HealthKit dietary samples for a log entry.
    /// Called after both append and update so this acts as an upsert.
    func sync(_ entry: LogEntry) async throws

    /// Remove the HealthKit dietary samples that were written for this entry.
    func remove(entryID: UUID) async throws

    // MARK: - Activity (read)

    /// Total active (exercise) energy burned on the given calendar day.
    func activeEnergyBurned(on day: Date) async throws -> Measurement<UnitEnergy>

    /// Resting (basal metabolic) energy on the given calendar day.
    func restingEnergyBurned(on day: Date) async throws -> Measurement<UnitEnergy>

    /// Step count on the given calendar day.
    func steps(on day: Date) async throws -> Int

    // MARK: - Body metrics (read)

    /// Most recent body mass reading. Used for personalised calorie goal calculation.
    func bodyMass() async throws -> Measurement<UnitMass>?
}
