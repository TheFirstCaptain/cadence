import Foundation
import Synchronization
import Testing

@testable import Cadence

@MainActor
struct MyGoalsModelTests {
  private let utc = TimeZone(secondsFromGMT: 0)!

  @Test
  func weekdayTargetsThisWeekAndSundayTargetsNextWeek() {
    let wednesday = instant(year: 2026, month: 10, day: 28, hour: 12)
    let sunday = instant(year: 2026, month: 11, day: 1, hour: 12)

    let weekdayIdentity = MyGoalsIdentity(instant: wednesday, timeZone: utc)
    let sundayIdentity = MyGoalsIdentity(instant: sunday, timeZone: utc)

    #expect(weekdayIdentity.phase == .thisWeek)
    #expect(weekdayIdentity.targetWeek.monday == LocalDay(year: 2026, month: 10, day: 26))
    #expect(sundayIdentity.phase == .nextWeek)
    #expect(sundayIdentity.targetWeek.monday == LocalDay(year: 2026, month: 11, day: 2))
  }

  @Test
  func targetIdentityUsesTheCurrentTimeZoneAcrossAYearBoundary() {
    let instant = instant(year: 2027, month: 1, day: 3, hour: 1)
    let newYork = TimeZone(identifier: "America/New_York")!

    let utcIdentity = MyGoalsIdentity(instant: instant, timeZone: utc)
    let newYorkIdentity = MyGoalsIdentity(instant: instant, timeZone: newYork)

    #expect(utcIdentity.phase == .nextWeek)
    #expect(utcIdentity.targetWeek.monday == LocalDay(year: 2027, month: 1, day: 4))
    #expect(newYorkIdentity.phase == .thisWeek)
    #expect(newYorkIdentity.targetWeek.monday == LocalDay(year: 2026, month: 12, day: 28))
  }

  @Test
  func sundayToMondayChangesPhaseEvenWhenTheTargetWeekStaysTheSame() async throws {
    let date = Mutex(instant(year: 2026, month: 11, day: 1, hour: 12))
    let repository = StubPlanningRepository()
    let model = MyGoalsModel(
      repository: repository,
      date: DateProvider { date.withLock { $0 } },
      timeZone: CurrentTimeZoneProvider { self.utc })

    await model.loadInitial()
    let sunday = try readyPresentation(model.state)
    date.withLock { $0 = instant(year: 2026, month: 11, day: 2, hour: 12) }
    await model.refreshFromBoundaryEvent()
    let monday = try readyPresentation(model.state)

    #expect(sunday.identity.targetWeek == monday.identity.targetWeek)
    #expect(sunday.identity.phase == .nextWeek)
    #expect(monday.identity.phase == .thisWeek)
    #expect(await repository.resolvedWeeks.count == 2)
  }

  @Test
  func presentationPreservesPlanOrderAndUsesCalmFrequencyLabels() {
    let week = WeekID(monday: LocalDay(year: 2026, month: 10, day: 26)!)!
    let identity = MyGoalsIdentity(
      instant: instant(year: 2026, month: 10, day: 28, hour: 12), timeZone: utc)
    let plan = snapshot(
      week: week,
      goals: [
        goal(name: "Walk", frequency: .daily, order: 0, week: week),
        goal(name: "Read", frequency: .custom(daysPerWeek: 3)!, order: 1, week: week),
        goal(name: "Swim", frequency: .weekly, order: 2, week: week),
      ])

    let presentation = MyGoalsPresentation(identity: identity, plan: plan)

    #expect(presentation.rows.map(\.name) == ["Walk", "Read", "Swim"])
    #expect(presentation.rows.map(\.frequencyText) == ["Daily", "3 days per week", "Weekly"])
  }

