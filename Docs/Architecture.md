# Cadence Architecture

## Current state

Cadence is in documentation and project-foundation planning. No Xcode project or production code exists yet.

## Intended platform

- Native iOS application.
- SwiftUI presentation.
- Local-first persistence; SwiftData is the leading candidate but requires an explicit project decision.
- No account, server, analytics, or cloud dependency in the initial version.

## Responsibilities

- `App/`: composition root, navigation, dependency setup, scene lifecycle.
- `Models/`: weekly plans, commitments, completion records, indulgence types, and indulgence entries.
- `Views/`: My Week, Sunday Planning, iCheated, History, and settings flows.
- `Components/`: reusable controls and visual building blocks without feature ownership.
- `Services/`: persistence adapters, calendar/week calculations, notifications, and future integrations.

## Boundaries

- Views render state and send user intent; they should not own persistence rules.
- Calendar calculations belong in a testable service and must use explicit calendars, locales, and time zones.
- Persistence must be accessed through a narrow boundary so migrations and test stores can be validated.
- Notifications, if approved, remain optional and must degrade safely when permission is denied.
- Domain models must not encode moral scores, punitive streaks, or health claims.

## High-risk areas

- Schema changes and migrations.
- Week boundaries, daylight-saving transitions, locale, and time-zone changes.
- Editing or deleting historical records.
- Notification scheduling and permission state.
- Export, sync, analytics, or any movement of private wellness data.
- Accessibility regressions that block Dynamic Type, VoiceOver, contrast, or reduced motion.

## Architecture decisions still required

- Minimum iOS version and supported device families.
- Persistence framework and migration strategy.
- Bundle identifier and signing arrangement.
- Testing structure and any formatting or linting tools.
