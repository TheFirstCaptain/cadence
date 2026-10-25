# Decision 003: Application Architecture and Quality Contract

## Context

F-002 must turn Cadence's approved product behavior into a project structure, schema, concurrency model, test strategy, and executable quality contract. Independent Tier 3 reviews identified two risks requiring explicit decisions: historical data cannot depend on mutable Goal records, and timestamps alone cannot preserve the user's original civil date after travel.

## Decision

Cadence uses one Xcode project with an app target, a Swift Testing target, an XCTest UI target, and a shared scheme. Feature code remains in the app target and is organized by My Day, My Goals, and History. No workspace, internal framework, package split, third-party dependency, or empty Settings surface is added initially.

SwiftData is isolated in one serialized actor-backed store. Focused planning, daily-tracking, and History repository protocols expose immutable Sendable domain values. Views never mutate a ModelContext or receive live SwiftData models. View models are MainActor-isolated, and Swift 6 complete concurrency checking is enabled without unchecked Sendable escape hatches.

Product dates use Gregorian civil dates in the recording time zone with fixed Monday-through-Sunday weeks. Locale affects formatting only. Activity records store a precise instant plus captured Gregorian date components, canonical day key, time-zone identifier, and UTC offset. Historical grouping never derives an old local day using the device's current time zone.

Weekly plans own week-specific Goal snapshots linked by a stable lineage ID. Carry-forward copies the Goal configuration into the next week. Active-week rename or frequency changes apply consistently to the entire active week, including its earlier days; prior-week snapshots never change. Removal ends a Goal's active interval instead of physically deleting historical context.

Schema V1 contains weekly plans, planned Goals, Goal checkoffs, indulgence categories, and indulgence occurrences. It uses app-generated UUIDs, optional relationships and explicit inverses where needed, nullifying rather than deny deletion rules, stable enum raw strings, safe defaults or optional fields, and a declared migration plan. Five built-in categories use fixed UUIDs and idempotent seeding.

The repository quality command is `Scripts/quality.sh`. It fails fast and performs:

1. Toolchain, project, scheme, and simulator-destination preflight.
2. Documentation, tracker/link, project-setting, and no-iCloud-entitlement validation.
3. Bundled Apple `swift format` strict lint over owned Swift sources and tests.
4. Clean temporary Derived Data creation outside the repository.
5. Simulator `build-for-testing` with code signing disabled.
6. Swift Testing through `test-without-building`.
7. XCTest UI smoke tests through `test-without-building`.
8. Result-bundle existence checks and actionable failure output.

The default logical destination is `platform=iOS Simulator,name=iPhone 17 Pro,OS=latest`, overridable through `CADENCE_DESTINATION`. No simulator UUID is committed. GitHub Actions invokes the same script, pins an environment with Xcode 27 when available, requires no signing secrets, and uploads result bundles or logs on failure.

F-002 creates only launch, default-tab, and three-tab navigation UI smoke coverage. Complete workflow UI tests belong to F-003 through F-005 when those workflows exist. Meaningful UI changes also require a manual accessibility matrix because automated tests cannot prove VoiceOver usability, Dynamic Type layout, contrast, haptics, or Reduce Motion behavior completely.

## Consequences

- Historical results remain stable across travel, later edits, and carried-forward plans.
- SwiftData and concurrency details stay out of SwiftUI feature code.
- CloudKit compatibility remains feasible but still requires a dedicated sync feature.
- The schema contains some deliberate duplication, such as durable foreign IDs beside optional relationships, to preserve renderable History.
- Active-week edits intentionally recalculate that week; users see one coherent plan per week rather than per-day configuration fragments.
- Local and hosted validation share one policy and do not depend on personal signing credentials.
- The initial repository carries more foundation tests and documentation, reducing migration and date-boundary risk later.

## Alternatives considered

- Use timestamps and the current time zone for History: rejected because travel would regroup past activity.
- Support arbitrary preferred calendar systems for V1: rejected because Cadence's fixed Monday-through-Sunday contract is clearest with Gregorian civil dates; locale still controls presentation.
- Reuse one mutable Goal record across weeks: rejected because edits would rewrite historical meaning.
- Expose SwiftData models directly to views: rejected because it leaks isolation and persistence concerns.
- Use one broad repository protocol: rejected because focused interfaces better preserve feature boundaries while one concrete store can still implement them.
- Require signing for every build: rejected because simulator and CI validation must remain credential-free.
- Add a third-party formatter or linter: rejected because bundled Apple `swift format` covers the initial need without dependency overhead.
- Require F-002 to automate complete product workflows: rejected because those screens do not exist yet and their tests belong to their implementing features.
