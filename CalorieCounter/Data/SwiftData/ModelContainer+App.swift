import Foundation
import SwiftData

public enum AppSchemaV1: VersionedSchema {
    public static var versionIdentifier: Schema.Version { .init(1, 0, 0) }
    public static var models: [any PersistentModel.Type] {
        [PersistedLogEntry.self, PersistedFoodItem.self]
    }
}

public enum AppSchemaV2: VersionedSchema {
    public static var versionIdentifier: Schema.Version { .init(2, 0, 0) }
    public static var models: [any PersistentModel.Type] {
        [PersistedLogEntry.self, PersistedFoodItem.self, PersistedMeal.self]
    }
}

public enum AppMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] { [AppSchemaV1.self, AppSchemaV2.self] }
    public static var stages: [MigrationStage] {
        [.lightweight(fromVersion: AppSchemaV1.self, toVersion: AppSchemaV2.self)]
    }
}

public enum AppModelContainer {
    public static func make(inMemory: Bool = false) throws -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: Schema(AppSchemaV2.models),
            isStoredInMemoryOnly: inMemory
        )
        return try ModelContainer(
            for: Schema(AppSchemaV2.models),
            migrationPlan: AppMigrationPlan.self,
            configurations: [configuration]
        )
    }
}
