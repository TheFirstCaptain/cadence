import Foundation
import SwiftData

nonisolated struct CadenceStoreDependencies: Sendable {
  let date: DateProvider
  let timeZone: CurrentTimeZoneProvider
  let uuid: UUIDProvider
  let beforeSave: @Sendable () throws -> Void

  init(
    date: DateProvider,
    timeZone: CurrentTimeZoneProvider,
    uuid: UUIDProvider,
    beforeSave: @escaping @Sendable () throws -> Void = {}
  ) {
    self.date = date
    self.timeZone = timeZone
    self.uuid = uuid
    self.beforeSave = beforeSave
  }

  static let live = CadenceStoreDependencies(
    date: .live,
    timeZone: .live,
    uuid: .live
  )
}

@ModelActor
actor CadenceStore:
  ApplicationPreparing, PlanningRepository, DailyTrackingRepository, HistoryRepository
{
  private var dependencies: CadenceStoreDependencies = .live

  init(modelContainer: ModelContainer, dependencies: CadenceStoreDependencies = .live) {
    let context = ModelContext(modelContainer)
    context.autosaveEnabled = false
    modelExecutor = DefaultSerialModelExecutor(modelContext: context)
    self.modelContainer = modelContainer
    self.dependencies = dependencies
  }

  func prepare() throws {
    try transaction {
      try seedBuiltInCategories()
    }
  }

  func plan(for week: WeekID) throws -> WeeklyPlanSnapshot? {
    let matches = try planRecords().filter { $0.weekKey == week.canonicalKey }
    guard matches.count <= 1 else { throw RepositoryError.duplicatePlan }
    return try matches.first.map(planSnapshot)
  }

  func ensurePlan(for week: WeekID) throws -> WeeklyPlanSnapshot {
    if let existing = try plan(for: week) { return existing }
    let operation = operationContext()
    try validateEditable(week: week, operation: operation)
    return try transaction {
      guard try planRecords().allSatisfy({ $0.weekKey != week.canonicalKey }) else {
        throw RepositoryError.duplicatePlan
      }
      let id = try nextUniqueID()
      let record = WeeklyPlanRecord(
        id: id,
        monday: week.monday,
        planningTimeZoneIdentifier: operation.timeZone.identifier,
        planningUTCOffsetSeconds: operation.offset,
        createdAt: operation.instant,
        updatedAt: operation.instant
      )
      modelContext.insert(record)
      return try planSnapshot(record)
    }
  }

  func addGoal(to week: WeekID, configuration: GoalConfiguration) throws -> PlannedGoalSnapshot {
    let operation = operationContext()
    try validateEditable(week: week, operation: operation)
    let validated = try validatedConfiguration(configuration)
    return try transaction {
      let plan = try requirePlan(week)
      let goals = try goalRecords(forPlanID: plan.id)
      guard !goals.contains(where: { $0.normalizedName == validated.normalizedName }) else {
        throw RepositoryError.duplicateGoalName
      }
      let id = try nextUniqueID()
      let record = PlannedGoalRecord(
        id: id,
        weeklyPlanID: plan.id,
        lineageID: try nextUniqueID(excluding: [id]),
        name: validated.name,
        normalizedName: validated.normalizedName,
        frequencyKindRaw: validated.frequency.kind.rawValue,
        customTarget: validated.frequency.kind == .custom ? validated.frequency.targetPerWeek : nil,
        sortOrder: goals.count,
        activeFrom: week == WeekID(containing: operation.day) ? operation.day : week.monday,
        createdAt: operation.instant,
        updatedAt: operation.instant,
        weeklyPlan: plan
      )
      modelContext.insert(record)
      return try goalSnapshot(record)
    }
  }

  func updateGoal(id: UUID, configuration: GoalConfiguration) throws -> PlannedGoalSnapshot {
    let validated = try validatedConfiguration(configuration)
    let operation = operationContext()
    return try transaction {
      let goal = try requireGoal(id)
      let week = try weekForGoal(goal)
      try validateEditable(week: week, operation: operation)
      let siblings = try goalRecords(forPlanID: goal.weeklyPlanID)
      guard
        !siblings.contains(where: { $0.id != id && $0.normalizedName == validated.normalizedName })
      else { throw RepositoryError.duplicateGoalName }
      goal.name = validated.name
      goal.normalizedName = validated.normalizedName
      goal.frequencyKindRaw = validated.frequency.kind.rawValue
      goal.customTarget =
        validated.frequency.kind == .custom ? validated.frequency.targetPerWeek : nil
      goal.updatedAt = operation.instant
      return try goalSnapshot(goal)
    }
  }

  func removeGoal(id: UUID, effectiveOn day: LocalDay) throws -> PlannedGoalSnapshot {
    let operation = operationContext()
    return try transaction {
      let goal = try requireGoal(id)
      let week = try weekForGoal(goal)
      try validateEditable(week: week, operation: operation)
      let activeFrom = try localDay(
        year: goal.activeFromYear,
        month: goal.activeFromMonth,
        day: goal.activeFromDay,
        key: goal.activeFromKey)
      if operation.day < activeFrom {
        guard try checkoffRecords().allSatisfy({ $0.plannedGoalID != id }) else {
          throw RepositoryError.inactiveGoal
        }
        let snapshot = try goalSnapshot(goal)
        modelContext.delete(goal)
        return snapshot
      }
      guard WeekID(containing: day) == week, day >= activeFrom else {
        throw RepositoryError.inactiveGoal
      }
      goal.activeThroughYear = day.year
      goal.activeThroughMonth = day.month
      goal.activeThroughDay = day.day
      goal.activeThroughKey = day.canonicalKey
      goal.updatedAt = operation.instant
      return try goalSnapshot(goal)
    }
  }

  func reorderGoals(in week: WeekID, orderedIDs: [UUID]) throws -> WeeklyPlanSnapshot {
    let operation = operationContext()
    try validateEditable(week: week, operation: operation)
    return try transaction {
      let plan = try requirePlan(week)
      let goals = try goalRecords(forPlanID: plan.id).filter { $0.activeThroughKey == nil }
      guard Set(goals.map(\.id)) == Set(orderedIDs), goals.count == orderedIDs.count else {
        throw RepositoryError.invalidOrdering
      }
      let byID = Dictionary(uniqueKeysWithValues: goals.map { ($0.id, $0) })
      for (index, id) in orderedIDs.enumerated() {
        byID[id]?.sortOrder = index
        byID[id]?.updatedAt = operation.instant
      }
      plan.updatedAt = operation.instant
      return try planSnapshot(plan)
    }
  }

  func carryForward(from source: WeekID, to target: WeekID) throws -> WeeklyPlanSnapshot {
    guard source.monday.addingDays(7) == target.monday else {
      throw RepositoryError.nonconsecutiveWeeks
    }
    if let existing = try plan(for: target) { return existing }
    let operation = operationContext()
    return try transaction {
      let sourcePlan = try requirePlan(source)
      guard try planRecords().allSatisfy({ $0.weekKey != target.canonicalKey }) else {
        throw RepositoryError.duplicatePlan
      }
      let destination = WeeklyPlanRecord(
        id: try nextUniqueID(),
        monday: target.monday,
        planningTimeZoneIdentifier: operation.timeZone.identifier,
        planningUTCOffsetSeconds: operation.offset,
        createdAt: operation.instant,
        updatedAt: operation.instant
      )
      modelContext.insert(destination)
      let sourceGoals = try goalRecords(forPlanID: sourcePlan.id)
        .map { record in (record, try goalSnapshot(record)) }
        .filter { $0.1.wasHistoricallyActive(on: source.sunday!) }
        .sorted { $0.1.sortOrder < $1.1.sortOrder }
      var reservedIDs: Set<UUID> = [destination.id]
      for (goal, snapshot) in sourceGoals {
        let id = try nextUniqueID(excluding: reservedIDs)
        reservedIDs.insert(id)
        let copy = PlannedGoalRecord(
          id: id,
          weeklyPlanID: destination.id,
          lineageID: goal.lineageID,
          name: snapshot.name,
          normalizedName: goal.normalizedName,
          frequencyKindRaw: snapshot.frequency.kind.rawValue,
          customTarget: snapshot.frequency.kind == .custom ? snapshot.frequency.targetPerWeek : nil,
          sortOrder: snapshot.sortOrder,
          activeFrom: target.monday,
          createdAt: operation.instant,
          updatedAt: operation.instant,
          weeklyPlan: destination
        )
        modelContext.insert(copy)
      }
      return try planSnapshot(destination)
    }
  }

  func daySnapshot(for day: LocalDay) throws -> DayActivitySnapshot {
    try makeDaySnapshot(day)
  }

  func myDaySnapshot(for day: LocalDay) throws -> MyDaySnapshot {
    guard let week = WeekID(containing: day) else { throw RepositoryError.corruptedData }
    let plan = try plan(for: week)
    let goals =
      plan?.goals
      .filter { $0.activeFrom <= day && $0.isCurrentlyOffered }
      .sorted { $0.sortOrder < $1.sortOrder } ?? []
    let goalIDs = Set(goals.map(\.id))
    let weekDayKeys = Set((0..<7).compactMap { week.monday.addingDays($0)?.canonicalKey })
    let weekCheckoffs = try checkoffRecords()
      .filter { goalIDs.contains($0.plannedGoalID) && weekDayKeys.contains($0.localDayKey) }
      .map(checkoffSnapshot)
      .sorted { $0.instant < $1.instant }
    return MyDaySnapshot(
      day: day,
      week: week,
      goals: goals,
      todayCheckoffs: weekCheckoffs.filter { $0.localDay == day },
      weekCheckoffs: weekCheckoffs
    )
  }

  func dayHistory(for day: LocalDay) throws -> DayActivitySnapshot {
    try makeDaySnapshot(day)
  }

  func weekSnapshot(for week: WeekID) throws -> WeekActivitySnapshot {
    let plan = try plan(for: week)
    let goalIDs = Set(plan?.goals.map(\.id) ?? [])
    let dayKeys = Set((0..<7).compactMap { week.monday.addingDays($0)?.canonicalKey })
    let checkoffs = try checkoffRecords()
      .filter { goalIDs.contains($0.plannedGoalID) && dayKeys.contains($0.localDayKey) }
      .map(checkoffSnapshot)
      .sorted { $0.instant < $1.instant }
    let occurrences = try occurrenceRecords()
      .filter { dayKeys.contains($0.localDayKey) }
      .map(occurrenceSnapshot)
      .sorted { $0.instant < $1.instant }
    return WeekActivitySnapshot(plan: plan, checkoffs: checkoffs, occurrences: occurrences)
  }

  func recordCheckoff(goalID: UUID, on day: LocalDay) throws -> GoalCheckoffSnapshot {
    let operation = operationContext()
    return try transaction {
      let goal = try requireGoal(goalID)
      guard try goalIsActive(goal, on: day), try weekForGoal(goal) == WeekID(containing: day) else {
        throw RepositoryError.inactiveGoal
      }
      let existing = try checkoffRecords().filter { $0.plannedGoalID == goalID }
      guard !existing.contains(where: { $0.localDayKey == day.canonicalKey }) else {
        throw RepositoryError.duplicateCheckoff
      }
      let frequency = try frequency(for: goal)
      guard existing.count < frequency.targetPerWeek else {
        throw RepositoryError.targetAlreadyMet
      }
      let eventInstant =
        day == operation.day
        ? operation.instant
        : GregorianCalendarService(timeZone: operation.timeZone).startOfDay(for: day)!
      let record = GoalCheckoffRecord(
        id: try nextUniqueID(),
        plannedGoalID: goalID,
        instant: eventInstant,
        localDay: day,
        timeZoneIdentifier: operation.timeZone.identifier,
        utcOffsetSeconds: operation.timeZone.secondsFromGMT(for: eventInstant),
        createdAt: operation.instant,
        updatedAt: operation.instant,
        plannedGoal: goal
      )
      modelContext.insert(record)
      return try checkoffSnapshot(record)
    }
  }

  func removeCheckoff(goalID: UUID, on day: LocalDay) throws -> GoalCheckoffSnapshot? {
    let record = try checkoffRecords().first {
      $0.plannedGoalID == goalID && $0.localDayKey == day.canonicalKey
    }
    guard let record else { return nil }
    let snapshot = try checkoffSnapshot(record)
    try transaction { modelContext.delete(record) }
    return snapshot
  }

  func recordIndulgence(categoryID: UUID) throws -> IndulgenceOccurrenceSnapshot {
    let operation = operationContext()
    return try transaction {
      let category = try requireCategory(categoryID)
      guard category.isActive else { throw RepositoryError.categoryNotFound }
      let record = IndulgenceOccurrenceRecord(
        id: try nextUniqueID(),
        categoryID: categoryID,
        instant: operation.instant,
        localDay: operation.day,
        timeZoneIdentifier: operation.timeZone.identifier,
        utcOffsetSeconds: operation.offset,
        createdAt: operation.instant,
        updatedAt: operation.instant,
        category: category
      )
      modelContext.insert(record)
      return try occurrenceSnapshot(record)
    }
  }

  func removeLatestIndulgence(categoryID: UUID, on day: LocalDay) throws
    -> IndulgenceOccurrenceSnapshot?
  {
    let candidates = try occurrenceRecords().filter {
      $0.categoryID == categoryID && $0.localDayKey == day.canonicalKey
    }
    let record = candidates.max { lhs, rhs in
      (lhs.instant, lhs.createdAt, lhs.id.uuidString) < (
        rhs.instant, rhs.createdAt, rhs.id.uuidString
      )
    }
    guard let record else { return nil }
    let snapshot = try occurrenceSnapshot(record)
    try transaction { modelContext.delete(record) }
    return snapshot
  }

  func removeOccurrence(id: UUID) throws -> IndulgenceOccurrenceSnapshot? {
    guard let record = try occurrenceRecords().first(where: { $0.id == id }) else { return nil }
    let snapshot = try occurrenceSnapshot(record)
    try transaction { modelContext.delete(record) }
    return snapshot
  }

  private func makeDaySnapshot(_ day: LocalDay) throws -> DayActivitySnapshot {
    let week = WeekID(containing: day)
    let plan = try week.flatMap { try plan(for: $0) }
    let goals = plan?.goals.filter { $0.wasHistoricallyActive(on: day) } ?? []
    let goalIDs = Set(goals.map(\.id))
    let checkoffs = try checkoffRecords()
      .filter { goalIDs.contains($0.plannedGoalID) && $0.localDayKey == day.canonicalKey }
      .map(checkoffSnapshot)
    let categories = try categoryRecords().map(categorySnapshot).sorted {
      $0.sortOrder < $1.sortOrder
    }
    let occurrences = try occurrenceRecords()
      .filter { $0.localDayKey == day.canonicalKey }
      .map(occurrenceSnapshot)
      .sorted { $0.instant < $1.instant }
    return DayActivitySnapshot(
      day: day,
      goals: goals,
      checkoffs: checkoffs,
      categories: categories,
      occurrences: occurrences
    )
  }

  private func transaction<T>(_ mutation: () throws -> T) throws -> T {
    guard !modelContext.hasChanges else { throw RepositoryError.persistenceFailure }
    do {
      let result = try mutation()
      try dependencies.beforeSave()
      if modelContext.hasChanges { try modelContext.save() }
      return result
    } catch let error as RepositoryError {
      modelContext.rollback()
      throw error
    } catch {
      modelContext.rollback()
      throw RepositoryError.persistenceFailure
    }
  }

  private struct OperationContext {
    let instant: Date
    let timeZone: TimeZone
    let day: LocalDay
    let offset: Int
  }

  private func operationContext() -> OperationContext {
    let instant = dependencies.date.now()
    let timeZone = dependencies.timeZone.current()
    return OperationContext(
      instant: instant,
      timeZone: timeZone,
      day: GregorianCalendarService(timeZone: timeZone).localDay(containing: instant),
      offset: timeZone.secondsFromGMT(for: instant)
    )
  }

  private func currentWeek() -> WeekID {
    WeekID(containing: operationContext().day)!
  }

  private func validateEditable(week: WeekID, operation: OperationContext) throws {
    let current = WeekID(containing: operation.day)!
    if week == current { return }
    if operation.day.weekday == 1, current.monday.addingDays(7) == week.monday { return }
    throw RepositoryError.immutablePlan
  }

  private func validatedConfiguration(_ configuration: GoalConfiguration) throws
    -> (name: String, normalizedName: String, frequency: GoalFrequency)
  {
    let name = configuration.name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !name.isEmpty else { throw RepositoryError.blankGoalName }
    let normalized = name.folding(
      options: [.caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
    return (name, normalized, configuration.frequency)
  }

  private func frequency(for record: PlannedGoalRecord) throws -> GoalFrequency {
    switch (GoalFrequency.Kind(rawValue: record.frequencyKindRaw), record.customTarget) {
    case (.daily?, nil): return .daily
    case (.weekly?, nil): return .weekly
    case (.custom?, let target?):
      guard let result = GoalFrequency.custom(daysPerWeek: target) else {
        throw RepositoryError.corruptedData
      }
      return result
    default: throw RepositoryError.corruptedData
    }
  }

  private func planSnapshot(_ record: WeeklyPlanRecord) throws -> WeeklyPlanSnapshot {
    let monday = try localDay(
      year: record.mondayYear,
      month: record.mondayMonth,
      day: record.mondayDay,
      key: record.weekKey)
    guard let week = WeekID(monday: monday) else { throw RepositoryError.corruptedData }
    let goals = try goalRecords(forPlanID: record.id).map(goalSnapshot).sorted {
      $0.sortOrder < $1.sortOrder
    }
    return WeeklyPlanSnapshot(
      id: record.id,
      week: week,
      planningTimeZoneIdentifier: record.planningTimeZoneIdentifier,
      planningUTCOffsetSeconds: record.planningUTCOffsetSeconds,
      goals: goals,
      createdAt: record.createdAt,
      updatedAt: record.updatedAt
    )
  }

  private func goalSnapshot(_ record: PlannedGoalRecord) throws -> PlannedGoalSnapshot {
    if let relationshipID = record.weeklyPlan?.id, relationshipID != record.weeklyPlanID {
      throw RepositoryError.corruptedData
    }
    let activeFrom = try localDay(
      year: record.activeFromYear,
      month: record.activeFromMonth,
      day: record.activeFromDay,
      key: record.activeFromKey)
    let activeThrough: LocalDay?
    switch (
      record.activeThroughYear, record.activeThroughMonth, record.activeThroughDay,
      record.activeThroughKey
    ) {
    case (nil, nil, nil, nil): activeThrough = nil
    case (let year?, let month?, let day?, let key?):
      activeThrough = try localDay(year: year, month: month, day: day, key: key)
    default: throw RepositoryError.corruptedData
    }
    guard activeThrough.map({ $0 >= activeFrom }) ?? true else {
      throw RepositoryError.corruptedData
    }
    let owningWeek = try weekForGoal(record)
    guard WeekID(containing: activeFrom) == owningWeek,
      activeThrough.map({ WeekID(containing: $0) == owningWeek }) ?? true
    else { throw RepositoryError.corruptedData }
    return PlannedGoalSnapshot(
      id: record.id,
      weeklyPlanID: record.weeklyPlanID,
      lineageID: record.lineageID,
      name: record.name,
      frequency: try frequency(for: record),
      sortOrder: record.sortOrder,
      activeFrom: activeFrom,
      activeThrough: activeThrough,
      createdAt: record.createdAt,
      updatedAt: record.updatedAt
    )
  }

  private func checkoffSnapshot(_ record: GoalCheckoffRecord) throws -> GoalCheckoffSnapshot {
    if let relationshipID = record.plannedGoal?.id, relationshipID != record.plannedGoalID {
      throw RepositoryError.corruptedData
    }
    return GoalCheckoffSnapshot(
      id: record.id,
      plannedGoalID: record.plannedGoalID,
      instant: record.instant,
      localDay: try localDay(
        year: record.localYear,
        month: record.localMonth,
        day: record.localDay,
        key: record.localDayKey),
      timeZoneIdentifier: record.timeZoneIdentifier,
      utcOffsetSeconds: record.utcOffsetSeconds,
      createdAt: record.createdAt,
      updatedAt: record.updatedAt
    )
  }

  private func categorySnapshot(_ record: IndulgenceCategoryRecord) -> IndulgenceCategorySnapshot {
    IndulgenceCategorySnapshot(
      id: record.id,
      name: record.name,
      symbolName: record.symbolName,
      sortOrder: record.sortOrder,
      isBuiltIn: record.isBuiltIn,
      isActive: record.isActive
    )
  }

  private func occurrenceSnapshot(_ record: IndulgenceOccurrenceRecord) throws
    -> IndulgenceOccurrenceSnapshot
  {
    if let relationshipID = record.category?.id, relationshipID != record.categoryID {
      throw RepositoryError.corruptedData
    }
    return IndulgenceOccurrenceSnapshot(
      id: record.id,
      categoryID: record.categoryID,
      instant: record.instant,
      localDay: try localDay(
        year: record.localYear,
        month: record.localMonth,
        day: record.localDay,
        key: record.localDayKey),
      timeZoneIdentifier: record.timeZoneIdentifier,
      utcOffsetSeconds: record.utcOffsetSeconds,
      createdAt: record.createdAt,
      updatedAt: record.updatedAt
    )
  }

  private func localDay(year: Int, month: Int, day: Int, key: String) throws -> LocalDay {
    guard let value = LocalDay(year: year, month: month, day: day), value.canonicalKey == key else {
      throw RepositoryError.corruptedData
    }
    return value
  }

  private func weekForGoal(_ goal: PlannedGoalRecord) throws -> WeekID {
    let matches = try planRecords().filter { $0.id == goal.weeklyPlanID }
    guard matches.count <= 1 else { throw RepositoryError.corruptedData }
    guard let plan = matches.first else { throw RepositoryError.planNotFound }
    let monday = try localDay(
      year: plan.mondayYear,
      month: plan.mondayMonth,
      day: plan.mondayDay,
      key: plan.weekKey)
    guard let week = WeekID(monday: monday) else { throw RepositoryError.corruptedData }
    return week
  }

  private func goalIsActive(_ goal: PlannedGoalRecord, on day: LocalDay) throws -> Bool {
    try goalSnapshot(goal).wasHistoricallyActive(on: day)
  }

  private func requirePlan(_ week: WeekID) throws -> WeeklyPlanRecord {
    let matches = try planRecords().filter { $0.weekKey == week.canonicalKey }
    guard matches.count <= 1 else { throw RepositoryError.duplicatePlan }
    guard let plan = matches.first else { throw RepositoryError.planNotFound }
    return plan
  }

  private func requireGoal(_ id: UUID) throws -> PlannedGoalRecord {
    let matches = try goalRecords().filter { $0.id == id }
    guard matches.count <= 1 else { throw RepositoryError.corruptedData }
    guard let goal = matches.first else {
      throw RepositoryError.goalNotFound
    }
    return goal
  }

  private func requireCategory(_ id: UUID) throws -> IndulgenceCategoryRecord {
    let matches = try categoryRecords().filter { $0.id == id }
    guard matches.count <= 1 else { throw RepositoryError.corruptedData }
    guard let category = matches.first else {
      throw RepositoryError.categoryNotFound
    }
    return category
  }

  private func nextUniqueID(excluding reserved: Set<UUID> = []) throws -> UUID {
    let id = dependencies.uuid.next()
    let plans = try planRecords()
    let goals = try goalRecords()
    let checkoffs = try checkoffRecords()
    let categories = try categoryRecords()
    let occurrences = try occurrenceRecords()
    let occupied =
      reserved.contains(id)
      || plans.contains { $0.id == id }
      || goals.contains { $0.id == id || $0.lineageID == id }
      || checkoffs.contains { $0.id == id }
      || categories.contains { $0.id == id }
      || occurrences.contains { $0.id == id }
    guard !occupied else { throw RepositoryError.identifierCollision }
    return id
  }

  private func seedBuiltInCategories() throws {
    let existingIDs = Set(try categoryRecords().map(\.id))
    let now = dependencies.date.now()
    for category in BuiltInIndulgenceCategories.all where !existingIDs.contains(category.id) {
      modelContext.insert(
        IndulgenceCategoryRecord(
          id: category.id,
          name: category.name,
          normalizedName: category.normalizedName,
          symbolName: category.symbolName,
          sortOrder: category.sortOrder,
          isBuiltIn: true,
          isActive: true,
          createdAt: now,
          updatedAt: now
        ))
    }
  }

  private func planRecords() throws -> [WeeklyPlanRecord] {
    try modelContext.fetch(FetchDescriptor<WeeklyPlanRecord>())
  }
  private func goalRecords() throws -> [PlannedGoalRecord] {
    try modelContext.fetch(FetchDescriptor<PlannedGoalRecord>())
  }
  private func goalRecords(forPlanID id: UUID) throws -> [PlannedGoalRecord] {
    try goalRecords().filter { $0.weeklyPlanID == id }
  }
  private func checkoffRecords() throws -> [GoalCheckoffRecord] {
    try modelContext.fetch(FetchDescriptor<GoalCheckoffRecord>())
  }
  private func categoryRecords() throws -> [IndulgenceCategoryRecord] {
    try modelContext.fetch(FetchDescriptor<IndulgenceCategoryRecord>())
  }
  private func occurrenceRecords() throws -> [IndulgenceOccurrenceRecord] {
    try modelContext.fetch(FetchDescriptor<IndulgenceOccurrenceRecord>())
  }
}
