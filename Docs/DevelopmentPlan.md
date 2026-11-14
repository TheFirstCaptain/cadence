# Cadence Development Plan

## Technical direction

- SwiftUI for an iPhone-only, portrait-only interface targeting iOS 27 or later.
- Local-only SwiftData behind a repository/service boundary.
- A versioned, CloudKit-compatible schema with app-generated UUIDs, optional relationships, explicit inverses where needed, and no persistence-level unique constraints.
- In-memory SwiftData configurations for automated tests.
- Swift Testing for domain, repository, calendar, aggregation, migration, and failure-path coverage.
- XCTest UI smoke coverage for the F-002 shell, with complete workflows added by F-003 through F-005.
- Injected clock and calendar dependencies for deterministic date tests.
- Injected time-zone and UUID dependencies where deterministic fixtures require them.
- Gregorian civil-date domain values with fixed Monday-through-Sunday week calculations.
- One actor-backed SwiftData store implementing focused planning, daily-tracking, and History repository protocols.
- Small feature-focused views supported by reusable components and services.
- Project creation began only after the user explicitly approved F-002 and later authorized the Xcode walkthrough.

## Proposed source organization

- `App/` — app entry point, navigation, and shared app state.
- `Models/` — weekly plans, Goals, checkoffs, iIndulged categories, and indulgence occurrences.
- `Views/` — My Day, My Goals, and History screens and flows.
- `Components/` — reusable controls, cards, progress indicators, and empty states.
- `Services/` — persistence, date/week calculations, and later integrations.
- `Docs/` — product, design, and implementation documentation.

## Delivery phases

### 1. Foundation

- **F-002 project shell:** Create one iOS 27 project with Cadence, CadenceTests, and CadenceUITests targets plus a shared scheme; establish bundle identity, simulator-safe signing, Swift 6 concurrency checking, and iPhone portrait settings. The initial shell is complete.
- **F-002E quality baseline:** Complete. Established authoritative local fast and full gates and expanded their shared policy coverage with each foundation slice.
- **F-002A domain and calendar:** Complete. Added domain date, identity, and frequency values plus deterministic clock, calendar, time-zone, and UUID dependencies with boundary tests.
- **F-002B SwiftData schema:** Complete. Added Schema V1, its migration-plan declaration, production and in-memory container factories, idempotent built-in category seeding, and persistence regression tests.
- **F-002C repositories:** Complete. Added the actor-backed store, focused repository protocols, immutable snapshots, and transaction, concurrency, rollback, and reopen tests.
- **F-002D application shell:** Complete. Added the three-tab placeholder interface with My Day selected by default plus launch, exact-tab-count, default-tab, and navigation UI smoke coverage.
- **F-002 application composition:** Complete. Added an app-owned preparing, ready, and failed bootstrap; one production store backs all focused repository interfaces, and non-destructive retry handles container or preparation failure.
- **F-002E quality completion:** Complete. Apple formatting, architecture and project-policy checks, and matching pull-request, protected-branch, and weekly GitHub Actions policy are validated; push-triggered hosted runs have passed.
- **F-002E regression guards:** Complete. Representative negative fixtures exercise the harness guards, with later drift classes ratcheted into permanent checks.
- **F-002 integration closeout:** Complete. Accessibility validation, documentation reconciliation, independent Tier 3 review, and local/hosted full gates passed; hosted run `41135991220` validates revision `6c580e57`.

### 2. My Day and My Goals

- **F-003A My Day presentation:** Complete. Added repository-backed screen states, Today/This Week grouping, capped progress, stable ordering, empty-plan routing, recoverable failure, and day/time-zone refresh.
- **F-003B Goal checkoffs:** Complete. Added one-tap completion and undo with persistence, rollback, relaunch, concurrency guards, and accessible feedback.
- **F-003 My Day:** Complete. Presentation, Goal checkoffs, and iIndulged quick logging passed independent review, local and hosted full gates, and manual validation.
- **F-004A weekly plan lifecycle:** Complete. Sunday Planning, atomic automatic carry-forward, boundary-safe My Goals states, My Day integration, independent review, local/hosted full gates, and manual validation passed.
- **F-004B Goal editor:** Complete. Focused creation/editing, Daily/Weekly/Custom frequency controls, duplicate and 60-character validation, active-week My Day refresh, independent review, the 90-test full gate, and manual validation passed.
- **F-004C Goal organization and removal:** Complete. Persisted ordering, gentle guidance beginning at 8 Goals, history-preserving removal, rollback, and regression coverage passed independent review, local and hosted 102-test full gates, documentation reconciliation, and manual accessibility validation.
- **F-004 My Goals integration:** Complete. B-003 resolved the hosted cross-test application-lifecycle failure with explicit teardown ownership and target-wide negative guards; immutable run `42371290847` validates revision `7d963e26`.

### 3. iIndulged expansion

- Validate the initial five-category quick-log flow.
- Add custom indulgence types when separately approved.
- Allow recent entries to be reviewed and corrected.

### 4. History

- **F-005A Week History foundation:** Complete. Current/prior Week aggregation, period navigation, plain Goal counts, neutral iIndulged distribution, lifecycle refresh, independent reviews, local/hosted 115-test gates, and the manual accessibility matrix passed.
- **F-005B Month History:** Complete. Majority-of-week mapping, atomic calendar-Month aggregation, complete overlapping weekly Goal rows, explicit outside-month accessibility, Week drill-down, independent final review, the hands-on accessibility matrix, and local/hosted 126-test gates passed; run `43470160752` attempt 2 validates `fd9237c`.
- **F-005C Day History detail:** Clarify and build read-only daily Goal/checkoff and timestamped occurrence inspection.
- **F-005D Historical corrections:** Clarify and build guarded past checkoff changes, exact occurrence deletion/temporary Undo, rollback, and immediate summary invalidation.

### 5. Polish and validation

- Add accessibility support, thoughtful empty states, and gentle feedback.
- Test week boundaries, Sunday planning, edits, and data persistence.
- Validate that core actions remain fast and the tone stays supportive.

## Remaining local setup

- The selected Apple development team has no registered physical device, so device provisioning remains deferred and simulator validation disables signing.
- The default destination is `platform=iOS Simulator,name=iPhone 17,OS=latest`, which currently resolves locally to iOS 27.0. Other machines and CI set `CADENCE_DESTINATION` when that compatible device type is unavailable.
