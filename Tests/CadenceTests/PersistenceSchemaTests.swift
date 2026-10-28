import Foundation
import SwiftData
import Testing

@testable import Cadence

@MainActor
struct PersistenceSchemaTests {
  @Test
  func schemaAndMigrationPlanContainExactlyTheApprovedModels() {
    let modelNames = Set(CadenceSchemaV1.models.map { String(describing: $0) })

    #expect(CadenceSchemaV1.versionIdentifier == Schema.Version(1, 0, 0))
    #expect(
      modelNames
        == Set([
          "WeeklyPlanRecord",
          "PlannedGoalRecord",
          "GoalCheckoffRecord",
          "IndulgenceCategoryRecord",
          "IndulgenceOccurrenceRecord",
        ]))
    #expect(CadenceMigrationPlan.schemas.count == 1)
    #expect(String(describing: CadenceMigrationPlan.schemas[0]) == "CadenceSchemaV1")
    #expect(CadenceMigrationPlan.stages.isEmpty)
  }

  @Test
  func configurationsRemainLocalAndUseTheVersionedSchema() throws {
    let production = CadenceModelContainerFactory.productionConfiguration(
      url: FileManager.default.temporaryDirectory
        .appending(path: UUID().uuidString)
        .appendingPathExtension("store")
    )
    let memory = CadenceModelContainerFactory.inMemoryConfiguration()

    #expect(!production.isStoredInMemoryOnly)
    #expect(memory.isStoredInMemoryOnly)
    #expect(production.cloudKitContainerIdentifier == nil)
    #expect(memory.cloudKitContainerIdentifier == nil)
    #expect(production.schema?.entities.count == 5)
    #expect(memory.schema?.entities.count == 5)

    let container = try CadenceModelContainerFactory.makeInMemoryContainer()
    #expect(container.schema.entities.count == 5)
    #expect(String(describing: container.migrationPlan) == "Optional(Cadence.CadenceMigrationPlan)")
  }

  @Test
  func allRecordsRoundTripWithCapturedHistoricalContext() throws {
    let container = try CadenceModelContainerFactory.makeInMemoryContainer()
    let fixture = try PersistenceFixture()
    let expectedPlanID = fixture.plan.id
    let expectedGoalID = fixture.goal.id
    let expectedLineageID = fixture.goal.lineageID
    let expectedCategoryID = fixture.category.id
    let expectedCheckoffID = fixture.checkoff.id
    let expectedOccurrenceID = fixture.occurrence.id

    let insertionContext = ModelContext(container)
    insertionContext.insert(fixture.plan)
    insertionContext.insert(fixture.goal)
    insertionContext.insert(fixture.checkoff)
    insertionContext.insert(fixture.category)
    insertionContext.insert(fixture.occurrence)
    try insertionContext.save()

    let verificationContext = ModelContext(container)
    let plans = try verificationContext.fetch(FetchDescriptor<WeeklyPlanRecord>())
    let goals = try verificationContext.fetch(FetchDescriptor<PlannedGoalRecord>())
    let checkoffs = try verificationContext.fetch(FetchDescriptor<GoalCheckoffRecord>())
    let categories = try verificationContext.fetch(FetchDescriptor<IndulgenceCategoryRecord>())
    let occurrences = try verificationContext.fetch(FetchDescriptor<IndulgenceOccurrenceRecord>())

    let savedPlan = try #require(plans.first)
    #expect(savedPlan.id == expectedPlanID)
    #expect(savedPlan.mondayYear == 2026)
    #expect(savedPlan.mondayMonth == 10)
    #expect(savedPlan.mondayDay == 26)
    #expect(savedPlan.weekKey == "2026-10-26")
    #expect(savedPlan.calendarIdentifier == "gregorian")
    #expect(savedPlan.planningTimeZoneIdentifier == "America/New_York")
    #expect(savedPlan.planningUTCOffsetSeconds == -14_400)
    #expect(savedPlan.plannedGoals?.first?.id == expectedGoalID)

    let savedGoal = try #require(goals.first)
    #expect(savedGoal.weeklyPlanID == expectedPlanID)
    #expect(savedGoal.lineageID == expectedLineageID)
    #expect(savedGoal.frequencyKindRaw == GoalFrequency.Kind.custom.rawValue)
    #expect(savedGoal.customTarget == 3)
    #expect(savedGoal.activeFromKey == "2026-10-26")
    #expect(savedGoal.activeThroughYear == 2026)
    #expect(savedGoal.activeThroughMonth == 11)
    #expect(savedGoal.activeThroughDay == 1)
    #expect(savedGoal.activeThroughKey == "2026-11-01")
    #expect(savedGoal.weeklyPlan?.id == expectedPlanID)
    #expect(savedGoal.checkoffs?.first?.id == expectedCheckoffID)

    let savedCheckoff = try #require(checkoffs.first)
    #expect(savedCheckoff.instant == fixture.instant)
    #expect(savedCheckoff.plannedGoalID == expectedGoalID)
    #expect(savedCheckoff.localYear == 2026)
    #expect(savedCheckoff.localMonth == 11)
    #expect(savedCheckoff.localDay == 1)
    #expect(savedCheckoff.localDayKey == "2026-11-01")
    #expect(savedCheckoff.timeZoneIdentifier == "America/New_York")
    #expect(savedCheckoff.utcOffsetSeconds == -14_400)
    #expect(savedCheckoff.plannedGoal?.id == expectedGoalID)

    #expect(categories.first?.id == expectedCategoryID)
    #expect(categories.first?.occurrences?.first?.id == expectedOccurrenceID)

    let savedOccurrence = try #require(occurrences.first)
    #expect(savedOccurrence.instant == fixture.instant)
    #expect(savedOccurrence.categoryID == expectedCategoryID)
    #expect(savedOccurrence.localYear == 2026)
    #expect(savedOccurrence.localMonth == 11)
    #expect(savedOccurrence.localDay == 1)
    #expect(savedOccurrence.localDayKey == "2026-11-01")
    #expect(savedOccurrence.timeZoneIdentifier == "America/New_York")
    #expect(savedOccurrence.utcOffsetSeconds == -14_400)
    #expect(savedOccurrence.category?.id == expectedCategoryID)
  }

  @Test
  func deletingParentsNullifiesEachRelationshipWithoutDeletingHistory() throws {
    let container = try CadenceModelContainerFactory.makeInMemoryContainer()
    let context = ModelContext(container)
    let fixture = try PersistenceFixture()
    let planID = fixture.plan.id
    let goalID = fixture.goal.id
    let categoryID = fixture.category.id

    context.insert(fixture.plan)
    context.insert(fixture.goal)
    context.insert(fixture.checkoff)
    context.insert(fixture.category)
    context.insert(fixture.occurrence)
    try context.save()

    context.delete(fixture.plan)
    try context.save()

    let afterPlanDeletion = ModelContext(container)
    let remainingGoal = try #require(
      afterPlanDeletion.fetch(FetchDescriptor<PlannedGoalRecord>()).first)
    #expect(remainingGoal.weeklyPlan == nil)
    #expect(remainingGoal.weeklyPlanID == planID)

    afterPlanDeletion.delete(remainingGoal)
    try afterPlanDeletion.save()

    let afterGoalDeletion = ModelContext(container)
    let remainingCheckoff = try #require(
      afterGoalDeletion.fetch(FetchDescriptor<GoalCheckoffRecord>()).first)
    #expect(remainingCheckoff.plannedGoal == nil)
    #expect(remainingCheckoff.plannedGoalID == goalID)
    #expect(remainingCheckoff.localDayKey == "2026-11-01")

    let savedCategory = try #require(
      afterGoalDeletion.fetch(FetchDescriptor<IndulgenceCategoryRecord>()).first)
    afterGoalDeletion.delete(savedCategory)
    try afterGoalDeletion.save()

    let afterCategoryDeletion = ModelContext(container)
    let remainingOccurrence = try #require(
      afterCategoryDeletion.fetch(FetchDescriptor<IndulgenceOccurrenceRecord>()).first)
    #expect(remainingOccurrence.category == nil)
    #expect(remainingOccurrence.categoryID == categoryID)
    #expect(remainingOccurrence.localDayKey == "2026-11-01")
  }

  @Test
  func productionContainerPersistsAndReopensAnExplicitLocalStore() throws {
    let directory = FileManager.default.temporaryDirectory
      .appending(path: "cadence-schema-tests-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let storeURL = directory.appending(path: "Cadence.store")
    let categoryID = UUID(uuidString: "30000000-0000-0000-0000-000000000001")!

    do {
      let container = try CadenceModelContainerFactory.makeProductionContainer(url: storeURL)
      let context = ModelContext(container)
      context.insert(
        IndulgenceCategoryRecord(
          id: categoryID,
          name: "Local Test",
          normalizedName: "local test",
          symbolName: "circle",
          sortOrder: 0,
          isBuiltIn: false,
          isActive: true,
          createdAt: .distantPast,
          updatedAt: .distantPast
        ))
      try context.save()
    }

    do {
      let reopened = try CadenceModelContainerFactory.makeProductionContainer(url: storeURL)
      let saved = try ModelContext(reopened).fetch(FetchDescriptor<IndulgenceCategoryRecord>())
      #expect(saved.map(\.id) == [categoryID])
    }
  }

  @Test
  func builtInSeedingIsFixedRepeatableAndNonDestructive() throws {
    let container = try CadenceModelContainerFactory.makeInMemoryContainer()
    let context = ModelContext(container)
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let first = BuiltInIndulgenceCategories.all[0]
    let archived = IndulgenceCategoryRecord(
      id: first.id,
      name: first.name,
      normalizedName: first.normalizedName,
      symbolName: first.symbolName,
      sortOrder: first.sortOrder,
      isBuiltIn: true,
      isActive: false,
      createdAt: now.addingTimeInterval(-100),
      updatedAt: now.addingTimeInterval(-100)
    )
    context.insert(archived)
    try context.save()

    try BuiltInIndulgenceCategories.seed(in: context, now: now)
    try BuiltInIndulgenceCategories.seed(in: context, now: now.addingTimeInterval(100))

    let saved = try context.fetch(
      FetchDescriptor<IndulgenceCategoryRecord>(
        sortBy: [SortDescriptor(\.sortOrder)]
      ))
    #expect(saved.count == 5)
    #expect(
      saved.map(\.id.uuidString)
        == [
          "10000000-0000-0000-0000-000000000001",
          "10000000-0000-0000-0000-000000000002",
          "10000000-0000-0000-0000-000000000003",
          "10000000-0000-0000-0000-000000000004",
          "10000000-0000-0000-0000-000000000005",
        ])
    #expect(saved.map(\.name) == ["Junk Food", "Unhealthy Snacks", "Candy", "Alcohol", "Desserts"])
    #expect(saved.map(\.symbolName) == Array(repeating: "circle", count: 5))
    let allAreBuiltIn = saved.allSatisfy(\.isBuiltIn)
    #expect(allAreBuiltIn)
    #expect(saved.first?.isActive == false)
    #expect(saved.first?.updatedAt == now.addingTimeInterval(-100))
  }

  @Test
  func failedSeedingRollsBackInsertedCategories() throws {
    struct ExpectedFailure: Error {}

    let container = try CadenceModelContainerFactory.makeInMemoryContainer()
    let context = ModelContext(container)

    #expect(throws: ExpectedFailure.self) {
      try BuiltInIndulgenceCategories.seed(
        in: context,
        now: .distantPast,
        save: { _ in throw ExpectedFailure() }
      )
    }
    #expect(!context.hasChanges)
    let saved = try context.fetch(FetchDescriptor<IndulgenceCategoryRecord>())
    #expect(saved.isEmpty)
  }
}

