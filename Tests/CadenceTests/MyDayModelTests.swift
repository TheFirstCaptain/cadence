import Foundation
import Synchronization
import Testing

@testable import Cadence

@MainActor
struct MyDayModelTests {
  private let utc = TimeZone(secondsFromGMT: 0)!
  private let wednesday = LocalDay(year: 2026, month: 10, day: 28)!

  @Test
  func presentationGroupsInPlanOrderAndDerivesDailyAndFlexibleProgress() async throws {
    let daily = goal(name: "Walk", frequency: .daily, sortOrder: 0)
    let weekly = goal(name: "Swim", frequency: .weekly, sortOrder: 1)
    let custom = goal(name: "Read", frequency: .custom(daysPerWeek: 3)!, sortOrder: 2)
    let snapshot = MyDaySnapshot(
      day: wednesday,
      week: WeekID(containing: wednesday)!,
      goals: [daily, weekly, custom],
      todayCheckoffs: [checkoff(goalID: daily.id, day: wednesday)],
      weekCheckoffs: [
        checkoff(goalID: daily.id, day: wednesday),
        checkoff(goalID: weekly.id, day: wednesday),
        checkoff(goalID: custom.id, day: wednesday),
        checkoff(goalID: custom.id, day: wednesday),
        checkoff(goalID: custom.id, day: wednesday.addingDays(-1)!),
      ])
    let repository = StubDailyTrackingRepository(results: [.success(snapshot)])
    let model = makeModel(repository: repository)

    await model.loadInitial()

    let presentation = try readyPresentation(model.state)
    #expect(presentation.today.map(\.name) == ["Walk"])
    #expect(presentation.today.first?.isCompleteToday == true)
    #expect(presentation.thisWeek.map(\.name) == ["Swim", "Read"])
    #expect(presentation.thisWeek.map(\.completed) == [1, 2])
    #expect(presentation.thisWeek.map(\.target) == [1, 3])
  }

  @Test
  func flexibleProgressIsCappedAtTheCurrentTargetAfterFrequencyChanges() throws {
    let weekly = goal(name: "Swim", frequency: .weekly, sortOrder: 0)
    let custom = goal(name: "Read", frequency: .custom(daysPerWeek: 2)!, sortOrder: 1)
    let days = (0..<5).map { wednesday.addingDays(-$0)! }
    let snapshot = MyDaySnapshot(
      day: wednesday,
      week: WeekID(containing: wednesday)!,
      goals: [weekly, custom],
      todayCheckoffs: [],
      weekCheckoffs: days.flatMap { day in
        [checkoff(goalID: weekly.id, day: day), checkoff(goalID: custom.id, day: day)]
      })

    let presentation = MyDayPresentation(snapshot: snapshot)

    #expect(presentation.thisWeek.map(\.completed) == [1, 2])
    #expect(presentation.thisWeek.map(\.target) == [1, 2])
  }

  @Test
  func failureCanRetryAndBoundaryEventsReloadOnlyWhenIdentityChanges() async throws {
    let thursday = wednesday.addingDays(1)!
    let dates = Mutex(instant(for: wednesday))
    let repository = StubDailyTrackingRepository(results: [
      .failure(MyDayTestError.expected),
      .success(emptySnapshot(for: wednesday)),
      .success(emptySnapshot(for: thursday)),
    ])
    let model = MyDayModel(
      repository: repository,
      date: DateProvider { dates.withLock { $0 } },
      timeZone: CurrentTimeZoneProvider { self.utc })

    await model.loadInitial()
    #expect(model.state == .failed)
    await model.retry()
    #expect(try readyPresentation(model.state).day == wednesday)
    await model.refreshFromBoundaryEvent()
    #expect(await repository.readCount == 2)

    dates.withLock { $0 = instant(for: thursday) }
    await model.refreshFromBoundaryEvent()
    #expect(try readyPresentation(model.state).day == thursday)
    #expect(await repository.readCount == 3)
  }

