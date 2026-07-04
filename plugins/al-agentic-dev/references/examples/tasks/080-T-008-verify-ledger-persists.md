---
task: T-008
status: blocked
blocked-on: slice technical tasks T-005, T-007 not yet done; verify opens behind the per-slice review gate
slice: audit-trail
kind: verify
depends_on: [T-005, T-007]
---
# T-008 — Verify: Allocation Ledger Entry rows persist after successful posting

User-facing slice `audit-trail`: after successful `Post` on balanced allocation, audit trail surfaces one `Allocation Ledger Entry` row per resolved allocation, queryable from `Posted Sales Invoice`.
