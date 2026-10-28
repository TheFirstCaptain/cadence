import SwiftData

enum CadenceMigrationPlan: SchemaMigrationPlan {
  static let schemas: [any VersionedSchema.Type] = [CadenceSchemaV1.self]
  static let stages: [MigrationStage] = []
}
