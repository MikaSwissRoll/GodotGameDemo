# Test workflow

## Purpose

How the harness in `tests/` is written and what each kind of test is allowed to
assert. The rule that matters most here was learned the hard way:

> **A test may assert an invariant. It may not assert luck.**

`tests/roguelite_playthrough.gd` used to fail whenever its AI died, and the run
randomizes its wave composition per room, so the same code passed or failed at
random. It wasted real time and reported nothing useful, because the failing
variant was never printed. The feature was fine; the assertion was wrong.

## Running the suites

```powershell
$godot="C:\Users\22141\Desktop\Godot_v4.7.2-stable_win64.exe"
& $godot --path . --headless --script res://tests/<name>.gd
```

Each script is a `SceneTree`, exits `0` on success, and prints a single
`... PASS: ...` line. Failures go to stderr via `push_error` and exit `1`.

Current suites:

| Suite | Covers |
| --- | --- |
| `smoke_game` | Classic scene: menu, movement, dash, pause, combat, archer, quest, gold, completion, death, restart |
| `playthrough` | Classic run across the real map, with a waypoint route |
| `ballistics` | Arrows ignoring terrain in both directions; the player's melee refused across elevation |
| `roguelite_smoke` | Run state machine: rooms, rewards, shop, upgrades, elite, win, reset, variation |
| `roguelite_playthrough` | Whole random run: **integrity**, not victory |
| `collision_smoke` | River, bridge, castle foundation, ramp |
| `new_features_smoke` | Guard, directional block, stamina costs and recovery, potions, Chinese HUD |
| `upgrade_effects_smoke` | Counter, guard efficiency, heavy attack, kill refund, swift dash, dash cleave |
| `stamina_feedback_smoke` | Warning thresholds, character shake, state icon, last-chance guard, exhaustion, input buffer, regen hold |
| `town_title_smoke` | Unified title screen |
| `classic_ui_smoke` | Classic HUD separation and return to the unified title |
| `interact_marker_smoke` | NPC interaction marker and prompt |

## Assert invariants, not outcomes

Split what you are checking:

- **Invariant** — true of every run, however the dice fall. Assert it. Examples:
  the phase is always a legal one; a reward never follows anything but combat; a
  terminal phase never returns to play; health stays inside `0..max`; a room in
  combat keeps making progress instead of stalling.
- **Outcome** — true of *some* runs. **Report it, do not assert it.** An AI dying
  in room 2 is a measurement. `roguelite_playthrough` prints it, exits `0`, and
  includes the wave composition and health trace so the data is usable.

If an outcome genuinely must be guaranteed, remove the randomness rather than
hoping: pin the variant or the seed, and say so in a comment. Do not leave a
"must win" assertion pointed at a randomized run.

## Determinism and diagnosing failures

`run_game.gd` calls `rng.randomize()`, which is right for play and wrong for a
test. `RunGame.previous_first_variant` and the `RUN_VARIANT` environment variable
already let a harness pin the first room's variant for hand-reproducing a specific
complaint:

```powershell
$env:RUN_VARIANT="1"; & $godot --path . --headless --script res://tests/roguelite_playthrough.gd
```

Any test that can lose should print enough to reproduce the loss on the spot:
the seed or forced variant, the per-room composition, and the health trace. A
failure line that says only `Could not finish room 2; HP=0` costs another hour
the next time it appears.

## A test that cannot fail on a real defect is not worth keeping

Before adding an assertion, say which defect it would catch. `assert(true)` style
checks — restating a constant, asserting a node exists right after creating it,
or confirming the value a setter was just given — add runtime cost and no safety.
Prefer driving the real code path over reimplementing its rule in the test: the
`ballistics` melee assertions call the actual hit handler rather than restating
the elevation comparison, so a change to the rule fails the test.

## Flaky tests

A flaky test is worse than no test: it trains everyone to ignore red. When one
turns up:

1. Decide whether it is asserting an invariant or an outcome. Reproduce it a few
   times and count — a pass rate between 10% and 90% means randomness is in play.
2. If it is an outcome, convert it to a report (see above). Do not add retries to
   paper over it; retries hide the very nondeterminism that makes the failure
   unreadable.
3. If it is a genuine invariant, make the input deterministic first, then fix the
   defect it exposes.

## Related documents

- [Scene workflow](SCENE_WORKFLOW.md) — building the scenes the tests drive.
- [UI workflow](ui/UI_WORKFLOW.md) — which suites to run for a UI change.
- [Visual QA](visual_qa.md) — the screenshot harness, which complements these.
