import Combine
import SwiftUI
import UIKit

nonisolated struct MyDayGoalRow: Hashable, Sendable, Identifiable {
  let id: UUID
  let name: String
  let isCompleteToday: Bool
  let completed: Int
  let target: Int

  var canToggle: Bool { isCompleteToday || completed < target }
}

nonisolated struct MyDayIndulgenceRow: Hashable, Sendable, Identifiable {
  let id: UUID
  let name: String
  let symbolName: String
  let count: Int
}

nonisolated struct MyDayPresentation: Hashable, Sendable {
  let day: LocalDay
  let week: WeekID
  let today: [MyDayGoalRow]
  let thisWeek: [MyDayGoalRow]
  let indulgences: [MyDayIndulgenceRow]

  var isEmpty: Bool { today.isEmpty && thisWeek.isEmpty }

  private init(
    day: LocalDay,
    week: WeekID,
    today: [MyDayGoalRow],
    thisWeek: [MyDayGoalRow],
    indulgences: [MyDayIndulgenceRow]
  ) {
    self.day = day
    self.week = week
    self.today = today
    self.thisWeek = thisWeek
    self.indulgences = indulgences
  }

  init(snapshot: MyDaySnapshot) {
    day = snapshot.day
    week = snapshot.week
    let todayIDs = Set(snapshot.todayCheckoffs.map(\.plannedGoalID))
    let completedDays = Dictionary(grouping: snapshot.weekCheckoffs, by: \.plannedGoalID)
      .mapValues { Set($0.map(\.localDay)).count }
    let rows = snapshot.goals.map { goal in
      MyDayGoalRow(
        id: goal.id,
        name: goal.name,
        isCompleteToday: todayIDs.contains(goal.id),
        completed: min(completedDays[goal.id, default: 0], goal.frequency.targetPerWeek),
        target: goal.frequency.targetPerWeek
      )
    }
    today = zip(snapshot.goals, rows).compactMap { goal, row in
      goal.frequency.kind == .daily ? row : nil
    }
    thisWeek = zip(snapshot.goals, rows).compactMap { goal, row in
      goal.frequency.kind == .daily ? nil : row
    }
    let occurrenceCounts = Dictionary(grouping: snapshot.todayOccurrences, by: \.categoryID)
      .mapValues(\.count)
    indulgences = snapshot.categories.map { category in
      MyDayIndulgenceRow(
        id: category.id,
        name: category.name,
        symbolName: category.symbolName,
        count: occurrenceCounts[category.id, default: 0])
    }
  }

  func togglingGoal(id: UUID) -> MyDayPresentation {
    func toggled(_ row: MyDayGoalRow) -> MyDayGoalRow {
      guard row.id == id else { return row }
      let isComplete = !row.isCompleteToday
      return MyDayGoalRow(
        id: row.id,
        name: row.name,
        isCompleteToday: isComplete,
        completed: min(max(row.completed + (isComplete ? 1 : -1), 0), row.target),
        target: row.target
      )
    }
    return MyDayPresentation(
      day: day,
      week: week,
      today: today.map(toggled),
      thisWeek: thisWeek.map(toggled),
      indulgences: indulgences
    )
  }

  func adjustingIndulgence(id: UUID, delta: Int) -> MyDayPresentation {
    MyDayPresentation(
      day: day,
      week: week,
      today: today,
      thisWeek: thisWeek,
      indulgences: indulgences.map { row in
        guard row.id == id else { return row }
        return MyDayIndulgenceRow(
          id: row.id,
          name: row.name,
          symbolName: row.symbolName,
          count: max(0, row.count + delta))
      })
  }
}

@MainActor
final class MyDayModel: ObservableObject {
  enum State: Equatable {
    case loading
    case ready(MyDayPresentation)
    case failed
  }

  @Published private(set) var state: State = .loading
  @Published private(set) var mutatingGoalID: UUID?
  @Published private(set) var mutatingIndulgenceID: UUID?
  @Published private(set) var mutationMessage: String?
  @Published private(set) var indulgenceMutationMessage: String?
  @Published private(set) var successfulMutationCount = 0
  @Published private(set) var accessibilityAnnouncement: String?

  private let repository: any DailyTrackingRepository
  private let date: DateProvider
  private let timeZone: CurrentTimeZoneProvider
  private var generation = 0
  private var refreshPending = false

  init(
    repository: any DailyTrackingRepository,
    date: DateProvider,
    timeZone: CurrentTimeZoneProvider
  ) {
    self.repository = repository
    self.date = date
    self.timeZone = timeZone
  }

  func loadInitial() async {
    await load(showLoading: true)
  }

  func retry() async {
    await load(showLoading: true)
  }

  func refreshFromForeground() async {
    guard !isMutating else {
      refreshPending = true
      return
    }
    await load(showLoading: false)
  }

  func refreshFromBoundaryEvent() async {
    guard !isMutating else {
      refreshPending = true
      return
    }
    let identity = currentIdentity()
    if case .ready(let presentation) = state,
      presentation.day == identity.day,
      presentation.week == identity.week
    {
      return
    }
    await load(showLoading: false)
  }

