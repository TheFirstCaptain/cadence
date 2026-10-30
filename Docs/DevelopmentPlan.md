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

- Establish F-003A's repository-backed My Day presentation, Today/This Week grouping, progress state, ordering, and empty-plan invitation.
- Add F-003B's one-tap Goal completion and undo with persistence, rollback, relaunch, and accessible feedback.
- Add F-003C's five built-in iIndulged counters with timestamped plus/minus behavior, final symbols, and accessible feedback.
- Close the F-003 umbrella through integration review, the manual accessibility matrix, full-gate evidence, and documentation reconciliation.
- Build Sunday Planning in My Goals for the upcoming Monday-through-Sunday week.
- Support Daily, Weekly, and Custom 2–6-times-per-week frequencies.
- Carry Goals forward and preserve History across midweek changes.

### 3. iIndulged expansion

- Validate the initial five-category quick-log flow.
- Add custom indulgence types when separately approved.
- Allow recent entries to be reviewed and corrected.

### 4. History

- Build current and prior Week views, calendar Month summaries, and day details.
- Show completed-of-target Goal counts and neutral iIndulged totals without percentages or comparisons.
- Support reversible historical corrections and stable original local dates.

### 5. Polish and validation

- Add accessibility support, thoughtful empty states, and gentle feedback.
- Test week boundaries, Sunday planning, edits, and data persistence.
- Validate that core actions remain fast and the tone stays supportive.

## Remaining local setup

- The selected Apple development team has no registered physical device, so device provisioning remains deferred and simulator validation disables signing.
- The default destination is `platform=iOS Simulator,name=iPhone 17,OS=latest`, which currently resolves locally to iOS 27.0. Other machines and CI set `CADENCE_DESTINATION` when that compatible device type is unavailable.