  @Test
  func laterRefreshWinsWhenAnOlderReadFinishesLast() async throws {
    let thursday = wednesday.addingDays(1)!
    let dates = Mutex(instant(for: wednesday))
    let repository = DelayedDailyTrackingRepository(
      slowDay: wednesday,
      snapshots: [
        wednesday: emptySnapshot(for: wednesday),
        thursday: emptySnapshot(for: thursday),
      ])
    let model = MyDayModel(
      repository: repository,
      date: DateProvider { dates.withLock { $0 } },
      timeZone: CurrentTimeZoneProvider { self.utc })

    let older = Task { await model.loadInitial() }
    await Task.yield()
    dates.withLock { $0 = instant(for: thursday) }
    await model.refreshFromForeground()
    await older.value

    #expect(try readyPresentation(model.state).day == thursday)
  }

  @Test
  func failedRefreshRemovesPreviouslyReadyGoals() async throws {
    let repository = StubDailyTrackingRepository(results: [
      .success(emptySnapshot(for: wednesday)),
      .failure(MyDayTestError.expected),
    ])
    let model = makeModel(repository: repository)

    await model.loadInitial()
    #expect(try readyPresentation(model.state).day == wednesday)
    await model.refreshFromForeground()
    #expect(model.state == .failed)
  }

  @Test
  func boundaryRefreshRecapturesSundayRolloverAndChangedTimeZone() async throws {
    let sunday = LocalDay(year: 2026, month: 11, day: 1)!
    let monday = sunday.addingDays(1)!
    let instant = Mutex(self.instant(for: sunday))
    let zone = Mutex(utc)
    let repository = StubDailyTrackingRepository(results: [
      .success(emptySnapshot(for: sunday)),
      .success(emptySnapshot(for: monday)),
      .success(emptySnapshot(for: sunday)),
    ])
    let model = MyDayModel(
      repository: repository,
      date: DateProvider { instant.withLock { $0 } },
      timeZone: CurrentTimeZoneProvider { zone.withLock { $0 } })

    await model.loadInitial()
    instant.withLock { $0 = self.instant(for: monday) }
    await model.refreshFromBoundaryEvent()
    #expect(try readyPresentation(model.state).week == WeekID(containing: monday))

    instant.withLock {
      $0 = GregorianCalendarService(timeZone: self.utc).startOfDay(for: monday)!
        .addingTimeInterval(7_200)
    }
    zone.withLock { $0 = TimeZone(secondsFromGMT: -18_000)! }
    await model.refreshFromBoundaryEvent()
    #expect(try readyPresentation(model.state).day == sunday)
    #expect(await repository.readCount == 3)
  }

