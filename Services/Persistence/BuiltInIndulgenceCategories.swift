import Foundation
import SwiftData

nonisolated struct BuiltInIndulgenceCategory: Equatable, Sendable {
  let id: UUID
  let name: String
  let normalizedName: String
  let sortOrder: Int
  let symbolName: String
}

nonisolated enum BuiltInIndulgenceCategories {
  static let all: [BuiltInIndulgenceCategory] = [
    BuiltInIndulgenceCategory(
      id: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!,
      name: "Junk Food",
      normalizedName: "junk food",
      sortOrder: 0,
      symbolName: "takeoutbag.and.cup.and.straw"
    ),
    BuiltInIndulgenceCategory(
      id: UUID(uuidString: "10000000-0000-0000-0000-000000000002")!,
      name: "Unhealthy Snacks",
      normalizedName: "unhealthy snacks",
      sortOrder: 1,
      symbolName: "popcorn"
    ),
    BuiltInIndulgenceCategory(
      id: UUID(uuidString: "10000000-0000-0000-0000-000000000003")!,
      name: "Candy",
      normalizedName: "candy",
      sortOrder: 2,
      symbolName: "birthday.cake"
    ),
    BuiltInIndulgenceCategory(
      id: UUID(uuidString: "10000000-0000-0000-0000-000000000004")!,
      name: "Alcohol",
      normalizedName: "alcohol",
      sortOrder: 3,
      symbolName: "wineglass"
    ),
    BuiltInIndulgenceCategory(
      id: UUID(uuidString: "10000000-0000-0000-0000-000000000005")!,
      name: "Desserts",
      normalizedName: "desserts",
      sortOrder: 4,
      symbolName: "fork.knife"
    ),
  ]

  static func seed(
    in context: ModelContext,
    now: Date,
    save: (ModelContext) throws -> Void = { try $0.save() }
  ) throws {
    do {
      let existing = try context.fetch(FetchDescriptor<IndulgenceCategoryRecord>())

      for category in all {
        let matches = existing.filter { $0.id == category.id }
        guard matches.count <= 1 else { throw RepositoryError.corruptedData }
        if let record = matches.first {
          if record.symbolName != category.symbolName {
            record.symbolName = category.symbolName
            record.updatedAt = now
          }
        } else {
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
