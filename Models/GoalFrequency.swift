import Foundation

nonisolated struct GoalFrequency: Codable, Hashable, Sendable {
  enum Kind: String, Codable, Sendable {
    case daily
    case weekly
    case custom
  }

  let kind: Kind
  let targetPerWeek: Int

  static let daily = GoalFrequency(kind: .daily, targetPerWeek: 7)
  static let weekly = GoalFrequency(kind: .weekly, targetPerWeek: 1)

  static func custom(daysPerWeek: Int) -> GoalFrequency? {
    guard (2...6).contains(daysPerWeek) else {
      return nil
    }
    return GoalFrequency(kind: .custom, targetPerWeek: daysPerWeek)
  }

  private init(kind: Kind, targetPerWeek: Int) {
    self.kind = kind
    self.targetPerWeek = targetPerWeek
  }

  private enum CodingKeys: String, CodingKey {
    case kind
    case targetPerWeek
  }

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let kind = try container.decode(Kind.self, forKey: .kind)
    let target = try container.decode(Int.self, forKey: .targetPerWeek)

    switch kind {
    case .daily where target == 7:
      self = .daily
    case .weekly where target == 1:
      self = .weekly
    case .custom:
      guard let frequency = Self.custom(daysPerWeek: target) else {
        throw DecodingError.dataCorruptedError(
          forKey: .targetPerWeek,
          in: container,
          debugDescription: "Custom Goal frequency must be between 2 and 6 days per week."
        )
      }
      self = frequency
    default:
      throw DecodingError.dataCorruptedError(
        forKey: .targetPerWeek,
        in: container,
        debugDescription: "Goal frequency target does not match its kind."
      )
    }
  }

  func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(kind, forKey: .kind)
    try container.encode(targetPerWeek, forKey: .targetPerWeek)
  }
}