  @Test
  func toggleCompletesAndUndoesGoalWithoutRemovingItsRow() async throws {
    let custom = goal(name: "Read", frequency: .custom(daysPerWeek: 3)!, sortOrder: 0)
    let snapshot = MyDaySnapshot(
      day: wednesday,
      week: WeekID(containing: wednesday)!,
      goals: [custom],
      todayCheckoffs: [],
      weekCheckoffs: [checkoff(goalID: custom.id, day: wednesday.addingDays(-1)!)]
    )
    let repository = ToggleDailyTrackingRepository(snapshot: snapshot)
    let model = makeModel(repository: repository)
    await model.loadInitial()

    var row = try #require(readyPresentation(model.state).thisWeek.first)
    await model.toggle(row)
    row = try #require(readyPresentation(model.state).thisWeek.first)
    #expect(row.isCompleteToday)
    #expect(row.completed == 2)
    #expect(model.successfulMutationCount == 1)

    await model.toggle(row)
    row = try #require(readyPresentation(model.state).thisWeek.first)
    #expect(!row.isCompleteToday)
    #expect(row.completed == 1)
    #expect(
      await repository.mutations == [.record(custom.id, wednesday), .remove(custom.id, wednesday)])
  }

  @Test
  func failedMutationRestoresPresentationAndShowsInlineGuidance() async throws {
    let daily = goal(name: "Walk", frequency: .daily, sortOrder: 0)
    let snapshot = MyDaySnapshot(
      day: wednesday,
      week: WeekID(containing: wednesday)!,
      goals: [daily],
      todayCheckoffs: [],
      weekCheckoffs: []
    )
    let repository = ToggleDailyTrackingRepository(snapshot: snapshot, failsMutation: true)
    let model = makeModel(repository: repository)
    await model.loadInitial()

    await model.toggle(try #require(readyPresentation(model.state).today.first))

    #expect(try readyPresentation(model.state).today.first?.isCompleteToday == false)
    #expect(model.mutationMessage == "Couldn’t update this Goal. Please try again.")
    #expect(model.successfulMutationCount == 0)
  }

  @Test
  func inFlightMutationSuppressesSecondTapAndUsesCapturedDay() async throws {
    let daily = goal(name: "Walk", frequency: .daily, sortOrder: 0)
    let snapshot = MyDaySnapshot(
      day: wednesday,
      week: WeekID(containing: wednesday)!,
      goals: [daily],
      todayCheckoffs: [],
      weekCheckoffs: []
    )
    let repository = ToggleDailyTrackingRepository(
      snapshot: snapshot, mutationDelay: .milliseconds(100))
    let model = makeModel(repository: repository)
    await model.loadInitial()
    let row = try #require(readyPresentation(model.state).today.first)

    let first = Task { await model.toggle(row) }
    await Task.yield()
    await model.toggle(row)
    await first.value

    #expect(await repository.mutations == [.record(daily.id, wednesday)])
  }

  @Test
  func targetMetOnEarlierDayCannotAddAnotherCheckoff() async throws {
    let weekly = goal(name: "Swim", frequency: .weekly, sortOrder: 0)
    let snapshot = MyDaySnapshot(
      day: wednesday,
      week: WeekID(containing: wednesday)!,
      goals: [weekly],
      todayCheckoffs: [],
      weekCheckoffs: [checkoff(goalID: weekly.id, day: wednesday.addingDays(-1)!)]
    )
    let repository = ToggleDailyTrackingRepository(snapshot: snapshot)
    let model = makeModel(repository: repository)
    await model.loadInitial()
    let row = try #require(readyPresentation(model.state).thisWeek.first)

    #expect(!row.canToggle)
    await model.toggle(row)
    #expect(await repository.mutations.isEmpty)
  }

  @Test
  func stalePresentationRefreshesNewLocalDayWithoutWriting() async throws {
    let thursday = wednesday.addingDays(1)!
    let daily = goal(name: "Walk", frequency: .daily, sortOrder: 0)
    let wednesdaySnapshot = MyDaySnapshot(
      day: wednesday, week: WeekID(containing: wednesday)!, goals: [daily],
      todayCheckoffs: [], weekCheckoffs: [])
    let thursdaySnapshot = MyDaySnapshot(
      day: thursday, week: WeekID(containing: thursday)!, goals: [daily],
      todayCheckoffs: [], weekCheckoffs: [])
    let dates = Mutex(instant(for: wednesday))
    let repository = ToggleDailyTrackingRepository(snapshots: [
      wednesday: wednesdaySnapshot, thursday: thursdaySnapshot,
    ])
    let model = MyDayModel(
      repository: repository,
      date: DateProvider { dates.withLock { $0 } },
      timeZone: CurrentTimeZoneProvider { self.utc })
    await model.loadInitial()
    let staleRow = try #require(readyPresentation(model.state).today.first)

    dates.withLock { $0 = self.instant(for: thursday) }
    await model.toggle(staleRow)

    #expect(try readyPresentation(model.state).day == thursday)
    #expect(await repository.mutations.isEmpty)
  }

  @Test
  func boundaryRefreshDuringSuccessfulMutationIsCoalescedAfterWrite() async throws {
    let thursday = wednesday.addingDays(1)!
    let daily = goal(name: "Walk", frequency: .daily, sortOrder: 0)
    let wednesdaySnapshot = MyDaySnapshot(
      day: wednesday, week: WeekID(containing: wednesday)!, goals: [daily],
      todayCheckoffs: [], weekCheckoffs: [])
    let thursdaySnapshot = MyDaySnapshot(
      day: thursday, week: WeekID(containing: thursday)!, goals: [daily],
      todayCheckoffs: [], weekCheckoffs: [])
    let dates = Mutex(instant(for: wednesday))
    let repository = ToggleDailyTrackingRepository(
      snapshots: [wednesday: wednesdaySnapshot, thursday: thursdaySnapshot],
      mutationDelay: .milliseconds(100))
    let model = MyDayModel(
      repository: repository,
      date: DateProvider { dates.withLock { $0 } },
      timeZone: CurrentTimeZoneProvider { self.utc })
    await model.loadInitial()
    let row = try #require(readyPresentation(model.state).today.first)

    let mutation = Task { await model.toggle(row) }
    await Task.yield()
    dates.withLock { $0 = self.instant(for: thursday) }
    await model.refreshFromBoundaryEvent()
    await mutation.value

    #expect(try readyPresentation(model.state).day == thursday)
    #expect(await repository.mutations == [.record(daily.id, wednesday)])
    #expect(await repository.readCount == 2)
  }

  @Test
  func foregroundRefreshDuringFailedMutationPreservesGuidanceUntilLaterRefresh() async throws {
    let daily = goal(name: "Walk", frequency: .daily, sortOrder: 0)
    let snapshot = MyDaySnapshot(
      day: wednesday, week: WeekID(containing: wednesday)!, goals: [daily],
      todayCheckoffs: [], weekCheckoffs: [])
    let repository = ToggleDailyTrackingRepository(
      snapshot: snapshot, failsMutation: true, mutationDelay: .milliseconds(100))
    let model = makeModel(repository: repository)
    await model.loadInitial()
    let row = try #require(readyPresentation(model.state).today.first)

    let mutation = Task { await model.toggle(row) }
    await Task.yield()
    await model.refreshFromForeground()
    await mutation.value

    #expect(try readyPresentation(model.state).today.first?.isCompleteToday == false)
    #expect(model.mutationMessage == "Couldn’t update this Goal. Please try again.")
    #expect(await repository.readCount == 2)

    await model.refreshFromForeground()
    #expect(model.mutationMessage == nil)
    #expect(await repository.readCount == 3)
  }

  private func makeModel(repository: any DailyTrackingRepository) -> MyDayModel {
    let now = instant(for: wednesday)
    let zone = utc
    return MyDayModel(
      repository: repository,
      date: DateProvider { now },
      timeZone: CurrentTimeZoneProvider { zone })
  }

  private func emptySnapshot(for day: LocalDay) -> MyDaySnapshot {
    MyDaySnapshot(
      day: day,
      week: WeekID(containing: day)!,
      goals: [],
      todayCheckoffs: [],
      weekCheckoffs: [])
  }

  private func goal(name: String, frequency: GoalFrequency, sortOrder: Int) -> PlannedGoalSnapshot {
    let day = wednesday
    let instant = instant(for: day)
    return PlannedGoalSnapshot(
      id: UUID(),
      weeklyPlanID: UUID(),
      lineageID: UUID(),
      name: name,
      frequency: frequency,
      sortOrder: sortOrder,
      activeFrom: day,
      activeThrough: nil,
      createdAt: instant,
      updatedAt: instant)
  }

  private func checkoff(goalID: UUID, day: LocalDay) -> GoalCheckoffSnapshot {
    let instant = instant(for: day)
    return GoalCheckoffSnapshot(
      id: UUID(),
      plannedGoalID: goalID,
      instant: instant,
      localDay: day,
      timeZoneIdentifier: utc.identifier,
      utcOffsetSeconds: 0,
      createdAt: instant,
      updatedAt: instant)
  }

  private func instant(for day: LocalDay) -> Date {
    GregorianCalendarService(timeZone: utc).startOfDay(for: day)!.addingTimeInterval(43_200)
  }

  private func readyPresentation(_ state: MyDayModel.State) throws -> MyDayPresentation {
    guard case .ready(let presentation) = state else {
      throw MyDayTestError.expected
    }
    return presentation
  }
}

