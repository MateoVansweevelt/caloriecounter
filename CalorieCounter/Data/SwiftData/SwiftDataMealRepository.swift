import Foundation
import SwiftData

public actor SwiftDataMealRepository: MealRepository {
    private let container: ModelContainer

    public init(container: ModelContainer) {
        self.container = container
    }

    public func all() async throws -> [CustomMeal] {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<PersistedMeal>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        let models = try context.fetch(descriptor)
        return try models.map { try PersistedMealMapping.meal(from: $0) }
    }

    public func save(_ meal: CustomMeal) async throws {
        let context = ModelContext(container)
        let id = meal.id
        let descriptor = FetchDescriptor<PersistedMeal>(
            predicate: #Predicate { $0.id == id }
        )
        if let existing = try context.fetch(descriptor).first {
            try PersistedMealMapping.apply(meal, to: existing)
        } else {
            let model = try PersistedMealMapping.make(from: meal)
            context.insert(model)
        }
        try context.save()
    }

    public func delete(_ meal: CustomMeal) async throws {
        let context = ModelContext(container)
        let id = meal.id
        let descriptor = FetchDescriptor<PersistedMeal>(
            predicate: #Predicate { $0.id == id }
        )
        if let model = try context.fetch(descriptor).first {
            context.delete(model)
            try context.save()
        }
    }
}
