import Foundation
import Testing
@testable import CalorieCounter

@Suite("EditLogEntryViewModel")
@MainActor
struct EditLogEntryViewModelTests {

    @Test("custom serving has no suggested selection or stale label")
    func customServingIsRepresentedExplicitly() {
        let entry = LogEntry(
            food: makeFood(),
            serving: .grams(73, label: "100 g"),
            consumedAt: .now,
            mealSlot: .snack
        )
        let model = EditLogEntryViewModel(entry: entry, logbook: SpyLogbookRepository())

        #expect(model.selectedSuggestedServing == nil)
        #expect(model.effectiveServing.amount == 73)
        #expect(model.effectiveServing.label == nil)
    }

    @Test("saving preserves edited notes")
    func savePersistsEditedNote() async throws {
        let repo = SpyLogbookRepository()
        let entry = LogEntry(
            food: makeFood(),
            serving: .grams(100, label: "100 g"),
            consumedAt: .now,
            mealSlot: .breakfast,
            note: "old note"
        )
        let model = EditLogEntryViewModel(entry: entry, logbook: repo)
        model.note = "new note"

        let saved = await model.save()
        let updated = await repo.updatedEntry()

        #expect(saved)
        #expect(updated?.note == "new note")
    }

    @Test("clearing note removes it from the entry")
    func saveClearsEmptyNote() async throws {
        let repo = SpyLogbookRepository()
        let entry = LogEntry(
            food: makeFood(),
            serving: .grams(100, label: "100 g"),
            consumedAt: .now,
            mealSlot: .breakfast,
            note: "old note"
        )
        let model = EditLogEntryViewModel(entry: entry, logbook: repo)
        model.note = ""

        let saved = await model.save()
        let updated = await repo.updatedEntry()

        #expect(saved)
        #expect(updated?.note == nil)
    }

    private func makeFood() -> FoodItem {
        FoodItem(
            name: "Test Food",
            source: .userCreated,
            facts: NutritionFacts(
                basis: .mass,
                energy: .init(value: 100, unit: .kilocalories),
                macros: Macros(
                    carbohydrates: .init(value: 10, unit: .grams),
                    protein: .init(value: 5, unit: .grams),
                    fat: .init(value: 2, unit: .grams)
                )
            ),
            suggestedServings: [
                .grams(100, label: "100 g"),
                .grams(50, label: "Half")
            ]
        )
    }
}

private actor SpyLogbookRepository: LogbookRepository {
    private var updated: LogEntry?

    func append(_ entry: LogEntry) async throws {}

    func delete(entryID: UUID) async throws {}

    func update(_ entry: LogEntry) async throws {
        updated = entry
    }

    func entries(on day: Date) async throws -> [LogEntry] { [] }

    func entries(from start: Date, to end: Date) async throws -> [LogEntry] { [] }

    func loggedDays(limit: Int) async throws -> [Date] { [] }

    func updatedEntry() -> LogEntry? {
        updated
    }
}
