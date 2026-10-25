# Decision 002: Platform and Persistence Foundation

## Context

Cadence needs a native foundation before product implementation begins. Its core workflows store private wellness information, depend on local-calendar correctness, permit historical edits, and require safe schema evolution. Future multi-device sync is desirable but is not part of V1.

The initial development Mac had Xcode 26.4.1 and the iOS 26.4 SDK installed. The selected iOS 27 target requires Xcode 27 or later and the iOS 27 SDK.

## Decision

Cadence V1 is an iPhone-only, portrait-only SwiftUI application with a minimum deployment target of iOS 27.0.

The project and display name are Cadence, the bundle identifier is `com.thefirstcaptain.cadence`, and Xcode automatic signing uses the user's selected Apple development team.

V1 uses SwiftData for local-only persistence behind repository/service interfaces. Production explicitly configures CloudKit synchronization as disabled, and automated tests use in-memory storage.

The first schema is versioned and remains compatible with a future private CloudKit database:

- Persisted records use app-generated UUIDs.
- Business uniqueness is enforced by repository logic rather than SwiftData unique constraints.
- Relationships are optional and define inverses where inference is unreliable.
- Models do not use deny deletion rules.
- New fields require safe defaults or optionality.
- Time-based records preserve precise timestamps and the original local-date and time-zone context needed for stable History.

Enabling iCloud is a separate Tier 3 feature. It must add capabilities intentionally and validate migration of existing local data, offline behavior, concurrent edits, conflicts, deletion propagation, account changes, and multi-device recovery before release.

Domain, repository, calendar, and aggregation tests use Swift Testing with in-memory persistence and injected clock/calendar dependencies. Complete user workflows use XCTest UI. One repository-owned quality command is authoritative both locally and in GitHub Actions.

## Consequences

- V1 remains private and fully usable without network access or an iCloud account.
- The project can use modern iOS 27 and SwiftData APIs without compatibility branches for older systems.
- iPad and landscape layout work is intentionally excluded.
- Repository isolation improves testability and limits SwiftData coupling.
- CloudKit compatibility constrains schema design now but avoids a predictable future rewrite.
- An Xcode 27 toolchain is required before project creation or validation.
- Xcode's license and first-launch components must be completed by the user before build tooling can run.
- Future CloudKit adoption still requires dedicated migration and conflict testing; compatibility does not make sync risk-free.

## Alternatives considered

- Support older iOS releases: rejected because the user selected the latest major platform for a focused personal V1.
- Universal iPhone and iPad support: rejected to keep the first interface and validation matrix focused.
- Direct SwiftData access from SwiftUI views: rejected because it would couple product logic to persistence and make deterministic tests and future migration harder.
- Use SwiftData features incompatible with CloudKit and redesign later: rejected because future sync is plausible and the known constraints are inexpensive to respect now.
- Enable CloudKit immediately: rejected because V1 is intentionally local-only and sync requires its own product, privacy, migration, and conflict decisions.
- Use XCTest for every test: rejected because Swift Testing is the clearer default for parameterized domain and service behavior, while XCTest UI remains necessary for end-to-end interface workflows.
- Maintain separate local and CI validation policies: rejected because one shared command prevents drift.

## References

- [Apple: Syncing model data across a person's devices](https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices)
- [Apple: Xcode release notes](https://developer.apple.com/documentation/xcode-release-notes)
