import Combine
import SwiftUI

nonisolated struct MyDayGoalRow: Hashable, Sendable, Identifiable {
  let id: UUID
  let name: String
  let isCompleteToday: Bool
  let completed: Int
  let target: Int
}

nonisolated struct MyDayPresentation: Hashable, Sendable {
  let day: LocalDay
  let week: WeekID
  let today: [MyDayGoalRow]
  let thisWeek: [MyDayGoalRow]

  var isEmpty: Bool { today.isEmpty && thisWeek.isEmpty }

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

  private let repository: any DailyTrackingRepository
  private let date: DateProvider
  private let timeZone: CurrentTimeZoneProvider
  private var generation = 0

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
    await load(showLoading: false)
  }

  func refreshFromBoundaryEvent() async {
    let identity = currentIdentity()
    if case .ready(let presentation) = state,
      presentation.day == identity.day,
      presentation.week == identity.week
    {
      return
    }
    await load(showLoading: false)
  }

  private func load(showLoading: Bool) async {
    generation += 1
    let requestGeneration = generation
    if showLoading { state = .loading }
    let identity = currentIdentity()
    do {
      let snapshot = try await repository.myDaySnapshot(for: identity.day)
      guard requestGeneration == generation else { return }
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
          VStack(alignment: .leading, spacing: 8) {
            Text("iIndulged")
              .font(.title2.bold())
              .accessibilityAddTraits(.isHeader)
            Text("Quick logging will appear here.")
              .foregroundStyle(.secondary)
          }
          .accessibilityIdentifier("iindulged-section")
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
          Label("Your Goals couldn’t be refreshed", systemImage: "arrow.clockwise.circle")
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
        HStack(alignment: .firstTextBaseline, spacing: 12) {
          if !showsProgress {
            Image(systemName: row.isCompleteToday ? "checkmark.circle.fill" : "circle")
              .foregroundStyle(.secondary)
              .accessibilityHidden(true)
          }
          Text(row.name)
            .frame(maxWidth: .infinity, alignment: .leading)
          if showsProgress {
            Text("\(row.completed) of \(row.target)")
              .foregroundStyle(.secondary)
              .padding(.leading, 8)
              .fixedSize(horizontal: true, vertical: false)
          }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
          showsProgress
            ? "\(row.name), \(row.completed) of \(row.target)"
            : "\(row.name), \(row.isCompleteToday ? "Complete" : "Not complete")"
        )
        .accessibilityIdentifier("goal-row-\(row.id.uuidString)")
      }
    }
    .accessibilityIdentifier(title == "Today" ? "today-group" : "this-week-group")
  }
}