  func toggle(_ row: MyDayGoalRow) async {
    guard !isMutating, row.canToggle,
      case .ready(let presentation) = state
    else { return }

    let identity = currentIdentity()
    guard presentation.day == identity.day, presentation.week == identity.week else {
      await load(showLoading: false)
      return
    }

    generation += 1
    let mutationGeneration = generation
    let previous = presentation
    mutationMessage = nil
    mutatingGoalID = row.id
    state = .ready(presentation.togglingGoal(id: row.id))
    var mutationFailed = false

    do {
      if row.isCompleteToday {
        _ = try await repository.removeCheckoff(goalID: row.id, on: identity.day)
      } else {
        _ = try await repository.recordCheckoff(goalID: row.id, on: identity.day)
      }
      if mutationGeneration == generation {
        successfulMutationCount += 1
      }
    } catch {
      mutationFailed = true
      if mutationGeneration == generation {
        state = .ready(previous)
        mutationMessage = "Couldn’t update this Goal. Please try again."
      }
    }
    mutatingGoalID = nil
    if refreshPending {
      refreshPending = false
      await load(showLoading: false, clearMutationMessage: !mutationFailed)
    }
  }

  func addIndulgence(_ row: MyDayIndulgenceRow) async {
    await mutateIndulgence(row, delta: 1)
  }

  func removeIndulgence(_ row: MyDayIndulgenceRow) async {
    guard row.count > 0 else { return }
    await mutateIndulgence(row, delta: -1)
  }

  private func mutateIndulgence(_ row: MyDayIndulgenceRow, delta: Int) async {
    guard !isMutating, case .ready(let presentation) = state else { return }
    let identity = currentIdentity()
    guard presentation.day == identity.day, presentation.week == identity.week else {
      await load(showLoading: false)
      return
    }

    generation += 1
    let mutationGeneration = generation
    let previous = presentation
    indulgenceMutationMessage = nil
    accessibilityAnnouncement = nil
    mutatingIndulgenceID = row.id
    state = .ready(presentation.adjustingIndulgence(id: row.id, delta: delta))
    var mutationFailed = false

    do {
      if delta > 0 {
        let occurrence = try await repository.recordIndulgence(categoryID: row.id)
        if occurrence.localDay != identity.day { refreshPending = true }
      } else {
        guard
          try await repository.removeLatestIndulgence(categoryID: row.id, on: identity.day)
            != nil
        else { throw RepositoryError.persistenceFailure }
      }
      if mutationGeneration == generation {
        successfulMutationCount += 1
        if case .ready(let updated) = state,
          let updatedRow = updated.indulgences.first(where: { $0.id == row.id })
        {
          accessibilityAnnouncement = "\(updatedRow.name), \(updatedRow.count) today"
        }
      }
    } catch {
      mutationFailed = true
      if mutationGeneration == generation {
        state = .ready(previous)
        indulgenceMutationMessage = "Couldn’t update this count. Please try again."
      }
    }

    mutatingIndulgenceID = nil
    if refreshPending {
      refreshPending = false
      await load(showLoading: false, clearMutationMessage: !mutationFailed)
    }
  }

  private func load(showLoading: Bool, clearMutationMessage: Bool = true) async {
    generation += 1
    let requestGeneration = generation
    if showLoading { state = .loading }
    let identity = currentIdentity()
    do {
      let snapshot = try await repository.myDaySnapshot(for: identity.day)
      guard requestGeneration == generation else { return }
      if clearMutationMessage { mutationMessage = nil }
      if clearMutationMessage { indulgenceMutationMessage = nil }
      state = .ready(MyDayPresentation(snapshot: snapshot))
    } catch {
      guard requestGeneration == generation else { return }
      state = .failed
    }
  }

  private func currentIdentity() -> (day: LocalDay, week: WeekID) {
    let instant = date.now()
    let zone = timeZone.current()
    let calendar = GregorianCalendarService(timeZone: zone)
    let day = calendar.localDay(containing: instant)
    return (day, calendar.week(containing: instant))
  }

  private var isMutating: Bool {
    mutatingGoalID != nil || mutatingIndulgenceID != nil
  }
}

struct MyDayView: View {
  @Environment(\.scenePhase) private var scenePhase
  @StateObject private var model: MyDayModel

  private let onOpenGoals: () -> Void
  private let refreshEvents: MyDayRefreshEvents

