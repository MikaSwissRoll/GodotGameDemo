# Current task: overlay polish, HUD layout, and porting to classic mode

## Goal

Four related UI requests:

1. Improve the **战技选择** (reward) and **行商营地** (shop) overlays.
2. Move the **battlefield info** (stage/enemy count) to the left of the gold
   readout so both sit on the top-right row.
3. Give the **生命药水 / 精力药水 / 战技** block a background again.
4. Port these HUD and overlay changes to **经典冒险** (classic mode).

## Existing systems affected

- `scripts/ui/run_ui.gd` — roguelite HUD and shared modal (items 1-3).
- `scripts/ui/game_ui.gd` — classic HUD and its own modal (item 4).
- `scripts/ui/tiny_bar.gd` — reused as-is; classic adopts it.

## Important assumptions

- Classic mode keeps its own characteristics: it has a quest banner, a merchant
  that sells potions only, and `继续探索` / `重新开始` result wording. Only the
  presentation is unified, not the flow.
- The classic quest label moves to the gold row to match the stage label, since
  both are the same kind of persistent objective readout.
- No gameplay, balance, scene, or asset changes.

## Implementation phases

1. ✅ Move the stage readout onto the gold row (item 2).
2. ✅ Add a backing panel behind the potion/build block (item 3).
3. ⏳ Restyle the reward modal's skill rows and body text, and give the shop modal
   the same treatment (item 1).
4. ✅ High-ground ballistics: high shots may fall to the low ground, low shots
   may not reach a plateau (item 5).
5. ⏳ Port to classic: `TinyBar` for health/stamina, unlabelled stacked bars, no
   dark backing panels, text outlines, quest on the gold row, potion block
   background, paper modal with adaptive height and a red title-return action
   (item 6).

## High-ground ballistics (item 5)

The complaint was that a plateau looked wrong for ranged combat, not that the
player got stuck: the archer behind a cliff could not be answered and its own
shots died on the cliff wall directly beneath it.

`tiny_swords_environment.gd` now keeps an elevation registry. `begin_world()` is
called by `world.gd` and by `run_arena.configure()` so a reloaded scene or a new
arena stage never inherits another world's plateaus, and `add_plateau()`
registers each footprint. `elevation_at()` and `plateau_at()` answer whether a
point is high ground; `cliff_y_of()` gives a plateau's drop line.

`EnemyArrow` carries `from_high_ground` and `origin_plateau`, set by the archer at
spawn, and applies two rules:

- **high to low** — a shot loosed from a plateau ignores the wall at its own
  cliff line, so it clears the edge and lands on the ground below;
- **low to high** — a shot loosed from the low ground passes under a target
  standing on a plateau (`_may_strike`), so shooting uphill is refused.

Any other wall still stops an arrow in both cases.

`tests/ballistics.gd` is a new permanent regression covering all three cases:
high-to-low hits, low-to-high is refused, level ground still hits.

## Test plan

- Run all seven harnesses after each phase.
- Capture and inspect `combat`, `shop_overlay` and `result_dead` plus the classic
  targets `village` and `dialogue_ui`.
- Add a `reward_overlay` visual QA target, since the reward modal is item 1 and
  currently has no target.

## Out of scope

Gameplay balance, combat, world layout, new assets, and the Godot MCP setup.
