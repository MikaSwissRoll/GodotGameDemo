# Current task: UI polish and HUD layout fixes

Status: complete. All reported display problems are fixed and verified by
capture, inspection, and the existing test suites.

## Goal

Fix the display problems found while inspecting the captured UI against
`docs/art/UI_VISUAL_RULES.md`. Player-facing behaviour and all game logic stayed
unchanged; this was layout, sizing, colour-state, and readability work only.

## Existing systems affected

- `scripts/ui/run_ui.gd` — roguelite HUD, main menu, modal overlays.
- `scripts/ui/tiny_swords_ui.gd` — shared panel and bar styleboxes.
- `tools/visual_qa_capture.gd`, `tools/capture_visual_qa.ps1` — two new targets.

Not affected: `scripts/ui/game_ui.gd` (classic adventure mode), gameplay
scripts, scenes, and assets.

## Root causes found and fixed

1. **`SpecialPaper`'s nine-patch does not paint at the Control's rect.** Isolated
   on a black backdrop it consistently painted `height - 27` (a 690x68 panel
   painted 41px; 135x52 painted 25px; 320x176 painted 149px; 540x53 painted 26px)
   and started ~20px below the declared top. Every HUD label therefore sat
   outside its own frame, which is the reported "the frame does not contain the
   text". The HUD boxes are only 50-180px tall, so the frame's fixed corner caps
   dominate them. HUD panels now use `TinySwordsUI.hud_panel_style()`, a flat
   slate box with a gold border that draws exactly at the declared rect. The
   large overlays keep the textured nine-patch, where it renders correctly.

2. **Labels were top-aligned inside their slot.** Godot's default
   `VERTICAL_ALIGNMENT_TOP` put the line box against the top of each label, so
   glyphs hugged the panel edge instead of sitting inside it. `_label()` now
   centres the line box vertically.

3. **The nine-patch also collapsed whenever `content_margin` was set**
   (measured 0.40 of the declared size with content margins versus 1.00 without).
   The content margins were removed from `panel_style()`.

4. **Bars conflicted with their own nine-slice.** `_bar()` forced 288x36 while
   `bar_background_style()` used 18px caps (36px total) and `bar_fill_style()`
   expanded -7px per side, so the middle stretch band collapsed and the fill was
   clipped. Caps are now 12px and the fill insets -6px inside a 40px bar.

5. **HUD sat outside the documented 20px viewport inset.** The stage panel's icon
   was 6px from the screen edge and icon-to-text spacing differed between panels.
   Both now use a 20px inset and 16px icon-to-text spacing.

6. **Panels were sized by guess.** The stats panel had 118px of room for 128px of
   content; the bottom panel was 690x90 for two short lines. Both are now the sum
   of their content with explicit padding.

7. **Main menu.** The three actions had three different widths (320/274/240) and a
   large empty area under the last button. All three are now 290x64 at a 76px
   pitch inside one card, and the shield no longer overlaps the card border or
   the title banner. The title banner is a solid stylebox rather than the ribbon
   sheet, whose tiles sit at offsets the nine-patch sampler cannot address.

8. **Subtitle contrast.** It used dark ink, but the card surface is dark
   (`#525b66`), not light paper. It now uses the warm light ink used elsewhere.

9. **HUD stayed visible behind the result overlay.** `_show()` set
   `hud_root.visible = next_mode != "menu"`, so `dead` and `win` kept the combat
   HUD under the modal. It is now shown only for `pause`, where the frozen HUD is
   the pause context the art rules ask for.

10. **Result overlay had a large dead area**, from a fixed 650x560 panel under two
    buttons. The panel now sizes to its action count with a floor that keeps the
    title and body from overlapping the first button.

11. **Missing destructive action state.** "返回主菜单" and "重新开始本局" used the
    blue affirmative style while the main menu's "退出游戏" was red. A per-mode
    danger map now gives cancelling actions the red state.

## Test plan and results

- All seven harnesses pass with exit code 0 and zero script/parser/resource
  errors: `smoke_game`, `playthrough`, `roguelite_smoke`,
  `roguelite_playthrough`, `collision_smoke`, `new_features_smoke`,
  `upgrade_effects_smoke`.
- Captured and inspected `main_menu`, `combat`, `pause_menu`, `shop_overlay`,
  and `result_dead`; each was reviewed against the art rules and re-captured
  until the reported problems were gone.
- Added `shop_overlay` (four-action modal, the tallest shared overlay) and
  `result_dead` (reached by an actual player death) as permanent QA targets.

## Out of scope

Gameplay balance, combat, world layout, new assets, new systems, and the classic
`game.tscn` HUD and its overlays.
