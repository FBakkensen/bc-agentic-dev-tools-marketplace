# Spec artifact examples

Three populated examples demonstrating the markdown shape, surgical-edit anchor pattern, and Mermaid fence usage for `al-agentic-dev` spec artifacts.

| File | What it is |
|---|---|
| `event-model.example.md` | User-facing journey, Role swimlanes (Sales Document Posting / Item Charge Allocation Validation). |
| `architecture.example.md` | Module map, R → P → W boundary, brownfield touchpoints, Mermaid module-deps + flow. |
| `tasks.example.md` | Slice-grouped tasks with comment anchors, technical + verify across two slices, task-deps Mermaid. |

Pattern-match against these before generating a feature's `event-model.md`, `architecture.md`, `tasks.md`. Cross-links inside examples use `.example.md` suffix; generated artifacts drop it.

The example feature (Sales Document Posting / Item Charge Allocation Validation) is realistic but synthetic. ADR-0007 references are intentionally dead links.

See [`../markdown-spec-discipline.md`](../markdown-spec-discipline.md) for the shape contract.