  @Test
  func manageableGuidanceBeginsAtEightGoals() {
    let week = WeekID(monday: LocalDay(year: 2026, month: 10, day: 26)!)!
    let identity = MyGoalsIdentity(
      instant: instant(year: 2026, month: 10, day: 28, hour: 12), timeZone: utc)
    let goals = (0..<8).map {
      goal(name: "Goal \($0 + 1)", frequency: .daily, order: $0, week: week)
    }
    let seven = snapshot(week: week, goals: Array(goals.prefix(7)))

    #expect(
      !MyGoalsPresentation(identity: identity, plan: seven)
        .showsManageableListGuidance)
    #expect(
      MyGoalsPresentation(identity: identity, plan: snapshot(week: week, goals: goals))
        .showsManageableListGuidance)
  }

  @Test
  func anOlderReadCannotReplaceANewerPhaseForTheSameWeek() async throws {
    let sunday = instant(year: 2026, month: 11, day: 1, hour: 12)
    let monday = instant(year: 2026, month: 11, day: 2, hour: 12)
    let date = Mutex(sunday)
    let repository = DelayedPlanningRepository()
    let model = MyGoalsModel(
      repository: repository,
      date: DateProvider { date.withLock { $0 } },
      timeZone: CurrentTimeZoneProvider { self.utc })

    let older = Task { await model.loadInitial() }
    await Task.yield()
    date.withLock { $0 = monday }
    await model.refreshFromForeground()
    await older.value

    #expect(try readyPresentation(model.state).identity.phase == .thisWeek)
  }

  @Test
  func successfulAddAndEditReconcileReturnedSnapshotsAndNotifyMyDay() async throws {
    let instant = instant(year: 2026, month: 10, day: 28, hour: 12)
    let repository = EditingPlanningRepository()
    let notifications = Mutex(0)
    let model = MyGoalsModel(
      repository: repository,
      date: DateProvider { instant },
      timeZone: CurrentTimeZoneProvider { self.utc },
      onPlanChanged: { notifications.withLock { $0 += 1 } })
    await model.loadInitial()
    let identity = try readyPresentation(model.state).identity

    #expect(
      await model.saveGoal(
        id: nil, configuration: GoalConfiguration(name: "Walk", frequency: .daily),
        presentedIdentity: identity) == .saved)
    let added = try #require(try readyPresentation(model.state).rows.first)
    #expect(added.name == "Walk")

    #expect(
      await model.saveGoal(
        id: added.id,
        configuration: GoalConfiguration(name: "Evening walk", frequency: .custom(daysPerWeek: 3)!),
        presentedIdentity: identity) == .saved)
    let edited = try #require(try readyPresentation(model.state).rows.first)
    #expect(edited.id == added.id)
    #expect(edited.name == "Evening walk")
    #expect(edited.frequency == .custom(daysPerWeek: 3))
    #expect(notifications.withLock { $0 } == 2)
  }

  @Test
  func successfulReorderAndRemovalReconcileAndNotifyMyDay() async throws {
    let instant = instant(year: 2026, month: 10, day: 28, hour: 12)
    let repository = EditingPlanningRepository()
    let notifications = Mutex(0)
    let model = MyGoalsModel(
      repository: repository, date: DateProvider { instant },
      timeZone: CurrentTimeZoneProvider { self.utc },
      onPlanChanged: { notifications.withLock { $0 += 1 } })
    await model.loadInitial()
    let identity = try readyPresentation(model.state).identity
    for name in ["Walk", "Read", "Swim"] {
      _ = await model.saveGoal(
        id: nil, configuration: GoalConfiguration(name: name, frequency: .daily),
        presentedIdentity: identity)
    }
    let original = try readyPresentation(model.state).rows
    let reordered = [original[2], original[0], original[1]]

    #expect(
      await model.reorderGoals(orderedRows: reordered, presentedIdentity: identity) == .saved)
    #expect(try readyPresentation(model.state).rows.map(\.name) == ["Swim", "Walk", "Read"])
    #expect(
      await model.removeGoal(id: original[0].id, presentedIdentity: identity) == .saved)
    #expect(try readyPresentation(model.state).rows.map(\.name) == ["Swim", "Read"])
    #expect(notifications.withLock { $0 } == 5)
  }

  @Test
  func failedReorderRollsBackAndFailedRemovalKeepsTheGoalForRetry() async throws {
    let instant = instant(year: 2026, month: 10, day: 28, hour: 12)
    let repository = EditingPlanningRepository(failReorderOnce: true, failRemovalOnce: true)
    let model = MyGoalsModel(
      repository: repository, date: DateProvider { instant },
      timeZone: CurrentTimeZoneProvider { self.utc })
    await model.loadInitial()
    let identity = try readyPresentation(model.state).identity
    for name in ["Walk", "Read"] {
      _ = await model.saveGoal(
        id: nil, configuration: GoalConfiguration(name: name, frequency: .daily),
        presentedIdentity: identity)
    }
    let original = try readyPresentation(model.state).rows

    #expect(
      await model.reorderGoals(
        orderedRows: Array(original.reversed()), presentedIdentity: identity) == .failed)
    #expect(try readyPresentation(model.state).rows == original)
    #expect(model.guidanceMessage == "Couldn’t reorder these Goals. Please try again.")
    #expect(await model.removeGoal(id: original[0].id, presentedIdentity: identity) == .failed)
    #expect(try readyPresentation(model.state).rows == original)
    #expect(await model.removeGoal(id: original[0].id, presentedIdentity: identity) == .saved)
    #expect(try readyPresentation(model.state).rows.map(\.name) == ["Read"])
  }

  @Test
  func staleEditorDoesNotWriteAfterPlanningWeekChanges() async throws {
    let date = Mutex(instant(year: 2026, month: 11, day: 1, hour: 12))
    let repository = EditingPlanningRepository()
    let model = MyGoalsModel(
      repository: repository,
      date: DateProvider { date.withLock { $0 } },
      timeZone: CurrentTimeZoneProvider { self.utc })
    await model.loadInitial()
    let sundayIdentity = try readyPresentation(model.state).identity
    date.withLock { $0 = instant(year: 2026, month: 11, day: 2, hour: 12) }

    let result = await model.saveGoal(
      id: nil, configuration: GoalConfiguration(name: "Walk", frequency: .daily),
      presentedIdentity: sundayIdentity)

    #expect(result == .planningWeekChanged)
    #expect(await repository.mutationCount == 0)
    #expect(try readyPresentation(model.state).identity.phase == .thisWeek)
  }

  @Test
  func staleReorderAndRemovalIntentsDoNotWrite() async throws {
    let date = Mutex(instant(year: 2026, month: 11, day: 1, hour: 12))
    let repository = EditingPlanningRepository()
    let model = MyGoalsModel(
      repository: repository, date: DateProvider { date.withLock { $0 } },
      timeZone: CurrentTimeZoneProvider { self.utc })
    await model.loadInitial()
    let identity = try readyPresentation(model.state).identity
    _ = await model.saveGoal(
      id: nil, configuration: GoalConfiguration(name: "Walk", frequency: .daily),
      presentedIdentity: identity)
    let rows = try readyPresentation(model.state).rows
    let mutationCount = await repository.mutationCount
    date.withLock { $0 = instant(year: 2026, month: 11, day: 2, hour: 12) }

    #expect(
      await model.reorderGoals(orderedRows: rows, presentedIdentity: identity)
        == .planningWeekChanged)
    #expect(
      await model.removeGoal(id: rows[0].id, presentedIdentity: identity)
        == .planningWeekChanged)
    #expect(await repository.mutationCount == mutationCount)
  }

  @Test
  func completedSaveAcrossBoundaryStillInvalidatesMyDayAndLoadsCurrentIdentity() async throws {
    let date = Mutex(instant(year: 2026, month: 11, day: 1, hour: 12))
    let repository = DelayedMutationPlanningRepository(shouldFail: false)
    let notifications = Mutex(0)
    let model = MyGoalsModel(
      repository: repository,
      date: DateProvider { date.withLock { $0 } },
      timeZone: CurrentTimeZoneProvider { self.utc },
      onPlanChanged: { notifications.withLock { $0 += 1 } })
    await model.loadInitial()
    let identity = try readyPresentation(model.state).identity

    let save = Task {
      await model.saveGoal(
        id: nil, configuration: GoalConfiguration(name: "Walk", frequency: .daily),
        presentedIdentity: identity)
    }
    await Task.yield()
    date.withLock { $0 = instant(year: 2026, month: 11, day: 2, hour: 12) }
    await model.refreshFromBoundaryEvent()

    #expect(await save.value == .saved)
    #expect(notifications.withLock { $0 } == 1)
    #expect(try readyPresentation(model.state).identity.phase == .thisWeek)
  }

  @Test
  func pendingBoundaryRefreshDrainsAfterFailedSave() async throws {
    let date = Mutex(instant(year: 2026, month: 11, day: 1, hour: 12))
    let repository = DelayedMutationPlanningRepository(shouldFail: true)
    let model = MyGoalsModel(
      repository: repository,
      date: DateProvider { date.withLock { $0 } },
      timeZone: CurrentTimeZoneProvider { self.utc })
    await model.loadInitial()
    let identity = try readyPresentation(model.state).identity

    let save = Task {
      await model.saveGoal(
        id: nil, configuration: GoalConfiguration(name: "Walk", frequency: .daily),
        presentedIdentity: identity)
    }
    await Task.yield()
    date.withLock { $0 = instant(year: 2026, month: 11, day: 2, hour: 12) }
    await model.refreshFromBoundaryEvent()

    #expect(await save.value == .failed)
    #expect(try readyPresentation(model.state).identity.phase == .thisWeek)
  }

  @Test
  func completedReorderAcrossBoundaryInvalidatesMyDayAndLoadsCurrentIdentity() async throws {
    let sunday = instant(year: 2026, month: 11, day: 1, hour: 12)
    let date = Mutex(sunday)
    let identity = MyGoalsIdentity(instant: sunday, timeZone: utc)
    let repository = DelayedOrganizationPlanningRepository(
      week: identity.targetWeek, operation: .reorder, shouldFail: false)
    let notifications = Mutex(0)
    let model = MyGoalsModel(
      repository: repository, date: DateProvider { date.withLock { $0 } },
      timeZone: CurrentTimeZoneProvider { self.utc },
      onPlanChanged: { notifications.withLock { $0 += 1 } })
    await model.loadInitial()
    let rows = try readyPresentation(model.state).rows

    let mutation = Task {
      await model.reorderGoals(
        orderedRows: Array(rows.reversed()), presentedIdentity: identity)
    }
    await Task.yield()
    date.withLock { $0 = instant(year: 2026, month: 11, day: 2, hour: 12) }
    await model.refreshFromBoundaryEvent()

    #expect(await mutation.value == .saved)
    #expect(notifications.withLock { $0 } == 1)
    #expect(try readyPresentation(model.state).identity.phase == .thisWeek)
  }

  @Test
  func delayedRemovalAndFailedReorderDrainBoundaryRefreshWithoutStaleState() async throws {
    let sunday = instant(year: 2026, month: 11, day: 1, hour: 12)
    let date = Mutex(sunday)
    let identity = MyGoalsIdentity(instant: sunday, timeZone: utc)
    let removalRepository = DelayedOrganizationPlanningRepository(
      week: identity.targetWeek, operation: .remove, shouldFail: true)
    let removalModel = MyGoalsModel(
      repository: removalRepository, date: DateProvider { date.withLock { $0 } },
      timeZone: CurrentTimeZoneProvider { self.utc })
    await removalModel.loadInitial()
    let removalRows = try readyPresentation(removalModel.state).rows
    let removal = Task {
      await removalModel.removeGoal(id: removalRows[0].id, presentedIdentity: identity)
    }
    await Task.yield()
    date.withLock { $0 = instant(year: 2026, month: 11, day: 2, hour: 12) }
    await removalModel.refreshFromBoundaryEvent()

    #expect(await removal.value == .planningWeekChanged)
    #expect(try readyPresentation(removalModel.state).identity.phase == .thisWeek)
    #expect(try readyPresentation(removalModel.state).rows.count == 2)

    date.withLock { $0 = sunday }
    let reorderRepository = DelayedOrganizationPlanningRepository(
      week: identity.targetWeek, operation: .reorder, shouldFail: true)
    let reorderModel = MyGoalsModel(
      repository: reorderRepository, date: DateProvider { date.withLock { $0 } },
      timeZone: CurrentTimeZoneProvider { self.utc })
    await reorderModel.loadInitial()
    let reorderRows = try readyPresentation(reorderModel.state).rows
    let reorder = Task {
      await reorderModel.reorderGoals(
        orderedRows: Array(reorderRows.reversed()), presentedIdentity: identity)
    }
    await Task.yield()
    date.withLock { $0 = instant(year: 2026, month: 11, day: 2, hour: 12) }
    await reorderModel.refreshFromBoundaryEvent()

    #expect(await reorder.value == .failed)
    #expect(try readyPresentation(reorderModel.state).identity.phase == .thisWeek)
    #expect(try readyPresentation(reorderModel.state).rows.map(\.name) == ["Walk", "Read"])
  }

  @Test
  func completedRemovalAcrossBoundaryInvalidatesMyDayAndLoadsCurrentIdentity() async throws {
    let sunday = instant(year: 2026, month: 11, day: 1, hour: 12)
    let date = Mutex(sunday)
    let identity = MyGoalsIdentity(instant: sunday, timeZone: utc)
    let repository = DelayedOrganizationPlanningRepository(
      week: identity.targetWeek, operation: .remove, shouldFail: false)
    let notifications = Mutex(0)
    let model = MyGoalsModel(
      repository: repository, date: DateProvider { date.withLock { $0 } },
      timeZone: CurrentTimeZoneProvider { self.utc },
      onPlanChanged: { notifications.withLock { $0 += 1 } })
    await model.loadInitial()
    let goalID = try #require(try readyPresentation(model.state).rows.first?.id)

    let mutation = Task { await model.removeGoal(id: goalID, presentedIdentity: identity) }
    await Task.yield()
    date.withLock { $0 = instant(year: 2026, month: 11, day: 2, hour: 12) }
    await model.refreshFromBoundaryEvent()

    #expect(await mutation.value == .saved)
    #expect(notifications.withLock { $0 } == 1)
    #expect(try readyPresentation(model.state).identity.phase == .thisWeek)
    #expect(try readyPresentation(model.state).rows.count == 1)
  }

  private func instant(year: Int, month: Int, day: Int, hour: Int) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = utc
    return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
  }

  private func snapshot(
    week: WeekID, goals: [PlannedGoalSnapshot] = []
  ) -> WeeklyPlanSnapshot {
    let date = Date(timeIntervalSince1970: 0)
    return WeeklyPlanSnapshot(
      id: UUID(), week: week, planningTimeZoneIdentifier: "GMT",
      planningUTCOffsetSeconds: 0, goals: goals, createdAt: date, updatedAt: date)
  }

  private func goal(
    name: String, frequency: GoalFrequency, order: Int, week: WeekID
  ) -> PlannedGoalSnapshot {
    let date = Date(timeIntervalSince1970: 0)
    return PlannedGoalSnapshot(
      id: UUID(), weeklyPlanID: UUID(), lineageID: UUID(), name: name,
      frequency: frequency, sortOrder: order, activeFrom: week.monday,
      activeThrough: nil, createdAt: date, updatedAt: date)
  }

  private func readyPresentation(_ state: MyGoalsModel.State) throws -> MyGoalsPresentation {
    guard case .ready(let presentation) = state else { throw MyGoalsTestError.expected }
    return presentation
  }
}

