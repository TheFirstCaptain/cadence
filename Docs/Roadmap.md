# Cadence Roadmap

## Phase 0: Development foundation

- Establish the agentic coding harness.
- Target iPhone portrait on iOS 27 or later.
- Use local-only SwiftData behind a repository boundary with a versioned, CloudKit-compatible schema.
- Decide bundle identity, signing, testing, and quality tooling.
- Create the Xcode project only after explicit approval.
- Add one authoritative local quality command and matching GitHub Actions workflow.

Foundation implementation is delivered as five slices, F-002A through F-002E. F-002E first establishes the local quality baseline; domain/calendar, schema, repository, and three-tab shell slices follow; F-002E then finishes hosted CI and complete regression-guard coverage before the F-002 integration closeout.

## Phase 1: My Day foundation

- Open the app to My Day.
- Show today's Goals first and iIndulged second.
- Separate Daily Goals under Today and flexible Goals under This Week.
- Provide a first-run empty Goals invitation without blocking iIndulged.
- Complete or undo a Goal checkoff in one tap.
- Record or remove an iIndulged occurrence with one tap.
- Show quiet weekly progress without punitive streaks.

## Phase 2: My Goals and iIndulged expansion

- Create and edit a small Monday-through-Sunday weekly plan in My Goals.
- Support Daily, Weekly, and 2–6-times-per-week Custom frequencies.
- Carry Goals forward and support flexible midweek changes without losing History.
- Add focused Goal creation/editing and manual ordering.
- Create and manage custom indulgence types.
- Review, correct, or remove recent entries.

## Phase 3: History

- Open to the current week and browse prior Week and calendar Month views.
- Show plain Goal progress and neutral iIndulged counts without percentages or comparisons.
- Drill into day details and correct personal records with reversible deletion.
- Preserve stable original local dates across time-zone changes.

## Phase 4: Polish

- Complete accessibility and device-size review.
- Refine empty states, language, and gentle feedback.
- Validate boundary dates, time zones, migrations, and recovery behavior.

## Later ideas requiring explicit approval

- Notifications.
- Data export or backup.
- Cross-device sync.
- HealthKit or other integrations.
- Widgets.

## Out of scope

- Social feeds, competition, and leaderboards.
- Calorie counting or medical guidance.
- Account creation or advertising.
- Guilt-based streak mechanics.
