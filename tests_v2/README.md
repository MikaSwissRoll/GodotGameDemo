# tests_v2 — the current validation suite

This is the **current** validation system, built from the game as it is today.

> The old `tests/` suite is **frozen and removed**. It is a historical artifact: not
> run, not repaired, not an acceptance criterion, and its assumptions were not
> carried over. Do not restore it. See `docs/TEST_WORKFLOW.md`.

## Running

```powershell
.\tests_v2\run.ps1                       # print the map; runs nothing
.\tests_v2\run.ps1 -Category baseline    # one category
.\tests_v2\run.ps1 -Suite player_core    # one suite
.\tests_v2\run.ps1 -All                  # everything
```

Suites run windowed, not headless: some drive real input, and the lab captures read
rendered pixels. `-Headless` exists for suites that touch no viewport.

## Categories

| Category | What it answers | Mechanism |
| --- | --- | --- |
| `baseline` | Did this change break a core system that already worked? | Automated, fast |
| `elevation` | Are the level, ramp, melee and ranged rules correct? | Automated, deterministic |
| `scenarios` | Does spatial behaviour work — routing, ramps, projectiles? | Driven runtime scenarios in the lab |
| `lab` | Is the terrain visually correct? | Screenshot capture + eyeball |

Do not force all four into one mechanism. Logic that is binary and stable belongs in
an automated check; navigation and terrain composition do not.

## How a suite is written

Every suite extends the shared harness:

```gdscript
extends "res://tests_v2/harness.gd"

const SUITE := "my_suite"

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    arm_timeout(45.0, SUITE)     # 1. always arm a timeout
    section("the rule I am checking")
    check(some_condition, "what the rule is, in words")
    finish(SUITE)                # 2. always finish, on every path
```

### The one rule that matters

**V2 never uses `assert()`.**

In Godot a failed `assert()` returns from the *enclosing function only*. Inside a
helper that means the helper aborts while the suite carries on to `quit(0)`: green
run, exit code 0, assertion never mattered. The frozen legacy suite was largely
unfalsifiable for exactly this reason, and it is the single most expensive mistake
this project has made with tests.

`check()` counts instead. `finish()` decides the exit code. A suite that recorded
**zero** checks is itself a failure, which catches the other silent killer — a suite
that quietly stopped running.

### Writing a good check

- One `check()` per rule, with a message that names the rule.
- **Test behaviour, not internals.** "Cross-elevation melee is rejected" is a rule;
  "this private method returns 4" is not.
- **Stage the situation, not the outcome.** Put the actors where the situation
  occurs and let the game decide. A check that sets up the result proves nothing.
- **Do not assert tuned constants.** A check that restates a balance value fails
  only when someone retunes on purpose, which is noise. Compare against the live
  field instead.
- **Never assert luck.** Report measurements; assert invariants.

## Adding a category

Create a directory under `tests_v2/`. The runner discovers categories from the
filesystem, so nothing needs registering. Suites inside are discovered by name.

## Related

- `docs/environment/ELEVATION_SYSTEM.md` — the elevation contract these suites test.
- `docs/environment/ELEVATION_AUDIT.md` — what the architecture looked like before.
- `docs/environment/HIGHGROUND_TILE_GRAMMAR.md` — the visual rules for the lab.
- `docs/TEST_WORKFLOW.md` — the frozen suite, and what it taught us.
