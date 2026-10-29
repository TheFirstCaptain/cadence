import SwiftUI

@main
struct CadenceApp: App {
  private static var dependencyFactory: @MainActor @Sendable () throws -> AppDependencies {
    if ProcessInfo.processInfo.arguments.contains("--ui-test-startup-failure") {
      return { throw UITestStartupError() }
    }
    return AppDependencies.live
  }

  var body: some Scene {
    WindowGroup {
      AppBootstrapView(makeDependencies: Self.dependencyFactory)
    }
  }
}

private struct UITestStartupError: Error {}
