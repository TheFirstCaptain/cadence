# Cadence Development Plan

## Technical direction

- SwiftUI for an iPhone-only, portrait-only interface targeting iOS 27 or later.
- Local-only SwiftData behind a repository/service boundary.
- A versioned, CloudKit-compatible schema with app-generated UUIDs, optional relationships, explicit inverses where needed, and no persistence-level unique constraints.
- In-memory SwiftData configurations for automated tests.
- Swift Testing for domain, repository, calendar, aggregation, migration, and failure-path coverage.
- XCTest UI for complete product workflows.
- Injected clock and calendar dependencies for deterministic date tests.
- Small feature-focused views supported by reusable components and services.
- No Xcode project will be created until explicitly approved.

## Proposed source organization

- `App/` — app entry point, navigation, and shared app state.
- `Models/` — weekly plans, Goals, checkoffs, iCheated categories, and indulgence occurrences.
- `Views/` — My Day, My Goals, and History screens and flows.
- `Components/` — reusable controls, cards, progress indicators, and empty states.
- `Services/` — persistence, date/week calculations, and later integrations.
- `Docs/` — product, design, and implementation documentation.

## Delivery phases

### 1. Foundation

- Update to Xcode 27 or later and create the iOS 27 iPhone project after the remaining foundation decisions are approved.
- Define data models and persistence boundaries.
- Establish navigation and the visual theme.

### 2. My Day and My Goals

- Build Sunday Planning in My Goals for the upcoming Monday-through-Sunday week.
- Support Daily, Weekly, and Custom 2–6-times-per-week frequencies.
- Carry Goals forward and preserve History across midweek changes.
- Build My Day with Goals first and iCheated second.
- Separate Daily Goals into Today and Weekly or Custom Goals into This Week.
- Add the first-run Goals empty state, manual ordering, Apple-style symbols, and quiet accessible feedback.
- Build today's one-tap goal checkoff experience.
- Add a simple weekly progress summary.

### 3. iCheated expansion

- Validate the initial five-category quick-log flow.
- Add custom indulgence types when separately approved.
- Allow recent entries to be reviewed and corrected.

### 4. History

- Build current and prior Week views, calendar Month summaries, and day details.
- Show completed-of-target Goal counts and neutral iCheated totals without percentages or comparisons.
- Support reversible historical corrections and stable original local dates.

### 5. Polish and validation

- Add accessibility support, thoughtful empty states, and gentle feedback.
- Test week boundaries, Sunday planning, edits, and data persistence.
- Validate that core actions remain fast and the tone stays supportive.

## Decisions to make before project creation

- Select the user's Apple development team in Xcode automatic signing.
- Formatting, linting, documentation validation, and `Scripts/quality.sh` contents.
