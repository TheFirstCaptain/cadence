import Combine
import SwiftUI

@MainActor
final class AppBootstrapModel: ObservableObject {
  enum Phase {
    case preparing
    case ready(AppDependencies)
    case failed
  }

  @Published private(set) var phase = Phase.preparing

  private let makeDependencies: @MainActor @Sendable () throws -> AppDependencies
  private var hasStarted = false

  init(
    makeDependencies: @escaping @MainActor @Sendable () throws -> AppDependencies =
      AppDependencies.live
  ) {
    self.makeDependencies = makeDependencies
  }

  func start() async {
    guard !hasStarted else { return }
    hasStarted = true
    phase = .preparing

    do {
      let dependencies = try makeDependencies()
      try await dependencies.prepare()
      phase = .ready(dependencies)
    } catch {
      phase = .failed
    }
  }

  func retry() async {
    guard case .failed = phase else { return }
    hasStarted = false
    await start()
  }
}

struct AppBootstrapView: View {
  @StateObject private var model: AppBootstrapModel

  init(
    makeDependencies: @escaping @MainActor @Sendable () throws -> AppDependencies =
      AppDependencies.live
  ) {
    _model = StateObject(
      wrappedValue: AppBootstrapModel(makeDependencies: makeDependencies)
    )
  }

  var body: some View {
    Group {
      switch model.phase {
      case .preparing:
        ProgressView("Preparing Cadence")
          .accessibilityIdentifier("app-preparing")
      case .ready:
        ContentView()
      case .failed:
        StartupFailureView {
          Task { await model.retry() }
        }
      }
    }
    .task { await model.start() }
  }
}

private struct StartupFailureView: View {
  let retry: () -> Void

  var body: some View {
    ContentUnavailableView {
      Label("Cadence couldn’t open", systemImage: "exclamationmark.circle")
    } description: {
      Text("Your data has not been changed. Please try again.")
    } actions: {
      Button("Try Again", action: retry)
        .buttonStyle(.borderedProminent)
    }
    .accessibilityIdentifier("app-startup-failed")
  }
}
