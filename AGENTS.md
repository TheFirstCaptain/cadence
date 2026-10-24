# Cadence Repository Guidelines

## Purpose

Cadence is a lightweight SwiftUI personal wellness app for finding a sustainable rhythm. Preserve its central promise: consistency over perfection, awareness without judgment, flexible planning, and low-effort tracking.

## Start Here

Before changing the repository, read:

- `Docs/Vision.md`
- `Docs/DesignGuidelines.md`
- `Docs/Architecture.md`
- `Docs/Terminology.md`
- `Docs/Roadmap.md`
- `Docs/AcceptanceTests.md`
- `Docs/DefinitionOfDone.md`
- `Docs/AgenticHarness.md`
- The relevant feature, bug, engineering, and decision records

Use these documents as the source of truth. If code and documentation disagree, stop and reconcile the discrepancy explicitly.

## Project Structure

- `App/`: app entry point, navigation, and shared app state.
- `Models/`: domain and persistence models.
- `Views/`: feature screens and flows.
- `Components/`: reusable presentation components.
- `Services/`: persistence, time/calendar logic, notifications, and integrations.
- `Docs/`: product, design, architecture, workflow, and tracked work.

## Working Agreement

1. Classify work before editing: feature, bug, or engineering maintenance.
2. Keep each change focused and record its objective, non-goals, and validation.
3. Choose the workflow tier described in `Docs/AgenticHarness.md`.
4. Use independent agent review when the selected tier requires it.
5. Treat persistence, migrations, dates, time zones, notifications, privacy, destructive actions, and dependency changes as high risk.
6. Keep user-facing language calm and nonjudgmental. Do not introduce streak punishment, moral scoring, or shame.
7. Update acceptance tests and source-of-truth documentation when behavior changes.
8. Run the authoritative repository quality command once it exists. Until the Xcode project is created, validate documentation links, tracker consistency, and the complete diff.
9. Finish with a factual summary of files changed, validation performed, and remaining risk.

## Product Boundaries

Do not add social competition, leaderboards, calorie counting, medical claims, cloud accounts, or third-party data sharing without an explicit roadmap and decision update.

Prefer local-first behavior, reversible edits, accessible SwiftUI, minimal data collection, and small understandable models.

## Git Conventions

- Use short imperative commit messages.
- Check repository status before and after work.
- Do not mix unrelated cleanup into a feature or bug fix.
- Never commit secrets, signing material, provisioning profiles, or personal wellness data.
