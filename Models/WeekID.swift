import Foundation

nonisolated struct WeekID: Codable, Comparable, Hashable, Sendable {
  let monday: LocalDay

  init?(monday: LocalDay) {
    guard monday.weekday == 2 else {
      return nil
    }
    self.monday = monday
  }

  init?(containing day: LocalDay) {
    guard let weekday = day.weekday else {
      return nil
    }
    let daysSinceMonday = (weekday + 5) % 7
    guard let monday = day.addingDays(-daysSinceMonday) else {
      return nil
    }
    self.monday = monday
  }

  var sunday: LocalDay? {
    monday.addingDays(6)
  }

  var canonicalKey: String {
    monday.canonicalKey
  }

  static func < (lhs: WeekID, rhs: WeekID) -> Bool {
    lhs.monday < rhs.monday
  }

  private enum CodingKeys: String, CodingKey {
    case monday
  }

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let monday = try container.decode(LocalDay.self, forKey: .monday)
    guard let week = WeekID(monday: monday) else {
      throw DecodingError.dataCorruptedError(
        forKey: .monday,
        in: container,
        debugDescription: "WeekID must begin on a Monday."
      )
    }
    self = week
  }

  func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(monday, forKey: .monday)
  }
}
