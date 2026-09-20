# Current task: Classic Mode progression

**Status: complete.** All eleven phases are implemented and verified. The suites
`classic_progression_smoke` and `free_play_spawn_smoke` cover the flow end to end,
and all fourteen suites pass.

## Goal

Extend Classic Mode progression from "spawn → fight → 试玩完成" into a four-phase
loop:

1. **Guard tutorial** — talk to the Guard, learn 移动 / 攻击 / 举盾, return, +10 金币
2. **Merchant tutorial** — talk to the Merchant, buy and use both potion types,
   return, +10 金币
3. **Main quest** — the existing 击败 5 名敌兵 + 收集 5 金币 quest, unchanged
4. **Free play** — the main quest no longer ends the session; outer enemies respawn
   on a cap so the player can keep fighting, earning and buying supplies

Classic Mode only. The roguelite mode must not change.

## Existing systems affected

| System | File | How it is used |
| --- | --- | --- |
| Quest state machine | `scripts/systems/quest_manager.gd` | Extended by a new progression manager; the main quest logic is kept as-is |
| Guard / Merchant dialogue | `scripts/main/game.gd` | Replaced by progression-aware branches |
| Quest UI | `scripts/ui/game_ui.gd` `set_quest()` | Reused; a one-line objective string |
| Potions | `scripts/main/game.gd` | Reused; the tutorial observes real transactions and real use |
| Enemy spawn / death | `scenes/main/game.tscn`, `scripts/enemies/enemy.gd` | Existing enemies reused; free-play respawn reuses the same scenes |
| Player actions | `scripts/player/player.gd` | Signals added so the tutorial observes real movement, attacks and guard |
| Demo Complete modal | `scripts/ui/game_ui.gd` `show_complete()` | No longer shown from Classic Mode completion |

## Important assumptions

- Progression is **per session**, not saved. There is no save system, so a new game
  starts at the Guard tutorial and a restart replays it. Nothing is persisted.
- The quest UI is a **single-line label**, so multi-objective quests are shown
  compactly (`移动 3/4 · 攻击 ✓ · 举盾 ○`) rather than as a multi-line checklist.
  A new interface is not warranted for this.
- The tutorial counts an **actual** attack and an **actual** guard state, and
  **actual** shop transactions and potion uses. No phase completes through
  dialogue alone.
- A Health Potion at full health is normally refused and not consumed. During the
  Merchant tutorial only, it is accepted and consumed at full health so the
  objective can be demonstrated without the player having to get hurt. Normal
  gameplay behaviour is unchanged.
- Free-play enemies reuse `melee_enemy.tscn` / `archer_enemy.tscn` and drop gold
  through the existing pickups. No new enemy type and no new currency.

## Implementation phases

1. Audit quest / dialogue / spawn architecture. **Done.**
2. Progression state: one source of truth for the four phases.
3. Guard tutorial quest (movement four ways, attack, guard).
4. Guard reward and the transition to the Merchant.
5. Merchant tutorial quest (buy and use both potions).
6. Merchant reward and progression-aware dialogue states.
7. Fold the existing main quest into the sequence.
8. Remove the forced game-end from Classic Mode completion.
9. Free-play repeatable outer enemy spawning, with a hard active cap.
10. Quest UI, dialogue and reward feedback.
11. Full regression and an end-to-end Classic Mode playthrough.

## Test plan

- `tests/classic_progression_smoke.gd` (new): phase order is enforced, objectives
  advance only on real actions, rewards are paid once, the main quest is unchanged,
  and completion does not end the session.
- `tests/free_play_spawn_smoke.gd` (new): respawn respects the cap, never spawns in
  the village or on the player, and does not count toward the finished main quest.
- Existing suites must stay green, in particular `playthrough` (which drives the
  classic map) and `smoke_game` (which asserts the classic menu and quest text).
- Runtime visual QA capture for the tutorial quest label and the reward toast.

## Out of scope

- Repeatable quest frameworks: daily quests, bounties, reputation, procedural quests.
- Any change to the roguelite mode, its HUD or its balance.
- Persistence / save games.
- New enemy types, new currencies, new art or audio.
