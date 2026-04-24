import Foundation

enum ServingDisplayUnit: Hashable, Sendable {
    case grams
    case kilograms
    case millilitres
    case litres

    var symbol: String {
        switch self {
        case .grams: "g"
        case .kilograms: "kg"
        case .millilitres: "ml"
        case .litres: "l"
        }
    }

    /// Multiplier from this display unit to the base unit (g or ml).
    var baseFactor: Double {
        switch self {
        case .grams, .millilitres: 1
        case .kilograms, .litres: 1000
        }
    }

    static func available(for basis: ServingBasis) -> [ServingDisplayUnit] {
        switch basis {
        case .mass: [.grams, .kilograms]
        case .volume: [.millilitres, .litres]
        }
    }

    static func `default`(for basis: ServingBasis) -> ServingDisplayUnit {
        switch basis {
        case .mass: .grams
        case .volume: .millilitres
        }
    }
}

@Observable
@MainActor
final class FoodDetailViewModel {
    let food: FoodItem
    var selectedServing: Serving
    var customAmount: Double
    var displayUnit: ServingDisplayUnit
    var mealSlot: MealSlot
    var consumedAt: Date = .now
    var note: String = ""
    var isSaving: Bool = false
    var errorMessage: String?

    private let logbook: any LogbookRepository

    init(food: FoodItem, logbook: any LogbookRepository) {
        self.food = food
        let defaultServing = food.defaultServing
        self.selectedServing = defaultServing
        self.customAmount = defaultServing.amount
        self.displayUnit = .default(for: food.facts.basis)
        self.mealSlot = .inferred(at: .now)
        self.logbook = logbook
    }

    var availableDisplayUnits: [ServingDisplayUnit] {
        ServingDisplayUnit.available(for: food.facts.basis)
    }

    /// Amount expressed in the currently-selected display unit.
    var displayAmount: Double {
        get { customAmount / displayUnit.baseFactor }
        set { customAmount = max(0, newValue * displayUnit.baseFactor) }
    }

    /// Step applied by +/- buttons, in display units. Larger units get smaller steps.
    var displayStep: Double {
        switch displayUnit {
        case .grams, .millilitres: 5
        case .kilograms, .litres: 0.05
        }
    }

    func incrementAmount() {
        displayAmount = displayAmount + displayStep
    }

    func decrementAmount() {
        displayAmount = max(0, displayAmount - displayStep)
    }

    var effectiveServing: Serving {
        Serving(basis: food.facts.basis, amount: customAmount, label: selectedServing.label)
    }

    var consumed: ConsumedNutrition {
        food.facts.values(for: effectiveServing)
    }

    func save() async -> Bool {
        isSaving = true
        defer { isSaving = false }
        let entry = LogEntry(
            food: food,
            serving: effectiveServing,
            consumedAt: consumedAt,
            mealSlot: mealSlot,
            note: note.isEmpty ? nil : note
        )
        do {
            try await logbook.append(entry)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