private actor StubPlanningRepository: PlanningRepository {
  private(set) var resolvedWeeks: [WeekID] = []

  func resolvePlan(for week: WeekID) -> WeeklyPlanSnapshot {
    resolvedWeeks.append(week)
    return emptyPlan(week)
  }
}

private actor DelayedPlanningRepository: PlanningRepository {
  private var readCount = 0

  func resolvePlan(for week: WeekID) async throws -> WeeklyPlanSnapshot {
    readCount += 1
    if readCount == 1 { try await Task.sleep(for: .milliseconds(100)) }
    return emptyPlan(week)
  }
}

private actor EditingPlanningRepository: PlanningRepository {
  private(set) var mutationCount = 0
  private var plans: [WeekID: WeeklyPlanSnapshot] = [:]
  private var failReorderOnce: Bool
  private var failRemovalOnce: Bool

  init(failReorderOnce: Bool = false, failRemovalOnce: Bool = false) {
    self.failReorderOnce = failReorderOnce
    self.failRemovalOnce = failRemovalOnce
  }

  func resolvePlan(for week: WeekID) -> WeeklyPlanSnapshot {
    if let plan = plans[week] { return plan }
    let plan = emptyPlan(week)
    plans[week] = plan
    return plan
  }

  func addGoal(to week: WeekID, configuration: GoalConfiguration) -> PlannedGoalSnapshot {
    mutationCount += 1
    let plan = plans[week] ?? emptyPlan(week)
    let goal = editableGoal(
      name: configuration.name, frequency: configuration.frequency, order: plan.goals.count,
      week: week)
    plans[week] = replacing(plan: plan, goal: goal)
    return goal
  }

  func updateGoal(id: UUID, configuration: GoalConfiguration) throws -> PlannedGoalSnapshot {
    mutationCount += 1
    guard let entry = plans.first(where: { $0.value.goals.contains(where: { $0.id == id }) }),
      let existing = entry.value.goals.first(where: { $0.id == id })
    else { throw RepositoryError.goalNotFound }
    let goal = PlannedGoalSnapshot(
      id: existing.id, weeklyPlanID: existing.weeklyPlanID, lineageID: existing.lineageID,
      name: configuration.name, frequency: configuration.frequency, sortOrder: existing.sortOrder,
      activeFrom: existing.activeFrom, activeThrough: existing.activeThrough,
      createdAt: existing.createdAt, updatedAt: existing.updatedAt)
    plans[entry.key] = replacing(plan: entry.value, goal: goal)
    return goal
  }

  func removeGoal(id: UUID, effectiveOn day: LocalDay) throws -> PlannedGoalSnapshot {
    mutationCount += 1
    if failRemovalOnce {
      failRemovalOnce = false
      throw RepositoryError.persistenceFailure
    }
    guard let entry = plans.first(where: { $0.value.goals.contains(where: { $0.id == id }) }),
      let existing = entry.value.goals.first(where: { $0.id == id })
    else { throw RepositoryError.goalNotFound }
    let removed = PlannedGoalSnapshot(
      id: existing.id, weeklyPlanID: existing.weeklyPlanID, lineageID: existing.lineageID,
      name: existing.name, frequency: existing.frequency, sortOrder: existing.sortOrder,
      activeFrom: existing.activeFrom, activeThrough: day, createdAt: existing.createdAt,
      updatedAt: existing.updatedAt)
    let remaining = entry.value.goals.filter { $0.id != id }
    plans[entry.key] = snapshotReplacingGoals(entry.value, goals: remaining)
    return removed
  }

  func reorderGoals(in week: WeekID, orderedIDs: [UUID]) throws -> WeeklyPlanSnapshot {
    mutationCount += 1
    if failReorderOnce {
      failReorderOnce = false
      throw RepositoryError.persistenceFailure
    }
    let plan = plans[week] ?? emptyPlan(week)
    let byID = Dictionary(uniqueKeysWithValues: plan.goals.map { ($0.id, $0) })
    guard orderedIDs.count == plan.goals.count, Set(orderedIDs) == Set(byID.keys) else {
      throw RepositoryError.invalidOrdering
    }
    let goals = try orderedIDs.enumerated().map { index, id in
      guard let goal = byID[id] else { throw RepositoryError.invalidOrdering }
      return PlannedGoalSnapshot(
        id: goal.id, weeklyPlanID: goal.weeklyPlanID, lineageID: goal.lineageID,
        name: goal.name, frequency: goal.frequency, sortOrder: index,
        activeFrom: goal.activeFrom, activeThrough: goal.activeThrough,
        createdAt: goal.createdAt, updatedAt: goal.updatedAt)
    }
    let updated = snapshotReplacingGoals(plan, goals: goals)
    plans[week] = updated
    return updated
  }

  private func replacing(
    plan: WeeklyPlanSnapshot, goal: PlannedGoalSnapshot
  ) -> WeeklyPlanSnapshot {
    let goals = plan.goals.filter { $0.id != goal.id } + [goal]
    return WeeklyPlanSnapshot(
      id: plan.id, week: plan.week,
      planningTimeZoneIdentifier: plan.planningTimeZoneIdentifier,
      planningUTCOffsetSeconds: plan.planningUTCOffsetSeconds,
      goals: goals.sorted { $0.sortOrder < $1.sortOrder }, createdAt: plan.createdAt,
      updatedAt: plan.updatedAt)
  }

  private func snapshotReplacingGoals(
    _ plan: WeeklyPlanSnapshot, goals: [PlannedGoalSnapshot]
  ) -> WeeklyPlanSnapshot {
    WeeklyPlanSnapshot(
      id: plan.id, week: plan.week,
      planningTimeZoneIdentifier: plan.planningTimeZoneIdentifier,
      planningUTCOffsetSeconds: plan.planningUTCOffsetSeconds,
      goals: goals, createdAt: plan.createdAt, updatedAt: plan.updatedAt)
  }
}

