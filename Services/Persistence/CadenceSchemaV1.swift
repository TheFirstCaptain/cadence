import Foundation
import SwiftData

enum CadenceSchemaV1: VersionedSchema {
  static let versionIdentifier = Schema.Version(1, 0, 0)

  static let models: [any PersistentModel.Type] = [
    WeeklyPlanRecord.self,
    PlannedGoalRecord.self,
    GoalCheckoffRecord.self,
    IndulgenceCategoryRecord.self,
    IndulgenceOccurrenceRecord.self,
  ]
}

@Model
final class WeeklyPlanRecord {
  var id: UUID = UUID()
  var mondayYear: Int = 0
  var mondayMonth: Int = 0
  var mondayDay: Int = 0
  var weekKey: String = ""
  var calendarIdentifier: String = "gregorian"
  var planningTimeZoneIdentifier: String = "UTC"
  var planningUTCOffsetSeconds: Int = 0
  var createdAt: Date = Date.distantPast
  var updatedAt: Date = Date.distantPast

  @Relationship(deleteRule: .nullify, inverse: \PlannedGoalRecord.weeklyPlan)
  var plannedGoals: [PlannedGoalRecord]?

  init(
    id: UUID,
    monday: LocalDay,
    planningTimeZoneIdentifier: String,
    planningUTCOffsetSeconds: Int,
    createdAt: Date,
    updatedAt: Date
  ) {
    self.id = id
    mondayYear = monday.year
    mondayMonth = monday.month
    mondayDay = monday.day
    weekKey = monday.canonicalKey
    self.planningTimeZoneIdentifier = planningTimeZoneIdentifier
    self.planningUTCOffsetSeconds = planningUTCOffsetSeconds
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }
}

@Model
final class PlannedGoalRecord {
  var id: UUID = UUID()
  var weeklyPlanID: UUID = UUID()
  var lineageID: UUID = UUID()
  var name: String = ""
  var normalizedName: String = ""
  var frequencyKindRaw: String = GoalFrequency.Kind.daily.rawValue
  var customTarget: Int?
  var sortOrder: Int = 0
  var activeFromYear: Int = 0
  var activeFromMonth: Int = 0
  var activeFromDay: Int = 0
  var activeFromKey: String = ""
  var activeThroughYear: Int?
  var activeThroughMonth: Int?
  var activeThroughDay: Int?
  var activeThroughKey: String?
  var createdAt: Date = Date.distantPast
  var updatedAt: Date = Date.distantPast
  var weeklyPlan: WeeklyPlanRecord?

  @Relationship(deleteRule: .nullify, inverse: \GoalCheckoffRecord.plannedGoal)
  var checkoffs: [GoalCheckoffRecord]?

  init(
    id: UUID,
    weeklyPlanID: UUID,
    lineageID: UUID,
    name: String,
    normalizedName: String,
    frequencyKindRaw: String,
    customTarget: Int?,
    sortOrder: Int,
    activeFrom: LocalDay,
    activeThrough: LocalDay? = nil,
    createdAt: Date,
    updatedAt: Date,
    weeklyPlan: WeeklyPlanRecord? = nil
  ) {
    self.id = id
    self.weeklyPlanID = weeklyPlanID
    self.lineageID = lineageID
    self.name = name
    self.normalizedName = normalizedName
    self.frequencyKindRaw = frequencyKindRaw
    self.customTarget = customTarget
    self.sortOrder = sortOrder
    activeFromYear = activeFrom.year
    activeFromMonth = activeFrom.month
    activeFromDay = activeFrom.day
    activeFromKey = activeFrom.canonicalKey
    activeThroughYear = activeThrough?.year
    activeThroughMonth = activeThrough?.month
    activeThroughDay = activeThrough?.day
    activeThroughKey = activeThrough?.canonicalKey
    self.createdAt = createdAt
    self.updatedAt = updatedAt
    self.weeklyPlan = weeklyPlan
  }
}

@Model
final class GoalCheckoffRecord {
  var id: UUID = UUID()
  var plannedGoalID: UUID = UUID()
  var instant: Date = Date.distantPast
  var localYear: Int = 0
  var localMonth: Int = 0
  var localDay: Int = 0
  var localDayKey: String = ""
  var timeZoneIdentifier: String = "UTC"
  var utcOffsetSeconds: Int = 0
  var createdAt: Date = Date.distantPast
  var updatedAt: Date = Date.distantPast
  var plannedGoal: PlannedGoalRecord?

  init(
    id: UUID,
    plannedGoalID: UUID,
    instant: Date,
    localDay: LocalDay,
    timeZoneIdentifier: String,
    utcOffsetSeconds: Int,
    createdAt: Date,
    updatedAt: Date,
    plannedGoal: PlannedGoalRecord? = nil
  ) {
    self.id = id
    self.plannedGoalID = plannedGoalID
    self.instant = instant
    localYear = localDay.year
    localMonth = localDay.month
    self.localDay = localDay.day
    localDayKey = localDay.canonicalKey
    self.timeZoneIdentifier = timeZoneIdentifier
    self.utcOffsetSeconds = utcOffsetSeconds
    self.createdAt = createdAt
    self.updatedAt = updatedAt
    self.plannedGoal = plannedGoal
  }
}

@Model
final class IndulgenceCategoryRecord {
  var id: UUID = UUID()
  var name: String = ""
  var normalizedName: String = ""
  var symbolName: String = "circle"
  var sortOrder: Int = 0
  var isBuiltIn: Bool = false
  var isActive: Bool = true
  var createdAt: Date = Date.distantPast
  var updatedAt: Date = Date.distantPast

  @Relationship(deleteRule: .nullify, inverse: \IndulgenceOccurrenceRecord.category)
  var occurrences: [IndulgenceOccurrenceRecord]?

  init(
    id: UUID,
    name: String,
    normalizedName: String,
    symbolName: String,
    sortOrder: Int,
    isBuiltIn: Bool,
    isActive: Bool,
    createdAt: Date,
    updatedAt: Date
  ) {
    self.id = id
    self.name = name
    self.normalizedName = normalizedName
    self.symbolName = symbolName
    self.sortOrder = sortOrder
    self.isBuiltIn = isBuiltIn
    self.isActive = isActive
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }
}

@Model
final class IndulgenceOccurrenceRecord {
  var id: UUID = UUID()
  var categoryID: UUID = UUID()
  var instant: Date = Date.distantPast
  var localYear: Int = 0
  var localMonth: Int = 0
  var localDay: Int = 0
  var localDayKey: String = ""
  var timeZoneIdentifier: String = "UTC"
  var utcOffsetSeconds: Int = 0
  var createdAt: Date = Date.distantPast
  var updatedAt: Date = Date.distantPast
  var category: IndulgenceCategoryRecord?

  init(
    id: UUID,
    categoryID: UUID,
    instant: Date,
    localDay: LocalDay,
    timeZoneIdentifier: String,
    utcOffsetSeconds: Int,
    createdAt: Date,
    updatedAt: Date,
    category: IndulgenceCategoryRecord? = nil
  ) {
    self.id = id
    self.categoryID = categoryID
    self.instant = instant
    localYear = localDay.year
    localMonth = localDay.month
    self.localDay = localDay.day
    localDayKey = localDay.canonicalKey
    self.timeZoneIdentifier = timeZoneIdentifier
    self.utcOffsetSeconds = utcOffsetSeconds
    self.createdAt = createdAt
    self.updatedAt = updatedAt
    self.category = category
  }
}
