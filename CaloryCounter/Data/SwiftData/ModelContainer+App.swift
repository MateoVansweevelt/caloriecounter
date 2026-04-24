import Foundation
import SwiftData

public enum AppSchemaV1: VersionedSchema {
    public static var versionIdentifier: Schema.Version { .init(1, 0, 0) }
    public static var models: [any PersistentModel.Type] {
        [PersistedLogEntry.self, PersistedFoodItem.self]
    }
}

public enum AppMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] { [AppSchemaV1.self] }
    public static var stages: [MigrationStage] { [] }
}

public enum AppModelContainer {
    public static func make(inMemory: Bool = false) throws -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: Schema(AppSchemaV1.models),
            isStoredInMemoryOnly: inMemory
        )
        return try ModelContainer(
            for: Schema(AppSchemaV1.models),
            migrationPlan: AppMigrationPlan.self,
            configurations: [configuration]
        )
    }
}
