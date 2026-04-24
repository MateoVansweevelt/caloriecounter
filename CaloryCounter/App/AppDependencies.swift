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

    public init(
        modelContainer: ModelContainer,
        nutritionProvider: any NutritionProvider,
        logbook: any LogbookRepository
    ) {
        self.modelContainer = modelContainer
        self.nutritionProvider = nutritionProvider
        self.logbook = logbook
    }

    public static func live() throws -> AppDependencies {
        let container = try AppModelContainer.make()
        let logbook = SwiftDataLogbookRepository(container: container)
        let nutrition = OpenFoodFactsClient()
        return AppDependencies(
            modelContainer: container,
            nutritionProvider: nutrition,
            logbook: logbook
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
