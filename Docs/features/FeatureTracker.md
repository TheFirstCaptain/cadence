# Feature Tracker

## Phases

`Proposed`, `Clarifying`, `Planned`, `Approved`, `Building`, `Validating`, `Reviewing`, `Done`, `Blocked`, and `Deferred`.

Use one outcome-oriented record per coherent capability. Keep implementation details in the feature document. Update `Docs/AcceptanceTests.md` when behavior changes and create a decision record before crossing a product or architecture boundary.

| ID | Title | Status | Phase | Feature document | Last updated | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| F-001 | Agentic Coding Harness | Complete | Done | [F-001.md](./F-001.md) | 2026-10-30 | Added documentation-impact assessment, same-change reconciliation checkpoints, template prompts, and deterministic policy guards. |
| F-001A | Repository README | Complete | Done | [F-001A.md](./F-001A.md) | 2026-10-24 | Added a public project overview, current status, documentation map, and contributor orientation. |
| F-002 | iOS Project Foundation | Complete | Done | [F-002.md](./F-002.md) | 2026-10-30 | All five slices, accessibility matrix, independent integration review, and local/hosted full gates are complete; run `41135991220` passed revision `6c580e57`. |
| F-002A | Domain and Calendar Foundation | Complete | Done | [F-002A.md](./F-002A.md) | 2026-10-27 | Added validated civil dates and weeks, Goal frequencies, injected system values, and DST, travel, rollover, and decoding tests. |
| F-002B | SwiftData Schema V1 | Complete | Done | [F-002B.md](./F-002B.md) | 2026-10-28 | Added Schema V1, local-only container factories, migration declaration, fixed built-ins, rollback-safe seeding, and persistence tests. |
| F-002C | Repository and Persistence Boundary | Complete | Done | [F-002C.md](./F-002C.md) | 2026-10-28 | Added the ModelActor store, focused repositories, immutable snapshots, transaction invariants, rollback, concurrency, and reopen tests. |
| F-002D | Three-Tab Application Shell | Complete | Done | [F-002D.md](./F-002D.md) | 2026-10-28 | Added the My Day default tab, My Goals and History placeholders, exact three-tab coverage, and navigation smoke tests. |
| F-002E | Quality and CI Contract | Complete | Done | [F-002E.md](./F-002E.md) | 2026-10-30 | Hosted run `41036710609` passed all 37 tests on revision `1d53b606`; local/CI parity and readiness guards are validated. |
| F-003 | My Day | Active | Clarifying | [F-003.md](./F-003.md) | 2026-10-29 | Umbrella milestone split into presentation, Goal-checkoff, and iIndulged delivery slices; exact built-in symbols remain open. |
| F-003A | My Day Presentation Foundation | Active | Validating | [F-003A.md](./F-003A.md) | 2026-10-31 | Repository-backed states, grouping, progress, routing, lifecycle refresh, fixtures, and regression tests are implemented; the final full gate passed 47 tests, with manual accessibility reconciliation remaining. |
| F-003B | My Day Goal Checkoffs | Active | Clarifying | [F-003B.md](./F-003B.md) | 2026-10-29 | Owns one-tap complete/undo, weekly progress mutation, rollback, relaunch, and accessible feedback. |
| F-003C | iIndulged Quick Logging | Active | Clarifying | [F-003C.md](./F-003C.md) | 2026-10-29 | Owns the five built-in counters, timestamped plus/minus behavior, symbols, persistence, and accessible feedback. |
| F-004 | My Goals | Active | Clarifying | [F-004.md](./F-004.md) | 2026-10-25 | Weekly lifecycle plus focused editing, normalized duplicates, manual ordering, and removal behavior defined. |
| F-005 | History | Active | Clarifying | [F-005.md](./F-005.md) | 2026-10-25 | Current Week, calendar Month, drill-down, correction, and stable local-date behavior defined. |
