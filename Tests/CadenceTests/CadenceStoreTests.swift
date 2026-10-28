import Foundation
import SwiftData
import Synchronization
import Testing

@testable import Cadence

@MainActor
struct CadenceStoreTests {
  private let now = ISO8601DateFormatter().date(from: "2026-10-28T16:00:00Z")!
  private let newYork = TimeZone(identifier: "America/New_York")!
  private let week = WeekID(monday: LocalDay(year: 2026, month: 10, day: 26)!)!

  @Test
  func repositoryBoundaryUsesSendableValueTypes() {
    requireSendable(GoalConfiguration.self)
    requireSendable(WeeklyPlanSnapshot.self)
    requireSendable(PlannedGoalSnapshot.self)
    requireSendable(GoalCheckoffSnapshot.self)
    requireSendable(IndulgenceCategorySnapshot.self)
    requireSendable(IndulgenceOccurrenceSnapshot.self)
    requireSendable(DayActivitySnapshot.self)
    requireSendable(WeekActivitySnapshot.self)
    requireSendable(RepositoryError.self)
  }

  @Test
  func planningEnforcesIdentityNormalizationOrderingAndHistoricalImmutability() async throws {
    let store = try makeStore()
    let first = try await store.ensurePlan(for: week)
    let repeated = try await store.ensurePlan(for: week)
    #expect(first.id == repeated.id)

    let walk = try await store.addGoal(
      to: week,
      configuration: GoalConfiguration(name: "  Walk  ", frequency: .daily)
    )
    #expect(walk.name == "Walk")
    #expect(walk.activeFrom == LocalDay(year: 2026, month: 10, day: 28))
    #expect(
      try await store.dayHistory(for: LocalDay(year: 2026, month: 10, day: 27)!).goals.isEmpty
    )
    await expectError(.duplicateGoalName) {
      _ = try await store.addGoal(
        to: self.week,
        configuration: GoalConfiguration(name: "wAlK", frequency: .weekly)
      )
    }
    await expectError(.blankGoalName) {
      _ = try await store.addGoal(
        to: self.week,
        configuration: GoalConfiguration(name: " \n ", frequency: .weekly)
      )
    }

    let read = try #require(try await store.plan(for: week))
    #expect(read.goals.map(\.id) == [walk.id])

