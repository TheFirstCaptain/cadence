import Foundation
import Synchronization
import Testing

@testable import Cadence

@MainActor
struct HistoryModelTests {
  private let utc = TimeZone(secondsFromGMT: 0)!
  private let monday = LocalDay(year: 2026, month: 10, day: 26)!

  @Test
  func presentationDerivesPartialWeekTargetsAndSevenDayPlacement() throws {
    let week = WeekID(monday: monday)!
    let friday = monday.addingDays(4)!
    let sunday = monday.addingDays(6)!
    let daily = goal(
      name: "Walk", frequency: .daily, order: 0, week: week, activeFrom: friday)
    let weekly = goal(
      name: "Swim", frequency: .weekly, order: 1, week: week, activeFrom: sunday)
    let custom = goal(
      name: "Read", frequency: .custom(daysPerWeek: 4)!, order: 2, week: week,
      activeFrom: friday)
    let snapshot = weekSnapshot(
      week: week,
      goals: [daily, weekly, custom],
      checkoffs: [
        checkoff(goalID: daily.id, day: friday),
        checkoff(goalID: custom.id, day: friday),
        checkoff(goalID: custom.id, day: friday),
        checkoff(goalID: custom.id, day: sunday),
      ])

    let presentation = WeekHistoryPresentation(
      snapshot: snapshot, week: week, currentDay: sunday, currentWeek: week)

    #expect(presentation.goals.map { $0.target } == [3, 1, 3])
    #expect(presentation.goals.map { $0.completed } == [1, 0, 2])
    #expect(
      presentation.goals[0].days == [
        .inactive, .inactive, .inactive, .inactive, .complete,
        .noCheckoff(isFuture: false), .noCheckoff(isFuture: false),
      ])
  }

  @Test
  func presentationCapsProgressButPreservesEveryRecordedCheckmark() throws {
    let week = WeekID(monday: monday)!
    let goal = goal(
      name: "Read", frequency: .custom(daysPerWeek: 2)!, order: 0, week: week,
      activeFrom: monday)
    let checkoffs = (0..<4).map { checkoff(goalID: goal.id, day: monday.addingDays($0)!) }

    let row = try #require(
      WeekHistoryPresentation(
        snapshot: weekSnapshot(week: week, goals: [goal], checkoffs: checkoffs),
        week: week,
        currentDay: monday.addingDays(6)!,
        currentWeek: week
      ).goals.first)

    #expect(row.completed == 2)
    #expect(row.target == 2)
    #expect(row.days.filter { $0 == .complete }.count == 4)
  }

  @Test
  func presentationUsesInclusiveRemovalDateForEveryFrequency() throws {
    let week = WeekID(monday: monday)!
    let wednesday = monday.addingDays(2)!
    let thursday = monday.addingDays(3)!
    let goals = [
      goal(
        name: "Walk", frequency: .daily, order: 0, week: week, activeFrom: monday,
        activeThrough: wednesday),
      goal(
        name: "Swim", frequency: .weekly, order: 1, week: week, activeFrom: monday,
        activeThrough: wednesday),
      goal(
        name: "Read", frequency: .custom(daysPerWeek: 4)!, order: 2, week: week,
        activeFrom: monday, activeThrough: wednesday),
    ]
    let snapshot = weekSnapshot(
      week: week,
      goals: goals,
      checkoffs: goals.flatMap {
        [checkoff(goalID: $0.id, day: wednesday), checkoff(goalID: $0.id, day: thursday)]
      })

    let rows = WeekHistoryPresentation(
      snapshot: snapshot,
      week: week,
      currentDay: monday.addingDays(6)!,
      currentWeek: week
    ).goals

    #expect(rows.map { $0.target } == [3, 1, 3])
    #expect(rows.map { $0.completed } == [1, 1, 1])
    #expect(rows.allSatisfy { $0.days[2] == .complete })
    #expect(rows.allSatisfy { $0.days[3] == .inactive })
  }

  @Test
  func presentationUsesDailyOccurrenceCountsAndArchivedMeaning() throws {
    let week = WeekID(monday: monday)!
    let active = category(name: "Candy", order: 0, active: true)
    let archived = category(name: "Desserts", order: 1, active: false)
    let snapshot = WeekActivitySnapshot(
      plan: nil,
      checkoffs: [],
      categories: [active, archived],
      occurrences: [
        occurrence(categoryID: archived.id, day: monday.addingDays(1)!),
        occurrence(categoryID: archived.id, day: monday.addingDays(1)!),
      ])

    let presentation = WeekHistoryPresentation(
      snapshot: snapshot, week: week, currentDay: monday, currentWeek: week)

    #expect(presentation.indulgences.map { $0.total } == [0, 2])
    #expect(presentation.indulgences[0].dailyCounts == Array(repeating: 0, count: 7))
    #expect(presentation.indulgences[1].dailyCounts[1] == 2)
    #expect(presentation.indulgences[1].isArchived)
    #expect(presentation.indulgences[1].accessibilityLabel.contains("archived"))
  }

  @Test
  func navigationGuardsFutureAndTodayReturnsToCurrentWeek() async throws {
    let week = WeekID(monday: monday)!
    let repository = StubHistoryRepository()
    let model = makeModel(repository: repository, day: monday.addingDays(2)!)

    await model.loadInitial()
    #expect(try ready(model.state).week == week)
    await model.showNextWeek()
    #expect(await repository.requestedWeeks == [week])

    await model.showPreviousWeek()
    let prior = WeekID(monday: monday.addingDays(-7)!)!
    #expect(try ready(model.state).week == prior)
    await model.showToday()
    #expect(try ready(model.state).week == week)
    #expect(await repository.requestedWeeks == [week, prior, week])
  }

  @Test
  func boundaryFollowsCurrentWeekButPreservesHistoricalSelection() async throws {
    let dates = Mutex(instant(for: monday.addingDays(6)!))
    let repository = StubHistoryRepository()
    let timeZone = utc
    let model = HistoryModel(
      repository: repository,
      date: DateProvider { dates.withLock { $0 } },
      timeZone: CurrentTimeZoneProvider { timeZone })

    await model.loadInitial()
    dates.withLock { $0 = instant(for: self.monday.addingDays(7)!) }
    await model.refreshFromForeground()
    let nextWeek = WeekID(monday: monday.addingDays(7)!)!
    #expect(try ready(model.state).week == nextWeek)

    await model.showPreviousWeek()
    dates.withLock { $0 = instant(for: self.monday.addingDays(14)!) }
    await model.refreshFromBoundaryEvent()
    #expect(try ready(model.state).week == WeekID(monday: monday)!)
  }

  @Test
  func newerWeekRefreshWinsWhenOlderReadFinishesLast() async throws {
    let dates = Mutex(instant(for: monday))
    let currentWeek = WeekID(monday: monday)!
    let nextMonday = monday.addingDays(7)!
    let nextWeek = WeekID(monday: nextMonday)!
    let repository = DelayedHistoryRepository(slowWeek: currentWeek)
    let timeZone = utc
    let model = HistoryModel(
      repository: repository,
      date: DateProvider { dates.withLock { $0 } },
      timeZone: CurrentTimeZoneProvider { timeZone })

    let older = Task { await model.loadInitial() }
    await Task.yield()
    dates.withLock { $0 = instant(for: nextMonday) }
    await model.refreshFromForeground()
    await older.value

    #expect(try ready(model.state).week == nextWeek)
  }

  @Test
  func foregroundRecapturesWeekAfterTimeZoneChange() async throws {
    let instant = ISO8601DateFormatter().date(from: "2026-11-02T01:00:00Z")!
    let zones = Mutex(utc)
    let repository = StubHistoryRepository()
    let model = HistoryModel(
      repository: repository,
      date: DateProvider { instant },
      timeZone: CurrentTimeZoneProvider { zones.withLock { $0 } })

    await model.loadInitial()
    let utcWeek = WeekID(monday: LocalDay(year: 2026, month: 11, day: 2)!)!
    #expect(try ready(model.state).week == utcWeek)

    zones.withLock { $0 = TimeZone(identifier: "America/New_York")! }
    await model.refreshFromForeground()

    #expect(try ready(model.state).week == WeekID(monday: monday)!)
  }

  @Test
  func failureRetryAndRevisionRefreshPreserveSelection() async throws {
    let week = WeekID(monday: monday)!
    let repository = StubHistoryRepository(failuresRemaining: 1)
    let model = makeModel(repository: repository, day: monday)

    await model.loadInitial()
    #expect(model.state == .failed)
    await model.retry()
    #expect(try ready(model.state).week == week)
    await model.refreshAfterRevision()
    #expect(try ready(model.state).week == week)
    #expect(await repository.requestedWeeks == [week, week, week])
  }

  private func makeModel(repository: any HistoryRepository, day: LocalDay) -> HistoryModel {
    let date = instant(for: day)
    let timeZone = utc
    return HistoryModel(
      repository: repository,
      date: DateProvider { date },
      timeZone: CurrentTimeZoneProvider { timeZone })
  }

  private func ready(_ state: HistoryModel.State) throws -> WeekHistoryPresentation {
    guard case .ready(let presentation) = state else {
      Issue.record("Expected ready History state")
      throw HistoryTestError.expected
    }
    return presentation
  }

  private func weekSnapshot(
    week: WeekID,
    goals: [PlannedGoalSnapshot],
    checkoffs: [GoalCheckoffSnapshot]
  ) -> WeekActivitySnapshot {
    WeekActivitySnapshot(
      plan: WeeklyPlanSnapshot(
        id: UUID(),
        week: week,
        planningTimeZoneIdentifier: utc.identifier,
        planningUTCOffsetSeconds: 0,
        goals: goals,
        createdAt: .distantPast,
        updatedAt: .distantPast),
      checkoffs: checkoffs,
      categories: [],
      occurrences: [])
  }

  private func goal(
    name: String,
    frequency: GoalFrequency,
    order: Int,
    week: WeekID,
    activeFrom: LocalDay,
    activeThrough: LocalDay? = nil
  ) -> PlannedGoalSnapshot {
    PlannedGoalSnapshot(
      id: UUID(),
      weeklyPlanID: UUID(),
      lineageID: UUID(),
      name: name,
      frequency: frequency,
      sortOrder: order,
      activeFrom: activeFrom,
      activeThrough: activeThrough,
      createdAt: .distantPast,
      updatedAt: .distantPast)
  }

  private func checkoff(goalID: UUID, day: LocalDay) -> GoalCheckoffSnapshot {
    GoalCheckoffSnapshot(
      id: UUID(),
      plannedGoalID: goalID,
      instant: instant(for: day),
      localDay: day,
      timeZoneIdentifier: utc.identifier,
      utcOffsetSeconds: 0,
      createdAt: .distantPast,
      updatedAt: .distantPast)
  }

  private func category(name: String, order: Int, active: Bool) -> IndulgenceCategorySnapshot {
    IndulgenceCategorySnapshot(
      id: UUID(),
      name: name,
      symbolName: "circle",
      sortOrder: order,
      isBuiltIn: false,
      isActive: active)
  }

  private func occurrence(categoryID: UUID, day: LocalDay) -> IndulgenceOccurrenceSnapshot {
    IndulgenceOccurrenceSnapshot(
      id: UUID(),
      categoryID: categoryID,
      instant: instant(for: day),
      localDay: day,
      timeZoneIdentifier: utc.identifier,
      utcOffsetSeconds: 0,
      createdAt: .distantPast,
      updatedAt: .distantPast)
  }

  private func instant(for day: LocalDay) -> Date {
    GregorianCalendarService(timeZone: utc).startOfDay(for: day)!.addingTimeInterval(43_200)
  }
}

