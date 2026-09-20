# Current task: Elevation System Reset

**Status: in progress.** Baseline snapshot `df1f260`. Legacy tests frozen and
removed. Authoritative elevation model not yet implemented; the main map is
untouched.

## Goal

Give the project **one authoritative two-level elevation model** shared by
terrain, collision, navigation, combat, targeting, followers and visual terrain
construction.

Two discrete gameplay levels only — `LOW = 0`, `HIGH = 1`. No continuous
physical Z height; this stays a top-down 2D game. Actors change level **only**
through designated ramp / stair / slope connections.

Today the project has no such model. Elevation is inferred differently in
different places, collision is built cliff-first, navigation does not know about
levels at all, and ranged targeting conflates "can I reach it" with "can I shoot
it". The symptoms below are one missing model, not seven bugs:

1. High-ground collision is inconsistent.
2. Characters enter or leave high ground through unintended edges.
3. Low↔high navigation is disconnected, so enemies freeze or fail to path.
4. Ranged enemies reject targets they could legally shoot.
5. Melee sometimes damages across an elevation boundary.
6. Pawn_Knife and future followers need elevation-aware navigation.
7. Tiny Swords high-ground tiles are composed cliff-first, producing box
   platforms and long mechanical cliff walls.

Do not patch these one at a time.

## Standing rules for this task

- **Legacy tests are frozen.** The former `tests/` suite is removed and is a
  historical artifact. It is not run, not repaired, not updated, and is never an
  acceptance criterion. Production code is never changed merely to satisfy it.
  Its assumptions are not carried into the new suite.
- **A V2 validation suite is being created** under `tests_v2/`, from the current
  game's architecture. It is deliberately small and high-value, not a second
  legacy monster.
- **The elevation architecture is being rebuilt cleanly**, in an isolated lab,
  before anything in the main map is touched.
- **Main-map high ground will NOT be migrated** until the isolated
  implementation passes its own validation. One region only after that, then
  stop for review. Never a blind whole-map rewrite.

## Existing systems affected

| System | File | Role in this change |
| --- | --- | --- |
| Player movement / melee | `scripts/player/player.gd` | Must use the shared elevation state and the central melee rule |
| Melee enemy AI | `scripts/enemies/enemy.gd` | Owns the current ad-hoc cliff rules that get replaced |
| Ranged enemy AI | `scripts/enemies/archer.gd` | Already fires across elevations; what is missing is an explicit rule and a stable fallback when it cannot reposition |
| Projectiles | `scripts/enemies/arrow.gd`, `scenes/enemies/arrow.tscn` | Must cross elevations; cliff collision must not block them |
| Faction / layer constants | `scripts/systems/party.gd` | Where layer and target-validity authority lives |
| Follower | `scripts/party/follower.gd` | Melee follower; reuses the shared rules, lifecycle unchanged |
| Terrain construction | `scripts/world/tiny_swords_environment.gd` | `add_plateau` is the current cliff-first builder |
| Classic map | `scripts/world/world.gd` | Holds both real plateaus; migration target, untouched for now |
| Expedition arena | `scripts/world/run_arena.gd` | Already flat; must stay flat |

## Important assumptions

- Two levels are enough. Anything needing a third should be re-derived from the
  contract rather than added ad hoc.
- Gameplay elevation is **explicit state on the actor**. It is never inferred
  from `z_index`, sprite ordering, Y coordinate, visual cliff height or render
  layer.
- The high-ground **top surface is walkable**, not one giant blocking collider.
  Collision represents cliff boundaries and only the illegal crossing they must
  prevent.
- A cliff boundary may block a character while still letting a projectile
  through. Character movement blockers and projectile blockers are separate
  concepts.
- `CanReachTarget` and `CanAttackTarget` are different questions and stay
  separate. A high archer may be unable to walk to a low player while still
  being able to shoot them.

## Implementation phases

0. Baseline snapshot and this document. **Done** (`df1f260`).
1. Audit the current production architecture; record conflicting assumptions.
2. `docs/environment/ELEVATION_SYSTEM.md` — the authoritative contract.
3. `docs/environment/HIGHGROUND_TILE_GRAMMAR.md` — from the real assets.
4. `tests_v2/` mechanism, then a small current-version baseline suite.
5. `tests_v2/elevation/ElevationLab.tscn` — minimal, current assets only.
6. Terrain and player only; scenarios A–F stable before anything else.
7. Encode stable terrain invariants in V2.
8. One melee enemy; navigation LOW↔HIGH through the ramp; no-path fallback.
9. Centralise melee elevation validation into one shared path.
10. V2 melee elevation checks.
11. One archer; ranged eligibility independent of reachability; projectile masks.
12. V2 ranged eligibility checks.
13. Pawn_Knife on the shared rules.
14. V2 follower/elevation regression.
15. Visual QA of ElevationLab against the tile grammar.
16. Run V2 suite + runtime scenarios + visual QA together.
17. Migrate **one** production high-ground region end to end, then stop.

## Test plan

- **V2 automated:** only rules that are important, stable, binary and costly to
  break. Small checks that name one rule each, testing behaviour rather than
  private internals.
- **Runtime scenarios in ElevationLab:** spatial navigation, ramp traversal and
  cross-elevation projectile travel, which are too brittle to automate reliably.
- **Visual QA:** screenshots judged against `HIGHGROUND_TILE_GRAMMAR.md`. Not an
  automated assertion.
- Verified in Phase 16 that the V2 baseline still passes, proving the refactor
  did not break project startup, player basics, core combat, faction behaviour,
  or the Pawn_Knife foundation.

## Out of scope

- Migrating the whole map. Phase 17 does one region and stops for review.
- Continuous Z height, visual elevation, or multi-level terrain.
- Rewriting the companion system. Pawn_Knife keeps its lifecycle and invariants.
- Reviving, porting or repairing anything from the legacy suite.
- Expedition mode, which is already flat and must stay flat.
