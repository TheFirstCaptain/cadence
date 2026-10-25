# Cadence Development Plan

## Technical direction

- SwiftUI for the interface.
- A simple local persistence layer, with SwiftData as the likely starting point.
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

- Approve the platform target and create the Xcode project.
- Define data models and persistence boundaries.
- Establish navigation and the visual theme.

### 2. My Day and My Goals

- Build Sunday Planning in My Goals for the upcoming Monday-through-Sunday week.
- Support Daily, Weekly, and Custom 2–6-times-per-week frequencies.
- Carry Goals forward and preserve History across midweek changes.
- Build My Day with Goals first and iCheated second.
- Build today's one-tap goal checkoff experience.
- Add a simple weekly progress summary.

### 3. iCheated expansion

- Validate the initial five-category quick-log flow.
- Add custom indulgence types when separately approved.
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
