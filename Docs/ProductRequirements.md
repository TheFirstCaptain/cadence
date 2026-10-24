# Cadence Product Requirements

## Product vision

Cadence is a lightweight personal wellness app that helps people find a sustainable rhythm in everyday life. It emphasizes consistency over perfection, awareness without judgment, flexible planning, and low-effort tracking.

## Core experience

### My Day

- Open the app to My Day by default.
- Show today's Goals first and the iCheated section second.
- Keep completed goals visible and allow their checkoffs to be reversed.
- Show today's iCheated counts while retaining timestamped occurrences for History.

### Weekly planning

- Invite the user to set intentions each Sunday for the coming week.
- Support a small, realistic set of wellness Goals.
- Keep plans flexible so a missed day never feels like failure.

### Daily checkoffs

- Show the current day's planned Goals clearly.
- Let the user mark an item complete with one tap.
- Reflect weekly progress without punitive streaks or warnings.

### iCheated

- Let the user quickly log an indulgence or off-plan choice from My Day.
- Begin with Junk Food, Unhealthy Snacks, Candy, Alcohol, and Desserts.
- Show each category as an icon, type, minus control, today's count, and plus control.
- Treat one plus tap as one timestamped occurrence; minus removes the most recent occurrence for that category today.
- Allow additional user-defined types in a later feature.
- Keep logging fast, neutral, and free of guilt-inducing language.

### History

- Present simple weekly and daily history.
- Help the user notice patterns across Goals and indulgence occurrences.
- Favor understandable summaries over dense analytics.

## Initial scope

- Native iOS app built with SwiftUI.
- Local-first data storage.
- Weekly plans, daily Goal completion records, the initial iCheated categories and occurrences, and history.
- Calm empty states and encouraging copy.

## Out of scope for the first version

- Social features, leaderboards, and competitive challenges.
- Punitive streak mechanics or failure alerts.
- Calorie counting or detailed medical tracking.
- Cloud sync, account creation, and third-party integrations unless added later.

## Success criteria

- Sunday planning feels quick and approachable.
- A daily Goal can be checked off in one tap.
- An indulgence can be logged in only a few seconds.
- History makes patterns visible without judgment.
- The overall experience feels light enough to use consistently.
