# Cadence Agentic Coding Harness

This document defines how human and AI contributors plan, implement, review, and validate Cadence changes.

## Session orientation

Before editing, read `AGENTS.md`, the core product documents it names, all relevant tracked-work records, and applicable decisions. Check Git status and preserve unrelated work.

## Classify the change

- **Feature:** adds or changes user, developer, tooling, or workflow capability. Track it in `Docs/features/`.
- **Bug:** implemented or promised behavior is broken, unsafe, or materially misleading. Track it in `Docs/bugs/`.
- **Engineering maintenance:** preserves behavior while improving structure, tests, diagnostics, or maintainability. Track it in `Docs/engineering/`.

Reclassify and cross-link the work if investigation changes its nature.

## Workflow tiers

Choose the highest applicable tier and record the rationale.

### Tier 0: Documentation and planning

Use when behavior, code, dependencies, commands, and quality policy do not change.

Required: rationale or clarification, documentation update, main-agent complete-diff review, and relevant consistency checks. Independent review is optional unless policy, architecture, roadmap sequencing, or completion rules change.

### Tier 1: Narrow and low risk

Use for copy, isolated visual polish, focused tests, or behavior-preserving cleanup that does not touch persistence, dates, notifications, privacy, dependencies, or destructive actions.

Required: clarification, implementation and validation notes, implementation, focused tests, independent code review, docs/tracker review, and final validation.

### Tier 2: Normal feature

Use for ordinary user-visible workflows without high-risk data or system boundaries.

Required: clarification; one independent planning review covering architecture, implementation, tests, and UX; implementation with tests; independent code review; docs/tracker review; final-diff review; and main-agent validation.

### Tier 3: High risk

Use for persistence or migrations, calendar/time-zone logic, notification scheduling, privacy or export, destructive operations, dependencies, signing/build setup, security assumptions, or changes that could lose data or undermine trust.

Required: clarification; independent architecture, implementation, test, and UX reviews; implementation with tests; independent code review; docs/tracker review; final-diff review; and main-agent validation.

When uncertain, choose the higher tier. If implementation reveals higher risk, reclassify before continuing.

## Independent review

The implementing agent cannot satisfy a required independent review. Use a focused subagent or a human reviewer. The main agent remains responsible for reconciling advice with product constraints and for the final result.

Reviewer output should include:

- Summary.
- Findings with severity.
- Recommendations.
- Files or systems affected.
- Validation required.
- Blockers or residual risk.

For code changes, the independent reviewer also inspects the complete diff, changed tests, newly required regression guards, and the authoritative quality result. The reviewer must confirm that a correction addresses the drift class rather than only the observed example.

Critical and high findings must be fixed. Medium findings must be fixed or explicitly accepted by the user with a tracked follow-up and residual risk. Low findings require a recorded disposition.

## Implementation loop

1. Confirm the tracked record and tier.
2. Record objective, acceptance notes, non-goals, and open questions.
3. Complete required planning and review stages.
4. Make the smallest coherent change, using test-first development where practical.
5. Run focused checks while working.
6. Update product documentation, acceptance tests, decisions, and trackers.
7. Review the complete diff.
8. Run the authoritative quality command when available.
9. Update status only when the Definition of Done is satisfied.

## Quality contract

Before Xcode project creation, the harness is documentation-enforced through structured review and tracker consistency.

When the project is created, add one repository-owned command, expected to be `Scripts/quality.sh`, that runs the same build, tests, formatting or linting, and harness checks used in CI. Do not maintain a weaker CI-only or local-only policy.

`Scripts/quality.sh --fast` is the supported inner loop. It runs deterministic documentation and harness checks, project-policy checks, strict formatting lint, compilation, and focused unit tests without UI tests. Contributors run it repeatedly while working.

`Scripts/quality.sh` is the authoritative full gate and a strict superset of `--fast`. It includes clean builds, all unit tests, required UI tests, and result-bundle checks. Run it before review handoff and again against the final reviewed diff. CI invokes the full command directly. Unknown modes fail, and shared implementation prevents local and CI stages from diverging.

The full gate runs for pull requests, pushes to the protected branch, and on a weekly schedule. Scheduled failures become tracked engineering work and must not be normalized by weakening checks.

## Drift prevention

Any discovered divergence among approved behavior, documentation, project settings, code, tests, or local and CI results must be classified and recorded. Before that work item closes, add the lowest-cost deterministic automated check that detects the entire drift class, not only the observed instance. Demonstrate the guard failing against a representative faulty state when practical and passing after correction.

If automation is not currently feasible, record a manual check, owner, reason, residual risk, and tracked automation follow-up. A regression guard may not be removed or weakened without updating the relevant tracked record and decision. Flaky failures are investigated; blind reruns, silent suppressions, and relaxed thresholds are not accepted as fixes.

## Scope control

Keep work small. Update the roadmap and create a decision record before crossing a product or architecture boundary. Do not silently add tracking, cloud, social, medical, advertising, or data-sharing capability.
