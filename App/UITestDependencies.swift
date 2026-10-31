import Foundation

nonisolated enum UITestMyDayMode: Equatable, Sendable {
  case empty
  case populated
  case readFailure
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
      mode == .readFailure ? FailingMyDayRepository(base: store) : store
    return AppDependencies(
      planning: store,
      dailyTracking: dailyTracking,
      history: store,
      applicationPreparing: preparer,
      date: date,
      timeZone: timeZone,
      uuid: uuid)
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
    guard mode == .populated else { return }
    let calendar = GregorianCalendarService(timeZone: timeZone)
    let day = calendar.localDay(containing: instant)
    let week = calendar.week(containing: instant)
    guard try await store.plan(for: week) == nil else { return }
    _ = try await store.ensurePlan(for: week)
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
  }
}

private actor FailingMyDayRepository: DailyTrackingRepository {
  let base: CadenceStore

  init(base: CadenceStore) {
    self.base = base
  }

  func myDaySnapshot(for day: LocalDay) throws -> MyDaySnapshot {
    throw RepositoryError.persistenceFailure
  }

  func daySnapshot(for day: LocalDay) async throws -> DayActivitySnapshot {
    try await base.daySnapshot(for: day)
  }

  func recordCheckoff(goalID: UUID, on day: LocalDay) async throws -> GoalCheckoffSnapshot {
    try await base.recordCheckoff(goalID: goalID, on: day)
  }

  func removeCheckoff(goalID: UUID, on day: LocalDay) async throws -> GoalCheckoffSnapshot? {
    try await base.removeCheckoff(goalID: goalID, on: day)
  }

  func recordIndulgence(categoryID: UUID) async throws -> IndulgenceOccurrenceSnapshot {
    try await base.recordIndulgence(categoryID: categoryID)
  }

  func removeLatestIndulgence(categoryID: UUID, on day: LocalDay) async throws
    -> IndulgenceOccurrenceSnapshot?
  {
    try await base.removeLatestIndulgence(categoryID: categoryID, on: day)
  }
}
