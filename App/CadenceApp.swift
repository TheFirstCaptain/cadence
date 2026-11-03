import SwiftUI

@main
struct CadenceApp: App {
  private static var dependencyFactory: @MainActor @Sendable () throws -> AppDependencies {
    let arguments = ProcessInfo.processInfo.arguments
    if arguments.contains("--ui-test-startup-failure") {
      return { throw UITestStartupError() }
    }
    if arguments.contains("--ui-test-my-day-populated") {
      return { try AppDependencies.uiTest(.populated) }
    }
    if arguments.contains("--ui-test-my-day-read-failure") {
      return { try AppDependencies.uiTest(.readFailure) }
    }
    if arguments.contains("--ui-test-my-day-mutation-failure") {
      return { try AppDependencies.uiTest(.mutationFailure) }
    }
    if arguments.contains("--ui-test-my-day-empty") {
      return { try AppDependencies.uiTest(.empty) }
    }
    if arguments.contains("--ui-test-my-goals-read-failure") {
      return { try AppDependencies.uiTest(.myGoalsReadFailure) }
    }
    if arguments.contains("--ui-test-my-goals-mutation-failure") {
      return { try AppDependencies.uiTest(.myGoalsMutationFailure) }
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
