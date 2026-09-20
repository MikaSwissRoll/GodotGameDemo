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

## Tests — the suite is FROZEN

**The automated test suite is frozen. Do not run it, do not add to it, and do not
wait on it.** `tests/` was emptied deliberately and no longer exists as a
harness: there is no runner, no suite, and nothing to invoke. Any command of the
form `.\tests\run_tests.ps1 ...` will simply fail.

Do not restore the old suites from Git history on your own initiative. If testing
is ever wanted again, that is a decision for the user, not a step in a task.

Verify changes the way the rest of this file describes instead:

- read the code you changed and the code that calls it;
- run the project and watch the parser, runtime, and resource output;
- for visual, UI, environment and scene work, take a rendered capture and inspect
  the actual pixels (`tools/capture_visual_qa.ps1`, `docs/visual_qa.md`);
- drive the affected flow by hand in a running build and say what you saw.

Never claim a change is verified because tests pass — there are no tests.
`docs/TEST_WORKFLOW.md` keeps what the suite taught us; read it before writing
any new test.

## UI Development

For significant UI, HUD, menu, dialogue, shop, or interface work, read and
apply:

- `docs/art/UI_VISUAL_RULES.md` for visual language and hierarchy;
- `docs/ui/UI_WORKFLOW.md` for creation, repair, capture, and verification;
- `docs/ui/UI_KNOWN_FAILURES.md` for project-specific failure diagnosis; and
- `docs/ui/UI_ASSET_GUIDE.md` for measured reusable assets.

Use existing assets from `asset/UI Elements/UI Elements` and
`asset/Shikashi's Fantasy Icons Pack v2` before default Godot controls,
`ColorRect` panels, or placeholder icons. Inspect the exact file and measured
geometry before use.

Treat rendered pixels as the source of truth. Distinguish the logical `Control`
rect, the complete painted silhouette, and the usable front-facing content
plane. Text on beveled or extruded art must be centered on the content plane,
not blindly on the rect or full shadowed silhouette.

Use this default UI loop:

```text
Inspect
-> Select affected states and contracts
-> Implement
-> Capture the target UI state
-> Inspect rendered pixels
-> Fix the measured cause
-> Recapture and compare
-> Re-run the affected flow by hand
```

For visual-only changes, a deterministic target capture and visual comparison
are the default verification. Do not play through the whole game to reach a UI
state. There is no test suite to lean on, so verification is a fresh rendered
capture plus driving the affected interaction by hand: menus, focus, modal
visibility, purchases, and scene navigation each have to be opened and looked at.

Capture the full viewport for context and add a crop only for measurement.
Check affected normal, focus, pressed, disabled, empty, full, long-Chinese-text,
and affordability states when relevant. Shared components require isolated
component coverage and captures of materially affected screens.

A UI task is not complete because it loads or logs no errors. It requires a
fresh rendered capture, a concrete visual review, and a hand-driven check of the
affected flow. Keep temporary screenshots out of Git unless they are useful
long-term references.

## Companion / Follower Systems

For work involving recruitable companions, follower AI, party-member combat,
formation or follow behavior, follower targeting, follower damage and downed
states, or companion recruitment, read and apply:

- `docs/FOLLOWER_SYSTEM_WORKFLOW.md` for the change workflow, invariants,
  failure signatures, and test matrix; and
- `docs/systems/FOLLOWER_SYSTEM.md` for the current architecture and tuned values.

Before changing follower behavior, inspect the current implementation and
preserve its documented invariants. Most follower regressions are a violated
invariant rather than a missing feature.

Route every "is this a valid target" question through
`scripts/systems/party.gd`. The project has two hostile classes with no shared
base (`Enemy` and `ArcherEnemy`), so a type test or a direct `.health` read will
silently exclude one of them.

For substantial follower changes, validate incrementally rather than implementing
recruitment, following, combat, targeting, and recovery before the first runtime
check. With the suite frozen, "validate" means build one layer and go watch it in
a running game:

```text
Inspect the foundation and the actual assets
-> Decide common vs class-specific behavior
-> Implement one layer
-> Run the project and drive that one layer by hand in Classic Mode; there is no
   companion suite to lean on, so watch the enemy targeting and the party state
   live rather than assuming they still work
-> Inspect a rendered capture for formation and combat readability
-> Continue
```

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
- after implementing, exercise the affected old behavior by hand in the running
  project, since nothing automated will catch a regression for you.

A new feature is not complete if it breaks an existing working feature.

### Completion Criteria

Do not declare a task complete until:

- the requested player-facing behavior exists;
- the project runs;
- relevant gameplay and UI flows were exercised in a running build and observed;
- persistent parser and runtime errors are resolved;
- affected existing features still work; and
- important assumptions and known issues are documented.

### Final Response

After completing a task, report concisely:

1. What was implemented
2. Major files and scenes changed
3. Important assumptions
4. How it was verified by hand — the test suite is frozen, so do not report a
   test run; report what you ran in the project and what you observed
5. Known issues, if any

Do not provide a long tutorial unless requested.
