import Foundation
import SwiftData

nonisolated struct BuiltInIndulgenceCategory: Equatable, Sendable {
  let id: UUID
  let name: String
  let normalizedName: String
  let sortOrder: Int

  // F-003 will select category-specific symbols. Identity is independent of this provisional value.
  let symbolName = "circle"
}

nonisolated enum BuiltInIndulgenceCategories {
  static let all: [BuiltInIndulgenceCategory] = [
    BuiltInIndulgenceCategory(
      id: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!,
      name: "Junk Food",
      normalizedName: "junk food",
      sortOrder: 0
    ),
    BuiltInIndulgenceCategory(
      id: UUID(uuidString: "10000000-0000-0000-0000-000000000002")!,
      name: "Unhealthy Snacks",
      normalizedName: "unhealthy snacks",
      sortOrder: 1
    ),
    BuiltInIndulgenceCategory(
      id: UUID(uuidString: "10000000-0000-0000-0000-000000000003")!,
      name: "Candy",
      normalizedName: "candy",
      sortOrder: 2
    ),
    BuiltInIndulgenceCategory(
      id: UUID(uuidString: "10000000-0000-0000-0000-000000000004")!,
      name: "Alcohol",
      normalizedName: "alcohol",
      sortOrder: 3
    ),
    BuiltInIndulgenceCategory(
      id: UUID(uuidString: "10000000-0000-0000-0000-000000000005")!,
      name: "Desserts",
      normalizedName: "desserts",
      sortOrder: 4
    ),
  ]

  static func seed(
    in context: ModelContext,
    now: Date,
    save: (ModelContext) throws -> Void = { try $0.save() }
  ) throws {
    do {
      let existing = try context.fetch(FetchDescriptor<IndulgenceCategoryRecord>())
      let existingIDs = Set(existing.map(\.id))

      for category in all where !existingIDs.contains(category.id) {
        context.insert(
          IndulgenceCategoryRecord(
            id: category.id,
            name: category.name,
            normalizedName: category.normalizedName,
            symbolName: category.symbolName,
            sortOrder: category.sortOrder,
            isBuiltIn: true,
            isActive: true,
            createdAt: now,
            updatedAt: now
          ))
      }

      if context.hasChanges {
        try save(context)
      }
    } catch {
      context.rollback()
      throw error
    }
  }
}