private actor DelayedHistoryRepository: HistoryRepository {
  let slowWeek: WeekID

  init(slowWeek: WeekID) {
    self.slowWeek = slowWeek
  }

  func weekSnapshot(for week: WeekID) async throws -> WeekActivitySnapshot {
    if week == slowWeek { try await Task.sleep(for: .milliseconds(100)) }
    return WeekActivitySnapshot(plan: nil, checkoffs: [], categories: [], occurrences: [])
  }

  func dayHistory(for day: LocalDay) throws -> DayActivitySnapshot {
    throw HistoryTestError.expected
  }

  func removeOccurrence(id: UUID) throws -> IndulgenceOccurrenceSnapshot? {
    throw HistoryTestError.expected
  }
}

private enum HistoryTestError: Error {
  case expected
}

private actor StubHistoryRepository: HistoryRepository {
  private(set) var requestedWeeks: [WeekID] = []
  private var failuresRemaining: Int

  init(failuresRemaining: Int = 0) {
    self.failuresRemaining = failuresRemaining
  }

  func weekSnapshot(for week: WeekID) throws -> WeekActivitySnapshot {
    requestedWeeks.append(week)
    if failuresRemaining > 0 {
      failuresRemaining -= 1
      throw HistoryTestError.expected
    }
    return WeekActivitySnapshot(
      plan: nil,
      checkoffs: [],
      categories: [],
      occurrences: [])
  }

  func dayHistory(for day: LocalDay) throws -> DayActivitySnapshot {
    DayActivitySnapshot(day: day, goals: [], checkoffs: [], categories: [], occurrences: [])
  }

  func removeOccurrence(id: UUID) throws -> IndulgenceOccurrenceSnapshot? {
    nil
  }
}
