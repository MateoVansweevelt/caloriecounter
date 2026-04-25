import Foundation
import SwiftData
import SwiftUI

/// Central wiring of concrete services. Exposed to the view tree via a SwiftUI Environment key
/// so view models can pick the services they need and previews can swap in fakes.
@MainActor
public final class AppDependencies {
    public let modelContainer: ModelContainer
    public let nutritionProvider: any NutritionProvider
    public let logbook: any LogbookRepository
    public let health: any HealthRepository
    public let meals: any MealRepository

    public init(
        modelContainer: ModelContainer,
        nutritionProvider: any NutritionProvider,
        logbook: any LogbookRepository,
        health: any HealthRepository,
        meals: any MealRepository
    ) {
        self.modelContainer = modelContainer
        self.nutritionProvider = nutritionProvider
        self.logbook = logbook
        self.health = health
        self.meals = meals
    }

    public static func live() throws -> AppDependencies {
        let container = try AppModelContainer.make()

        // To enable HealthKit sync: replace NullHealthRepository() with HealthKitRepository()
        // and add the HealthKit capability entitlement to the project target.
        let health: any HealthRepository = NullHealthRepository()

        let baseLogbook = SwiftDataLogbookRepository(container: container)
        let logbook = HealthSyncingLogbookRepository(inner: baseLogbook, health: health)
        let meals = SwiftDataMealRepository(container: container)

        return AppDependencies(
            modelContainer: container,
            nutritionProvider: OpenFoodFactsClient(),
            logbook: logbook,
            health: health,
            meals: meals
        )
    }
}

private struct AppDependenciesKey: EnvironmentKey {
    static let defaultValue: AppDependencies? = nil
}

public extension EnvironmentValues {
    var dependencies: AppDependencies? {
        get { self[AppDependenciesKey.self] }
        set { self[AppDependenciesKey.self] = newValue }
    }
}
