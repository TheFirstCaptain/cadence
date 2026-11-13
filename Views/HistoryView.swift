import Combine
import SwiftUI

nonisolated enum WeekHistoryGoalDayState: Hashable, Sendable {
  case inactive
  case noCheckoff(isFuture: Bool)
  case complete
}

nonisolated struct WeekHistoryDay: Hashable, Sendable, Identifiable {
  let day: LocalDay
  let isToday: Bool

  var id: LocalDay { day }
}

nonisolated struct WeekHistoryGoalRow: Hashable, Sendable, Identifiable {
  let id: UUID
  let name: String
  let completed: Int
  let target: Int
  let days: [WeekHistoryGoalDayState]

  var accessibilityLabel: String {
    let details = zip(WeekHistoryPresentation.fullWeekdayNames, days).map { weekday, state in
      switch state {
      case .inactive: "\(weekday) inactive"
      case .noCheckoff(let isFuture): "\(weekday) \(isFuture ? "not yet" : "no checkoff")"
      case .complete: "\(weekday) complete"
      }
    }.joined(separator: "; ")
    return "\(name), \(completed) of \(target). \(details)"
  }
}

nonisolated struct WeekHistoryIndulgenceRow: Hashable, Sendable, Identifiable {
  let id: UUID
  let name: String
  let symbolName: String
  let isArchived: Bool
  let total: Int
  let dailyCounts: [Int]

  var accessibilityLabel: String {
    let archive = isArchived ? ", archived" : ""
    let details = zip(WeekHistoryPresentation.fullWeekdayNames, dailyCounts).map {
      "\($0), \(Self.occurrenceCount($1))"
    }.joined(separator: "; ")
    return "\(name)\(archive), \(Self.occurrenceCount(total)) this week. \(details)"
  }

  private static func occurrenceCount(_ count: Int) -> String {
    "\(count) \(count == 1 ? "occurrence" : "occurrences")"
  }
}

nonisolated struct WeekHistoryPresentation: Hashable, Sendable {
  static let shortWeekdayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
  static let fullWeekdayNames = [
    "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday",
  ]

  let week: WeekID
  let currentWeek: WeekID
  let days: [WeekHistoryDay]
  let goals: [WeekHistoryGoalRow]
  let indulgences: [WeekHistoryIndulgenceRow]

  var isCurrentWeek: Bool { week == currentWeek }

  init(snapshot: WeekActivitySnapshot, week: WeekID, currentDay: LocalDay, currentWeek: WeekID) {
    self.week = week
    self.currentWeek = currentWeek
    let weekDays = (0..<7).compactMap { week.monday.addingDays($0) }
    days = weekDays.map { WeekHistoryDay(day: $0, isToday: $0 == currentDay) }

    let checkoffsByGoal = Dictionary(grouping: snapshot.checkoffs) { $0.plannedGoalID }
    goals = (snapshot.plan?.goals ?? [])
      .sorted {
        ($0.sortOrder, $0.name, $0.id.uuidString) < ($1.sortOrder, $1.name, $1.id.uuidString)
      }
      .compactMap { goal in
        let eligibleDays = weekDays.filter(goal.wasHistoricallyActive)
        guard !eligibleDays.isEmpty else { return nil }
        let eligibleSet = Set(eligibleDays)
        let completedDays = Set(
          checkoffsByGoal[goal.id, default: []]
            .map { $0.localDay }
            .filter { eligibleSet.contains($0) })
        let target: Int =
          switch goal.frequency.kind {
          case .daily: eligibleDays.count
          case .weekly: 1
          case .custom: min(goal.frequency.targetPerWeek, eligibleDays.count)
          }
        let states = weekDays.map { day in
          if !eligibleSet.contains(day) { return WeekHistoryGoalDayState.inactive }
          if completedDays.contains(day) { return WeekHistoryGoalDayState.complete }
          return WeekHistoryGoalDayState.noCheckoff(isFuture: day > currentDay)
        }
        return WeekHistoryGoalRow(
          id: goal.id,
          name: goal.name,
          completed: min(completedDays.count, target),
          target: target,
          days: states)
      }

    let occurrencesByCategory = Dictionary(grouping: snapshot.occurrences) { $0.categoryID }
    indulgences = snapshot.categories.map { category in
      let categoryOccurrences = occurrencesByCategory[category.id, default: []]
      let countsByDay = Dictionary(grouping: categoryOccurrences) { $0.localDay }
        .mapValues { $0.count }
      return WeekHistoryIndulgenceRow(
        id: category.id,
        name: category.name,
        symbolName: category.symbolName,
        isArchived: !category.isActive,
        total: categoryOccurrences.count,
        dailyCounts: weekDays.map { countsByDay[$0, default: 0] })
    }
  }
}

