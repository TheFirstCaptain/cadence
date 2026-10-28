import Foundation

nonisolated struct LocalDay: Codable, Comparable, Hashable, Sendable {
  let year: Int
  let month: Int
  let day: Int

  init?(year: Int, month: Int, day: Int) {
    guard Self.isValid(year: year, month: month, day: day) else {
      return nil
    }

    self.year = year
    self.month = month
    self.day = day
  }

  var canonicalKey: String {
    String(format: "%04d-%02d-%02d", year, month, day)
  }

  static func < (lhs: LocalDay, rhs: LocalDay) -> Bool {
    (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
  }

  private enum CodingKeys: String, CodingKey {
    case year
    case month
    case day
  }

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let year = try container.decode(Int.self, forKey: .year)
    let month = try container.decode(Int.self, forKey: .month)
    let day = try container.decode(Int.self, forKey: .day)
    guard let localDay = LocalDay(year: year, month: month, day: day) else {
      throw DecodingError.dataCorruptedError(
        forKey: .day,
        in: container,
        debugDescription: "LocalDay must contain a valid Gregorian civil date."
      )
    }
    self = localDay
  }

  func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(year, forKey: .year)
    try container.encode(month, forKey: .month)
    try container.encode(day, forKey: .day)
  }

  func addingDays(_ dayCount: Int) -> LocalDay? {
    guard
      let date = Self.referenceCalendar.date(from: dateComponents),
      let result = Self.referenceCalendar.date(byAdding: .day, value: dayCount, to: date)
    else {
      return nil
    }

    let components = Self.referenceCalendar.dateComponents([.year, .month, .day], from: result)
    guard let year = components.year, let month = components.month, let day = components.day else {
      return nil
    }
    return LocalDay(year: year, month: month, day: day)
  }

  var weekday: Int? {
    guard let date = Self.referenceCalendar.date(from: dateComponents) else {
      return nil
    }
    return Self.referenceCalendar.component(.weekday, from: date)
  }

  private var dateComponents: DateComponents {
    DateComponents(
      calendar: Self.referenceCalendar,
      timeZone: Self.referenceCalendar.timeZone,
      year: year,
      month: month,
      day: day,
      hour: 12
    )
  }

  private static func isValid(year: Int, month: Int, day: Int) -> Bool {
    guard year > 0,
      let date = referenceCalendar.date(from: DateComponents(year: year, month: month, day: day))
    else {
      return false
    }
    let components = referenceCalendar.dateComponents([.year, .month, .day], from: date)
    return components.year == year && components.month == month && components.day == day
  }

  private static var referenceCalendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.locale = Locale(identifier: "en_US_POSIX")
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar
  }
}
