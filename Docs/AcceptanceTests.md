# Cadence Acceptance Tests

These are product-level scenarios. Feature records should add narrower validation as behavior is designed.

## My Day

1. When the user opens Cadence, then the app opens to My Day.
2. My Day presents Goals before iCheated.
3. Given a Goal scheduled for today, when the user taps it, then it becomes complete and remains visible.
4. Given a completed Goal, when the user taps it again, then its checkoff is removed.
5. Each iCheated category displays an icon, type, minus control, today's count, and plus control.
6. When the user taps plus, then today's count increases by one and a date-and-time occurrence is stored.
7. When the user taps minus, then the most recent occurrence for that category today is removed and the count decreases by one.
8. An iCheated count cannot fall below zero.
9. My Day uses the device's local calendar to determine today.
10. Daily Goals appear under Today; Weekly and Custom Goals appear under This Week.
11. A Weekly Goal remains available until checked once, then remains visible as 1 of 1 for the rest of the week.
12. A Custom Goal remains available on later days until its target is met, accepts at most one checkoff per day, and remains visible with completed progress afterward.
13. On first launch with no Goals, My Day offers a clear route to My Goals while iCheated remains usable.
14. Goal rows preserve the manual order from My Goals within their respective My Day groups.

## Weekly planning

1. Given Sunday in the active week, when the user opens My Goals for Sunday Planning, then changes target the upcoming Monday-through-Sunday week without altering the Sunday that is ending.
2. Given a short Goal name, when the user selects Daily, then the plan expects one completion on each day of the week.
3. Given a short Goal name, when the user selects Weekly, then the plan expects one completion at any point during the week.
4. Given Custom frequency, when the user configures it, then only targets from 2 through 6 days per week are offered and no day contributes more than one checkoff.
5. Given Goals in the ending week, when the upcoming week begins without explicit Sunday Planning, then those Goals carry forward automatically.
6. Given an active weekly plan, when the user adds or changes a Goal, then the change applies immediately without prorating its target and existing checkoffs count toward the updated frequency.
7. Given a Goal with earlier checkoffs, when the user removes it midweek, then it leaves remaining My Day views while earlier checkoffs remain in History.
8. Given a Goal name that matches another after trimming and case-insensitive comparison, when the user tries to save it in the same plan, then the duplicate is prevented with clear, nonjudgmental guidance.
9. My Goals encourages a manageable list without enforcing a hard Goal limit.
10. Add and edit use a focused sheet with name and frequency controls; Custom offers 2 through 6.
11. Goal names are trimmed and compared case-insensitively for duplicates.
12. New Goals appear at the bottom and manual reordering persists into My Day.
13. Removing a Goal explains that prior History remains and requires confirmation.

## Daily checkoffs

1. Given a Goal planned for today, when the user taps its completion control, then it is marked complete immediately.
2. Given an accidental checkoff, when the user reverses it, then the original state is restored without penalty.
3. Given missed Goals, when the user returns, then the app remains welcoming and does not display a broken-streak warning.

## iCheated

1. My Day initially offers Junk Food, Unhealthy Snacks, Candy, Alcohol, and Desserts.
2. One plus tap represents one occurrence rather than a serving or precise quantity.
3. Given an incorrect occurrence, when the user removes it, then retained history reflects the correction.
4. All indulgence copy remains descriptive and nonjudgmental.

## History

1. When the user opens History, then the current Monday-through-Sunday Week view appears.
2. Goal progress uses plain counts such as 5 of 7 without percentages.
3. Every iCheated category remains visible, including categories with a zero count, and no previous-period comparison appears.
4. Week view shows daily Goal checkoffs and daily iCheated distribution; tapping a day opens its details.
5. Month view uses a calendar month, totals iCheated occurrences dated in that month, and shows compact full-week Goal rows without splitting a weekly target at the month boundary.
6. The user may navigate to prior weeks and months without an artificial limit, may not navigate into future periods, and can return through Today.
7. Day detail shows Goal checkoffs and individual iCheated occurrences with their recorded times.
8. A past Goal checkoff may be added or removed only when the Goal was active on that date.
9. A past iCheated occurrence may be removed individually and restored through a temporary Undo action.
10. Historical corrections immediately update all affected summaries.
11. History never combines Goals and iCheated into one score or converts behavior into moral or competitive rankings.

## Data and time

1. Records remain correct across Sunday/week boundaries, daylight-saving changes, and a device time-zone change.
2. An app update or schema migration preserves existing records or fails safely with a documented recovery path.
3. Destructive actions are deliberate, clearly scoped, and recoverable where practical.
4. Every timestamped record preserves its original local date and time-zone context; a later time-zone change does not regroup past History.
5. New records use the device's current local date and time zone.

## Platform and persistence

1. Cadence builds and runs as an iPhone-only app targeting iOS 27 or later.
2. V1 supports portrait orientation and does not expose iPad or landscape layouts.
3. Production data remains on device and SwiftData CloudKit synchronization is explicitly disabled.
4. Views access persistence through the repository/service boundary rather than mutating the SwiftData context directly.
5. An in-memory SwiftData configuration supports deterministic automated tests.
6. Persisted models use app-generated UUIDs and repository-level duplicate validation instead of CloudKit-incompatible unique constraints.
7. Model relationships remain optional, define inverses where needed, and avoid deny deletion rules so a future sync feature does not require avoidable schema reconstruction.
8. Versioned schema and migration tests preserve existing records across application updates.

## Accessibility and privacy

1. Core flows remain usable with Dynamic Type and VoiceOver.
2. Meaning is not conveyed by color alone.
3. Personal wellness data remains on device unless the user explicitly enables a later approved capability.