private actor DelayedMutationPlanningRepository: PlanningRepository {
  let shouldFail: Bool

  init(shouldFail: Bool) { self.shouldFail = shouldFail }

  func resolvePlan(for week: WeekID) -> WeeklyPlanSnapshot { emptyPlan(week) }

  func addGoal(to week: WeekID, configuration: GoalConfiguration) async throws
    -> PlannedGoalSnapshot
  {
    try await Task.sleep(for: .milliseconds(100))
    if shouldFail { throw RepositoryError.persistenceFailure }
    return editableGoal(
      name: configuration.name, frequency: configuration.frequency, order: 0, week: week)
  }
}

private actor DelayedOrganizationPlanningRepository: PlanningRepository {
  enum Operation: Sendable { case reorder, remove }

  let operation: Operation
  let shouldFail: Bool
  private var plan: WeeklyPlanSnapshot

  init(week: WeekID, operation: Operation, shouldFail: Bool) {
    self.operation = operation
    self.shouldFail = shouldFail
    plan = WeeklyPlanSnapshot(
      id: UUID(), week: week, planningTimeZoneIdentifier: "GMT",
      planningUTCOffsetSeconds: 0,
      goals: [
        editableGoal(name: "Walk", frequency: .daily, order: 0, week: week),
        editableGoal(name: "Read", frequency: .weekly, order: 1, week: week),
      ], createdAt: .distantPast, updatedAt: .distantPast)
  }

  func resolvePlan(for week: WeekID) -> WeeklyPlanSnapshot { plan }

  func reorderGoals(in week: WeekID, orderedIDs: [UUID]) async throws -> WeeklyPlanSnapshot {
    try await Task.sleep(for: .milliseconds(100))
    if shouldFail { throw RepositoryError.persistenceFailure }
    let byID = Dictionary(uniqueKeysWithValues: plan.goals.map { ($0.id, $0) })
    let goals = try orderedIDs.enumerated().map { index, id in
      guard let goal = byID[id] else { throw RepositoryError.invalidOrdering }
      return PlannedGoalSnapshot(
        id: goal.id, weeklyPlanID: goal.weeklyPlanID, lineageID: goal.lineageID,
        name: goal.name, frequency: goal.frequency, sortOrder: index,
        activeFrom: goal.activeFrom, activeThrough: goal.activeThrough,
        createdAt: goal.createdAt, updatedAt: goal.updatedAt)
    }
    plan = replacingGoals(in: plan, goals: goals)
    return plan
  }

  func removeGoal(id: UUID, effectiveOn day: LocalDay) async throws -> PlannedGoalSnapshot {
    try await Task.sleep(for: .milliseconds(100))
    if shouldFail { throw RepositoryError.inactiveGoal }
    guard let goal = plan.goals.first(where: { $0.id == id }) else {
      throw RepositoryError.goalNotFound
    }
    plan = replacingGoals(in: plan, goals: plan.goals.filter { $0.id != id })
    return goal
  }

  private func replacingGoals(
    in plan: WeeklyPlanSnapshot, goals: [PlannedGoalSnapshot]
  ) -> WeeklyPlanSnapshot {
    WeeklyPlanSnapshot(
      id: plan.id, week: plan.week,
      planningTimeZoneIdentifier: plan.planningTimeZoneIdentifier,
      planningUTCOffsetSeconds: plan.planningUTCOffsetSeconds,
      goals: goals, createdAt: plan.createdAt, updatedAt: plan.updatedAt)
  }
}