nonisolated struct MonthHistoryIndulgenceRow: Hashable, Sendable, Identifiable {
  let id: UUID
  let name: String
  let symbolName: String
  let isArchived: Bool
  let total: Int

  var accessibilityLabel: String {
    "\(name)\(isArchived ? ", archived" : ""), \(total) \(total == 1 ? "occurrence" : "occurrences") this month"
  }
}

nonisolated struct MonthHistoryWeek: Hashable, Sendable, Identifiable {
  let week: WeekID
  let presentation: WeekHistoryPresentation
  let inMonth: [Bool]

  var id: WeekID { week }
}

nonisolated struct MonthHistoryPresentation: Hashable, Sendable {
  let month: MonthID
  let currentMonth: MonthID
  let weeks: [MonthHistoryWeek]
  let indulgences: [MonthHistoryIndulgenceRow]

  var isCurrentMonth: Bool { month == currentMonth }

  init(snapshot: MonthActivitySnapshot, currentDay: LocalDay) {
    month = snapshot.month
    currentMonth = MonthID(containing: currentDay)
    let currentWeek = WeekID(containing: currentDay)!
    weeks = snapshot.weeks.map { value in
      let presentation = WeekHistoryPresentation(
        snapshot: value.activity, week: value.week, currentDay: currentDay,
        currentWeek: currentWeek)
      return MonthHistoryWeek(
        week: value.week,
        presentation: presentation,
        inMonth: presentation.days.map { snapshot.month.contains($0.day) })
    }
    let occurrencesByCategory = Dictionary(grouping: snapshot.occurrences) { $0.categoryID }
    indulgences = snapshot.categories.map { category in
      MonthHistoryIndulgenceRow(
        id: category.id, name: category.name, symbolName: category.symbolName,
        isArchived: !category.isActive,
        total: occurrencesByCategory[category.id, default: []].count)
    }
  }
}

nonisolated enum HistoryPeriodPresentation: Equatable, Sendable {
  case week(WeekHistoryPresentation)
  case month(MonthHistoryPresentation)
}

nonisolated enum HistoryMode: String, CaseIterable, Sendable {
  case week = "Week"
  case month = "Month"
}

@MainActor
final class HistoryModel: ObservableObject {
  enum State: Equatable {
    case loading
    case ready(HistoryPeriodPresentation)
    case failed
  }

  @Published private(set) var state: State = .loading
  @Published private(set) var mode: HistoryMode = .week

  private let repository: any HistoryRepository
  private let date: DateProvider
  private let timeZone: CurrentTimeZoneProvider
  private var selectedWeek: WeekID?
  private var selectedMonth: MonthID?
  private var referenceDay: LocalDay?
  private var knownCurrentWeek: WeekID?
  private var knownCurrentMonth: MonthID?
  private var generation = 0

  init(
    repository: any HistoryRepository,
    date: DateProvider,
    timeZone: CurrentTimeZoneProvider
  ) {
    self.repository = repository
    self.date = date
    self.timeZone = timeZone
  }

  func loadInitial() async {
    let identity = currentIdentity()
    selectedWeek = identity.week
    selectedMonth = identity.month
    referenceDay = identity.day
    knownCurrentWeek = identity.week
    knownCurrentMonth = identity.month
    await load(week: identity.week, showLoading: true, identity: identity)
  }

  func retry() async {
    let identity = currentIdentity()
    switch mode {
    case .week:
      await load(week: selectedWeek ?? identity.week, showLoading: true, identity: identity)
    case .month:
      await load(month: selectedMonth ?? identity.month, showLoading: true, identity: identity)
    }
  }

