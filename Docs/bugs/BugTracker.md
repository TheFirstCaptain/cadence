# Bug Tracker

Track confirmed or suspected defects, regressions, compatibility problems, unsafe data behavior, and blockers.

Statuses: `Open`, `Investigating`, `Fixing`, `Validating`, `Resolved`, `Deferred`, and `Won't Fix`.

Priorities: `P0` blocks useful development or risks severe data loss; `P1` blocks a core workflow; `P2` is important but not broadly blocking; `P3` is minor or cosmetic.

Before resolving a bug, confirm it, add a regression test where practical, make the smallest correction, review data/privacy/accessibility impact, validate it, and update related records.

| ID | Title | Status | Priority | Bug document | Last updated | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| B-001 | Hosted quality run masked UI test failures | Resolved | P1 | [B-001.md](./B-001.md) | 2026-10-29 | Run `40971487838` correctly failed and uploaded evidence after result verification, pipeline propagation, and artifact-path guards were added. |
| B-002 | Hosted shell UI tests fail before feature content appears | Investigating | P1 | [B-002.md](./B-002.md) | 2026-10-29 | Three hosted runs failed the default shell tests while local full gates pass; retained run `40971487838` evidence awaits diagnosis. |
