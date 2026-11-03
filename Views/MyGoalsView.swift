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
  let frequency: GoalFrequency
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
        frequency: goal.frequency,
        frequencyText: Self.frequencyText(goal.frequency))
    }
  }

  func replacing(with goal: PlannedGoalSnapshot) -> MyGoalsPresentation {
    var updated = rows.filter { $0.id != goal.id }
    updated.append(
      MyGoalsRow(
        id: goal.id, name: goal.name, frequency: goal.frequency,
        frequencyText: Self.frequencyText(goal.frequency)))
    if let oldIndex = rows.firstIndex(where: { $0.id == goal.id }),
      let newIndex = updated.firstIndex(where: { $0.id == goal.id })
    {
      let row = updated.remove(at: newIndex)
      updated.insert(row, at: oldIndex)
    }
    return MyGoalsPresentation(identity: identity, rows: updated)
  }

  private init(identity: MyGoalsIdentity, rows: [MyGoalsRow]) {
    self.identity = identity
    self.rows = rows
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
  enum SaveResult: Equatable {
    case saved
    case duplicate
    case tooLong
    case planningWeekChanged
    case failed
  }
  enum State: Equatable {
    case loading
    case ready(MyGoalsPresentation)
    case failed
  }

  @Published private(set) var state: State = .loading
  @Published private(set) var isSaving = false
  @Published private(set) var guidanceMessage: String?

  private let repository: any PlanningRepository
  private let date: DateProvider
  private let timeZone: CurrentTimeZoneProvider
  private var generation = 0
  private var refreshPending = false
  private let onPlanChanged: @MainActor () -> Void

  init(
    repository: any PlanningRepository,
    date: DateProvider,
    timeZone: CurrentTimeZoneProvider,
    onPlanChanged: @escaping @MainActor () -> Void = {}
  ) {
    self.repository = repository
    self.date = date
    self.timeZone = timeZone
    self.onPlanChanged = onPlanChanged
  }

  func loadInitial() async {
    await load(showLoading: true)
  }

  func retry() async {
    await load(showLoading: true)
  }

  func refreshFromForeground() async {
    if isSaving {
      refreshPending = true
      return
    }
    await load(showLoading: false)
  }

  func refreshFromBoundaryEvent() async {
    if isSaving {
      refreshPending = true
      return
    }
    let identity = currentIdentity()
    if case .ready(let presentation) = state, presentation.identity == identity { return }
    await load(showLoading: false)
  }

  func saveGoal(
    id: UUID?, configuration: GoalConfiguration, presentedIdentity: MyGoalsIdentity
  ) async -> SaveResult {
    guard !isSaving, case .ready(let presentation) = state else { return .failed }
    guard presentation.identity == presentedIdentity, currentIdentity() == presentedIdentity else {
      guidanceMessage = "Your planning week changed. Please review this plan and try again."
      await load(showLoading: false)
      return .planningWeekChanged
    }

    guidanceMessage = nil
    isSaving = true
    generation += 1
    let mutationGeneration = generation
    defer { isSaving = false }
    do {
      let goal =
        if let id {
          try await repository.updateGoal(id: id, configuration: configuration)
        } else {
          try await repository.addGoal(
            to: presentedIdentity.targetWeek, configuration: configuration)
        }
      onPlanChanged()
      guard mutationGeneration == generation, currentIdentity() == presentedIdentity else {
        refreshPending = false
        await load(showLoading: false)
        return .saved
      }
      state = .ready(presentation.replacing(with: goal))
      await drainPendingRefresh()
      return .saved
    } catch RepositoryError.duplicateGoalName {
      await drainPendingRefresh()
      return .duplicate
    } catch RepositoryError.goalNameTooLong {
      await drainPendingRefresh()
      return .tooLong
    } catch RepositoryError.immutablePlan {
      guidanceMessage = "Your planning week changed. Please review this plan and try again."
      await load(showLoading: false)
      return .planningWeekChanged
    } catch {
      await drainPendingRefresh()
      return .failed
    }
  }

  private func drainPendingRefresh() async {
    guard refreshPending else { return }
    refreshPending = false
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
  @State private var editor: GoalEditorRoute?

  private let refreshEvents: LocalCalendarRefreshEvents

  init(
    repository: any PlanningRepository,
    date: DateProvider,
    timeZone: CurrentTimeZoneProvider,
    refreshEvents: LocalCalendarRefreshEvents = .live,
    onPlanChanged: @escaping @MainActor () -> Void = {}
  ) {
    _model = StateObject(
      wrappedValue: MyGoalsModel(
        repository: repository, date: date, timeZone: timeZone,
        onPlanChanged: onPlanChanged))
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
      .toolbar {
        if case .ready(let presentation) = model.state {
          Button("Add Goal", systemImage: "plus") {
            editor = GoalEditorRoute(identity: presentation.identity, row: nil)
          }
        }
      }
      .accessibilityIdentifier("my-goals-screen")
    }
    .sheet(item: $editor) { route in
      GoalEditorView(
        route: route,
        existingRows: readyRows,
        save: { configuration in
          await model.saveGoal(
            id: route.row?.id, configuration: configuration,
            presentedIdentity: route.identity)
        })
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
        if let guidanceMessage = model.guidanceMessage {
          Text(guidanceMessage)
            .font(.callout)
            .foregroundStyle(.secondary)
            .accessibilityIdentifier("my-goals-guidance")
        }
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
              HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                  Text(row.name)
                  Text(row.frequencyText)
                    .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(row.name), \(row.frequencyText)")

                Button("Edit \(row.name)", systemImage: "pencil") {
                  editor = GoalEditorRoute(identity: presentation.identity, row: row)
                }
                .labelStyle(.iconOnly)
                .accessibilityLabel("Edit \(row.name)")
              }
              .padding(.vertical, 12)
              .accessibilityIdentifier("my-goals-row-\(row.id.uuidString)")
              if row.id != presentation.rows.last?.id { Divider() }
            }
          }
        }
      }
      .padding()
    }
  }

  private var readyRows: [MyGoalsRow] {
    guard case .ready(let presentation) = model.state else { return [] }
    return presentation.rows
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

private struct GoalEditorRoute: Identifiable {
  let id = UUID()
  let identity: MyGoalsIdentity
  let row: MyGoalsRow?
}

private struct GoalEditorView: View {
  @Environment(\.dismiss) private var dismiss
  @FocusState private var nameFocused: Bool
  let route: GoalEditorRoute
  let existingRows: [MyGoalsRow]
  let save: (GoalConfiguration) async -> MyGoalsModel.SaveResult

  @State private var name: String
  @State private var kind: GoalFrequency.Kind
  @State private var customTarget: Int
  @State private var isSaving = false
  @State private var message: String?

  init(
    route: GoalEditorRoute, existingRows: [MyGoalsRow],
    save: @escaping (GoalConfiguration) async -> MyGoalsModel.SaveResult
  ) {
    self.route = route
    self.existingRows = existingRows
    self.save = save
    _name = State(initialValue: route.row?.name ?? "")
    _kind = State(initialValue: route.row?.frequency.kind ?? .daily)
    _customTarget = State(
      initialValue: route.row?.frequency.kind == .custom
        ? route.row?.frequency.targetPerWeek ?? 2
        : 2)
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Goal") {
          TextField("Name", text: $name)
            .focused($nameFocused)
            .textInputAutocapitalization(.sentences)
            .accessibilityIdentifier("goal-name-field")
          if trimmedName.count >= 50 {
            Text("\(trimmedName.count) of \(GoalConfiguration.maximumNameLength) characters")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
          if let validationMessage {
            Text(validationMessage)
              .font(.callout)
              .foregroundStyle(.secondary)
          }
        }

        Section("Frequency") {
          Picker("Frequency", selection: $kind) {
            Text("Daily").tag(GoalFrequency.Kind.daily)
            Text("Weekly").tag(GoalFrequency.Kind.weekly)
            Text("Custom").tag(GoalFrequency.Kind.custom)
          }
          .pickerStyle(.inline)
          if kind == .custom {
            Stepper("\(customTarget) days per week", value: $customTarget, in: 2...6)
              .accessibilityIdentifier("goal-custom-target")
          }
        }

        if let message {
          Section { Text(message).foregroundStyle(.secondary) }
        }
      }
      .navigationTitle(route.row == nil ? "Add Goal" : "Edit Goal")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button(route.row == nil ? "Add" : "Save") { Task { await submit() } }
            .disabled(!canSave || isSaving)
        }
      }
      .onAppear { if route.row == nil { nameFocused = true } }
    }
  }

  private var trimmedName: String {
    name.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private var isDuplicate: Bool {
    let normalized = trimmedName.folding(
      options: [.caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
    return existingRows.contains {
      $0.id != route.row?.id
        && $0.name.folding(
          options: [.caseInsensitive], locale: Locale(identifier: "en_US_POSIX")) == normalized
    }
  }

  private var validationMessage: String? {
    if trimmedName.isEmpty { return "Enter a name for this Goal." }
    if trimmedName.count > GoalConfiguration.maximumNameLength {
      return "Keep the name to 60 characters or fewer."
    }
    if isDuplicate { return "That Goal is already in this plan." }
    return nil
  }

  private var canSave: Bool { validationMessage == nil }

  private func submit() async {
    guard canSave else { return }
    let frequency: GoalFrequency
    switch kind {
    case .daily: frequency = .daily
    case .weekly: frequency = .weekly
    case .custom:
      guard let custom = GoalFrequency.custom(daysPerWeek: customTarget) else { return }
      frequency = custom
    }
    isSaving = true
    message = nil
    let result = await save(GoalConfiguration(name: name, frequency: frequency))
    isSaving = false
    switch result {
    case .saved: dismiss()
    case .duplicate: message = "That Goal is already in this plan."
    case .tooLong: message = "Keep the name to 60 characters or fewer."
    case .planningWeekChanged: dismiss()
    case .failed: message = "Couldn’t save this Goal. Please try again."
    }
  }
}
