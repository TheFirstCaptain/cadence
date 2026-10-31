import Foundation
import UIKit

nonisolated struct MyDayRefreshEvents: Sendable {
  private let makeStream: @Sendable () -> AsyncStream<Void>

  init(makeStream: @escaping @Sendable () -> AsyncStream<Void>) {
    self.makeStream = makeStream
  }

  func events() -> AsyncStream<Void> {
    makeStream()
  }

  static let live = MyDayRefreshEvents {
    AsyncStream { continuation in
      let boundaryScheduler = LocalDayBoundaryScheduler()
      let task = Task {
        await boundaryScheduler.reschedule(continuation: continuation)
        await withTaskGroup(of: Void.self) { group in
          group.addTask {
            for await _ in NotificationCenter.default.notifications(
              named: UIApplication.significantTimeChangeNotification)
            {
              continuation.yield()
              await boundaryScheduler.reschedule(continuation: continuation)
            }
          }
          group.addTask {
            for await _ in NotificationCenter.default.notifications(
              named: NSNotification.Name.NSSystemTimeZoneDidChange)
            {
              continuation.yield()
              await boundaryScheduler.reschedule(continuation: continuation)
            }
          }
          await group.waitForAll()
        }
      }
      continuation.onTermination = { _ in
        task.cancel()
        Task { await boundaryScheduler.stop() }
      }
    }
  }
}

private actor LocalDayBoundaryScheduler {
  private var task: Task<Void, Never>?

  func reschedule(continuation: AsyncStream<Void>.Continuation) {
    task?.cancel()
    task = Task {
      let now = Date()
      var calendar = Calendar(identifier: .gregorian)
      calendar.timeZone = .current
      guard
        let nextDay = calendar.date(byAdding: .day, value: 1, to: now),
        let nextMidnight = calendar.dateInterval(of: .day, for: nextDay)?.start
      else { return }
      let delay = max(1, nextMidnight.timeIntervalSince(now))
      try? await Task.sleep(for: .seconds(delay))
      guard !Task.isCancelled else { return }
      continuation.yield()
      reschedule(continuation: continuation)
    }
  }

  func stop() {
    task?.cancel()
    task = nil
  }
}
