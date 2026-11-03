import Foundation

nonisolated enum UITestMyDayMode: Equatable, Sendable {
  case empty
  case populated
  case readFailure
  case mutationFailure
  case myGoalsReadFailure
  case myGoalsMutationFailure
  case manyGoals
  case myGoalsReorderFailure
  case myGoalsRemovalFailure
}

extension AppDependencies {
  @MainActor
  static func uiTest(_ mode: UITestMyDayMode) throws -> AppDependencies {
    let instant = ISO8601DateFormatter().date(from: "2026-10-28T16:00:00Z")!
    let zone = TimeZone(identifier: "America/New_York")!
    let date = DateProvider { instant }
    let timeZone = CurrentTimeZoneProvider { zone }
    let uuid = UUIDProvider.live
    let store = CadenceStore(
      modelContainer: try CadenceModelContainerFactory.makeInMemoryContainer(),
      dependencies: CadenceStoreDependencies(date: date, timeZone: timeZone, uuid: uuid))
    let preparer = UITestMyDayPreparer(store: store, mode: mode, instant: instant, timeZone: zone)
    let dailyTracking: any DailyTrackingRepository =
      switch mode {
      case .readFailure: FailingMyDayRepository(base: store, failsReads: true)
      case .mutationFailure: FailingMyDayRepository(base: store, failsReads: false)
      case .empty, .populated, .myGoalsReadFailure, .myGoalsMutationFailure, .manyGoals,
        .myGoalsReorderFailure, .myGoalsRemovalFailure:
        store
      }
    let planning: any PlanningRepository =
      switch mode {
      case .myGoalsReadFailure: FailingPlanningRepository(base: store)
      case .myGoalsMutationFailure:
        FailFirstMutationPlanningRepository(base: store, operation: .add)
      case .myGoalsReorderFailure:
        FailFirstMutationPlanningRepository(base: store, operation: .reorder)
      case .myGoalsRemovalFailure:
        FailFirstMutationPlanningRepository(base: store, operation: .remove)
      default: store
      }
    return AppDependencies(
      planning: planning,
      dailyTracking: dailyTracking,
      history: store,
      applicationPreparing: preparer,
      date: date,
      timeZone: timeZone,
      uuid: uuid)
  }
}

private actor FailFirstMutationPlanningRepository: PlanningRepository {
  enum Operation: Equatable, Sendable { case add, reorder, remove }

  let base: CadenceStore
  let operation: Operation
  private var hasFailed = false

  init(base: CadenceStore, operation: Operation) {
    self.base = base
    self.operation = operation
  }

  func plan(for week: WeekID) async throws -> WeeklyPlanSnapshot? {
    try await base.plan(for: week)
  }

  func resolvePlan(for week: WeekID) async throws -> WeeklyPlanSnapshot {
    try await base.resolvePlan(for: week)
  }

  func ensurePlan(for week: WeekID) async throws -> WeeklyPlanSnapshot {
    try await base.ensurePlan(for: week)
  }

  func addGoal(to week: WeekID, configuration: GoalConfiguration) async throws
    -> PlannedGoalSnapshot
  {
    if operation == .add, !hasFailed {
      hasFailed = true
      throw RepositoryError.persistenceFailure
    }
    return try await base.addGoal(to: week, configuration: configuration)
  }

  func updateGoal(id: UUID, configuration: GoalConfiguration) async throws -> PlannedGoalSnapshot {
    try await base.updateGoal(id: id, configuration: configuration)
  }

  func removeGoal(id: UUID, effectiveOn day: LocalDay) async throws -> PlannedGoalSnapshot {
    if operation == .remove, !hasFailed {
      hasFailed = true
      throw RepositoryError.persistenceFailure
    }
    return try await base.removeGoal(id: id, effectiveOn: day)
  }

  func reorderGoals(in week: WeekID, orderedIDs: [UUID]) async throws -> WeeklyPlanSnapshot {
    if operation == .reorder, !hasFailed {
      hasFailed = true
      throw RepositoryError.persistenceFailure
    }
    return try await base.reorderGoals(in: week, orderedIDs: orderedIDs)
  }

  func carryForward(from source: WeekID, to target: WeekID) async throws -> WeeklyPlanSnapshot {
    try await base.carryForward(from: source, to: target)
  }
}

