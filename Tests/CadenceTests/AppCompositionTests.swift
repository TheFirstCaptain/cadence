import Foundation
import Testing

@testable import Cadence

@MainActor
struct AppCompositionTests {
  @Test
  func sharedStorePreparesBuiltInsAndConnectsAllRepositories() async throws {
    let (appDependencies, _) = try makeDependencies()

    try await appDependencies.prepare()
    try await appDependencies.prepare()

    let day = try #require(LocalDay(year: 2026, month: 10, day: 28))
    let week = try #require(WeekID(containing: day))
    _ = try await appDependencies.planning.ensurePlan(for: week)

    let daily = try await appDependencies.dailyTracking.daySnapshot(for: day)
    let history = try await appDependencies.history.weekSnapshot(for: week)
    #expect(daily.categories.count == 5)
    #expect(history.plan?.week == week)
  }

  @Test
  func bootstrapBecomesReadyOnlyAfterPreparationSucceeds() async throws {
    let preparer = ControlledPreparer()
    let (dependencies, _) = try makeDependencies(preparer: preparer)
    let model = AppBootstrapModel { dependencies }

    let startup = Task { await model.start() }
    await preparer.waitUntilCalled()
    if case .preparing = model.phase {
    } else {
      Issue.record("Expected bootstrap to remain preparing")
    }

    await preparer.succeed()
    await startup.value
    if case .ready = model.phase {
    } else {
      Issue.record("Expected bootstrap to become ready")
    }
  }

  @Test
  func bootstrapPreparationFailureCanRetry() async throws {
    let preparer = SequencedPreparer()
    let (dependencies, store) = try makeDependencies(preparer: preparer)
    let model = AppBootstrapModel { dependencies }

    await model.start()
    if case .failed = model.phase {
    } else {
      Issue.record("Expected the first preparation attempt to fail")
    }

    await model.retry()
    if case .ready(let readyDependencies) = model.phase {
      let day = try #require(LocalDay(year: 2026, month: 10, day: 28))
      _ = try await store.daySnapshot(for: day)
      _ = try await readyDependencies.dailyTracking.daySnapshot(for: day)
    } else {
      Issue.record("Expected retry to become ready")
    }
    #expect(await preparer.callCount == 2)
  }

  @Test
  func bootstrapConstructionFailureCanRetry() async throws {
    let (dependencies, _) = try makeDependencies()
    let factory = SequencedFactory(dependencies: dependencies)
    let model = AppBootstrapModel { try factory.make() }

    await model.start()
    if case .failed = model.phase {
    } else {
      Issue.record("Expected the first construction attempt to fail")
    }

    await model.retry()
    if case .ready = model.phase {
    } else {
      Issue.record("Expected construction retry to become ready")
    }
    #expect(factory.callCount == 2)
  }

  private func makeDependencies(
    preparer: (any ApplicationPreparing)? = nil
  ) throws -> (AppDependencies, CadenceStore) {
    let instant = try #require(ISO8601DateFormatter().date(from: "2026-10-28T16:00:00Z"))
    let storeDependencies = CadenceStoreDependencies(
      date: DateProvider { instant },
      timeZone: CurrentTimeZoneProvider { TimeZone(secondsFromGMT: 0)! },
      uuid: UUIDProvider(UUID.init)
    )
    let store = CadenceStore(
      modelContainer: try CadenceModelContainerFactory.makeInMemoryContainer(),
      dependencies: storeDependencies
    )
    return (
      AppDependencies(
        planning: store,
        dailyTracking: store,
        history: store,
        applicationPreparing: preparer ?? store,
        date: storeDependencies.date,
        timeZone: storeDependencies.timeZone,
        uuid: storeDependencies.uuid
      ),
      store
    )
  }
}

private actor ControlledPreparer: ApplicationPreparing {
  private var continuation: CheckedContinuation<Void, Never>?
  private var wasCalled = false

  func prepare() async throws {
    wasCalled = true
    await withCheckedContinuation { continuation = $0 }
  }

  func waitUntilCalled() async {
    while !wasCalled { await Task.yield() }
  }

  func succeed() {
    continuation?.resume()
    continuation = nil
  }
}

private actor SequencedPreparer: ApplicationPreparing {
  private(set) var callCount = 0

  func prepare() throws {
    callCount += 1
    if callCount == 1 { throw CompositionTestError.expected }
  }
}

@MainActor
private final class SequencedFactory {
  private let dependencies: AppDependencies
  private(set) var callCount = 0

  init(dependencies: AppDependencies) {
    self.dependencies = dependencies
  }

  func make() throws -> AppDependencies {
    callCount += 1
    if callCount == 1 { throw CompositionTestError.expected }
    return dependencies
  }
}

private enum CompositionTestError: Error {
  case expected
}
