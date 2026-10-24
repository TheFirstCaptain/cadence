# Cadence Acceptance Tests

These are product-level scenarios. Feature records should add narrower validation as behavior is designed.

## Weekly planning

1. Given no plan for the coming week, when the user begins Sunday Planning, then the app offers a short, understandable way to set realistic commitments.
2. Given an existing plan, when life changes, then the user can revise it without failure language or losing unrelated history.

## Daily checkoffs

1. Given a commitment planned for today, when the user taps its completion control, then it is marked complete immediately.
2. Given an accidental checkoff, when the user reverses it, then the original state is restored without penalty.
3. Given missed commitments, when the user returns, then the app remains welcoming and does not display a broken-streak warning.

## iCheated

1. Given a custom indulgence type, when the user logs it, then the entry is recorded in only a few seconds.
2. Given an incorrect entry, when the user edits or removes it, then history reflects the correction.
3. All indulgence copy remains descriptive and nonjudgmental.

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
