import Foundation
import HealthKit

/// Full HealthKit implementation. Ready to activate — just:
///   1. Add the HealthKit capability in Xcode (requires paid Apple Developer account)
///   2. Add NSHealthShareUsageDescription & NSHealthUpdateUsageDescription to Info.plist
///   3. In AppDependencies.live(), replace NullHealthRepository() with HealthKitRepository()
public actor HealthKitRepository: HealthRepository {

    private let store = HKHealthStore()

    public init() {}

    // MARK: - Availability & Authorization

    public nonisolated var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    public func requestAuthorization() async throws {
        guard isAvailable else { return }
        try await store.requestAuthorization(toShare: shareTypes, read: readTypes)
    }

    public func authorizationStatus() async -> HealthAuthorizationStatus {
        guard isAvailable else { return .unavailable }
        switch store.authorizationStatus(for: HKQuantityType(.dietaryEnergyConsumed)) {
        case .notDetermined: return .notDetermined
        case .sharingAuthorized: return .authorized
        case .sharingDenied: return .denied
        @unknown default: return .notDetermined
        }
    }

    // MARK: - Nutrition writes

    public func sync(_ entry: LogEntry) async throws {
        guard isAvailable else { return }
        // Remove any previous samples for this entry then write fresh ones.
        try await deleteExisting(entryID: entry.id)
        let correlation = buildCorrelation(for: entry)
        try await store.save(correlation)
    }

    public func remove(entryID: UUID) async throws {
        guard isAvailable else { return }
        try await deleteExisting(entryID: entryID)
    }

    // MARK: - Activity reads

    public func activeEnergyBurned(on day: Date) async throws -> Measurement<UnitEnergy> {
        guard isAvailable else { return .init(value: 0, unit: .kilocalories) }
        let sum = try await cumulativeSum(for: .activeEnergyBurned, on: day, unit: .kilocalorie())
        return .init(value: sum, unit: .kilocalories)
    }

    public func restingEnergyBurned(on day: Date) async throws -> Measurement<UnitEnergy> {
        guard isAvailable else { return .init(value: 0, unit: .kilocalories) }
        let sum = try await cumulativeSum(for: .basalEnergyBurned, on: day, unit: .kilocalorie())
        return .init(value: sum, unit: .kilocalories)
    }

    public func steps(on day: Date) async throws -> Int {
        guard isAvailable else { return 0 }
        let sum = try await cumulativeSum(for: .stepCount, on: day, unit: .count())
        return Int(sum)
    }

    // MARK: - Body metrics

    public func bodyMass() async throws -> Measurement<UnitMass>? {
        guard isAvailable else { return nil }
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKQuantityType(.bodyMass),
                predicate: nil,
                limit: 1,
                sortDescriptors: [sort]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let sample = samples?.first as? HKQuantitySample {
                    let kg = sample.quantity.doubleValue(for: .gramUnit(with: .kilo))
                    continuation.resume(returning: .init(value: kg, unit: .kilograms))
                } else {
                    continuation.resume(returning: nil)
                }
            }
            self.store.execute(query)
        }
    }

    // MARK: - Private helpers

    private func deleteExisting(entryID: UUID) async throws {
        let predicate = HKQuery.predicateForObjects(
            withMetadataKey: HKMetadataKeyExternalUUID,
            operatorType: .equalTo,
            value: entryID.uuidString
        )
        let existing: [HKCorrelation] = try await withCheckedThrowingContinuation { continuation in
            let query = HKCorrelationQuery(
                type: HKCorrelationType(.food),
                predicate: predicate,
                samplePredicates: nil
            ) { _, correlations, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: correlations ?? []) }
            }
            self.store.execute(query)
        }
        if !existing.isEmpty {
            try await store.delete(existing)
        }
    }

    private func buildCorrelation(for entry: LogEntry) -> HKCorrelation {
        let c = entry.consumed
        let date = entry.consumedAt
        let metadata: [String: Any] = [
            HKMetadataKeyExternalUUID: entry.id.uuidString,
            HKMetadataKeyFoodType: entry.food.name
        ]

        func sample(_ id: HKQuantityTypeIdentifier, _ quantity: HKQuantity) -> HKQuantitySample {
            HKQuantitySample(type: HKQuantityType(id), quantity: quantity,
                             start: date, end: date, metadata: metadata)
        }
        func grams(_ m: Measurement<UnitMass>) -> HKQuantity {
            HKQuantity(unit: .gram(), doubleValue: m.converted(to: .grams).value)
        }

        var samples: Set<HKSample> = [
            sample(.dietaryEnergyConsumed,
                   HKQuantity(unit: .kilocalorie(),
                              doubleValue: c.energy.converted(to: .kilocalories).value)),
            sample(.dietaryCarbohydrates, grams(c.macros.carbohydrates)),
            sample(.dietaryProtein,       grams(c.macros.protein)),
            sample(.dietaryFatTotal,      grams(c.macros.fat)),
        ]

        if let fiber    = c.macros.fiber        { samples.insert(sample(.dietaryFiber,       grams(fiber))) }
        if let sugars   = c.macros.sugars       { samples.insert(sample(.dietarySugar,       grams(sugars))) }
        if let satFat   = c.macros.saturatedFat { samples.insert(sample(.dietaryFatSaturated, grams(satFat))) }

        // Prefer micros[.sodium] (direct measurement); fall back to deriving from salt (NaCl → Na ≈ 39.3%)
        if let sodium = c.micros[.sodium] {
            samples.insert(sample(.dietarySodium, grams(sodium.mass)))
        } else if let salt = c.macros.salt {
            let sodiumGrams = salt.converted(to: .grams).value * 0.393
            samples.insert(sample(.dietarySodium, HKQuantity(unit: .gram(), doubleValue: sodiumGrams)))
        }

        let microMapping: [(MicroKey, HKQuantityTypeIdentifier)] = [
            (.potassium, .dietaryPotassium),
            (.calcium,   .dietaryCalcium),
            (.iron,      .dietaryIron),
            (.magnesium, .dietaryMagnesium),
            (.zinc,      .dietaryZinc),
            (.vitaminA,  .dietaryVitaminA),
            (.vitaminC,  .dietaryVitaminC),
            (.vitaminD,  .dietaryVitaminD),
            (.vitaminE,  .dietaryVitaminE),
            (.vitaminB6, .dietaryVitaminB6),
            (.vitaminB12,.dietaryVitaminB12),
            (.folate,    .dietaryFolate),
        ]
        for (key, hkID) in microMapping {
            if let value = c.micros[key] { samples.insert(sample(hkID, grams(value.mass))) }
        }

        return HKCorrelation(type: HKCorrelationType(.food),
                             start: date, end: date,
                             objects: samples, metadata: metadata)
    }

    private func cumulativeSum(for typeID: HKQuantityTypeIdentifier,
                               on day: Date, unit: HKUnit) async throws -> Double {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: day)
        let end   = calendar.date(byAdding: .day, value: 1, to: start)!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: HKQuantityType(typeID),
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: statistics?.sumQuantity()?.doubleValue(for: unit) ?? 0) }
            }
            self.store.execute(query)
        }
    }

    // MARK: - Authorization type sets

    private var shareTypes: Set<HKSampleType> {
        var types: Set<HKSampleType> = [HKCorrelationType(.food)]
        let ids: [HKQuantityTypeIdentifier] = [
            .dietaryEnergyConsumed, .dietaryCarbohydrates, .dietaryProtein,
            .dietaryFatTotal, .dietaryFiber, .dietarySugar, .dietaryFatSaturated,
            .dietarySodium, .dietaryPotassium, .dietaryCalcium, .dietaryIron,
            .dietaryMagnesium, .dietaryZinc, .dietaryVitaminA, .dietaryVitaminC,
            .dietaryVitaminD, .dietaryVitaminE, .dietaryVitaminB6, .dietaryVitaminB12,
            .dietaryFolate,
        ]
        types.formUnion(ids.map { HKQuantityType($0) })
        return types
    }

    private var readTypes: Set<HKObjectType> {
        [
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.basalEnergyBurned),
            HKQuantityType(.stepCount),
            HKQuantityType(.bodyMass),
        ]
    }
}
