---
task: T-008
status: blocked
slice: audit-trail
kind: verify
depends_on: [T-005, T-007]
---
# T-008 — Verify: Allocation Ledger Entry rows persist after successful posting

User-facing slice `audit-trail`: after successful `Post` on balanced allocation, audit trail surfaces one `Allocation Ledger Entry` row per resolved allocation, queryable from `Posted Sales Invoice`.
