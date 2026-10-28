import Foundation

nonisolated struct DateProvider: Sendable {
  private let value: @Sendable () -> Date

  init(_ value: @escaping @Sendable () -> Date) {
    self.value = value
  }

  func now() -> Date {
    value()
  }

  static let live = DateProvider(Date.init)
}

nonisolated struct CurrentTimeZoneProvider: Sendable {
  private let value: @Sendable () -> TimeZone

  init(_ value: @escaping @Sendable () -> TimeZone) {
    self.value = value
  }

  func current() -> TimeZone {
    value()
  }

  // Call at an operation boundary, then retain the returned snapshot with any records created.
  static let live = CurrentTimeZoneProvider { .current }
}

nonisolated struct UUIDProvider: Sendable {
  private let value: @Sendable () -> UUID

  init(_ value: @escaping @Sendable () -> UUID) {
    self.value = value
  }

  func next() -> UUID {
    value()
  }

  static let live = UUIDProvider(UUID.init)
}
