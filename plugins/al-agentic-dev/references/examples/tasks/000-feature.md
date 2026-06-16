# Feature: Sales Document Posting, Item Charge Allocation Validation

| | |
|---|---|
| **Slug**         | sales-charge-validation |
| **ADR**          | ADR-0007 |
| **Event model**  | [../event-model.example.md](../event-model.example.md) |
| **Architecture** | [../architecture.example.md](../architecture.example.md) |
| **Tasks**        | 6 technical + 2 verify |
| **Slices**       | post-validates-allocation, audit-trail |

## Goal

Catch item charge allocation mismatches at posting before invoice posts, surface cause inline on document, produce deterministic audit trail tying each allocation back to source line.

> A fresh `/al-scope` run brackets the feature tasks with two ops tasks, omitted from the per-task files here to keep the focus on slice and proof shapes: a `T-001` `kind: provision` `slice: provision` task first (`/al-provision` refreshes the build environment) and a `kind: breaking-change` `slice: breaking-change` task last, `depends_on:` the final terminal task (`/al-validate-breaking-changes`). Both carry no proof section and run `ready` → `done`/`blocked`, bypassing `/al-refine`. The feature tasks shown here would shift to `T-002…` after provision.

## Slices

- **post-validates-allocation** — Order Processor releases and posts a `Sales Header` with `Item Charge Assignment (Sales)`. Balanced allocations post cleanly; mismatched allocations halt posting with an inline breakdown on `Sales Order Card`.
- **audit-trail** — after a successful `Post` on balanced allocation, the audit trail surfaces one `Allocation Ledger Entry` row per resolved allocation, queryable from `Posted Sales Invoice`.

## Execution order

The `NNN-` filename prefix is the run order; `ls tasks/` lists tasks as they execute. The `T-MMM` id is a stable locator, not an order key — note `050-T-006` (slice-one verify) runs before `060-T-005` (slice-two first technical), so id order and run order diverge on purpose.