private actor StubDailyTrackingRepository: DailyTrackingRepository {
  private var results: [Result<MyDaySnapshot, any Error>]
  private(set) var readCount = 0

  init(results: [Result<MyDaySnapshot, any Error>]) {
    self.results = results
  }

  func myDaySnapshot(for day: LocalDay) throws -> MyDaySnapshot {
    readCount += 1
    return try results.removeFirst().get()
  }

  func daySnapshot(for day: LocalDay) throws -> DayActivitySnapshot {
    throw MyDayTestError.expected
  }
  func recordCheckoff(goalID: UUID, on day: LocalDay) throws -> GoalCheckoffSnapshot {
    throw MyDayTestError.expected
  }
  func removeCheckoff(goalID: UUID, on day: LocalDay) throws -> GoalCheckoffSnapshot? {
    throw MyDayTestError.expected
  }
  func recordIndulgence(categoryID: UUID) throws -> IndulgenceOccurrenceSnapshot {
    throw MyDayTestError.expected
  }
  func removeLatestIndulgence(categoryID: UUID, on day: LocalDay) throws
    -> IndulgenceOccurrenceSnapshot?
  {
    throw MyDayTestError.expected
  }
}

private actor DelayedDailyTrackingRepository: DailyTrackingRepository {
  let slowDay: LocalDay
  let snapshots: [LocalDay: MyDaySnapshot]

  init(slowDay: LocalDay, snapshots: [LocalDay: MyDaySnapshot]) {
    self.slowDay = slowDay
    self.snapshots = snapshots
  }

  func myDaySnapshot(for day: LocalDay) async throws -> MyDaySnapshot {
    if day == slowDay { try await Task.sleep(for: .milliseconds(100)) }
    guard let snapshot = snapshots[day] else { throw MyDayTestError.expected }
    return snapshot
  }

  func daySnapshot(for day: LocalDay) throws -> DayActivitySnapshot {
    throw MyDayTestError.expected
  }
  func recordCheckoff(goalID: UUID, on day: LocalDay) throws -> GoalCheckoffSnapshot {
    throw MyDayTestError.expected
  }
  func removeCheckoff(goalID: UUID, on day: LocalDay) throws -> GoalCheckoffSnapshot? {
    throw MyDayTestError.expected
  }
  func recordIndulgence(categoryID: UUID) throws -> IndulgenceOccurrenceSnapshot {
    throw MyDayTestError.expected
  }
  func removeLatestIndulgence(categoryID: UUID, on day: LocalDay) throws
    -> IndulgenceOccurrenceSnapshot?
  {
    throw MyDayTestError.expected
  }
}

