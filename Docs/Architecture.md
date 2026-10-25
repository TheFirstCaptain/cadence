# Cadence Architecture

## Current state

Cadence is in documentation and project-foundation planning. No Xcode project or production code exists yet.

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
- Bundle identifier: `com.thefirstcaptain.cadence`.
- Signing: automatic, using the user's selected Apple development team.
- Swift Testing: domain models, repositories, calendar logic, aggregation, migrations, and failure paths.
- XCTest UI: complete My Day, My Goals, and History workflows.
- Date-sensitive behavior receives injected clock and calendar dependencies.
- Local and CI validation call the same repository-owned quality command.

## Boundaries

- Views render state and send user intent; they should not own persistence rules.
- Calendar calculations belong in a testable service and must use explicit calendars, locales, and time zones.
- Weekly plans run Monday through Sunday. Sunday Planning edits the upcoming week without mutating the Sunday that ends the active week.
- Carried-forward Goals seed the upcoming plan. Midweek edits affect the active plan immediately while historical checkoffs remain attached to their original dates.
- Daily checkoffs and indulgence occurrences preserve their original local date and time-zone context so travel never regroups past History. New records use the device's current local calendar.
- History derives weekly and calendar-month summaries from persisted records. Weekly Goal targets retain Monday-through-Sunday boundaries even when a week crosses a month boundary.
- Persistence must be accessed through a narrow boundary so migrations and test stores can be validated.
- Production uses an on-device SwiftData configuration with CloudKit explicitly disabled; tests use an in-memory configuration.
- Persisted records use app-generated UUID identity. Duplicate business rules are enforced in repository logic rather than SwiftData unique constraints.
- Relationships remain CloudKit-compatible: optional with explicit inverses where inference is unreliable, and without deny deletion rules.
- Schema evolution uses versioned SwiftData schemas and migration plans; new fields require safe defaults or optionality.
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

- Bundle identifier and signing arrangement.
- Testing structure and any formatting or linting tools.
- Exact repository protocols, initial schema types, and migration-test fixtures.
