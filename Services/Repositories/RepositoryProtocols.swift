import Foundation

protocol PlanningRepository: Sendable {
  func plan(for week: WeekID) async throws -> WeeklyPlanSnapshot?
  func ensurePlan(for week: WeekID) async throws -> WeeklyPlanSnapshot
  func addGoal(to week: WeekID, configuration: GoalConfiguration) async throws
    -> PlannedGoalSnapshot
  func updateGoal(id: UUID, configuration: GoalConfiguration) async throws -> PlannedGoalSnapshot
  func removeGoal(id: UUID, effectiveOn day: LocalDay) async throws -> PlannedGoalSnapshot
  func reorderGoals(in week: WeekID, orderedIDs: [UUID]) async throws -> WeeklyPlanSnapshot
  func carryForward(from source: WeekID, to target: WeekID) async throws -> WeeklyPlanSnapshot
}

protocol DailyTrackingRepository: Sendable {
  func daySnapshot(for day: LocalDay) async throws -> DayActivitySnapshot
  func recordCheckoff(goalID: UUID, on day: LocalDay) async throws -> GoalCheckoffSnapshot
  func removeCheckoff(goalID: UUID, on day: LocalDay) async throws -> GoalCheckoffSnapshot?
  func recordIndulgence(categoryID: UUID) async throws -> IndulgenceOccurrenceSnapshot
  func removeLatestIndulgence(categoryID: UUID, on day: LocalDay) async throws
    -> IndulgenceOccurrenceSnapshot?
}

protocol HistoryRepository: Sendable {
  func weekSnapshot(for week: WeekID) async throws -> WeekActivitySnapshot
  func dayHistory(for day: LocalDay) async throws -> DayActivitySnapshot
  func removeOccurrence(id: UUID) async throws -> IndulgenceOccurrenceSnapshot?
}