  func selectMode(_ newMode: HistoryMode) async {
    guard newMode != mode else { return }
    let identity = currentIdentity()
    mode = newMode
    switch newMode {
    case .month:
      let week = selectedWeek ?? identity.week
      let month = MonthID.majorityMonth(of: week)
      referenceDay = week.monday.addingDays(3)
      selectedMonth = month
      await load(month: month, showLoading: true, identity: identity)
    case .week:
      let day = referenceDay ?? selectedMonth?.firstDay ?? identity.day
      let week = WeekID(containing: day)!
      selectedWeek = week
      await load(week: week, showLoading: true, identity: identity)
    }
  }

  func showPreviousWeek() async {
    guard let selectedWeek, let monday = selectedWeek.monday.addingDays(-7),
      let previous = WeekID(monday: monday)
    else { return }
    self.selectedWeek = previous
    referenceDay = previous.monday.addingDays(3)
    await load(week: previous, showLoading: true)
  }

  func showNextWeek() async {
    let identity = currentIdentity()
    guard let selectedWeek, selectedWeek < identity.week,
      let monday = selectedWeek.monday.addingDays(7), let next = WeekID(monday: monday)
    else { return }
    let target = min(next, identity.week)
    self.selectedWeek = target
    referenceDay = target.monday.addingDays(3)
    await load(week: target, showLoading: true, identity: identity)
  }

  func showToday() async {
    let identity = currentIdentity()
    switch mode {
    case .week:
      guard selectedWeek != identity.week else { return }
      selectedWeek = identity.week
      referenceDay = identity.day
      await load(week: identity.week, showLoading: true, identity: identity)
    case .month:
      guard selectedMonth != identity.month else { return }
      selectedMonth = identity.month
      referenceDay = identity.day
      await load(month: identity.month, showLoading: true, identity: identity)
    }
  }

  func showPreviousMonth() async {
    guard let selectedMonth, let target = selectedMonth.previous else { return }
    self.selectedMonth = target
    referenceDay = target.clamped(day: referenceDay?.day ?? 1)
    await load(month: target, showLoading: true)
  }

  func showNextMonth() async {
    let identity = currentIdentity()
    guard let selectedMonth, selectedMonth < identity.month else { return }
    let target = min(selectedMonth.next, identity.month)
    self.selectedMonth = target
    referenceDay = target.clamped(day: referenceDay?.day ?? 1)
    await load(month: target, showLoading: true, identity: identity)
  }

  func showWeek(_ week: WeekID) async {
    mode = .week
    selectedWeek = week
    referenceDay = week.monday.addingDays(3)
    await load(week: week, showLoading: true)
  }

  func refreshFromForeground() async {
    await refreshFromBoundaryEvent()
  }

  func refreshFromBoundaryEvent() async {
    let identity = currentIdentity()
    let wasFollowingCurrentWeek = selectedWeek == knownCurrentWeek
    let wasFollowingCurrentMonth = selectedMonth == knownCurrentMonth
    knownCurrentWeek = identity.week
    knownCurrentMonth = identity.month
    switch mode {
    case .week:
      let target = wasFollowingCurrentWeek ? identity.week : (selectedWeek ?? identity.week)
      selectedWeek = target
      await load(week: target, showLoading: false, identity: identity)
    case .month:
      let target = wasFollowingCurrentMonth ? identity.month : (selectedMonth ?? identity.month)
      selectedMonth = target
      await load(month: target, showLoading: false, identity: identity)
    }
  }

  func refreshAfterRevision() async {
    await refreshFromForeground()
  }

  private func load(
    week: WeekID,
    showLoading: Bool,
    identity suppliedIdentity: (day: LocalDay, week: WeekID, month: MonthID)? = nil
  ) async {
    generation += 1
    let requestGeneration = generation
    if showLoading { state = .loading }
    let identity = suppliedIdentity ?? currentIdentity()
    knownCurrentWeek = identity.week
    knownCurrentMonth = identity.month
    do {
      let snapshot = try await repository.weekSnapshot(for: week)
      guard requestGeneration == generation else { return }
      state = .ready(
        .week(
          WeekHistoryPresentation(
            snapshot: snapshot,
            week: week,
            currentDay: identity.day,
            currentWeek: identity.week)))
    } catch {
      guard requestGeneration == generation else { return }
      state = .failed
    }
  }