    let historicalStore = try makeStore(
      instant: ISO8601DateFormatter().date(from: "2026-11-04T16:00:00Z")!)
    await expectError(.immutablePlan) {
      _ = try await historicalStore.ensurePlan(for: self.week)
    }
  }

  @Test
  func removalUsesInclusiveHistoryWhileCurrentOfferingEndsImmediately() async throws {
    let store = try makeStore()
    _ = try await store.ensurePlan(for: week)
    let goal = try await store.addGoal(
      to: week,
      configuration: GoalConfiguration(name: "Stretch", frequency: .daily)
    )
    let wednesday = LocalDay(year: 2026, month: 10, day: 28)!
    _ = try await store.recordCheckoff(goalID: goal.id, on: wednesday)
    let removed = try await store.removeGoal(id: goal.id, effectiveOn: wednesday)

    #expect(removed.activeThrough == wednesday)
    #expect(removed.wasHistoricallyActive(on: wednesday))
    #expect(!removed.isCurrentlyOffered)
    await expectError(.inactiveGoal) {
      _ = try await store.recordCheckoff(
        goalID: goal.id,
        on: LocalDay(year: 2026, month: 10, day: 29)!
      )
    }
    let history = try await store.dayHistory(for: wednesday)
    #expect(history.goals.map(\.id) == [goal.id])
    #expect(history.checkoffs.count == 1)
  }

  @Test
  func checkoffsEnforceDayUniquenessTargetAndExactRemoval() async throws {
    let store = try makeStore()
    _ = try await store.ensurePlan(for: week)
    let weekly = try await store.addGoal(
      to: week,
      configuration: GoalConfiguration(name: "Swim", frequency: .weekly)
    )
    let day = LocalDay(year: 2026, month: 10, day: 28)!
    let checkoff = try await store.recordCheckoff(goalID: weekly.id, on: day)
    #expect(checkoff.localDay == day)
    #expect(
      GregorianCalendarService(timeZone: newYork).localDay(containing: checkoff.instant) == day)
    #expect(checkoff.timeZoneIdentifier == "America/New_York")
    #expect(checkoff.utcOffsetSeconds == -14_400)
    await expectError(.duplicateCheckoff) {
      _ = try await store.recordCheckoff(goalID: weekly.id, on: day)
    }
    await expectError(.targetAlreadyMet) {
      _ = try await store.recordCheckoff(
        goalID: weekly.id,
        on: LocalDay(year: 2026, month: 10, day: 29)!
      )
    }
    #expect(try await store.removeCheckoff(goalID: weekly.id, on: day)?.id == checkoff.id)
    #expect(try await store.removeCheckoff(goalID: weekly.id, on: day) == nil)
  }

  @Test
  func carryForwardCopiesOrderedActiveGoalsWithStableLineage() async throws {
    let store = try makeStore()
    _ = try await store.ensurePlan(for: week)
    let daily = try await store.addGoal(
      to: week,
      configuration: GoalConfiguration(name: "Walk", frequency: .daily)
    )
    let custom = try await store.addGoal(
      to: week,
      configuration: GoalConfiguration(name: "Read", frequency: .custom(daysPerWeek: 3)!)
    )
    let ended = try await store.addGoal(
      to: week,
      configuration: GoalConfiguration(name: "Temporary", frequency: .weekly)
    )
    _ = try await store.removeGoal(
      id: ended.id,
      effectiveOn: LocalDay(year: 2026, month: 10, day: 28)!
    )
    _ = try await store.reorderGoals(in: week, orderedIDs: [custom.id, daily.id])
    let sourceBefore = try #require(try await store.plan(for: week))
    let target = WeekID(monday: LocalDay(year: 2026, month: 11, day: 2)!)!

    let carried = try await store.carryForward(from: week, to: target)
    let repeated = try await store.carryForward(from: week, to: target)
    #expect(carried.id == repeated.id)
    #expect(carried.goals.map(\.name) == ["Read", "Walk"])
    #expect(carried.goals.map(\.lineageID) == [custom.lineageID, daily.lineageID])
    #expect(carried.goals.allSatisfy { $0.activeFrom == target.monday && $0.activeThrough == nil })
    #expect(Set(carried.goals.map(\.id)).isDisjoint(with: sourceBefore.goals.map(\.id)))
    #expect(try await store.plan(for: week) == sourceBefore)
  }

  @Test
  func sundayPlanningCanRemoveAnUpcomingUnstartedGoal() async throws {
    let sunday = ISO8601DateFormatter().date(from: "2026-11-01T04:30:00Z")!
    let store = try makeStore(instant: sunday)
    let upcoming = WeekID(monday: LocalDay(year: 2026, month: 11, day: 2)!)!
    _ = try await store.ensurePlan(for: upcoming)
    let goal = try await store.addGoal(
      to: upcoming,
      configuration: GoalConfiguration(name: "Walk", frequency: .daily)
    )

    _ = try await store.removeGoal(id: goal.id, effectiveOn: upcoming.monday)

    #expect(try await store.plan(for: upcoming)?.goals.isEmpty == true)
  }

  @Test
  func historicalCheckoffContextUsesTheEventDaysDSTOffset() async throws {
    let sundayBeforeFallback = ISO8601DateFormatter().date(from: "2026-11-01T04:30:00Z")!
    let store = try makeStore(instant: sundayBeforeFallback)
    let upcoming = WeekID(monday: LocalDay(year: 2026, month: 11, day: 2)!)!
    _ = try await store.ensurePlan(for: upcoming)
    let goal = try await store.addGoal(
      to: upcoming,
      configuration: GoalConfiguration(name: "Walk", frequency: .daily)
    )

    let checkoff = try await store.recordCheckoff(goalID: goal.id, on: upcoming.monday)

    #expect(checkoff.localDay == upcoming.monday)
    #expect(
      GregorianCalendarService(timeZone: newYork).localDay(containing: checkoff.instant)
        == upcoming.monday)
    #expect(checkoff.utcOffsetSeconds == -18_000)
  }

  @Test
  func failedCarryForwardRollsBackTheWholeDestination() async throws {
    let calls = Mutex(0)
    let store = try makeStore(beforeSave: {
      let shouldFail = calls.withLock { count in
        count += 1
        return count == 3
      }
      if shouldFail { throw InjectedFailure() }
    })
    _ = try await store.ensurePlan(for: week)
    _ = try await store.addGoal(
      to: week,
      configuration: GoalConfiguration(name: "Walk", frequency: .daily)
    )
    let target = WeekID(monday: LocalDay(year: 2026, month: 11, day: 2)!)!

    await expectError(.persistenceFailure) {
      _ = try await store.carryForward(from: self.week, to: target)
    }

    #expect(try await store.plan(for: target) == nil)
    #expect(try await store.plan(for: week)?.goals.count == 1)
  }

  @Test
  func indulgenceRemovalUsesPreservedDayAndDeterministicLatestOrdering() async throws {
    let store = try makeStore()
    try await store.prepare()
    let category = try #require(
      (try await store.daySnapshot(for: LocalDay(year: 2026, month: 10, day: 28)!)).categories.first
    )
    let first = try await store.recordIndulgence(categoryID: category.id)
    let second = try await store.recordIndulgence(categoryID: category.id)
    let expected = [first, second].max { $0.id.uuidString < $1.id.uuidString }!

    let removed = try await store.removeLatestIndulgence(
      categoryID: category.id, on: first.localDay)
    #expect(removed?.id == expected.id)
    #expect(try await store.dayHistory(for: first.localDay).occurrences.count == 1)
    _ = try await store.removeLatestIndulgence(categoryID: category.id, on: first.localDay)
    #expect(
      try await store.removeLatestIndulgence(categoryID: category.id, on: first.localDay) == nil)
  }

  @Test
  func failedTransactionRollsBackBeforeLaterSuccess() async throws {
    let calls = Mutex(0)
    let store = try makeStore(beforeSave: {
      let shouldFail = calls.withLock { count in
        count += 1
        return count == 1
      }
      if shouldFail { throw InjectedFailure() }
    })

    await expectError(.persistenceFailure) {
      _ = try await store.ensurePlan(for: self.week)
    }
    #expect(try await store.plan(for: week) == nil)
    let successful = try await store.ensurePlan(for: week)
    #expect(try await store.plan(for: week)?.id == successful.id)
  }

  @Test
  func concurrentCallsPreservePlanGoalAndCheckoffInvariants() async throws {
    let store = try makeStore()
    let plans = try await withThrowingTaskGroup(of: WeeklyPlanSnapshot.self) { group in
      for _ in 0..<12 { group.addTask { try await store.ensurePlan(for: self.week) } }
      var results: [WeeklyPlanSnapshot] = []
      while let result = try await group.next() { results.append(result) }
      return results
    }
    #expect(Set(plans.map(\.id)).count == 1)

    let goalResults = await withTaskGroup(of: Result<PlannedGoalSnapshot, RepositoryError>.self) {
      group in
      for index in 0..<12 {
        group.addTask {
          do {
            return .success(
              try await store.addGoal(
                to: self.week,
                configuration: GoalConfiguration(
                  name: index.isMultiple(of: 2) ? "Walk" : " walk ",
                  frequency: .daily
                )
              ))
          } catch let error as RepositoryError {
            return .failure(error)
          } catch {
            return .failure(.persistenceFailure)
          }
        }
      }
      var results: [Result<PlannedGoalSnapshot, RepositoryError>] = []
      while let result = await group.next() { results.append(result) }
      return results
    }
    let successes = goalResults.compactMap { try? $0.get() }
    #expect(successes.count == 1)
    #expect(
      goalResults.count(where: { if case .failure(.duplicateGoalName) = $0 { true } else { false } }
      ) == 11)

    let goal = try #require(successes.first)
    let day = LocalDay(year: 2026, month: 10, day: 28)!
    let checkoffResults = await withTaskGroup(
      of: Result<GoalCheckoffSnapshot, RepositoryError>.self
    ) {
      group in
      for _ in 0..<12 {
        group.addTask {
          do { return .success(try await store.recordCheckoff(goalID: goal.id, on: day)) } catch let
            error as RepositoryError
          { return .failure(error) } catch { return .failure(.persistenceFailure) }
        }
      }
      var results: [Result<GoalCheckoffSnapshot, RepositoryError>] = []
      while let result = await group.next() { results.append(result) }
      return results
    }
    #expect(checkoffResults.compactMap { try? $0.get() }.count == 1)
    #expect(try await store.daySnapshot(for: day).checkoffs.count == 1)
  }

  @Test
  func repositoryDataSurvivesFileBackedReopen() async throws {
    let directory = FileManager.default.temporaryDirectory
      .appending(path: "cadence-store-tests-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appending(path: "Cadence.store")
    var planID: UUID?

    do {
      let container = try CadenceModelContainerFactory.makeProductionContainer(url: url)
      let store = CadenceStore(modelContainer: container, dependencies: dependencies())
      planID = try await store.ensurePlan(for: week).id
      _ = try await store.addGoal(
        to: week,
        configuration: GoalConfiguration(name: "Walk", frequency: .daily)
      )
    }

    do {
      let container = try CadenceModelContainerFactory.makeProductionContainer(url: url)
      let reopened = CadenceStore(modelContainer: container, dependencies: dependencies())
      let plan = try #require(try await reopened.plan(for: week))
      #expect(plan.id == planID)
      #expect(plan.goals.map(\.name) == ["Walk"])
    }
  }

  private func makeStore(
    instant: Date? = nil,
    beforeSave: @escaping @Sendable () throws -> Void = {}
  ) throws -> CadenceStore {
    CadenceStore(
      modelContainer: try CadenceModelContainerFactory.makeInMemoryContainer(),
      dependencies: dependencies(instant: instant, beforeSave: beforeSave)
    )
  }

  private func dependencies(
    instant: Date? = nil,
    beforeSave: @escaping @Sendable () throws -> Void = {}
  ) -> CadenceStoreDependencies {
    CadenceStoreDependencies(
      date: DateProvider { instant ?? self.now },
      timeZone: CurrentTimeZoneProvider { self.newYork },
      uuid: .live,
      beforeSave: beforeSave
    )
  }

  private func expectError<T: Sendable>(
    _ expected: RepositoryError,
    operation: @escaping @Sendable () async throws -> T
  ) async {
    do {
      _ = try await operation()
      Issue.record("Expected \(expected)")
    } catch let error as RepositoryError {
      #expect(error == expected)
    } catch {
      Issue.record("Unexpected error: \(error)")
    }
  }

  private func requireSendable<T: Sendable>(_ type: T.Type) {}
}

private struct InjectedFailure: Error {}
