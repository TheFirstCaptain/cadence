import SwiftUI

struct ContentView: View {
  @State private var selection = PrimaryTab.myDay
  @State private var planningRevision = 0
  @State private var historyRevision = 0
  let dependencies: AppDependencies

  var body: some View {
    TabView(selection: $selection) {
      Tab(value: PrimaryTab.myDay) {
        MyDayView(
          repository: dependencies.dailyTracking,
          date: dependencies.date,
          timeZone: dependencies.timeZone,
          planningRevision: planningRevision,
          onOpenGoals: { selection = .myGoals }
        )
      } label: {
        Label("My Day", systemImage: "sun.max")
      }

      Tab(value: PrimaryTab.myGoals) {
        MyGoalsView(
          repository: dependencies.planning,
          date: dependencies.date,
          timeZone: dependencies.timeZone,
          onPlanChanged: { planningRevision += 1 }
        )
      } label: {
        Label("My Goals", systemImage: "target")
      }

      Tab(value: PrimaryTab.history) {
        HistoryView(
          repository: dependencies.history,
          date: dependencies.date,
          timeZone: dependencies.timeZone,
          planningRevision: planningRevision,
          historyRevision: historyRevision
        )
      } label: {
        Label("History", systemImage: "clock.arrow.circlepath")
      }
    }
    .accessibilityIdentifier("app-ready")
  }
}

enum PrimaryTab: Hashable {
  case myDay
  case myGoals
  case history
}
