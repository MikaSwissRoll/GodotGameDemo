# Current task: the test suite is frozen

**Status: closed by the user.** The suite was reorganised and repaired, then
frozen, and `tests/` was emptied. Nothing is pending.

## What happened

1. The suite had grown to 18 flat `*.gd` files that could only be run as one
   pile, so a change had no way to run only what was relevant.
2. They were moved into six group folders (`classic/ combat/ companion/
   expedition/ terrain/ ui/`) behind a `tests/run_tests.ps1` that printed the
   group map when given no arguments, and an audit was done of what each suite
   actually covered.
3. That audit found the suite was largely **unfalsifiable**: a failed `assert()`
   in Godot returns from the enclosing function only, so an assert inside a
   `_check_*` helper left the suite exiting `0` and printing `PASS`. Eight of the
   eighteen suites kept their assertions in helpers. Several checks were dead
   code from a missing `await`, and two named defects they could not detect.
4. Those defects were repaired and the full sweep went 18/18 green.
5. **The user then froze the suite and deleted `tests/`.** That decision stands;
   see `docs/TEST_WORKFLOW.md`.

## What was removed before the freeze

| Removed | Why |
| --- | --- |
| `test-collision.log` (repo root, tracked by Git) | A stale Godot failure log from 2026-09-19, referenced by nothing |
| `stamina_feedback_smoke._check_balance_unchanged` | Nine asserts restating tuned constants; it was red after the deliberate `stamina_regen_rate` 22→44 change and could only fail on a deliberate retune |
| `ballistics` check 4 | A literal rerun of check 1, and its actual claim was untestable the way it was written |
| `stamina_feedback_smoke` hand-armed buffer assert | Assigned `_buffer_attack_left` and then asserted it held that value |
| `companion_archer_smoke._check_player_is_blocked_by_npc` | Could not fail, and named a collision that is not implemented |

No suite was deleted for being redundant — the audit found each held unique
coverage. What was wrong with them was at assertion level.

## Defects the audit exposed, now fixed and then frozen

- `free_play_spawn_smoke._check_kills_do_not_count` had never run (missing
  `await`), its call was one argument short of `_on_enemy_defeated(at, drop)`, and
  the setup was wrong: `_on_main_quest_completed()` opens free play without
  advancing the progression phase, so the Guard was still in `GUARD_TUTORIAL` and
  briefed instead of handing the quest in.
- `ballistics` ran one of its three melee assertions (missing `await`).
- `stamina_feedback_smoke._check_buffers` never reached its expiry checks
  (missing `await`); rewritten to drive the real input path.
- `town_title_smoke` was red: it asserted the Guard starts the main quest on first
  contact, which the four-phase progression made false.

## Open question, never resolved

`player.tscn`'s `collision_mask` is `6` (world + enemy body) and does not include
`LAYER_NPC_BODY` (256), so **the Guard, Merchant and recruit are solid to enemies
and to the companion, but the player walks straight through them.** The old check
claimed otherwise and passed anyway, and the suite printed "player and companion
collide with them" while the player did not.

This is still unaddressed and is a gameplay decision, not a test one: widening the
mask would also make the player collide with the Expedition merchant. Left exactly
as it is.

## Going forward

Do not run, add to, or restore the test suite. Verify changes by reading the code,
running the project, taking a rendered capture, and driving the affected flow by
hand — and report what you observed rather than claiming a pass. `AGENTS.md` and
`docs/TEST_WORKFLOW.md` both state this.