  init(
    repository: any DailyTrackingRepository,
    date: DateProvider,
    timeZone: CurrentTimeZoneProvider,
    refreshEvents: MyDayRefreshEvents = .live,
    onOpenGoals: @escaping () -> Void
  ) {
    _model = StateObject(
      wrappedValue: MyDayModel(repository: repository, date: date, timeZone: timeZone))
    self.refreshEvents = refreshEvents
    self.onOpenGoals = onOpenGoals
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          goalsSection
          indulgencesSection
        }
        .padding()
      }
      .navigationTitle("My Day")
      .accessibilityIdentifier("my-day-screen")
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
    .sensoryFeedback(.selection, trigger: model.successfulMutationCount)
    .onChange(of: model.accessibilityAnnouncement) { _, announcement in
      guard let announcement else { return }
      UIAccessibility.post(notification: .announcement, argument: announcement)
    }
  }

  @ViewBuilder
  private var goalsSection: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Goals")
        .font(.title2.bold())
        .accessibilityAddTraits(.isHeader)

      switch model.state {
      case .loading:
        ProgressView("Loading Goals")
          .frame(maxWidth: .infinity, alignment: .leading)
      case .failed:
        ContentUnavailableView {
          Label("Your day couldn’t be refreshed", systemImage: "arrow.clockwise.circle")
        } description: {
          Text("Please try again when you’re ready.")
        } actions: {
          Button("Try Again") { Task { await model.retry() } }
        }
        .accessibilityIdentifier("my-day-failed")
      case .ready(let presentation) where presentation.isEmpty:
        ContentUnavailableView {
          Label("No Goals planned yet", systemImage: "target")
        } description: {
          Text("Add a Goal when you’re ready.")
        } actions: {
          Button("Go to My Goals", action: onOpenGoals)
        }
        .accessibilityIdentifier("my-day-empty")
      case .ready(let presentation):
        if let mutationMessage = model.mutationMessage {
          Text(mutationMessage)
            .font(.callout)
            .foregroundStyle(.secondary)
            .accessibilityIdentifier("goal-mutation-failed")
        }
        if !presentation.today.isEmpty {
          goalGroup("Today", rows: presentation.today, showsProgress: false)
        }
        if !presentation.thisWeek.isEmpty {
          goalGroup("This Week", rows: presentation.thisWeek, showsProgress: true)
        }
      }
    }
    .accessibilityIdentifier("goals-section")
  }

  @ViewBuilder
  private var indulgencesSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("iIndulged")
        .font(.title2.bold())
        .accessibilityAddTraits(.isHeader)
      if case .ready(let presentation) = model.state {
        if let message = model.indulgenceMutationMessage {
          Text(message)
            .font(.callout)
            .foregroundStyle(.secondary)
        }
        ForEach(presentation.indulgences) { row in
          HStack(spacing: 12) {
            Image(systemName: row.symbolName)
              .frame(width: 24)
              .accessibilityHidden(true)
            Text(row.name)
              .frame(maxWidth: .infinity, alignment: .leading)
            Button {
              Task { await model.removeIndulgence(row) }
            } label: {
              Image(systemName: "minus.circle")
            }
            .accessibilityLabel("Remove \(row.name) occurrence")
            .disabled(
              row.count == 0 || model.mutatingGoalID != nil
                || model.mutatingIndulgenceID != nil)
            Text("\(row.count)")
              .monospacedDigit()
              .frame(minWidth: 28)
              .accessibilityLabel("\(row.count) today")
            Button {
              Task { await model.addIndulgence(row) }
            } label: {
              Image(systemName: "plus.circle")
            }
            .accessibilityLabel("Add \(row.name) occurrence")
            .disabled(model.mutatingGoalID != nil || model.mutatingIndulgenceID != nil)
          }
          .accessibilityIdentifier("indulgence-row-\(row.id.uuidString)")
        }
      } else if case .loading = model.state {
        ProgressView("Loading iIndulged")
      } else {
        Text("Counts are unavailable right now.")
          .foregroundStyle(.secondary)
      }
    }
    .accessibilityIdentifier("iindulged-section")
  }

  private func goalGroup(
    _ title: String,
    rows: [MyDayGoalRow],
    showsProgress: Bool
  ) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title)
        .font(.headline)
        .accessibilityAddTraits(.isHeader)
      ForEach(rows) { row in
        Button {
          Task { await model.toggle(row) }
        } label: {
          HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: row.isCompleteToday ? "checkmark.circle.fill" : "circle")
              .foregroundStyle(.secondary)
              .accessibilityHidden(true)
            Text(row.name)
              .frame(maxWidth: .infinity, alignment: .leading)
            if showsProgress {
              Text("\(row.completed) of \(row.target)")
                .foregroundStyle(.secondary)
                .padding(.leading, 8)
                .fixedSize(horizontal: true, vertical: false)
            }
          }
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(
          model.mutatingGoalID != nil || model.mutatingIndulgenceID != nil || !row.canToggle
        )
        .padding(.vertical, 6)
        .accessibilityLabel(
          showsProgress
            ? "\(row.name), \(row.isCompleteToday ? "Complete today" : "Not complete today"), \(row.completed) of \(row.target)"
            : "\(row.name), \(row.isCompleteToday ? "Complete" : "Not complete")"
        )
        .accessibilityHint(
          row.canToggle
            ? (row.isCompleteToday
              ? "Double tap to mark incomplete" : "Double tap to mark complete")
            : "Weekly target met"
        )
        .accessibilityIdentifier("goal-row-\(row.id.uuidString)")
      }
    }
    .accessibilityIdentifier(title == "Today" ? "today-group" : "this-week-group")
  }
}
