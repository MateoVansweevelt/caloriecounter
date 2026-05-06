import Foundation

@Observable
@MainActor
final class EditLogEntryViewModel {
    let entry: LogEntry
    var customAmount: Double
    var displayUnit: ServingDisplayUnit
    var consumedAt: Date
    var mealSlot: MealSlot
    var note: String
    var isSaving: Bool = false
    var errorMessage: String?

    private let logbook: any LogbookRepository

    init(entry: LogEntry, logbook: any LogbookRepository) {
        self.entry = entry
        self.customAmount = entry.serving.amount
        self.displayUnit = .default(for: entry.serving.basis)
        self.consumedAt = entry.consumedAt
        self.mealSlot = entry.mealSlot
        self.note = entry.note ?? ""
        self.logbook = logbook
    }

    var availableDisplayUnits: [ServingDisplayUnit] {
        ServingDisplayUnit.available(for: entry.serving.basis)
    }

    var displayAmount: Double {
        get { customAmount / displayUnit.baseFactor }
        set { customAmount = max(0, newValue * displayUnit.baseFactor) }
    }

    var displayStep: Double {
        switch displayUnit {
        case .grams, .millilitres: 5
        case .kilograms, .litres: 0.05
        case .ounces, .fluidOunces: 0.5
        case .pounds: 0.1
        }
    }

    func incrementAmount() { displayAmount += displayStep }
    func decrementAmount() { displayAmount = max(0, displayAmount - displayStep) }

    var selectedSuggestedServing: Serving? {
        entry.food.suggestedServings.first {
            $0.basis == entry.serving.basis && $0.amount == customAmount
        }
    }

    func applySuggestedServing(_ serving: Serving?) {
        guard let serving else { return }
        customAmount = serving.amount
        displayUnit = .default(for: serving.basis)
    }

    var effectiveServing: Serving {
        Serving(basis: entry.serving.basis, amount: customAmount, label: selectedSuggestedServing?.label)
    }

    var consumed: ConsumedNutrition {
        entry.food.facts.values(for: effectiveServing)
    }

    func save() async -> Bool {
        isSaving = true
        defer { isSaving = false }
        var updated = entry
        updated.serving = effectiveServing
        updated.consumedAt = consumedAt
        updated.mealSlot = mealSlot
        updated.note = note.isEmpty ? nil : note
        do {
            try await logbook.update(updated)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func delete() async -> Bool {
        isSaving = true
        defer { isSaving = false }
        do {
            try await logbook.delete(entryID: entry.id)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
