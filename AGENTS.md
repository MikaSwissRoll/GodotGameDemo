# Godot project rules

Build a small, playable top-down 2D pixel-art Action RPG demo. Keep each change
focused on the current vertical slice.

- Use Godot 4.7.2, GDScript, and the Compatibility renderer. Use Godot 4 APIs;
  avoid deprecated Godot 3 APIs.
- Use the `godot-gdscript-patterns` skill for relevant code patterns, but add
  state machines, Autoloads, Resources, and components only when useful here.
- Prefer scene composition and focused scripts over large monolithic scripts.
  Use typed GDScript when practical, `@export` for tunable gameplay values, and
  signals to decouple systems where appropriate.
- Use Godot's 2D nodes as needed: `CharacterBody2D`, `AnimatedSprite2D`,
  `AnimationPlayer`, `Area2D`, `CollisionShape2D`, `Camera2D`, `TileMapLayer`,
  and `Control` for UI.
- Keep enemy AI, combat, quests, HUD, and saveable configuration simple. Do not
  add multiplayer, backend services, procedural generation, crafting,
  inventory, or complex skill trees unless requested.
- Reuse the existing Tiny Swords assets. Inspect actual filenames before
  referencing them, and never overwrite original third-party assets.
- After significant gameplay changes, run the project, inspect parser,
  runtime, and resource errors, and fix them before continuing.
- For visual, UI, environment, and scene-design work, capture the rendered
  result when practical, inspect it with the agent's image capabilities, and
  iterate based on visual QA.
- Route art tasks through `docs/art/`: read `ART_DIRECTION.md` for all visual
  work; add `ENVIRONMENT_DESIGN.md`, `SCENE_DESIGN_WORKFLOW.md`,
  `UI_VISUAL_RULES.md`, or `ASSET_USAGE_RULES.md` for the matching task.
- Prioritize a working playable demo over architectural complexity.
- Use the configured Godot MCP proactively when useful for running the project,
  inspecting debug/runtime output, validating scenes/resources, and verifying
  gameplay changes. If a required MCP capability is unavailable, fall back to
  the local Godot CLI or other appropriate project tools.

## Autonomous Development Workflow

For all non-trivial development tasks in this project, the agent should work as
a product-minded game developer, Godot engineer, and QA tester rather than only
as a code generator.

### Default Workflow

When the user gives a high-level or partially specified goal:

1. Understand the intended player-facing outcome.
2. Inspect the relevant existing scenes, scripts, resources, signals, UI,
   assets, and architecture before editing.
3. Infer reasonable missing implementation details from the current game.
4. Prefer extending existing working systems over replacing them.
5. Form a concrete implementation plan before coding.
6. Implement in small, testable phases.
7. Run Godot after meaningful changes.
8. Inspect parser and runtime errors, broken resources, signals, UI issues, and
   regressions.
9. Fix issues autonomously and rerun.
10. Continue until the requested behavior is implemented and verified.

Do not stop after producing a plan.

### Handling Underspecified Requests

The user is not expected to provide a full technical specification. For
routine implementation details, make reasonable decisions yourself, including:

- scene and node structure;
- signal usage;
- Resources and exported values;
- state management;
- collision setup;
- UI structure;
- script organization;
- input wiring; and
- debugging approach.

When details are missing:

- preserve the current game direction and visual style;
- choose the smallest coherent feature set that satisfies the goal;
- avoid unnecessary systems;
- avoid overengineering; and
- document important assumptions.

Only ask the user when ambiguity materially changes the gameplay experience or
project scope, or requires destructive changes.

### Planning

For substantial tasks, create or update `docs/CURRENT_TASK.md`. Keep it
concise and include:

- Goal
- Existing systems affected
- Important assumptions
- Implementation phases
- Test plan
- Out of scope

After writing the plan, continue directly to implementation unless genuine
clarification is required.

### Godot Development

Follow existing project conventions and applicable Godot/GDScript skills. Use
available Godot MCP capabilities when useful for running, debugging, and
verifying the project. Do not edit code and assume it works.

Prefer this loop:

```text
Inspect
→ Plan
→ Implement
→ Run
→ Observe
→ Fix
→ Verify
→ Continue
```

### Scope and Architecture

Prefer solutions that are simple, maintainable, testable, and consistent with
the existing project. Avoid unnecessary abstractions, speculative future
systems, giant rewrites, and expanding a small request into a large feature
set. When the user gives a broad goal, implement the smallest meaningful
solution first.

### Regression Safety

When modifying an existing system:

- identify affected existing behavior;
- preserve unrelated working functionality; and
- test relevant old behavior after implementation.

A new feature is not complete if it breaks an existing working feature.

### Completion Criteria

Do not declare a task complete until:

- the requested player-facing behavior exists;
- the project runs;
- relevant gameplay and UI flows were tested;
- persistent parser and runtime errors are resolved;
- affected existing features still work; and
- important assumptions and known issues are documented.

### Final Response

After completing a task, report concisely:

1. What was implemented
2. Major files and scenes changed
3. Important assumptions
4. Tests performed
5. Known issues, if any

Do not provide a long tutorial unless requested.

