# Cadence Development Plan

## Technical direction

- SwiftUI for the interface.
- A simple local persistence layer, with SwiftData as the likely starting point.
- Small feature-focused views supported by reusable components and services.
- No Xcode project will be created until explicitly approved.

## Proposed source organization

- `App/` — app entry point, navigation, and shared app state.
- `Models/` — weekly plans, commitments, completion records, indulgence types, and indulgence entries.
- `Views/` — My Week, Sunday planning, iCheated, and History screens.
- `Components/` — reusable controls, cards, progress indicators, and empty states.
- `Services/` — persistence, date/week calculations, and later integrations.
- `Docs/` — product, design, and implementation documentation.

## Delivery phases

### 1. Foundation

- Approve the platform target and create the Xcode project.
- Define data models and persistence boundaries.
- Establish navigation and the visual theme.

### 2. My Week

- Build Sunday planning for a small set of commitments.
- Build today's one-tap checkoff experience.
- Add a simple weekly progress summary.

### 3. iCheated

- Add custom indulgence types.
- Build the quick-log flow.
- Allow recent entries to be reviewed and corrected.

### 4. History

- Show past weeks and daily details.
- Summarize useful patterns without scores or judgment.

### 5. Polish and validation

- Add accessibility support, thoughtful empty states, and gentle feedback.
- Test week boundaries, Sunday planning, edits, and data persistence.
- Validate that core actions remain fast and the tone stays supportive.

## Decisions to make before project creation

- Minimum supported iOS version.
- iPhone-only or universal iPhone/iPad support.
- Final bundle identifier and development team.
- Whether SwiftData is acceptable for the first release.
