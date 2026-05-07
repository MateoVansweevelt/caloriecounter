import Foundation
import Testing
@testable import CalorieCounter

@Suite("MacroSnapshot")
struct MacroSnapshotTests {

    @Test("encodes and decodes without data loss")
    func codableRoundTrip() throws {
        let snapshot = MacroSnapshot(
            consumedCarbsGrams: 132.5,
            consumedProteinGrams: 88.25,
            consumedFatGrams: 54.5,
            targetCarbsGrams: 250,
            targetProteinGrams: 140,
            targetFatGrams: 70,
            dayStart: Date(timeIntervalSince1970: 1_700_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_700_003_600)
        )

        let encoded = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(MacroSnapshot.self, from: encoded)
        #expect(decoded == snapshot)
    }

    @Test("store save/load round trip")
    func storeRoundTrip() {
        let snapshot = MacroSnapshot(
            consumedCarbsGrams: 100,
            consumedProteinGrams: 60,
            consumedFatGrams: 30,
            targetCarbsGrams: 240,
            targetProteinGrams: 140,
            targetFatGrams: 70,
            dayStart: Calendar.current.startOfDay(for: .now)
        )

        MacroSnapshotStore.save(snapshot)
        #expect(MacroSnapshotStore.load() == snapshot)
    }
}
