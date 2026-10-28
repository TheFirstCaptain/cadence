import Foundation
import Testing

@testable import Cadence

struct DomainFoundationTests {
  @Test
  func localDayValidatesAndFormatsGregorianDates() {
    #expect(LocalDay(year: 2024, month: 2, day: 29)?.canonicalKey == "2024-02-29")
    #expect(LocalDay(year: 2023, month: 2, day: 29) == nil)
    #expect(LocalDay(year: 2026, month: 13, day: 1) == nil)
  }

  @Test
  func decodingCannotBypassDateAndWeekValidation() {
    let invalidDay = Data(#"{"year":2023,"month":2,"day":29}"#.utf8)
    let sundayWeek = Data(#"{"monday":{"year":2026,"month":10,"day":25}}"#.utf8)

    #expect(throws: DecodingError.self) {
      try JSONDecoder().decode(LocalDay.self, from: invalidDay)
    }
    #expect(throws: DecodingError.self) {
      try JSONDecoder().decode(WeekID.self, from: sundayWeek)
    }
  }

  @Test
  func weekUsesMondayThroughSundayAcrossYearBoundary() throws {
    let thursday = try #require(LocalDay(year: 2026, month: 12, day: 31))
    let friday = try #require(LocalDay(year: 2027, month: 1, day: 1))
    let monday = try #require(LocalDay(year: 2026, month: 12, day: 28))
    let sunday = try #require(LocalDay(year: 2027, month: 1, day: 3))

    #expect(WeekID(containing: thursday)?.monday == monday)
    #expect(WeekID(containing: friday)?.monday == monday)
    #expect(WeekID(containing: thursday)?.sunday == sunday)
  }

  @Test
  func sundayAndMondayBelongToDifferentWeeks() throws {
    let sunday = try #require(LocalDay(year: 2026, month: 10, day: 25))
    let monday = try #require(LocalDay(year: 2026, month: 10, day: 26))

    #expect(WeekID(containing: sunday)?.monday == LocalDay(year: 2026, month: 10, day: 19))
    #expect(WeekID(containing: monday)?.monday == monday)
  }

  @Test
  func goalFrequencyAllowsOnlyApprovedTargets() throws {
    #expect(GoalFrequency.daily.targetPerWeek == 7)
    #expect(GoalFrequency.weekly.targetPerWeek == 1)
    #expect(GoalFrequency.custom(daysPerWeek: 2)?.targetPerWeek == 2)
    #expect(GoalFrequency.custom(daysPerWeek: 6)?.targetPerWeek == 6)
    #expect(GoalFrequency.custom(daysPerWeek: 1) == nil)
    #expect(GoalFrequency.custom(daysPerWeek: 7) == nil)

    let invalid = Data(#"{"kind":"custom","targetPerWeek":1}"#.utf8)
    #expect(throws: DecodingError.self) {
      try JSONDecoder().decode(GoalFrequency.self, from: invalid)
    }
  }

  @Test
  func injectedSystemValuesAreDeterministic() throws {
    let date = Date(timeIntervalSince1970: 1_800_000_000)
    let timeZone = try #require(TimeZone(identifier: "Pacific/Auckland"))
    let identifier = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000123"))

    #expect(DateProvider { date }.now() == date)
    #expect(CurrentTimeZoneProvider { timeZone }.current() == timeZone)
    #expect(UUIDProvider { identifier }.next() == identifier)
  }
}
