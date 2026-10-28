import Foundation
import Testing

@testable import Cadence

struct GregorianCalendarServiceTests {
  @Test
  func daylightSavingTransitionsKeepTheirCivilDay() throws {
    let newYork = try #require(TimeZone(identifier: "America/New_York"))
    let service = GregorianCalendarService(timeZone: newYork)

    #expect(
      service.localDay(containing: instant("2026-03-08T06:59:00Z"))
        == LocalDay(year: 2026, month: 3, day: 8))
    #expect(
      service.localDay(containing: instant("2026-03-08T07:01:00Z"))
        == LocalDay(year: 2026, month: 3, day: 8))
    #expect(
      service.localDay(containing: instant("2026-11-01T05:59:00Z"))
        == LocalDay(year: 2026, month: 11, day: 1))
    #expect(
      service.localDay(containing: instant("2026-11-01T06:01:00Z"))
        == LocalDay(year: 2026, month: 11, day: 1))
  }

  @Test
  func oneInstantCanBelongToDifferentLocalDaysWhileRecordedDaysStayStable() throws {
    let instant = instant("2026-01-01T02:00:00Z")
    let newYork = GregorianCalendarService(
      timeZone: try #require(TimeZone(identifier: "America/New_York")))
    let tokyo = GregorianCalendarService(timeZone: try #require(TimeZone(identifier: "Asia/Tokyo")))

    let newYorkDay = newYork.localDay(containing: instant)
    let tokyoDay = tokyo.localDay(containing: instant)

    #expect(newYorkDay == LocalDay(year: 2025, month: 12, day: 31))
    #expect(tokyoDay == LocalDay(year: 2026, month: 1, day: 1))
    #expect(newYorkDay.canonicalKey == "2025-12-31")
  }

  @Test
  func localMidnightMovesFromSundayIntoANewWeek() throws {
    let newYork = GregorianCalendarService(
      timeZone: try #require(TimeZone(identifier: "America/New_York"))
    )
    let finalSundaySecond = instant("2026-10-26T03:59:59Z")
    let firstMondaySecond = instant("2026-10-26T04:00:00Z")

    #expect(
      newYork.localDay(containing: finalSundaySecond)
        == LocalDay(year: 2026, month: 10, day: 25)
    )
    #expect(
      newYork.localDay(containing: firstMondaySecond)
        == LocalDay(year: 2026, month: 10, day: 26)
    )
    #expect(
      newYork.week(containing: finalSundaySecond).monday
        == LocalDay(year: 2026, month: 10, day: 19)
    )
    #expect(
      newYork.week(containing: firstMondaySecond).monday
        == LocalDay(year: 2026, month: 10, day: 26)
    )
  }

  @Test
  func startOfDayUsesTheRecordingTimeZone() throws {
    let losAngeles = try #require(TimeZone(identifier: "America/Los_Angeles"))
    let service = GregorianCalendarService(timeZone: losAngeles)
    let day = try #require(LocalDay(year: 2026, month: 7, day: 4))
    let start = try #require(service.startOfDay(for: day))

    #expect(start == instant("2026-07-04T07:00:00Z"))
  }

  private func instant(_ value: String) -> Date {
    ISO8601DateFormatter().date(from: value)!
  }
}