  private func load(
    month: MonthID,
    showLoading: Bool,
    identity suppliedIdentity: (day: LocalDay, week: WeekID, month: MonthID)? = nil
  ) async {
    generation += 1
    let requestGeneration = generation
    if showLoading { state = .loading }
    let identity = suppliedIdentity ?? currentIdentity()
    knownCurrentWeek = identity.week
    knownCurrentMonth = identity.month
    do {
      let snapshot = try await repository.monthSnapshot(for: month)
      guard requestGeneration == generation, mode == .month else { return }
      state = .ready(.month(MonthHistoryPresentation(snapshot: snapshot, currentDay: identity.day)))
    } catch {
      guard requestGeneration == generation else { return }
      state = .failed
    }
  }

  private func currentIdentity() -> (day: LocalDay, week: WeekID, month: MonthID) {
    let instant = date.now()
    let calendar = GregorianCalendarService(timeZone: timeZone.current())
    let day = calendar.localDay(containing: instant)
    return (day, calendar.week(containing: instant), MonthID(containing: day))
  }
}

struct HistoryView: View {
  @Environment(\.scenePhase) private var scenePhase
  @StateObject private var model: HistoryModel

  private let refreshEvents: LocalCalendarRefreshEvents
  private let planningRevision: Int
  private let historyRevision: Int

  init(
    repository: any HistoryRepository,
    date: DateProvider,
    timeZone: CurrentTimeZoneProvider,
    refreshEvents: LocalCalendarRefreshEvents = .live,
    planningRevision: Int = 0,
    historyRevision: Int = 0
  ) {
    _model = StateObject(
      wrappedValue: HistoryModel(repository: repository, date: date, timeZone: timeZone))
    self.refreshEvents = refreshEvents
    self.planningRevision = planningRevision
    self.historyRevision = historyRevision
  }

  var body: some View {
    NavigationStack {
      Group {
        switch model.state {
        case .loading:
          ProgressView("Loading History")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityIdentifier("history-loading")
        case .failed:
          ContentUnavailableView {
            Label("History couldn’t be refreshed", systemImage: "arrow.clockwise.circle")
          } description: {
            Text("Please try again when you’re ready.")
          } actions: {
            Button("Try Again") { Task { await model.retry() } }
          }
          .accessibilityIdentifier("history-failed")
        case .ready(let presentation):
          switch presentation {
          case .week(let week): historyContent(week)
          case .month(let month): monthContent(month)
          }
        }
      }
      .navigationTitle("History")
      .accessibilityIdentifier("history-screen")
    }
    .task {
      await model.loadInitial()
      for await _ in refreshEvents.events() {
        await model.refreshFromBoundaryEvent()
      }
    }
    .onChange(of: scenePhase) { _, phase in
      guard phase == .active else { return }
      Task { await model.refreshFromForeground() }
    }
    .onChange(of: planningRevision) { _, _ in
      Task { await model.refreshAfterRevision() }
    }
    .onChange(of: historyRevision) { _, _ in
      Task { await model.refreshAfterRevision() }
    }
  }

