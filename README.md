# Cadence

**Find your rhythm.**

Cadence is a lightweight personal wellness app for building a sustainable rhythm without turning life into a scorecard. It favors consistency over perfection, awareness without judgment, flexible planning, and tracking that takes almost no effort.

## The idea

Cadence is designed around four simple experiences:

- **Sunday Planning:** set a small, realistic plan for the coming week.
- **Daily checkoffs:** mark today's Goals complete with one tap.
- **iIndulged:** quickly record something you chose to enjoy, without guilt or moral scoring, so repeated patterns remain easy to notice.
- **History:** notice useful patterns through simple weekly and daily review.

The app is intended to be private and local-first. Punitive streaks, leaderboards, calorie counting, medical claims, and social competition are outside the initial product direction.

## Current status

Cadence has completed its development foundation, My Day, and My Goals. Its three-tab product skeleton—My Day, My Goals, and History—builds on a versioned local data model, repository boundary, deterministic date services, and a shared local/hosted quality gate. The F-005A weekly History foundation is now being built and validated.

[F-002: iOS Project Foundation](Docs/features/F-002.md), [F-003: My Day](Docs/features/F-003.md), and [F-004: My Goals](Docs/features/F-004.md) are complete. [F-005A: Week History Foundation](Docs/features/F-005A.md) is building; later History slices remain queued for clarification. Cadence targets iPhone in portrait on iOS 27 and uses one prepared local-only SwiftData store behind focused repository interfaces with a CloudKit-compatible schema.

## Repository layout

```text
Cadence/
├── App/          App entry point, navigation, and shared state
├── Models/       Immutable domain values
├── Views/        Feature screens and flows
├── Components/   Reusable presentation components
├── Services/     Persistence records/adapters, calendar logic, and integrations
├── Tests/        Swift Testing and XCTest UI targets
├── Cadence.xcodeproj/  Shared native project and scheme
└── Docs/         Product direction, architecture, tracked work, and decisions
```

The foundation currently contains the app shell and test targets; product implementation will fill the feature-owned folders incrementally.

## Product documentation

- [Vision](Docs/Vision.md)
- [Product requirements](Docs/ProductRequirements.md)
- [Design guidelines](Docs/DesignGuidelines.md)
- [Architecture](Docs/Architecture.md)
- [Roadmap](Docs/Roadmap.md)
- [Acceptance tests](Docs/AcceptanceTests.md)
- [Terminology](Docs/Terminology.md)

## Development workflow

Cadence uses a repository-owned agentic coding harness so product intent, implementation, review, and validation remain aligned across development sessions.

Before contributing, read [AGENTS.md](AGENTS.md) and the [Agentic Coding Harness](Docs/AgenticHarness.md). Work is classified as a feature, bug, or engineering-maintenance item and follows a risk-based workflow. Each change identifies its documentation impact before implementation, updates affected sources of truth alongside the work, and reconciles them before review, commit, push, or status transition. Persistence, migrations, date and time-zone logic, notifications, privacy, destructive actions, dependencies, and build setup receive the highest level of review.

`Scripts/quality.sh` is the authoritative native quality command shared by local development and GitHub Actions.

## Guiding principle

Cadence should always feel supportive enough to return to after an imperfect day or week.
