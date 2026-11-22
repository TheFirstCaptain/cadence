# Bug Tracker

Track confirmed or suspected defects, regressions, compatibility problems, unsafe data behavior, and blockers.

Statuses: `Open`, `Investigating`, `Fixing`, `Validating`, `Resolved`, `Deferred`, and `Won't Fix`.

Priorities: `P0` blocks useful development or risks severe data loss; `P1` blocks a core workflow; `P2` is important but not broadly blocking; `P3` is minor or cosmetic.

Before resolving a bug, confirm it, add a regression test where practical, make the smallest correction, review data/privacy/accessibility impact, validate it, and update related records.

| ID | Title | Status | Priority | Bug document | Last updated | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| B-001 | Hosted quality run masked UI test failures | Resolved | P1 | [B-001.md](./B-001.md) | 2026-10-29 | Run `40971487838` correctly failed and uploaded evidence after result verification, pipeline propagation, and artifact-path guards were added. |
| B-002 | Hosted shell UI tests fail on cold launch and adaptive navigation | Resolved | P1 | [B-002.md](./B-002.md) | 2026-11-08 | Original correction passed run `41036710609`; B-004 separately tracks the later discovery that exit status alone can accept failed simulator migration. |
| B-003 | Hosted UI tests can retain the app between cases | Resolved | P1 | [B-003.md](./B-003.md) | 2026-11-07 | Revision `7d963e2` centralizes test-owned app cleanup; local and hosted 102-test full gates passed, including run `42371290847`. |
| B-004 | Simulator readiness can accept failed data migration | Resolved | P1 | [B-004.md](./B-004.md) | 2026-11-08 | Fail-closed readiness validation and serialized destination ownership passed local and hosted 102-test full gates, including run `42528236848`. |
| B-005 | Hosted test clones can lose simulator services | Resolved | P1 | [B-005.md](./B-005.md) | 2026-11-08 | Revision `cca0eaf` keeps the authoritative suite on the prepared simulator; run `42528236848` passed all 102 tests without a private clone. |
| B-006 | Hosted Day History back navigation query fails on iOS 27.2 | Resolved | P1 | [B-006.md](./B-006.md) | 2026-11-22 | Both affected iOS 27.2 History navigation tests and the complete 143-test gate passed in immutable run `45030208178`. |
| B-007 | Hosted quality stalls can consume artifact-upload window | Resolved | P1 | [B-007.md](./B-007.md) | 2026-11-22 | Revision `c9ac429` adds the process-group watchdog and upload reserve; immutable run `45030208178` passed the complete 143-test hosted gate. |
