# Elevation Audit — the current architecture

Findings from reading the production code and scenes as they were at baseline
`df1f260`, before any elevation change. Read with
[`ELEVATION_SYSTEM.md`](ELEVATION_SYSTEM.md), which is the model that replaces it.

Everything here is quoted from the code with a line reference. Nothing is inferred
from the frozen legacy suite.

---

## 1. What exists today

A **point-sampled boolean over a static rect list**:

- `TinySwordsEnvironment._plateaus: Array[Rect2i]` (`tiny_swords_environment.gd:48`),
  cleared per world by `begin_world()` (54).
- `elevation_at(point)` (68) floors the point to a **64 px tile** and answers "is
  this tile inside any plateau rect".
- `add_plateau(...)` (81) registers the footprint, paints a surface and one cliff
  row, and optionally builds one wall along the **bottom edge only** (123).

Three pieces of it are **dead**:

| Symbol | Status |
| --- | --- |
| `plateau_at()` (`:59`) | Defined, never called |
| `cliff_y_of()` (`:77`) | Defined, never called |
| `PLATEAU_CLIFF_GROUP` (`:46`) | Two writers (`:128`, `world.gd:62`), **zero readers** |

The group's comment claims arrows pass over cliffs because the wall is tagged. They
do not: the tag is never queried.

## 2. There is no navigation architecture

Project-wide grep for `NavigationAgent2D`, `NavigationRegion2D`, `NavigationLink2D`,
`NavigationObstacle2D`, `AStar2D`, `AStarGrid2D`, navmesh, `get_simple_path`,
`move_and_collide` → **zero matches**.

Movement is direct steering plus `move_and_slide()`. The only "can I get there"
logic in the project is the melee enemy's `_update_cliff_hold` heuristic and the
follower's teleport fallback. **A navigation layer has to be built, not integrated.**

## 3. The elevation rule is written four times, in two shapes, and missing twice

| Site | Form | Gates |
| --- | --- | --- |
| `enemy.gd:67-68` | helper `_elevation_blocks()` | movement (132), attack decision (140), the hit itself (299) |
| `archer.gd:163-164` | byte-identical copy of the helper | repositioning only (85, 88) |
| `player.gd:612` | **inline**, no helper | the swing's damage only |
| `follower.gd` | **none at all** | — |
| `player.gd:623-633` dash cleave | **none at all** | — |

Consequences:

- **The companion damages across a cliff in both directions.** `follower.gd:276-284`
  has no elevation term, and its hitbox sits 44 px in front (266) — the exact hazard
  `enemy.gd:295-298` names and guards against.
- **The player's dash-cleave damages across a cliff**, while the normal swing beside
  it refuses the same target. Two melee paths, two answers.

## 4. Collision: the cliff does not physically exist for enemies

| Body | layer | mask | Effect |
| --- | --- | --- | --- |
| Player | 1 | **6** (world + enemy body) | stopped by cliffs; walks through NPC bodies (256) |
| MeleeEnemy / ArcherEnemy | 4 | **772** = 4+256+512 | **no world bit** → cliffs, walls, river and buildings never collide with them; also no player bit |
| Follower | 512 | **262** = 2+4+256 | stopped by cliffs |
| `EnemyArrow` | 64 | **162** = 2+32+128 | world bit is **dead** (no `body_entered`) |

So a cliff stops the player and the follower **physically**, and a melee enemy
**only behaviourally**, through `_update_cliff_hold`. Two unrelated mechanisms for
one boundary.

Terrain tiles carry **no collision at all** — `_new_tile_layer` (`:341-364`) never
adds a physics layer. Every solid surface in the game is a runtime `add_wall`
`StaticBody2D` on layer 2.

### Dead mask bits

`melee_enemy.tscn:29` and `archer_enemy.tscn:26` hurtbox mask `8`; `player.tscn:54`
and `follower.tscn:31` hurtbox mask `64`; `arrow.tscn:11` bit 2. Nothing connects a
handler on the receiving side, so none of these can fire.

## 5. The logical and physical boundary disagree

For `CampRise = Rect2i(53, 1, 19, 9)` (`world.gd:69`):

- logical: tile row 9 is HIGH, row 10 is LOW → the boundary is `y = 640`;
- physical: the wall is centred at `y = 672` with height 58 → it spans `y 643..701`,
  **entirely inside the tile row the registry calls LOW**.

A character can therefore be legitimately HIGH while standing in the wall band, or
LOW while pressed against the wall's lower face. `cliff_y_of` encodes the other
convention and is never called.

## 6. Only the bottom edge is walled

`add_plateau` builds one wall along the bottom edge (123-128) and nothing on the
sides or top. `elevation_at` flips at **any** footprint edge, so every unwalled side
is an unintended level transition. `CastleTerrace` is registered with
`collision: false` (`world.gd:59`) and gets a hand-placed wall covering only
`x 1024..1472` of its `x 960..1536` footprint.

## 7. Ramps are decoration

`world.gd:64-68` places four tile cells as `CastleRamps`. They are **visual only**:
no collision, no registration, no ramp concept in the registry at all. They work
only because no wall happens to be built in those two columns, which makes them
indistinguishable from any other open edge.

