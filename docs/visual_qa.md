# Visual QA workflow

This project uses a small Godot viewport capture harness for visual review. The
existing Godot MCP remains the normal tool for launching the game and reading
runtime output. Its current tool set has no screenshot command, so the harness
captures the rendered 1280 by 720 game viewport with Godot's own rendering API.

## Capture a screen

From the project root, run:

```powershell
.\tools\capture_visual_qa.ps1 -Target main_menu
```

The launcher waits for Godot to finish and writes the PNG to
`screenshots/visual_qa/main_menu.png`. It uses `GODOT_PATH` when set, accepts an
explicit `-GodotPath`, and otherwise checks the project's current Windows Godot
location.

Use `-Output` to keep comparison images:

```powershell
.\tools\capture_visual_qa.ps1 -Target main_menu `
  -Output res://screenshots/visual_qa/main_menu_before.png
.\tools\capture_visual_qa.ps1 -Target main_menu `
  -Output res://screenshots/visual_qa/main_menu_after.png
```

## Supported targets

| Target | Captured state |
| --- | --- |
| `main_menu` | Live classic town with the side menu |
| `main_menu_focus` | Expedition action focused |
| `main_menu_pressed` | Classic action held through a viewport mouse event |
| `menu_transition` | Halfway through the classic camera zoom |
| `classic_entry` | Same town after the camera handoff, with classic HUD |
| `town_overview` | Town overview without the side menu |
| `village` | Classic village and HUD with the active quest progress text |
| `wilderness` | River crossing and borderland |
| `enemy_camp` | Red faction camp and enemies |
| `combat` | Active roguelite combat room |
| `stamina_low` | Stamina driven just past the shallow warning line (30) |
| `stamina_deep` | Stamina driven past the deep warning line (20) |
| `stamina_denied` | A refused action: the denial signal the player emits when a press cannot be afforded |
| `stamina_exhausted` | Guard break reached through a real underfunded block |
| `merchant_shop` | Roguelite merchant encounter in the arena |
| `shop_overlay` | Four-action merchant modal, the tallest shared overlay |
| `result_dead` | Run-failed result reached by an actual player death |
| `dialogue_ui` | Village guard dialogue presentation |
| `pause_menu` | Paused roguelite run |
| `reward_overlay` | Roguelite upgrade selection |

Each target instantiates the real project scene, enters the requested state,
waits for rendered frames, freezes the state, and saves the viewport texture.
The title targets also freeze explicitly processing scenery, set resident
positions to their first route point, and fix sprite frames for repeatability.
The screenshot is the actual Compatibility renderer output rather than a mockup
or a reconstruction from node coordinates.

## Review loop

For UI, environment, map, and visual polish work:

1. Read `art/ART_DIRECTION.md` and the matching documents under `docs/art/`.
2. Capture the current target with a `_before` filename.
3. Inspect the PNG with the agent's local image viewing.
4. Record concrete observations about hierarchy, contrast, alignment, density,
   clipping, readability, or scene composition.
5. Make one focused change.
6. Capture the same target with an `_after` filename.
7. Inspect both images and continue until the visible result is acceptable.
8. Use the Godot MCP or normal runtime checks for parser and runtime errors.

A scene loading without errors is only runtime verification. Visual work also
requires inspection of the rendered screenshot.

## Adding or adjusting a target

Target staging lives in `tools/visual_qa_capture.gd`. Keep target setup short
and deterministic: load an existing scene, use its public signals or state
methods, position the player or camera, wait for several frames, and capture.
Do not duplicate gameplay scenes just for screenshots.

The current dialogue target captures the guard toast because that is the
project's present dialogue presentation. Update that target if a dedicated
dialogue panel replaces it.

## Screenshot storage

Generated files under `screenshots/visual_qa/` are ignored by Git. Keep useful
before and after images locally while reviewing, then remove stale captures as
needed. Do not add large screenshot histories to source control.

## Verified example

The first tested loop captured `main_menu_before.png`. Inspection found that the
buttons extended beyond the wood panel's effective visual width, the pale
subtitle had weak contrast on the light banner, and the shield, title, and
subtitle competed at the panel top. The revised capture
`main_menu_after.png` uses narrower centered buttons, a centered shield and
title stack, and dark subtitle text. The updated layout keeps all three actions
inside the paper area and makes the menu hierarchy easier to scan.

## Live town ownership

The application starts in `scenes/main/town_title.tscn`. It holds the actual
classic game instance and a separate overview camera. `town_title.gd` owns the
protected transition; `town_menu.gd` owns the side menu. The classic world builds
its buildings and ambient residents through `starting_town.gd`.

The title flow used to be covered by `town_title_smoke`, which checked real
viewport mouse dispatch, paused player and enemy isolation, ambient activity,
continuous classic handoff, pause, merchant/guard interactions, restart, and both
mode-return routes. **That suite is gone: the test suite is frozen and `tests/` is
empty.** Those checks are now manual — open the title screen in a build and
operate it, using the `main_menu` and `classic_entry` capture targets for the
rendered half. See `TEST_WORKFLOW.md`.
