# Legacy AL Refactor Plan — 11 steps

Phased process for refactoring legacy AL code that ships **without sufficient tests**. From https://alguidelines.dev/docs/agentic-coding/gettingmore/refactoring/.

## When to use this

- **Standalone refactor of legacy code** — code that predates this plugin's TDD flow, lacks behaviour-verifying tests, or has tangled responsibilities.
- **Not** for the post-green refactor inside `/al-implement` — that uses `/al-refactor`'s inline discipline (tests already exist, R→P→W boundary already drawn, brownfield touchpoints already named in `architecture.md`).

The 11-step plan complements the inline `/al-refactor` discipline; it does not replace it. Use this when there is no calling task and no architecture document.

## Preconditions

- Code is version-controlled.
- You can build and run the app (`/al-build` works).
- You're prepared to write tests *before* changing behaviour — not after.

## The 11 steps

**Step 1 — Write tests first.**
Write comprehensive tests verifying current behaviour before any refactoring. Tests pass with existing code and catch regressions. This establishes the safety net.

**Step 2 — Initial assessment.**
Analyse the code, identify refactoring opportunities, categorise issues as Critical / Major / Minor. Document problems and proposed solutions.

**Step 3 — Create a refactoring plan.**
Break the work into phases. Each phase has specific changes and a risk level. Plan to run tests after every phase. Sequence phases low-risk → higher-risk.

**Step 4 — Run your tests.**
Before refactoring anything, verify all tests pass. Confirm green baseline.

**Step 5 — Phase 1: safe refactorings.**
- Rename variables descriptively (BC vocabulary).
- Add XML documentation.
- Extract magic numbers to constants.
- Improve formatting and add comments where the WHY is non-obvious.

**Step 6 — Run tests after Phase 1.**
Confirm no behaviour change. Address any failure before Phase 2.

**Step 7 — Phase 2: structural improvements.**
- Extract separate procedures for distinct responsibilities.
- Replace `Message()` with proper `Error()` for validation failures.
- Add error handling.
- Improve string formatting.

**Step 8 — Run tests after Phase 2.**
Confirm structural changes maintain functionality.

**Step 9 — Phase 3: API modernisation.**
- Replace deprecated `Find('-')` with `FindSet()`.
- Add `SetLoadFields` for performance.
- Implement proper transaction handling.
- Replace hard-coded values with configuration tables (Setup table or similar).
- BC v24+: replace `NoSeriesManagement` with `codeunit "No. Series"`.

**Step 10 — Update tests for behavioural changes.**
Modify tests to reflect intentional behaviour changes (e.g. `Message` → `Error` flips a previously-silent branch into an error case). Update assertions for the new error-handling shape.

**Step 11 — Expand test coverage.**
Add tests for edge cases and error conditions. Test each extracted procedure independently. Increase overall coverage so the next refactor has an even stronger safety net.

## Post-conditions per phase

- All tests pass without modification (until Step 10, where intentional behavioural changes update tests alongside).
- Code-quality metrics improve.
- No performance degradation.
- Modern AL practices applied throughout.

## Composition with the rest of the plugin

- After Step 1's tests exist, the rest of the plan composes naturally with `/al-refactor` — the inline *Architecture* and *Simplification* sections of that skill are effectively Phases 1 + 2 of this plan, with the second-opinion gate and `/al-build` after every meaningful change.
- If during Phase 2 or 3 a hidden requirement or design flaw surfaces, halt and recommend `/al-design` (architecture reshape) or `/al-refine` (Gherkin reshape) via `/al-steer`. **No silent scope expansion.**
- If R→P→W boundary work surfaces during Phase 2/3, that's `/al-refactor` Replan trigger #6 — set `[!]` if there's a calling task, otherwise note and recommend `/al-steer`.