They are also the **shoreline corner** tiles (`c0`/`c3` × `r4-r5`), i.e. land meeting
water — see [`HIGHGROUND_TILE_GRAMMAR.md`](HIGHGROUND_TILE_GRAMMAR.md) §4. The only
legal way onto a plateau is drawn as a beach.

## 8. Reachability does not exist, and the fallbacks are bad

- The melee enemy's cliff-hold (`enemy.gd:244-276`) backs off to
  `cliff_hold_distance` (110 px) at 70 px/s, waits `approach_retry_seconds` (1.6 s),
  and then — because `same_level` is still false — falls into the **idle** branch
  (147-150) and **never re-approaches**. The retry pause is not a retry.
- It retreats *away from the target*, not away from the cliff (`:248`), and picks
  `Vector2.DOWN` when the target is exactly on top (`:250`).
- The archer's only response to a level mismatch is `velocity = _knockback` plus
  idle (`archer.gd:88-91`): **it never moves at all**, so it also never repositions
  to get back into range.
- The follower's `_safe_point_near_player` (`follower.gd:410-421`) point-tests only
  `LAYER_WORLD` at 8 fixed offsets, with **no elevation test**, and is used both for
  the stuck teleport (404) and the revive (433) — an unguarded LOW↔HIGH transition.

## 9. Ranged already crosses elevations — by accident, and the comment lies

`archer.gd:104` is `if distance < detection_range and _shoot_left <= 0.0 and not _shooting:`
with **no elevation term**, and `_shoot()` (167-189) tells the arrow nothing about
levels. So the desired behaviour ("ranged may cross elevations") is **already true**.

What is wrong is that it is unintentional and undocumented:

- the comment at `archer.gd:82-84` claims "it does not fire when the only thing
  between it and the target is a cliff face" — **the code does not implement this**;
- the target-validity path (`_is_target_valid` 134-142, `_nearest_party_actor`
  147-157, `_retarget` 116-131) tests no distance, elevation or reachability, so
  there was never a reachability gate to remove.

Correcting the record: an earlier revision of `docs/CURRENT_TASK.md` claimed the
archer "gates target validity on reachability". That was wrong and has been fixed.

## 10. Other conflicting answers found

- **Two `_is_target_valid` semantics.** `enemy.gd:185` only checks the method
  *exists* then reads `.state`/`.health` raw; `archer.gd:139` *calls*
  `is_party_member()`. Both bypass `Party` for the follow-up read.
- **Two retarget bias rules.** `enemy.gd:172` always multiplies by
  `companion_preference` (0.6); `archer.gd:127-128` uses `1.0` when the current
  target is the player. Same stated intent, different behaviour.
- **`_nearest_party_actor` differs.** `enemy.gd:204-207` falls back to the `player`
  group; `archer.gd:157` returns null.
- **Faction validity is answered two ways.** The follower routes through
  `Party.is_hostile`; the player duck-types `has_method("take_damage")`
  (`player.gd:603`, `:627`).
- **One-hit-per-swing is implemented three ways.** Player: a dictionary per enemy,
  so one swing can hit many. Enemy: a single boolean, so one swing can hit only
  **one** victim ever. Follower: **neither**, and both its `area_entered` connection
  (116) and its manual sweep (271) feed the same handler, so one enemy can be hit
  twice in a swing.
- **The downed state is a magic number in two places.** `enemy.gd:186` and
  `archer.gd:141` both test `state != 4` instead of `Follower.State.DOWNED`; the
  follower exposes no `is_downed()`.
- **The sample point and the acting point differ.** The player samples elevation at
  its feet but projects damage from a hitbox 66 px forward and 25 px up (`:587`).
- **`party.gd:11-20` documents only layers 1-8** while its own constants define
  layers 9 (`LAYER_NPC_BODY` 256) and 10 (`LAYER_COMPANION_BODY` 512).

## 11. Live instances of the bug in shipped content

- **`game.tscn:51` places `ArcherEnemy1` at `Vector2(3890, 600)`, which is inside
  `CampRise`** — a walled, rampless plateau. `game.gd:22-25` records that the
  free-play spawn point was moved off the rise for exactly this reason, but the
  story instance in the scene was not moved with it. A melee enemy there is
  unreachable and the player cannot melee up to it.
- **Expedition silently changes the meaning of the same code.** `run_arena.gd:30`
  clears the registry, so `elevation_at` is false everywhere and `_elevation_blocks`
  is always false: no cliff-hold, no level gate. The enemy scripts have no mode
  flag, so the code means "flat" in one mode and "level-gated" in the other.

## 12. What this means for the reset

Ordered by what blocks what:

1. Build the terrain authority and the ramp concept (nothing else can be correct first).
2. Build the cliff boundary as **movement** collision along all edges, opening at ramps.
3. Give enemies the world collision bit they are missing, so a cliff is physical for them too.
4. Centralise the melee rule and route **all four** melee paths through it, including
   the follower and dash-cleave.
5. Make ranged crossing explicit rather than accidental, and fix the comment.
6. Replace the cliff-hold heuristic with a real level-graph reachability answer and a
   fallback that does not go permanently idle.
7. Stop anchor-free teleports from crossing a level.
8. Delete the dead symbols (`plateau_at`, `cliff_y_of`, `PLATEAU_CLIFF_GROUP`).
