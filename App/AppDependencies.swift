import Foundation

nonisolated struct AppDependencies: Sendable {
  let planning: any PlanningRepository
  let dailyTracking: any DailyTrackingRepository
  let history: any HistoryRepository
  let applicationPreparing: any ApplicationPreparing
  let date: DateProvider
  let timeZone: CurrentTimeZoneProvider
  let uuid: UUIDProvider

  @MainActor
  static func live() throws -> AppDependencies {
    let date = DateProvider.live
    let timeZone = CurrentTimeZoneProvider.live
    let uuid = UUIDProvider.live
    let store = CadenceStore(
      modelContainer: try CadenceModelContainerFactory.makeProductionContainer(),
      dependencies: CadenceStoreDependencies(
        date: date,
        timeZone: timeZone,
        uuid: uuid
      )
    )
    return AppDependencies(
      planning: store,
      dailyTracking: store,
      history: store,
      applicationPreparing: store,
      date: date,
      timeZone: timeZone,
      uuid: uuid
    )
  }

  func prepare() async throws {
    try await applicationPreparing.prepare()
  }
}
