# Current task: main menu visual redesign

## Goal

Replace the oversized generic overlay composition with a compact, polished Tiny
Swords title screen whose hierarchy is title, primary action, secondary actions,
and visible world background.

## Existing systems affected

- Roguelite main-menu presentation in `scripts/ui/run_ui.gd`.
- Shared Tiny Swords UI helpers only if a reusable visual primitive is needed.
- Main-menu visual QA captures and documentation outcome.

## Important assumptions

- Start Game, Classic Adventure, and Quit Game behavior remains unchanged.
- Reward, shop, pause, and result overlays keep their existing functional flow.
- The title screen uses the existing arena background and Tiny Swords UI assets.
- Corner gameplay decoration or controls should not compete with the menu.

## Implementation phases

1. Capture and inspect the current menu and relevant Tiny Swords UI sheets.
2. Separate the title screen composition from the generic modal overlay.
3. Build a compact title group and short, proportionate action buttons.
4. Reduce global dimming and hide non-menu HUD or corner distractions.
5. Run at least two screenshot, critique, and revision cycles.
6. Verify all three menu actions remain wired and inspect the final render.

## Test plan

- Capture the baseline, intermediate, and final main-menu screenshots.
- Score hierarchy, readability, proportion, Tiny Swords consistency, background
  integration, and professional finish against the supplied rubric.
- Capture shop or pause once to ensure shared modal presentation still renders.
- Run the existing menu and roguelite smoke test after the visual work.

## Out of scope

Gameplay balance, combat systems, world reconstruction, new assets, and changes
to the existing Godot MCP.