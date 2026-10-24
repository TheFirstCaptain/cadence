# Cadence Definition of Done

A change is done only when every applicable item is satisfied or a limitation is recorded explicitly.

## Every change

- Work is classified as a feature, bug, or engineering maintenance item.
- Objective, non-goals, workflow tier, and acceptance notes are current.
- The implementation matches Vision, Design Guidelines, Architecture, and Terminology.
- Relevant automated tests pass.
- Relevant manual validation is complete or documented as unavailable.
- The complete diff has been reviewed for scope creep, privacy, data loss, and stale documentation.
- Tracker state and related records are current.
- No unresolved critical or high finding remains.
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
- The app builds for the documented simulator or destination.
- Unit and UI tests appropriate to the change pass.
- GitHub Actions uses the same quality policy as local development.