private enum ToggleMutation: Equatable, Sendable {
  case record(UUID, LocalDay)
  case remove(UUID, LocalDay)
}

private actor ToggleDailyTrackingRepository: DailyTrackingRepository {
  let snapshots: [LocalDay: MyDaySnapshot]
  let failsMutation: Bool
  let mutationDelay: Duration?
  private(set) var mutations: [ToggleMutation] = []
  private(set) var readCount = 0

  init(
    snapshot: MyDaySnapshot,
    failsMutation: Bool = false,
    mutationDelay: Duration? = nil
  ) {
    self.snapshots = [snapshot.day: snapshot]
    self.failsMutation = failsMutation
    self.mutationDelay = mutationDelay
  }

  init(
    snapshots: [LocalDay: MyDaySnapshot],
    failsMutation: Bool = false,
    mutationDelay: Duration? = nil
  ) {
    self.snapshots = snapshots
    self.failsMutation = failsMutation
    self.mutationDelay = mutationDelay
  }

  func myDaySnapshot(for day: LocalDay) throws -> MyDaySnapshot {
    readCount += 1
    guard let snapshot = snapshots[day] else { throw MyDayTestError.expected }
    return snapshot
  }
  func daySnapshot(for day: LocalDay) throws -> DayActivitySnapshot {
    throw MyDayTestError.expected
  }

  func recordCheckoff(goalID: UUID, on day: LocalDay) async throws -> GoalCheckoffSnapshot {
    if let mutationDelay { try await Task.sleep(for: mutationDelay) }
    mutations.append(.record(goalID, day))
    if failsMutation { throw MyDayTestError.expected }
    let now = Date(timeIntervalSince1970: 0)
    return GoalCheckoffSnapshot(
      id: UUID(), plannedGoalID: goalID, instant: now, localDay: day,
      timeZoneIdentifier: "UTC", utcOffsetSeconds: 0, createdAt: now, updatedAt: now)
  }

  func removeCheckoff(goalID: UUID, on day: LocalDay) async throws -> GoalCheckoffSnapshot? {
    if let mutationDelay { try await Task.sleep(for: mutationDelay) }
    mutations.append(.remove(goalID, day))
    if failsMutation { throw MyDayTestError.expected }
    return nil
  }

  func recordIndulgence(categoryID: UUID) throws -> IndulgenceOccurrenceSnapshot {
    throw MyDayTestError.expected
  }
  func removeLatestIndulgence(categoryID: UUID, on day: LocalDay) throws
    -> IndulgenceOccurrenceSnapshot?
  { throw MyDayTestError.expected }
}

private enum MyDayTestError: Error {
  case expected
}
