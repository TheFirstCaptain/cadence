# Cadence Architecture

## Current state

Cadence is implementing its project foundation. The Xcode project shell, app entry point, template view, unit-test target, and UI-test target now exist; product features and persistence remain to be implemented.

## Intended platform

- Native iPhone application targeting iOS 27 or later.
- Portrait-only interface in V1; iPad and landscape layouts are out of scope.
- SwiftUI presentation.
- Local-only SwiftData persistence behind a repository/service boundary.
- A versioned, CloudKit-compatible schema from the first release, with iCloud sync disabled until a separate feature is approved and validated.
- No account, server, analytics, or cloud dependency in the initial version.

## Responsibilities

- `App/`: composition root, navigation, dependency setup, scene lifecycle.
- `Models/`: immutable weekly plan boundaries, Goals and their frequencies, checkoffs, iCheated categories, and indulgence occurrences.
- `Views/`: the three primary tabs My Day, My Goals, and History; focused sheets and drill-down details.
- `Components/`: reusable controls and visual building blocks without feature ownership.
- `Services/`: persistence adapters, calendar/week calculations, notifications, and future integrations.

## Project identity and testing

- Product and display name: Cadence.
- Bundle identifier: `com.kirkgartside.cadence`.
- Signing: automatic, using the user's selected Apple development team.
- Swift Testing: domain models, repositories, calendar logic, aggregation, migrations, and failure paths.
- XCTest UI in F-002: launch, default-tab, and three-tab navigation smoke coverage. Complete workflows belong to F-003 through F-005.
- Date-sensitive behavior receives injected clock, Gregorian calendar, and time-zone dependencies.
- Local and CI validation call the same repository-owned quality command.
- Simulator validation disables code signing and never requires a personal development team or signing secret.

## Domain and persistence design

- Product dates use Gregorian civil dates in the recording time zone with fixed Monday-through-Sunday weeks; locale affects presentation, not week boundaries.
- `LocalDay` and `WeekID` are immutable Sendable domain values. Persisted activity keeps its precise instant, Gregorian date components, canonical day key, time-zone identifier, and UTC offset captured at creation.
- Each Monday-through-Sunday plan owns week-specific Goal snapshots. Carry-forward creates a new planned record with a stable lineage identifier rather than mutating one Goal across weeks.
- Renames and frequency changes relabel and recalculate the entire active week, including earlier active-week days; prior weeks remain unchanged.
- Removing a Goal ends its active interval instead of physically deleting the data required by History.
- The five built-in iCheated categories use fixed app-defined UUIDs and idempotent seeding. Future removal archives a category rather than orphaning History.
- Persistence is serialized through one actor-backed SwiftData store. SwiftData models and `ModelContext` never cross that isolation boundary.
- Repositories return immutable Sendable domain snapshots and are separated by responsibility: planning, daily tracking, and History.

## Schema Version 1

- `WeeklyPlanRecord`: week identity, Gregorian/calendar context, planning time zone, timestamps, and optional planned-Goal relationships.
- `PlannedGoalRecord`: week-specific identity, stable lineage ID, name and normalized name, frequency, optional Custom target, sort order, active interval, timestamps, optional plan/checkoff relationships.
- `GoalCheckoffRecord`: ID, durable planned-Goal ID, precise instant, preserved local-date/time-zone fields, timestamps, and optional Goal relationship.
- `IndulgenceCategoryRecord`: fixed or generated ID, name and normalized name, SF Symbol name, sort order, built-in/active flags, timestamps, and optional occurrence relationships.
- `IndulgenceOccurrenceRecord`: ID, durable category ID, precise instant, preserved local-date/time-zone fields, timestamp, and optional category relationship.

Repository transactions enforce one canonical plan per week, normalized Goal-name uniqueness within a plan, valid frequency/target combinations, one checkoff per Goal/local day, active-interval guards, ordered carry-forward, and latest-occurrence removal.

## App composition and concurrency

- One Xcode project with `Cadence`, `CadenceTests`, and `CadenceUITests` targets and a shared scheme.
- No workspace, internal framework, package split, or third-party dependency initially.
- `CadenceApp` creates the local ModelContainer, actor-backed store, system time dependencies, and `AppDependencies` composition root.
- Feature view models are `@MainActor`; views use constructor or environment injection and never import SwiftData for mutation.
- Swift 6 language mode and complete concurrency checking are enabled. `@unchecked Sendable` is not used to hide isolation problems.

## Boundaries

- Views render state and send user intent; they should not own persistence rules.
- Calendar calculations belong in a testable service and must use explicit Gregorian calendars and time zones; locale is used only for presentation.
- Weekly plans run Monday through Sunday. Sunday Planning edits the upcoming week without mutating the Sunday that ends the active week.
- Carried-forward Goals seed the upcoming plan. Midweek edits affect the active plan immediately while historical checkoffs remain attached to their original dates.
- Daily checkoffs and indulgence occurrences preserve their original local date and time-zone context so travel never regroups past History. New records use the device's current local calendar.
- History derives weekly and calendar-month summaries from persisted records. Weekly Goal targets retain Monday-through-Sunday boundaries even when a week crosses a month boundary.
- Persistence must be accessed through a narrow boundary so migrations and test stores can be validated.
- Production uses an on-device SwiftData configuration with CloudKit explicitly disabled; tests use an in-memory configuration.
- Persisted records use app-generated UUID identity. Duplicate business rules are enforced in repository logic rather than SwiftData unique constraints.
- Relationships remain CloudKit-compatible: optional with explicit inverses where inference is unreliable, and without deny deletion rules.
- Schema evolution uses versioned SwiftData schemas and migration plans; new fields require safe defaults or optionality.
- Failed repository mutations must not expose partially updated UI state.
- Notifications, if approved, remain optional and must degrade safely when permission is denied.
- Domain models must not encode moral scores, punitive streaks, or health claims.
- V1 has no Settings tab; future preferences must justify a separate surface rather than displacing a primary workflow.

## High-risk areas

- Schema changes and migrations.
- Week boundaries, daylight-saving transitions, locale, and time-zone changes.
- Editing or deleting historical records.
- Notification scheduling and permission state.
- Export, sync, analytics, or any movement of private wellness data.
- Accessibility regressions that block Dynamic Type, VoiceOver, contrast, or reduced motion.

## Architecture decisions still required

None before project creation. Future CloudKit enablement, notifications, analytics, exports, and post-V1 schema changes each require their own reviewed decision.
