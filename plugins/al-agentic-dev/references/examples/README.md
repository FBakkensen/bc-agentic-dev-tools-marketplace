# Spec artifact examples

Populated examples demonstrating the markdown shape and surgical-edit anchor pattern for `al-agentic-dev` spec artifacts.

| File | What it is |
|---|---|
| `event-model.example.md` | User-facing journey, Role swimlanes (Sales Document Posting / Item Charge Allocation Validation). |
| `architecture.example.md` | Module map, R → P → W boundary, brownfield touchpoints. |
| `tasks/` | The `tasks/` folder shape: `000-feature.md` header (Goal + slice intent) plus one `NNN-T-MMM-slug.md` frontmatter file per task, technical + verify across two slices. |

Pattern-match against these before generating a feature's `event-model.md`, `architecture.md`, and `tasks/` folder. Cross-links inside the single-file examples use the `.example.md` suffix; generated artifacts drop it. The `tasks/` example files carry no `.example` suffix — the folder name disambiguates — and link up to the sibling examples with `../`.

The example feature (Sales Document Posting / Item Charge Allocation Validation) is realistic but synthetic. ADR-0007 references are intentionally dead links.

See [`../markdown-spec-discipline.md`](../markdown-spec-discipline.md) for the shape contract.
