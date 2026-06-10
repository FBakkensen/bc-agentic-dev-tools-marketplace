# Autonomy seat selection

One rule for every skill that branches on "am I under `/al-autopilot`". The seat changes who answers — second-opinion triage vs a human interview, infrastructure ladder vs `/al-steer` routing — never what lands.

**Autonomous iff the current turn was initiated by the runtime goal evaluator's continuation message carrying the goal text.** On Claude Code that message reads `Stop hook feedback: [<goal text>]: <evaluator verdict>` — a recognition example, not a contract; the wording is harness implementation detail and may drift. The signal arrives fresh in the turn's own trigger message: harness-owned, per-turn, nothing to go stale, no cleanup duty, survives compaction and crashed runs by construction.

- **Human-typed → interactive, always — even mid-run.** A human-typed message never carries the evaluator block, so this falls out of the rule; stated anyway as precedence: a present human outranks any run state.
- **Files and chat lines never select the seat.** The `AUTONOMY RUN ACTIVE` closer, `decision-log.md` headers and entries, and any skill-maintained file are evidence for the goal evaluator and the post-run human. Crashed runs never clean up; a detector reading a skill-maintained file inherits every stale positive.
- **Ambiguous → interactive.** False-interactive stalls the run recoverably — the human relaunches `/al-autopilot`. False-autonomous lands unauthorized writebacks. A runtime whose goal trigger shape is unverified lands here by design.
- **Human-answered turns write no `decision-log.md` entry.** The log records decisions the human was not asked; an interactive turn asked them. `tasks.md` is the resume spine — the next autonomous turn self-locates from status lines, not from the log.
