# CLAUDE.md — Godot 4 (Arknights-like TD)

Source spec: IMPLEMENTATION_PLAN.md :contentReference[oaicite:0]{index=0}

## Non-negotiables
- **NO GIT COMMANDS.** Never run/print `git` commands.
- **ECS-first.** Prefer an Entity+Components+Systems layout over deep inheritance.
- **All cross-node/script communication via MessageBus signals only** (`scripts/global/message_bus.gd`). No direct calls, no singletons talking to each other directly, no `get_node()` wiring for gameplay flow.
- **Prefer `@export` vars** for configuration and references; avoid hard links between nodes/scripts.
- **Data-driven:** favor **Resources in `data/`** for unit/wave/map definitions (no hardcoded stats).

## Core rules (from the plan)
- **Grid is truth:** all gameplay uses `Vector3i` cells; world coords are visuals only; ranges/distances are grid units (Manhattan). :contentReference[oaicite:1]{index=1}
- **Unified unit model:** player units + enemies share the same component set; behavior differs by faction/roles/data. :contentReference[oaicite:2]{index=2}
- **Enemies follow predefined lanes; blockers stop them; no rerouting around blockers.** :contentReference[oaicite:3]{index=3}
- **Setup phase deployment** onto deployable tiles; validate tile + occupancy + DP; choose facing. :contentReference[oaicite:4]{index=4}
- **Waves are scripted via Resources** (groups with start_time/interval/count). :contentReference[oaicite:5]{index=5}

## Implementation style
- Keep scripts small, single-purpose, testable.
- Prefer composition:
  - Components: `GridPos`, `Stats`, `Faction`, `Targeting`, `Attack`, `Blocker`, `Mover`, `Health`, `OccupancyRef`
  - Systems: `GridService/MapScan/PathBuild`, `MoveSystem`, `TargetSystem`, `AttackSystem`, `BlockSystem`, `WaveSystem`, `GameFlowSystem`
- Emit MessageBus events like: `unit_spawned`, `unit_died`, `cell_occupied`, `cell_freed`, `dp_changed`, `phase_changed`, `wave_started`, `wave_ended`, `enemy_exited`.

## Output expectations
- Write code that compiles in Godot 4.
- Use `class_name` and typed GDScript.
- Prefer Resources + `@export` over scene hard-coding.
- When unsure, follow the spec above exactly.

## Local-only execution
- **LOCAL MODEL ONLY.** Do not use or reference any remote/hosted model (e.g., Claude/Sonnet/Opus) or any provider APIs.
- **Do not change models.** Never suggest running `/model` or switching to a different hosted model.
- If the configured model is missing/unavailable, **stop** and explain: “Your local model config is invalid/unavailable; fix the local LLM selection/config and rerun.” Do not attempt any remote fallback.
- **No web access.** Do not browse, fetch URLs, or rely on external documentation at runtime.

## Memory
- **MEMORY DISABLED.** Do not recall, store, embed, summarize, or index any past sessions or project memory.
- Do not run any “recall”, “remember”, “explore memory”, or vector/embedding steps.
- Rely only on the current workspace files explicitly read in this session and this `CLAUDE.md`.
- If the toolchain attempts a memory step, **stop** and tell the user to disable memory in the runner config.


# Local LLM Constraints (IMPORTANT)

This project is being worked on with a local LLM that can stall on long, silent reasoning
or when context grows too large. Optimize for reliability over elegance
When performing long refactors or analysis, always emit progress updates
or partial results at least every 1–2 minutes. Never remain silent
for extended periods of time.

Never read more than one file per step.
After reading a file, summarize it in <500 tokens.
Do not keep raw file contents in context.

1) Anti-context-bloat rules (most important)

Never paste full file contents into responses.

Summarize each file immediately after reading (short bullets).

Keep only:

public API (signals, exported vars, function signatures)

TODO list

exact change plan

Max 1 search per step.

Prefer small diffs

NEVER seek approval for plans or file edits.

