# Cadence Product Requirements

## Product vision

Cadence is a lightweight personal wellness app that helps people find a sustainable rhythm in everyday life. It emphasizes consistency over perfection, awareness without judgment, flexible planning, and low-effort tracking.

## Core experience

### My Day

- Open the app to My Day by default.
- Show Goals first, divided into Today for Daily Goals and This Week for Weekly and Custom Goals, followed by iCheated.
- Keep completed goals visible and allow their checkoffs to be reversed.
- Keep Weekly and Custom Goals available across the week until their targets are met, then retain their completed progress for the rest of the week.
- On first launch, show a calm empty Goals state linking to My Goals while keeping iCheated usable.
- Show today's iCheated counts while retaining timestamped occurrences for History.

### Weekly planning

- Provide a My Goals tab for setting intentions each Sunday for the upcoming Monday-through-Sunday week.
- Let the user add a short Goal name and select Daily, Weekly, or Custom frequency.
- Define Daily as once per day, Weekly as once at any point during the week, and Custom as completion on 2–6 days during the week.
- Carry Goals forward automatically so Monday still has a plan when Sunday Planning is skipped.
- Allow Goals to be added, renamed, rescheduled, or removed during an active week without rewriting prior History.
- Prevent Goal names that match after trimming and case-insensitive comparison within the same weekly plan.
- Add and edit Goals in a focused sheet; compare trimmed Goal names case-insensitively for duplicates.
- Allow manual Goal ordering and preserve that order within My Day's Today and This Week groups.
- Encourage a manageable set of Goals without imposing a hard limit.
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

- Open to the current Monday-through-Sunday week and allow switching between Week and calendar Month.
- Show Goal results as plain completed-of-target counts without percentages.
- Show every iCheated category, including zero counts, without previous-period comparisons.
- Allow navigation to prior periods, day and week drill-down, and a Today action; do not expose future periods.
- Allow correction of past Goal checkoffs and removal of individual past iCheated occurrences with Undo.
- Help the user notice patterns across Goals and indulgence occurrences.
- Favor understandable summaries over dense analytics.

## Initial scope

- Native iOS app built with SwiftUI.
- Local-first data storage.
- Weekly plans, daily Goal completion records, the initial iCheated categories and occurrences, and history.
- Calm empty states and encouraging copy.
- Three primary tabs: My Day, My Goals, and History.

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
