# Current task: classic menu return and HUD separation

## Goal

Fix two classic-mode defects:

1. Returning to the title from classic mode must open the unified roguelite main
   menu instead of reloading the legacy "Tiny Kingdom" menu.
2. The classic quest objective and gold groups must remain visually separate at
   the top of the viewport.

## Existing systems affected

- `scripts/main/game.gd` classic scene navigation.
- `scripts/ui/game_ui.gd` classic HUD layout.
- `tests/smoke_game.gd` classic title-return expectation.
- A focused classic UI regression test.
- The existing `village` visual QA target.

## Important assumptions

- Restart continues to restart classic mode.
- The classic entry menu remains available when classic mode first opens.
- The longest current active-quest text must fit on one row without entering the
  gold icon or value.
- Gameplay, balance, and the roguelite HUD remain unchanged.

## Implementation phases

1. Capture the current classic village HUD.
2. Route classic title requests to `run_game.tscn`.
3. Give the quest group enough width and a fixed gap before the gold group.
4. Add a focused regression for HUD separation and title navigation.
5. Capture the updated village HUD and compare.
6. Run the focused test and check Godot runtime output.

## Test plan

- Compare before and after `village` captures at 1280 by 720.
- Check the longest active quest text against the gold icon and label.
- Verify classic `title_requested` changes to `run_game.tscn`.
- Confirm the unified main menu is paused and visible after the transition.
- Run Godot's project parse check.

## Out of scope

Removing the classic entry menu, redesigning the full HUD, changing the
roguelite UI, gameplay changes, and a full-game playthrough.

## Outcome

- Classic title requests now open `run_game.tscn`, while restart still reloads
  classic mode.
- The quest group is pinned before the gold group, sizes itself from the current
  objective text, and keeps its shield beside the text.
- The `village` capture target now stages the longest active quest progress
  state.
- `tests/classic_ui_smoke.gd` verifies HUD separation and the scene transition.
- The focused test and Godot parse check passed.
- The final 1280 by 720 capture was inspected in full and at the HUD crop. The
  active objective is complete and separated from the gold group.
