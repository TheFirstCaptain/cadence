# Decision 001: Agentic Development Workflow

## Context

Cadence will be developed with substantial AI assistance. Short prompts and context changes can otherwise lead to scope drift, skipped validation, stale documentation, or unsafe decisions around personal data, persistence, and time-based behavior.

## Decision

Cadence adopts the repository-owned workflow in `Docs/AgenticHarness.md`.

Work is classified as feature, bug, or engineering maintenance. Each change receives a risk tier from 0 through 3. Tier 1 through Tier 3 work requires independent review, with more specialized stages as risk increases. The main agent owns integration, documentation reconciliation, final validation, and handoff.

The harness begins as a lightweight documentation contract. After the Xcode project exists, one local quality command and a matching GitHub Actions workflow will mechanically enforce the build, tests, and applicable repository policies.

The workflow requires documentation continuity. Each tracked change records its documentation impact before implementation, updates affected sources of truth in the same coherent change as facts change, and reconciles them before review handoff, commit, push, or status transition. A `None` assessment requires a concrete reason. Documentation-only closeout is limited to immutable evidence and final status; it is not a substitute for keeping executable-contract documentation current during implementation.

## Consequences

- Future sessions have durable product context and work state.
- Higher-risk changes receive proportionate planning and independent review.
- Small documentation changes avoid a heavyweight process.
- Contributors must maintain records alongside implementation.
- Reviewable documentation-impact assessments make same-change reconciliation explicit without requiring meaningless documentation churn.
- Repository-owned tooling now enforces selected structural documentation invariants, links, trackers, and policy retention; semantic truth remains a complete-diff and independent-review responsibility.

## Alternatives considered

- Informal prompt-only development: rejected because important context and validation would not survive reliably between sessions.
- Copying the full TabletopFog harness immediately: rejected because Cadence does not yet have code, an Xcode project, or stable native quality commands.
- Requiring the full review workflow for every change: rejected because it would add ceremony without proportional value for low-risk work.