  private func historyContent(_ presentation: WeekHistoryPresentation) -> some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        periodPicker
        weekNavigation(presentation)
        dayHeader(presentation.days)
        goalsSection(presentation)
        indulgenceSection(presentation)
      }
      .padding()
    }
    .accessibilityIdentifier("history-week-ready")
  }

  private var periodPicker: some View {
    Picker(
      "History period",
      selection: Binding(
        get: { model.mode },
        set: { value in Task { await model.selectMode(value) } }
      )
    ) {
      ForEach(HistoryMode.allCases, id: \.self) { mode in
        Text(mode.rawValue).tag(mode)
      }
    }
    .pickerStyle(.segmented)
    .accessibilityIdentifier("history-period-picker")
  }

  private func monthContent(_ presentation: MonthHistoryPresentation) -> some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        periodPicker
        monthNavigation(presentation)
        monthGoalsSection(presentation)
        monthIndulgenceSection(presentation)
      }
      .padding()
    }
    .accessibilityIdentifier("history-month-ready")
  }

  private func monthNavigation(_ presentation: MonthHistoryPresentation) -> some View {
    VStack(spacing: 12) {
      Text(monthName(presentation.month))
        .font(.title2.bold())
        .frame(maxWidth: .infinity)
        .accessibilityAddTraits(.isHeader)
        .accessibilityIdentifier("history-month-range")
      HStack {
        Button("Previous month", systemImage: "chevron.left") {
          Task { await model.showPreviousMonth() }
        }
        .labelStyle(.iconOnly)
        .frame(minWidth: 44, minHeight: 44)
        .accessibilityLabel("Previous month")
        .accessibilityIdentifier("history-previous-month")
        Spacer()
        Button("Today") { Task { await model.showToday() } }
          .disabled(presentation.isCurrentMonth)
          .accessibilityIdentifier("history-today")
        Spacer()
        Button("Next month", systemImage: "chevron.right") {
          Task { await model.showNextMonth() }
        }
        .labelStyle(.iconOnly)
        .frame(minWidth: 44, minHeight: 44)
        .accessibilityLabel("Next month")
        .disabled(presentation.isCurrentMonth)
        .accessibilityIdentifier("history-next-month")
      }
      .buttonStyle(.bordered)
    }
  }

  private func monthGoalsSection(_ presentation: MonthHistoryPresentation) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Goals by week").font(.title2.bold()).accessibilityAddTraits(.isHeader)
      ForEach(presentation.weeks) { week in
        VStack(alignment: .leading, spacing: 10) {
          Button {
            Task { await model.showWeek(week.week) }
          } label: {
            HStack {
              Text(weekRange(week.week)).font(.headline)
              Spacer()
              Image(systemName: "chevron.right").accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .accessibilityHint("Shows week details")
          .accessibilityIdentifier("history-month-week-\(week.week.canonicalKey)")
          monthDayHeader(week, month: presentation.month)
          if week.presentation.goals.isEmpty {
            Text("No Goals were planned for this week.")
              .font(.subheadline).foregroundStyle(.secondary)
          } else {
            ForEach(week.presentation.goals) { row in
              VStack(alignment: .leading, spacing: 6) {
                HStack {
                  Text(row.name).lineLimit(2)
                  Spacer()
                  Text("\(row.completed) of \(row.target)")
                    .monospacedDigit().foregroundStyle(.secondary)
                }
                monthGoalStates(row, week: week)
              }
              .accessibilityElement(children: .ignore)
              .accessibilityLabel(monthGoalLabel(row, week: week, month: presentation.month))
            }
          }
        }
        .padding()
        .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
      }
    }
  }

  private func monthGoalStates(_ row: WeekHistoryGoalRow, week: MonthHistoryWeek) -> some View {
    LazyVGrid(columns: gridColumns, spacing: 6) {
      ForEach(row.days.indices, id: \.self) { index in
        Image(systemName: symbol(for: row.days[index]))
          .foregroundStyle(week.inMonth[index] ? Color.primary : Color.secondary)
          .frame(maxWidth: .infinity, minHeight: 28)
          .overlay {
            if !week.inMonth[index] {
              RoundedRectangle(cornerRadius: 5).stroke(style: StrokeStyle(dash: [3, 2]))
            }
          }
      }
    }
    .dynamicTypeSize(.xSmall ... .xxxLarge)
    .accessibilityHidden(true)
  }

  private func monthDayHeader(_ week: MonthHistoryWeek, month: MonthID) -> some View {
    LazyVGrid(columns: gridColumns, spacing: 6) {
      ForEach(week.presentation.days.indices, id: \.self) { index in
        let day = week.presentation.days[index].day
        VStack(spacing: 2) {
          Text(WeekHistoryPresentation.shortWeekdayNames[index]).font(.caption2)
          Text("\(day.day)").font(.caption.bold())
          if !week.inMonth[index] { Text("Out").font(.caption2.bold()) }
        }
        .foregroundStyle(week.inMonth[index] ? Color.primary : Color.secondary)
        .padding(.vertical, 3)
        .frame(maxWidth: .infinity)
        .overlay {
          if !week.inMonth[index] {
            RoundedRectangle(cornerRadius: 6).stroke(style: StrokeStyle(dash: [3, 2]))
          }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(dayLabel(day, in: month))
      }
    }
    .dynamicTypeSize(.xSmall ... .xxxLarge)
  }

  private func monthIndulgenceSection(_ presentation: MonthHistoryPresentation) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("iIndulged this month").font(.title2.bold()).accessibilityAddTraits(.isHeader)
      ForEach(presentation.indulgences) { row in
        HStack {
          Label(row.name, systemImage: row.symbolName)
          if row.isArchived { Text("Archived").font(.caption).foregroundStyle(.secondary) }
          Spacer()
          Text("\(row.total)").monospacedDigit()
        }
        .padding()
        .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.accessibilityLabel)
        .accessibilityIdentifier("history-month-indulgence-\(row.id.uuidString)")
      }
    }
  }

  private func weekNavigation(_ presentation: WeekHistoryPresentation) -> some View {
    VStack(spacing: 12) {
      Text(weekRange(presentation.week))
        .font(.title2.bold())
        .frame(maxWidth: .infinity)
        .accessibilityAddTraits(.isHeader)
        .accessibilityIdentifier("history-week-range")

      if let today = presentation.days.first(where: { $0.isToday }) {
        Text("Today · \(shortDate(today.day))")
          .font(.caption.bold())
          .padding(.horizontal, 10)
          .padding(.vertical, 5)
          .background(.secondary.opacity(0.12), in: Capsule())
          .accessibilityIdentifier("history-today-marker")
      }

      HStack {
        Button("Previous week", systemImage: "chevron.left") {
          Task { await model.showPreviousWeek() }
        }
        .labelStyle(.iconOnly)
        .frame(minWidth: 44, minHeight: 44)
        .accessibilityLabel("Previous week")
        .accessibilityIdentifier("history-previous-week")

        Spacer()

        Button("Today") { Task { await model.showToday() } }
          .disabled(presentation.isCurrentWeek)
          .accessibilityIdentifier("history-today")

        Spacer()

        Button("Next week", systemImage: "chevron.right") {
          Task { await model.showNextWeek() }
        }
        .labelStyle(.iconOnly)
        .frame(minWidth: 44, minHeight: 44)
        .accessibilityLabel("Next week")
        .disabled(presentation.isCurrentWeek)
        .accessibilityIdentifier("history-next-week")
      }
      .buttonStyle(.bordered)
    }
  }

  private func dayHeader(_ days: [WeekHistoryDay]) -> some View {
    LazyVGrid(columns: gridColumns, spacing: 8) {
      ForEach(days.indices, id: \.self) { index in
        let value = days[index]
        VStack(spacing: 2) {
          Text(WeekHistoryPresentation.shortWeekdayNames[index])
            .font(.caption2)
          Text("\(value.day.day)")
            .font(.caption.bold())
        }
        .frame(maxWidth: .infinity, minHeight: 40)
        .overlay {
          if value.isToday {
            RoundedRectangle(cornerRadius: 8).stroke(lineWidth: 2)
          }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
          "\(WeekHistoryPresentation.fullWeekdayNames[index]), \(fullDate(value.day))\(value.isToday ? ", Today" : "")"
        )
      }
    }
  }

  @ViewBuilder
  private func goalsSection(_ presentation: WeekHistoryPresentation) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Goals")
        .font(.title2.bold())
        .accessibilityAddTraits(.isHeader)

      if presentation.goals.isEmpty {
        Text("No Goals were planned for this week.")
          .foregroundStyle(.secondary)
          .accessibilityIdentifier("history-goals-empty")
      } else {
        ForEach(presentation.goals) { row in
          VStack(alignment: .leading, spacing: 10) {
            ViewThatFits(in: .horizontal) {
              HStack(alignment: .firstTextBaseline) {
                Text(row.name).font(.headline)
                Spacer()
                goalTotal(row)
              }
              VStack(alignment: .leading, spacing: 4) {
                Text(row.name).font(.headline)
                goalTotal(row)
              }
            }
            LazyVGrid(columns: gridColumns, spacing: 8) {
              ForEach(row.days.indices, id: \.self) { index in
                goalDayCell(row.days[index])
              }
            }
          }
          .padding()
          .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
          .accessibilityElement(children: .ignore)
          .accessibilityLabel(row.accessibilityLabel)
          .accessibilityIdentifier("history-goal-\(row.id.uuidString)")
        }
      }
    }
  }

  private func indulgenceSection(_ presentation: WeekHistoryPresentation) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("iIndulged")
        .font(.title2.bold())
        .accessibilityAddTraits(.isHeader)

      ForEach(presentation.indulgences) { row in
        VStack(alignment: .leading, spacing: 10) {
          ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline) {
              indulgenceTitle(row)
              Spacer()
              indulgenceTotal(row)
            }
            VStack(alignment: .leading, spacing: 4) {
              indulgenceTitle(row)
              indulgenceTotal(row)
            }
          }
          LazyVGrid(columns: gridColumns, spacing: 8) {
            ForEach(row.dailyCounts.indices, id: \.self) { index in
              countCell(row.dailyCounts[index])
            }
          }
        }
        .padding()
        .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.accessibilityLabel)
        .accessibilityIdentifier("history-indulgence-\(row.id.uuidString)")
      }
    }
  }

  private var gridColumns: [GridItem] {
    Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
  }

  private func goalDayCell(_ state: WeekHistoryGoalDayState) -> some View {
    let isInactive: Bool
    switch state {
    case .inactive: isInactive = true
    case .noCheckoff, .complete: isInactive = false
    }
    return Image(systemName: symbol(for: state))
      .frame(maxWidth: .infinity, minHeight: 32)
      .foregroundStyle(isInactive ? Color.secondary : Color.primary)
      .accessibilityHidden(true)
  }

  private func countCell(_ count: Int) -> some View {
    Text(String(count))
      .font(.body.monospacedDigit())
      .frame(maxWidth: .infinity, minHeight: 32)
      .accessibilityHidden(true)
  }

  private func goalTotal(_ row: WeekHistoryGoalRow) -> some View {
    Text("\(row.completed) of \(row.target)")
      .font(.subheadline.monospacedDigit())
      .foregroundStyle(.secondary)
  }

  private func indulgenceTitle(_ row: WeekHistoryIndulgenceRow) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 6) {
      Label(row.name, systemImage: row.symbolName).font(.headline)
      if row.isArchived {
        Text("Archived")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
  }

  private func indulgenceTotal(_ row: WeekHistoryIndulgenceRow) -> some View {
    Text("\(row.total) this week")
      .font(.subheadline.monospacedDigit())
      .foregroundStyle(.secondary)
  }

  private func symbol(for state: WeekHistoryGoalDayState) -> String {
    switch state {
    case .inactive: "minus"
    case .noCheckoff: "circle"
    case .complete: "checkmark.circle.fill"
    }
  }

  private func weekRange(_ week: WeekID) -> String {
    guard let sunday = week.sunday else { return week.canonicalKey }
    if week.monday.year == sunday.year {
      return "\(shortDate(week.monday)) – \(shortDate(sunday)), \(sunday.year)"
    }
    return "\(fullDate(week.monday)) – \(fullDate(sunday))"
  }

  private func shortDate(_ day: LocalDay) -> String {
    let date = Calendar(identifier: .gregorian).date(
      from: DateComponents(year: day.year, month: day.month, day: day.day))!
    return date.formatted(.dateTime.month(.abbreviated).day())
  }

  private func fullDate(_ day: LocalDay) -> String {
    let date = Calendar(identifier: .gregorian).date(
      from: DateComponents(year: day.year, month: day.month, day: day.day))!
    return date.formatted(.dateTime.month(.abbreviated).day().year())
  }

  private func monthName(_ month: MonthID) -> String {
    let date = Calendar(identifier: .gregorian).date(
      from: DateComponents(year: month.year, month: month.month, day: 1))!
    return date.formatted(.dateTime.month(.wide).year())
  }

  private func dayLabel(_ day: LocalDay, in month: MonthID) -> String {
    let base = fullDate(day)
    return month.contains(day) ? base : "\(base), outside \(monthName(month))"
  }

  private func monthGoalLabel(
    _ row: WeekHistoryGoalRow, week: MonthHistoryWeek, month: MonthID
  ) -> String {
    let details = zip(week.presentation.days, row.days).map { day, state in
      let status: String =
        switch state {
        case .inactive: "inactive"
        case .noCheckoff(let future): future ? "not yet" : "no checkoff"
        case .complete: "complete"
        }
      return "\(dayLabel(day.day, in: month)), \(status)"
    }.joined(separator: "; ")
    return "\(row.name), \(row.completed) of \(row.target). \(details)"
  }
}
