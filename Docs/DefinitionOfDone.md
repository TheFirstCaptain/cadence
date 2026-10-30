# Cadence Definition of Done

A change is done only when every applicable item is satisfied or a limitation is recorded explicitly.

## Every change

- Work is classified as a feature, bug, or engineering maintenance item.
- Objective, non-goals, workflow tier, and acceptance notes are current.
- Documentation impact is recorded, naming affected documents and status surfaces or stating `None` with a concrete reason.
- The implementation matches Vision, Design Guidelines, Architecture, and Terminology.
- Relevant automated tests pass.
- Relevant manual validation is complete or documented as unavailable.
- The complete diff has been reviewed for scope creep, privacy, data loss, and stale documentation.
- Tracker state and related records are current.
- Affected documentation was updated in the same coherent change and reconciled before review handoff, commit, push, and status transition.
- No unresolved critical or high finding remains.
- Every discovered drift class has a permanent automated regression guard, or a tracked manual check and automation follow-up with an owner and residual risk.
- The handoff states files changed, behavior changed, validation performed, and residual risk.

## User-visible behavior

- Acceptance tests and feature acceptance notes are updated.
- Copy is concise, supportive, and nonjudgmental.
- VoiceOver, Dynamic Type, contrast, reduced motion, and one-handed use were considered where applicable.
- Screenshots or previews accompany meaningful UI changes when practical.

## Persistence, dates, or notifications

- Valid, invalid, boundary, migration, and partial-failure cases are covered.
- Existing data is preserved and rejected operations do not leave partial state.
- Sunday boundaries, locale, time zone, and daylight-saving behavior are tested where relevant.
- Notification denial, revocation, rescheduling, and stale requests are handled where relevant.

## Before the Xcode project exists

- Documentation links and tracker entries are internally consistent.
- The Git diff is reviewed in full.

## After the Xcode project exists

- The authoritative quality command passes locally.
- Completion evidence records the exact quality command, tested source revision or tree, immutable CI/handoff run identity, Xcode/Swift version, simulator destination, and result. A documentation-only evidence closeout may add immutable evidence and final status after the full run, but must pass documentation and consistency checks, may not alter executable inputs, and may not defer known documentation updates from the implementation change.
- The app builds for the documented simulator or destination.
- Unit and UI tests appropriate to the change pass.
- GitHub Actions uses the same quality policy as local development.
- GitHub Actions runs the full gate for pull requests, protected-branch pushes, and weekly drift detection.
- Simulator validation runs without personal signing credentials.
- Meaningful UI changes complete a manual matrix covering largest supported Dynamic Type, VoiceOver focus/actions, Reduce Motion, light/dark appearance, and one-handed reach.
