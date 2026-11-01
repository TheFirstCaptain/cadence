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
