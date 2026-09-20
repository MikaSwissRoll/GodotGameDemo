# Current task: Pawn_Knife, the first recruitable companion

**Status: implemented and verified.** `tests/companion_smoke.gd` covers the
contract, all 15 suites pass, and the recruit dialogue, formation and combat were
reviewed in runtime captures.

## Goal

A recruitable melee companion for Classic Mode only: hire Pawn_Knife in the village
for 25 gold once the main quest is handed in, after which he follows the player,
assists in nearby fights, returns to formation, and can be downed but never
permanently lost.

## Existing systems affected

| System | File | How it is used |
| --- | --- | --- |
| Progression | `scripts/systems/classic_progression.gd` | `FREE_PLAY` gates availability; unchanged otherwise |
| NPC interaction | `scripts/world/recruit_npc.gd` | Same Area2D + `[E]` prompt + `interacted` pattern as Guard and Merchant |
| Dialogue UI | `scripts/ui/game_ui.gd` | Same overlay and `ActionRow` stack; two new signals for the hire choice |
| Gold | `scripts/main/game.gd` | The existing `gold`; no second currency |
| Enemy AI | `scripts/enemies/enemy.gd` | Target acquisition widened to party members, on a timer |
| Arrows | `scripts/enemies/arrow.gd` | Hit any party member, not only the Player |
| Collision | `enemies/melee_enemy.tscn`, `enemies/arrow.tscn` | Masks widened to see the companion hurtbox |

## Important assumptions

- **Pawn_Knife has exactly three animations**: `Pawn_Idle Knife` (8 frames),
  `Pawn_Run Knife` (6), `Pawn_Attack Knife` (4), all 192x192 frames. No hurt, no
  death, and no directional variants anywhere in the pack. The project uses
  horizontal flipping only, which these support.
- **There is no death art**, so the downed pose is the idle frame **rotated 90° and
  greyed/darkened** in code, as specified. Taking a hit flashes red via `modulate`,
  the same convention the player and enemies already use.
- **Recruitment is session-only.** There is no save system, so it follows the rest
  of Classic Mode progression: a restart replays it. No save framework was invented.
- **Hiring is gated twice** — the NPC node is inert until free play, and the game
  handler independently refuses outside `FREE_PLAY`.
- **Friendly fire is prevented by collision masks, not by checks**, so it cannot
  regress if a damage path forgets a faction test.
- **No companion HUD.** Health is readable from the hit flash and the downed pose.

## Implementation phases

1. Audit systems and Pawn_Knife assets. **Done.**
2. Faction layer table and `Party` rules. **Done.**
3. Recruit NPC, hidden until free play. **Done.**
4. Atomic 25-gold hire with the NPC-to-follower transition. **Done.**
5. Follower foundation: states, formation slot, catch-up. **Done.**
6. Melee combat with cooldown and a momentary hit window. **Done.**
7. Enemy and arrow targeting extended to party members. **Done.**
8. Downed, revival, out-of-combat regeneration. **Done.**
9. Stuck recovery with a rate-limited fallback. **Done.**
10. Runtime visual QA and full regression. **Done.**

## Balance assumptions

Against the player (100 HP, 25 damage, 0.5s) and the melee enemy (75 HP, 12 damage,
1.3s):

| Value | Pawn_Knife |
| --- | --- |
| `max_health` | 60 |
| `move_speed` | 150 |
| `attack_damage` | 14 |
| `attack_cooldown` | 1.15 |
| `attack_range` | 62 |
| `follow_offset` | (-46, 30) |
| `catch_up_distance` | 260 |
| `assist_radius` | 340 |
| `leash_distance` | 420 |
| `downed_seconds` | 6 |
| `revive_health_ratio` | 0.5 |
| `regen_per_second` | 3 |
| `stuck_check_seconds` | 2.5 |
| `reposition_cooldown` | 12 |

A companion should noticeably improve a fight without soloing it, so its damage and
cadence both sit below the player's.

## Test plan

- `tests/companion_smoke.gd` (new): gating before free play, insufficient-gold
  refusal that spends nothing, the exact 25-gold deduction, no duplicate follower
  and no second charge, following without standing on the player, faction safety
  against player/Guard/Merchant, target stickiness, landed damage, leash abandon,
  downed state and revival without pausing.
- All existing suites must stay green.
- Runtime captures: `recruit_offer`, `companion_follow`, `companion_combat`.

## Out of scope

Multiple simultaneous followers, companion inventory, equipment, XP, levels, skill
trees, command wheel, formation UI, travel dialogue, loyalty, permadeath, healer or
ranged companions, companion quests, and any procedural or LLM-driven party AI.

## Result

- 15/15 suites pass.
- Visual QA confirms the hire modal renders in style, the companion sits behind and
  to one side of the player without merging, and combat shows both fighters landing
  hits.
- See [Follower System](../systems/FOLLOWER_SYSTEM.md) for the design, the
  extension points for future classes, and the four implementation problems worth
  remembering.
