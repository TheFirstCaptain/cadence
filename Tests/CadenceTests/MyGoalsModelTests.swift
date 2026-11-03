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
