# Current Task — Expedition: terrain knolls, run stats, and the result screen

## Goal

Two changes to Expedition mode.

1. **A small raised knoll on every expedition stage.** Done.
2. **Run telemetry and a redesigned result screen.** Not started. Track the shop
   purchase record, a run timer, and a damage counter, and show all three on the
   redesigned 远征胜利 / 远征失败 screen.

## Existing systems affected

| System | Where | Why it matters |
| --- | --- | --- |
| Stage terrain | `scripts/world/run_arena.gd` | six stages, `configure(stage)`, `MainGround` = `Rect2i(1, 1, 18, 10)` |
| Run state | `scripts/main/run_game.gd` | owns gold, potions, upgrades, enemy spawning |
| Run UI | `scripts/ui/run_ui.gd` | HUD, shop, `show_rewards`, and the `complete` / `game_over` overlay |
| Shop | `run_game.gd` `_buy_*` | where a purchase would be recorded |
| Damage | `scripts/player/player.gd`, enemy scripts | damage is dealt in several places; there is no single counter today |
| Result screen | `run_ui.gd` `_show_overlay(..., "complete"/"game_over", ...)` | the screen being redesigned |

## Phase 1 — terrain knolls (DONE, `ec419ab`)

Six rects, three tiles at most either way, one per stage, each a palette distinct from
both the stage ground and its landmark patch. No stair is declared, so each knoll is
sealed: full-width wall, collision on all four edges. Kept to the lower half of the
arena where the stage builders place no buildings, and inside `MainGround` so every wall
row lands on ground.

**Outstanding: not yet looked at in a rendered capture.** Elevation changes are supposed
to get a visual check (`AGENTS.md`, "Elevation / High Ground"), and this one has not had
it. Do that before calling Phase 1 finished.

## Phase 2 — run telemetry

Three counters, all reset when a run starts.

- **Timer.** Wall-clock seconds since the run began, stopped when the run ends. Must not
  advance while the game is paused for the shop or the pause menu.
- **Damage dealt.** Accumulated across every source that damages an enemy. There is no
  single funnel today, so the honest options are: add one, or sum at the few call sites.
  Prefer a funnel — a counter incremented in several places drifts the moment someone
  adds a new damage source.
- **Shop purchases.** A list of `(what, price)` in the order bought, plus a total spent.

Where they live: on the run state, not on the UI. The result screen reads them; so could
a future save or a score screen.

## Phase 3 — the result screen

Redesign 远征胜利 / 远征失败 to present:

- the outcome, prominent;
- **elapsed time**;
- **damage dealt**;
- **the purchase record** — each purchase with its price, and the total spent;
- the existing rewards / restart affordances, kept reachable.

Design notes: this is a results panel, so the numbers are the content and the framing
should not compete with them. A long purchase list must not push the buttons off the
panel — scroll or cap the list. Check the empty case too: a run with no purchases must
read as "spent nothing", not as a missing section.

## Test plan

- `.\tests_v2\run.ps1 -All` after each phase.
- **A rendered capture of a finished run's result screen**, and one of the same screen
  with an empty purchase list. The suite cannot judge a layout.
- A capture of each of the six expedition stages to confirm the knolls look like raised
  ground and not like paint.

## Out of scope

- No stairs or entrances on the knolls.
- No changes to Classic mode.
- No persistence of run stats across sessions.
