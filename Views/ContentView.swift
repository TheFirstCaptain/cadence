import SwiftUI

struct ContentView: View {
  @State private var selection = PrimaryTab.myDay
  let dependencies: AppDependencies

  var body: some View {
    TabView(selection: $selection) {
      Tab(value: PrimaryTab.myDay) {
        MyDayView(
          repository: dependencies.dailyTracking,
          date: dependencies.date,
          timeZone: dependencies.timeZone,
          onOpenGoals: { selection = .myGoals }
        )
      } label: {
        Label("My Day", systemImage: "sun.max")
      }

      Tab(value: PrimaryTab.myGoals) {
        PlaceholderView(
          title: "My Goals",
          message: "Your weekly intentions will live here.",
          accessibilityIdentifier: "my-goals-screen"
        )
      } label: {
        Label("My Goals", systemImage: "target")
      }

      Tab(value: PrimaryTab.history) {
        PlaceholderView(
          title: "History",
          message: "Your rhythm over time will appear here.",
          accessibilityIdentifier: "history-screen"
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

private struct PlaceholderView: View {
  let title: String
  let message: String
  let accessibilityIdentifier: String

  var body: some View {
    VStack(spacing: 12) {
      Text(title)
        .font(.largeTitle.bold())
        .accessibilityIdentifier(accessibilityIdentifier)

      Text(message)
        .font(.body)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}
