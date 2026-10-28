import Foundation
import SwiftData

enum CadenceModelContainerFactory {
  static func productionConfiguration(url: URL? = nil) -> ModelConfiguration {
    let schema = Schema(versionedSchema: CadenceSchemaV1.self)
    if let url {
      return ModelConfiguration(
        "Cadence",
        schema: schema,
        url: url,
        cloudKitDatabase: .none
      )
    }
    return ModelConfiguration(
      "Cadence",
      schema: schema,
      isStoredInMemoryOnly: false,
      groupContainer: .none,
      cloudKitDatabase: .none
    )
  }

  static func inMemoryConfiguration() -> ModelConfiguration {
    ModelConfiguration(
      "CadenceTests",
      schema: Schema(versionedSchema: CadenceSchemaV1.self),
      isStoredInMemoryOnly: true,
      groupContainer: .none,
      cloudKitDatabase: .none
    )
  }

  static func makeProductionContainer(url: URL? = nil) throws -> ModelContainer {
    try makeContainer(configuration: productionConfiguration(url: url))
  }

  static func makeInMemoryContainer() throws -> ModelContainer {
    try makeContainer(configuration: inMemoryConfiguration())
  }

  private static func makeContainer(configuration: ModelConfiguration) throws -> ModelContainer {
    try ModelContainer(
      for: Schema(versionedSchema: CadenceSchemaV1.self),
      migrationPlan: CadenceMigrationPlan.self,
      configurations: [configuration]
    )
  }
}
