import Foundation

nonisolated struct GoalConfiguration: Hashable, Sendable {
  let name: String
  let frequency: GoalFrequency
}

nonisolated struct WeeklyPlanSnapshot: Hashable, Sendable {
  let id: UUID
  let week: WeekID
  let planningTimeZoneIdentifier: String
  let planningUTCOffsetSeconds: Int
  let goals: [PlannedGoalSnapshot]
  let createdAt: Date
  let updatedAt: Date
}

nonisolated struct PlannedGoalSnapshot: Hashable, Sendable {
  let id: UUID
  let weeklyPlanID: UUID
  let lineageID: UUID
  let name: String
  let frequency: GoalFrequency
  let sortOrder: Int
  let activeFrom: LocalDay
  let activeThrough: LocalDay?
  let createdAt: Date
  let updatedAt: Date

  func wasHistoricallyActive(on day: LocalDay) -> Bool {
    activeFrom <= day && (activeThrough.map { day <= $0 } ?? true)
  }

  var isCurrentlyOffered: Bool {
    activeThrough == nil
  }
}

nonisolated struct GoalCheckoffSnapshot: Hashable, Sendable {
  let id: UUID
  let plannedGoalID: UUID
  let instant: Date
  let localDay: LocalDay
  let timeZoneIdentifier: String
  let utcOffsetSeconds: Int
  let createdAt: Date
  let updatedAt: Date
}

nonisolated struct IndulgenceCategorySnapshot: Hashable, Sendable {
  let id: UUID
  let name: String
  let symbolName: String
  let sortOrder: Int
  let isBuiltIn: Bool
  let isActive: Bool
}

nonisolated struct IndulgenceOccurrenceSnapshot: Hashable, Sendable {
  let id: UUID
  let categoryID: UUID
  let instant: Date
  let localDay: LocalDay
  let timeZoneIdentifier: String
  let utcOffsetSeconds: Int
  let createdAt: Date
  let updatedAt: Date
}

nonisolated struct DayActivitySnapshot: Hashable, Sendable {
  let day: LocalDay
  let goals: [PlannedGoalSnapshot]
  let checkoffs: [GoalCheckoffSnapshot]
  let categories: [IndulgenceCategorySnapshot]
  let occurrences: [IndulgenceOccurrenceSnapshot]
}

nonisolated struct MyDaySnapshot: Hashable, Sendable {
  let day: LocalDay
  let week: WeekID
  let goals: [PlannedGoalSnapshot]
  let todayCheckoffs: [GoalCheckoffSnapshot]
  let weekCheckoffs: [GoalCheckoffSnapshot]
}

nonisolated struct WeekActivitySnapshot: Hashable, Sendable {
  let plan: WeeklyPlanSnapshot?
  let checkoffs: [GoalCheckoffSnapshot]
  let occurrences: [IndulgenceOccurrenceSnapshot]
}

nonisolated enum RepositoryError: Error, Equatable, Sendable {
  case duplicatePlan
  case planNotFound
  case goalNotFound
  case categoryNotFound
  case blankGoalName
  case duplicateGoalName
  case invalidFrequency
  case invalidOrdering
  case immutablePlan
  case nonconsecutiveWeeks
  case inactiveGoal
  case duplicateCheckoff
  case targetAlreadyMet
  case identifierCollision
  case corruptedData
  case persistenceFailure
}