private func editableGoal(
  name: String, frequency: GoalFrequency, order: Int, week: WeekID
) -> PlannedGoalSnapshot {
  let date = Date(timeIntervalSince1970: 0)
  return PlannedGoalSnapshot(
    id: UUID(), weeklyPlanID: UUID(), lineageID: UUID(), name: name,
    frequency: frequency, sortOrder: order, activeFrom: week.monday,
    activeThrough: nil, createdAt: date, updatedAt: date)
}

private func emptyPlan(_ week: WeekID) -> WeeklyPlanSnapshot {
  let date = Date(timeIntervalSince1970: 0)
  return WeeklyPlanSnapshot(
    id: UUID(), week: week, planningTimeZoneIdentifier: "GMT",
    planningUTCOffsetSeconds: 0, goals: [], createdAt: date, updatedAt: date)
}

extension PlanningRepository {
  fileprivate func plan(for week: WeekID) throws -> WeeklyPlanSnapshot? {
    throw MyGoalsTestError.expected
  }
  fileprivate func ensurePlan(for week: WeekID) throws -> WeeklyPlanSnapshot {
    throw MyGoalsTestError.expected
  }
  fileprivate func addGoal(to week: WeekID, configuration: GoalConfiguration) throws
    -> PlannedGoalSnapshot
  {
    throw MyGoalsTestError.expected
  }
  fileprivate func updateGoal(id: UUID, configuration: GoalConfiguration) throws
    -> PlannedGoalSnapshot
  {
    throw MyGoalsTestError.expected
  }
  fileprivate func removeGoal(id: UUID, effectiveOn day: LocalDay) throws -> PlannedGoalSnapshot {
    throw MyGoalsTestError.expected
  }
  fileprivate func reorderGoals(in week: WeekID, orderedIDs: [UUID]) throws -> WeeklyPlanSnapshot {
    throw MyGoalsTestError.expected
  }
  fileprivate func carryForward(from source: WeekID, to target: WeekID) throws -> WeeklyPlanSnapshot
  {
    throw MyGoalsTestError.expected
  }
}

private enum MyGoalsTestError: Error {
  case expected
}
