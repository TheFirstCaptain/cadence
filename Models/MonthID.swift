import Foundation

nonisolated struct MonthID: Codable, Comparable, Hashable, Sendable {
  let year: Int
  let month: Int

  init?(year: Int, month: Int) {
    guard year > 0, (1...12).contains(month) else { return nil }
    self.year = year
    self.month = month
  }

  init(containing day: LocalDay) {
    year = day.year
    month = day.month
  }

  var firstDay: LocalDay { LocalDay(year: year, month: month, day: 1)! }

  var lastDay: LocalDay {
    next.firstDay.addingDays(-1)!
  }

  var previous: MonthID? {
    month == 1 ? MonthID(year: year - 1, month: 12) : MonthID(year: year, month: month - 1)
  }

  var next: MonthID {
    month == 12 ? MonthID(year: year + 1, month: 1)! : MonthID(year: year, month: month + 1)!
  }

  var overlappingWeeks: [WeekID] {
    let first = WeekID(containing: firstDay)!
    let last = WeekID(containing: lastDay)!
    var result: [WeekID] = []
    var week = first
    while week <= last {
      result.append(week)
      guard let monday = week.monday.addingDays(7), let following = WeekID(monday: monday) else {
        break
      }
      week = following
    }
    return result
  }

  func contains(_ day: LocalDay) -> Bool {
    day.year == year && day.month == month
  }

  func clamped(day: Int) -> LocalDay {
    LocalDay(year: year, month: month, day: min(max(day, 1), lastDay.day))!
  }

  static func majorityMonth(of week: WeekID) -> MonthID {
    MonthID(containing: week.monday.addingDays(3)!)
  }

  static func < (lhs: MonthID, rhs: MonthID) -> Bool {
    (lhs.year, lhs.month) < (rhs.year, rhs.month)
  }

  private enum CodingKeys: String, CodingKey {
    case year
    case month
  }

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let year = try container.decode(Int.self, forKey: .year)
    let month = try container.decode(Int.self, forKey: .month)
    guard let value = MonthID(year: year, month: month) else {
      throw DecodingError.dataCorruptedError(
        forKey: .month, in: container,
        debugDescription: "MonthID must contain a valid Gregorian year and month.")
    }
    self = value
  }

  func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(year, forKey: .year)
    try container.encode(month, forKey: .month)
  }
}