private actor UITestMyDayPreparer: ApplicationPreparing {
  let store: CadenceStore
  let mode: UITestMyDayMode
  let instant: Date
  let timeZone: TimeZone

  init(store: CadenceStore, mode: UITestMyDayMode, instant: Date, timeZone: TimeZone) {
    self.store = store
    self.mode = mode
    self.instant = instant
    self.timeZone = timeZone
  }

  func prepare() async throws {
    try await store.prepare()
    guard
      [
        UITestMyDayMode.populated, .mutationFailure, .manyGoals, .myGoalsReorderFailure,
        .myGoalsRemovalFailure,
      ].contains(mode)
    else { return }
    let calendar = GregorianCalendarService(timeZone: timeZone)
    let day = calendar.localDay(containing: instant)
    let week = calendar.week(containing: instant)
    guard try await store.plan(for: week) == nil else { return }
    _ = try await store.ensurePlan(for: week)
    if mode == .manyGoals {
      for index in 1...8 {
        _ = try await store.addGoal(
          to: week,
          configuration: GoalConfiguration(name: "Goal \(index)", frequency: .daily))
      }
      return
    }
    let custom = try await store.addGoal(
      to: week,
      configuration: GoalConfiguration(name: "Read", frequency: .custom(daysPerWeek: 3)!))
    let daily = try await store.addGoal(
      to: week,
      configuration: GoalConfiguration(name: "Walk", frequency: .daily))
    let weekly = try await store.addGoal(
      to: week,
      configuration: GoalConfiguration(name: "Swim", frequency: .weekly))
    _ = try await store.reorderGoals(in: week, orderedIDs: [weekly.id, daily.id, custom.id])
    _ = try await store.recordCheckoff(goalID: daily.id, on: day)
    _ = try await store.recordCheckoff(goalID: custom.id, on: day)
    _ = try await store.recordCheckoff(goalID: custom.id, on: day.addingDays(1)!)
    _ = try await store.recordIndulgence(categoryID: BuiltInIndulgenceCategories.all[2].id)
    _ = try await store.recordIndulgence(categoryID: BuiltInIndulgenceCategories.all[2].id)
  }
}

private actor FailingMyDayRepository: DailyTrackingRepository {
  let base: CadenceStore
  let failsReads: Bool

  init(base: CadenceStore, failsReads: Bool) {
    self.base = base
    self.failsReads = failsReads
  }

  func myDaySnapshot(for day: LocalDay) async throws -> MyDaySnapshot {
    if failsReads { throw RepositoryError.persistenceFailure }
    return try await base.myDaySnapshot(for: day)
  }

  func daySnapshot(for day: LocalDay) async throws -> DayActivitySnapshot {
    try await base.daySnapshot(for: day)
  }

  func recordCheckoff(goalID: UUID, on day: LocalDay) async throws -> GoalCheckoffSnapshot {
    if !failsReads { throw RepositoryError.persistenceFailure }
    return try await base.recordCheckoff(goalID: goalID, on: day)
  }

  func removeCheckoff(goalID: UUID, on day: LocalDay) async throws -> GoalCheckoffSnapshot? {
    if !failsReads { throw RepositoryError.persistenceFailure }
    return try await base.removeCheckoff(goalID: goalID, on: day)
  }

  func recordIndulgence(categoryID: UUID) async throws -> IndulgenceOccurrenceSnapshot {
    if !failsReads { throw RepositoryError.persistenceFailure }
    return try await base.recordIndulgence(categoryID: categoryID)
  }

  func removeLatestIndulgence(categoryID: UUID, on day: LocalDay) async throws
    -> IndulgenceOccurrenceSnapshot?
  {
    if !failsReads { throw RepositoryError.persistenceFailure }
    return try await base.removeLatestIndulgence(categoryID: categoryID, on: day)
  }
}

private actor FailingPlanningRepository: PlanningRepository {
  let base: CadenceStore

  init(base: CadenceStore) {
    self.base = base
  }

  func plan(for week: WeekID) async throws -> WeeklyPlanSnapshot? {
    try await base.plan(for: week)
  }

  func resolvePlan(for week: WeekID) throws -> WeeklyPlanSnapshot {
    throw RepositoryError.persistenceFailure
  }

  func ensurePlan(for week: WeekID) async throws -> WeeklyPlanSnapshot {
    try await base.ensurePlan(for: week)
  }

  func addGoal(to week: WeekID, configuration: GoalConfiguration) async throws
    -> PlannedGoalSnapshot
  {
    try await base.addGoal(to: week, configuration: configuration)
  }

  func updateGoal(id: UUID, configuration: GoalConfiguration) async throws -> PlannedGoalSnapshot {
    try await base.updateGoal(id: id, configuration: configuration)
  }

  func removeGoal(id: UUID, effectiveOn day: LocalDay) async throws -> PlannedGoalSnapshot {
    try await base.removeGoal(id: id, effectiveOn: day)
  }

  func reorderGoals(in week: WeekID, orderedIDs: [UUID]) async throws -> WeeklyPlanSnapshot {
    try await base.reorderGoals(in: week, orderedIDs: orderedIDs)
  }

  func carryForward(from source: WeekID, to target: WeekID) async throws -> WeeklyPlanSnapshot {
    try await base.carryForward(from: source, to: target)
  }
}
