import SwiftUI

struct ContentView: View {
  @State private var selection = PrimaryTab.myDay

  var body: some View {
    TabView(selection: $selection) {
      Tab("My Day", systemImage: "sun.max", value: PrimaryTab.myDay) {
        PlaceholderView(
          title: "My Day",
          message: "Your daily rhythm will appear here.",
          accessibilityIdentifier: "my-day-screen"
        )
      }

      Tab("My Goals", systemImage: "target", value: PrimaryTab.myGoals) {
        PlaceholderView(
          title: "My Goals",
          message: "Your weekly intentions will live here.",
          accessibilityIdentifier: "my-goals-screen"
        )
      }

      Tab("History", systemImage: "clock.arrow.circlepath", value: PrimaryTab.history) {
        PlaceholderView(
          title: "History",
          message: "Your rhythm over time will appear here.",
          accessibilityIdentifier: "history-screen"
        )
      }
    }
  }
}

private enum PrimaryTab: Hashable {
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

#Preview {
  ContentView()
}
