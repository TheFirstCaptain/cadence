import Combine
import SwiftUI

nonisolated enum MyGoalsPlanningPhase: Hashable, Sendable {
  case thisWeek
  case nextWeek

  var title: String {
    switch self {
    case .thisWeek: "This week"
    case .nextWeek: "Planning next week"
    }
  }
}

nonisolated struct MyGoalsIdentity: Hashable, Sendable {
  let referenceDay: LocalDay
  let targetWeek: WeekID
  let phase: MyGoalsPlanningPhase

  init(instant: Date, timeZone: TimeZone) {
    let calendar = GregorianCalendarService(timeZone: timeZone)
    let day = calendar.localDay(containing: instant)
    let currentWeek = calendar.week(containing: instant)
    referenceDay = day
    if day.weekday == 1, let nextMonday = currentWeek.monday.addingDays(7),
      let nextWeek = WeekID(monday: nextMonday)
    {
      targetWeek = nextWeek
      phase = .nextWeek
    } else {
      targetWeek = currentWeek
      phase = .thisWeek
    }
  }
}

nonisolated struct MyGoalsRow: Hashable, Sendable, Identifiable {
  let id: UUID
  let name: String
  let frequencyText: String
}

nonisolated struct MyGoalsPresentation: Hashable, Sendable {
  let identity: MyGoalsIdentity
  let rows: [MyGoalsRow]

  init(identity: MyGoalsIdentity, plan: WeeklyPlanSnapshot) {
    self.identity = identity
    rows = plan.goals.filter(\.isCurrentlyOffered).map { goal in
      MyGoalsRow(
        id: goal.id,
        name: goal.name,
        frequencyText: Self.frequencyText(goal.frequency))
    }
  }

  private static func frequencyText(_ frequency: GoalFrequency) -> String {
    switch frequency.kind {
    case .daily: "Daily"
    case .weekly: "Weekly"
    case .custom: "\(frequency.targetPerWeek) days per week"
    }
  }
}

@MainActor
final class MyGoalsModel: ObservableObject {
  enum State: Equatable {
    case loading
    case ready(MyGoalsPresentation)
    case failed
  }

  @Published private(set) var state: State = .loading

  private let repository: any PlanningRepository
  private let date: DateProvider
  private let timeZone: CurrentTimeZoneProvider
  private var generation = 0

  init(
    repository: any PlanningRepository,
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
    if case .ready(let presentation) = state, presentation.identity == identity { return }
    await load(showLoading: false)
  }

  private func load(showLoading: Bool) async {
    generation += 1
    let requestGeneration = generation
    if showLoading { state = .loading }
    let identity = currentIdentity()
    do {
      let plan = try await repository.resolvePlan(for: identity.targetWeek)
      guard requestGeneration == generation else { return }
      state = .ready(MyGoalsPresentation(identity: identity, plan: plan))
    } catch {
      guard requestGeneration == generation else { return }
      state = .failed
    }
  }

  private func currentIdentity() -> MyGoalsIdentity {
    MyGoalsIdentity(instant: date.now(), timeZone: timeZone.current())
  }
}

struct MyGoalsView: View {
  @Environment(\.scenePhase) private var scenePhase
  @StateObject private var model: MyGoalsModel

  private let refreshEvents: LocalCalendarRefreshEvents

  init(
    repository: any PlanningRepository,
    date: DateProvider,
    timeZone: CurrentTimeZoneProvider,
    refreshEvents: LocalCalendarRefreshEvents = .live
  ) {
    _model = StateObject(
      wrappedValue: MyGoalsModel(repository: repository, date: date, timeZone: timeZone))
    self.refreshEvents = refreshEvents
  }

  var body: some View {
    NavigationStack {
      Group {
        switch model.state {
        case .loading:
          ProgressView("Loading My Goals")
        case .failed:
          ContentUnavailableView {
            Label("Your plan couldn’t be refreshed", systemImage: "arrow.clockwise.circle")
          } description: {
            Text("Please try again when you’re ready.")
          } actions: {
            Button("Try Again") { Task { await model.retry() } }
          }
          .accessibilityIdentifier("my-goals-failed")
        case .ready(let presentation):
          readyContent(presentation)
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .navigationTitle("My Goals")
      .accessibilityIdentifier("my-goals-screen")
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
  private func readyContent(_ presentation: MyGoalsPresentation) -> some View {
    let range = weekRangeText(presentation.identity.targetWeek)
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        VStack(alignment: .leading, spacing: 4) {
          Text(presentation.identity.phase.title)
            .font(.title2.bold())
          Text(range)
            .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(presentation.identity.phase.title), \(range)")
        .accessibilityIdentifier("my-goals-week-context")

        if presentation.rows.isEmpty {
          ContentUnavailableView {
            Label(emptyTitle(for: presentation.identity.phase), systemImage: "target")
          } description: {
            Text(emptyDescription(for: presentation.identity.phase))
          }
          .accessibilityIdentifier("my-goals-empty")
        } else {
          VStack(spacing: 0) {
            ForEach(presentation.rows) { row in
              ViewThatFits(in: .horizontal) {
                HStack {
                  Text(row.name)
                    .frame(maxWidth: .infinity, alignment: .leading)
                  Text(row.frequencyText)
                    .foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 4) {
                  Text(row.name)
                  Text(row.frequencyText)
                    .foregroundStyle(.secondary)
                }
              }
              .padding(.vertical, 12)
              .accessibilityElement(children: .combine)
              .accessibilityLabel("\(row.name), \(row.frequencyText)")
              .accessibilityIdentifier("my-goals-row-\(row.id.uuidString)")
              if row.id != presentation.rows.last?.id { Divider() }
            }
          }
          .accessibilityIdentifier("my-goals-list")
        }
      }
      .padding()
    }
  }

  private func weekRangeText(_ week: WeekID) -> String {
    guard let sunday = week.sunday else { return week.monday.canonicalKey }
    return "\(formatted(week.monday)) through \(formatted(sunday))"
  }

  private func emptyTitle(for phase: MyGoalsPlanningPhase) -> String {
    phase == .thisWeek
      ? "No Goals planned for this week yet"
      : "No Goals planned for next week yet"
  }

  private func emptyDescription(for phase: MyGoalsPlanningPhase) -> String {
    phase == .thisWeek
      ? "You can shape this week when you’re ready."
      : "You can shape next week when you’re ready."
  }

  private func formatted(_ day: LocalDay) -> String {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let date = calendar.date(from: DateComponents(year: day.year, month: day.month, day: day.day))!
    return date.formatted(.dateTime.month(.wide).day().year())
  }
}