@MainActor
private struct PersistenceFixture {
  let instant = Date(timeIntervalSince1970: 1_793_518_800)
  let plan: WeeklyPlanRecord
  let goal: PlannedGoalRecord
  let checkoff: GoalCheckoffRecord
  let category: IndulgenceCategoryRecord
  let occurrence: IndulgenceOccurrenceRecord

  init() throws {
    let monday = try #require(LocalDay(year: 2026, month: 10, day: 26))
    let activityDay = try #require(LocalDay(year: 2026, month: 11, day: 1))
    let timestamp = Date(timeIntervalSince1970: 1_793_518_800)
    let planID = try #require(UUID(uuidString: "20000000-0000-0000-0000-000000000001"))
    let goalID = try #require(UUID(uuidString: "20000000-0000-0000-0000-000000000002"))
    let categoryID = try #require(UUID(uuidString: "20000000-0000-0000-0000-000000000003"))

    plan = WeeklyPlanRecord(
      id: planID,
      monday: monday,
      planningTimeZoneIdentifier: "America/New_York",
      planningUTCOffsetSeconds: -14_400,
      createdAt: timestamp,
      updatedAt: timestamp
    )
    goal = PlannedGoalRecord(
      id: goalID,
      weeklyPlanID: planID,
      lineageID: UUID(),
      name: "Walk",
      normalizedName: "walk",
      frequencyKindRaw: GoalFrequency.Kind.custom.rawValue,
      customTarget: 3,
      sortOrder: 0,
      activeFrom: monday,
      activeThrough: activityDay,
      createdAt: timestamp,
      updatedAt: timestamp,
      weeklyPlan: plan
    )
    checkoff = GoalCheckoffRecord(
      id: UUID(),
      plannedGoalID: goalID,
      instant: timestamp,
      localDay: activityDay,
      timeZoneIdentifier: "America/New_York",
      utcOffsetSeconds: -14_400,
      createdAt: timestamp,
      updatedAt: timestamp,
      plannedGoal: goal
    )
    category = IndulgenceCategoryRecord(
      id: categoryID,
      name: "Desserts",
      normalizedName: "desserts",
      symbolName: "circle",
      sortOrder: 4,
      isBuiltIn: true,
      isActive: true,
      createdAt: timestamp,
      updatedAt: timestamp
    )
    occurrence = IndulgenceOccurrenceRecord(
      id: UUID(),
      categoryID: categoryID,
      instant: timestamp,
      localDay: activityDay,
      timeZoneIdentifier: "America/New_York",
      utcOffsetSeconds: -14_400,
      createdAt: timestamp,
      updatedAt: timestamp,
      category: category
    )
  }
}
