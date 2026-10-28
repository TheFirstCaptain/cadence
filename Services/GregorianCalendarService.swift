import Foundation

nonisolated struct GregorianCalendarService: Sendable {
  let timeZone: TimeZone

  init(timeZone: TimeZone) {
    self.timeZone = timeZone
  }

  func localDay(containing instant: Date) -> LocalDay {
    let components = calendar.dateComponents([.year, .month, .day], from: instant)
    guard
      let year = components.year,
      let month = components.month,
      let day = components.day,
      let localDay = LocalDay(year: year, month: month, day: day)
    else {
      preconditionFailure("A Gregorian calendar must produce valid civil-date components.")
    }
    return localDay
  }

  func week(containing instant: Date) -> WeekID {
    guard let week = WeekID(containing: localDay(containing: instant)) else {
      preconditionFailure("A valid Gregorian civil date must belong to a week.")
    }
    return week
  }

  func startOfDay(for localDay: LocalDay) -> Date? {
    calendar.date(
      from: DateComponents(
        calendar: calendar,
        timeZone: timeZone,
        year: localDay.year,
        month: localDay.month,
        day: localDay.day
      )
    )
  }

  private var calendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.locale = Locale(identifier: "en_US_POSIX")
    calendar.timeZone = timeZone
    calendar.firstWeekday = 2
    calendar.minimumDaysInFirstWeek = 4
    return calendar
  }
}
