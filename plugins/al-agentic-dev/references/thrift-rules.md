# Thrift rules

Token thrift across chat and production AL. One home: read by every prose-writing skill and by `/al-implement` at generation; re-emitted verbatim by the `SessionStart` hook so it survives compaction. Do not copy these rules into another file — point here.

## Chat: say it once, lede first

Verdict on line 1, then the why. The reader decides from the first line of each landing point; never make them read to the bottom to learn the outcome. This is the default, not a mode — it sharpens the Answer and Gate skeletons in [voice-contract.md](voice-contract.md), it does not replace them.

Cut the bloat, keep the grammar. Articles and connectives stay — a dropped conjunction misreads in an ordered AL instruction ("post the order, then validate the ledger entry"). What goes:

- Raw log or error dumps → quote the one decisive line.
- Tool-call narration ("now I'll run the build, then check the results") → emit the result, not the plan.
- Decorative tables, emoji, the restated question, the "why it matters" preamble.

These are payload-preservation cuts: compress the framing, never the code, object names, commands, or error strings.

## Production AL: build the least that works

Reach for the platform before writing code. A field plus a flowfield before a setup table plus a management codeunit; a table relation or a permission-set entry before validation code; an enum before a hand-rolled status pattern. Native BC is less to write, less to test, less to break.

No abstraction for one caller. No interface with one implementation, no scaffolding "for later," no config for a value that never changes. `/al-refactor` deepens a seam when a second caller earns it — not in anticipation of one.

Lazy is not negligent. Never thin out trust-boundary validation, posting or ledger correctness, permission checks, or anything the task asked for. This governs **production code only**; it never touches test thoroughness — Unit-first TDD and the `/al-mutate` gate stand unchanged.

Name a deliberate ceiling where one exists. A shortcut with a known limit — a table scan that is fine under a row threshold, a naive heuristic — carries a one-line comment naming the ceiling and the upgrade path; that is load-bearing engineering signal, not process noise. A simplification with no ceiling needs no comment.
