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

## Weekly planning

1. Given Sunday in the active week, when the user opens My Goals for Sunday Planning, then changes target the upcoming Monday-through-Sunday week without altering the Sunday that is ending.
2. Given a short Goal name, when the user selects Daily, then the plan expects one completion on each day of the week.
3. Given a short Goal name, when the user selects Weekly, then the plan expects one completion at any point during the week.
4. Given Custom frequency, when the user configures it, then only targets from 2 through 6 days per week are offered and no day contributes more than one checkoff.
5. Given Goals in the ending week, when the upcoming week begins without explicit Sunday Planning, then those Goals carry forward automatically.
6. Given an active weekly plan, when the user adds or changes a Goal, then the change applies immediately without prorating its target and existing checkoffs count toward the updated frequency.
7. Given a Goal with earlier checkoffs, when the user removes it midweek, then it leaves remaining My Day views while earlier checkoffs remain in History.
8. Given an exact duplicate Goal name in the same plan, when the user tries to save it, then the duplicate is prevented with clear, nonjudgmental guidance.
9. My Goals encourages a manageable list without enforcing a hard Goal limit.

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

1. Given prior activity, when the user opens History, then weekly and daily records are understandable without dense analytics.
2. History never converts personal behavior into moral scores or competitive rankings.

## Data and time

1. Records remain correct across Sunday/week boundaries, daylight-saving changes, and a device time-zone change.
2. An app update or schema migration preserves existing records or fails safely with a documented recovery path.
3. Destructive actions are deliberate, clearly scoped, and recoverable where practical.

## Accessibility and privacy

1. Core flows remain usable with Dynamic Type and VoiceOver.
2. Meaning is not conveyed by color alone.
3. Personal wellness data remains on device unless the user explicitly enables a later approved capability.
