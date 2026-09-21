# Elevation System

**This is the authoritative specification for elevation in this project.** If code,
a scene, or another document disagrees with this file, this file wins and the other
thing is a bug. Read it before touching terrain, cliffs, ramps, cross-elevation
combat, ranged targeting, or follower navigation.

Related: [`HIGHGROUND_TILE_GRAMMAR.md`](HIGHGROUND_TILE_GRAMMAR.md) for how to build
the terrain visually, and [`../FOLLOWER_SYSTEM_WORKFLOW.md`](../FOLLOWER_SYSTEM_WORKFLOW.md)
when follower behaviour is involved.

---

## 1. Two levels, and only two

```
LOW  = 0
HIGH = 1
```

This is a top-down 2D game. There is **no continuous physical Z height**, no
gravity, no height map, and no multi-storey terrain. "Elevation" is a discrete
gameplay property meaning *which walkable layer an actor is standing on*.

Two levels are enough for every scene in this project. If something appears to need
a third, the requirement is wrong and should be re-derived against this document
rather than added as a special case.

## 2. Gameplay elevation is explicit, never inferred

Every elevation-aware actor has an explicit elevation level, and it is read from
**one authority** (§3).

Gameplay elevation must **never** be inferred from:

| Forbidden source | Why it is wrong |
| --- | --- |
| `z_index` | A draw-order hint. Changing it for art reasons would silently move actors between levels. |
| `Sprite2D` ordering / `y_sort` | Same problem, and it changes with camera and art tweaks. |
| Y coordinate | A ramp, a shadow, and a decorative tile all move an actor's Y. |
| Visual cliff height | Art. A 128px painted face and a 64px one are the same gameplay drop. |
| Render layer / `CanvasLayer` | Presentation only. |
| Collision layer | Overloaded already; it answers *what may touch what*, not *where am I*. |

**Rendering and gameplay elevation are different concepts.** They usually agree, and
that agreement is a property to verify — not a mechanism to rely on.

## 3. One authority, and actors read from it

Elevation truth lives in a single terrain-side registry, queried by point:

```
level_at(world_point) -> LOW | HIGH
```

An actor's `elevation_level` is derived from that query, not stored independently
and not computed with its own copy of the rules. Two actors standing in the same
place therefore cannot disagree about their level, which is the defect that
produced most of the symptoms this document exists to remove.

The registry is rebuilt per world, exactly like the current plateau registry, so a
reloaded scene or a new stage never inherits the previous world's regions.

## 4. Terrain vocabulary

Three distinct things. Conflating them is the root cause of the old cliff-first
terrain.

### 4.1 High-Ground Surface

The walkable top of a plateau. It **represents HIGH elevation** and it is
**walkable**.

It is **not** a giant movement-blocking collider. A common historical mistake was
to build the whole footprint as one solid block, which made actors collide with the
floor they were supposed to stand on. Only the *boundary* carries collision (§5).

### 4.2 Cliff Boundary

The edge where the surface ends and the drop begins. It:

- separates two elevation levels;
- blocks a character from crossing directly;
- represents an **illegal elevation transition**.

A cliff boundary is a **line along an edge**, not a filled region.

### 4.3 Ramp / Stair / Slope

The **only legal LOW ↔ HIGH connection**. It:

- is declared explicitly as a ramp with a direction;
- leaves an opening in the cliff boundary;
- is represented consistently in collision **and** navigation;
- results in the actor's level changing as it crosses onto the high surface.

A plateau with no ramp is legal: it is simply unreachable. A plateau is never
reachable through an edge that is not a declared ramp.

#### 4.3.1 The ramp's rows must include the terrace's own last surface row

This is the one rule that silently seals a plateau.

Two mechanisms read the ramp's tile rect:

- the **level flip** happens when an actor steps off the ramp onto the terrace's **own
  surface**. A ramp that stops short of that surface never produces a flip;
- the **boundary builder opens collision on ramp tiles**. A ramp that misses the row the
  boundary runs along leaves that boundary solid.

So a ramp spanning only the rows *below* the terrace - the wall row and the low row
beneath it, say - is registered, is painted, and connects nothing. The terrace is
sealed, and no error is raised anywhere.

`HighGround.stair_rect` derives the rect as

```gdscript
Rect2i(column, last_row + top_row_offset, 1, STAIR_ROWS)
```

where `last_row` is the wall row, one past the terrace's last surface row. The offset
therefore has to be **-2 or -1**; **0 and above break it**. The art and the legal
crossing are derived from the same rect, so a stair cannot be drawn where it does not
connect - but it *can* be drawn and connect nothing if the offset is wrong.

`top_row_offset` is **per stair**, not a project-wide constant. Making it global once
moved every scene's stairs at the same time, including the ElevationLab's, and broke
seven checks in two suites with nothing to indicate the two scenes were coupled.

## 5. Collision: two jobs, two colliders

A cliff boundary may stop a character while still letting an arrow fly over it.
These are different questions and must not share one collider.

| Role | Blocks | Does not block |
| --- | --- | --- |
| **CharacterMovementBlocker** | character bodies crossing the elevation boundary | projectiles |
| **ProjectileBlocker** | projectiles | characters (a projectile blocker is separate art, e.g. a building) |

Rules:

- A cliff boundary is a **CharacterMovementBlocker**. It is not automatically a
  ProjectileBlocker.
- Projectiles may travel HIGH → LOW and LOW → HIGH, **at most one crossing** (section 7).
  The crossing budget is what limits a shot, not collision.
- Real obstacles — buildings, fortress walls, a closed gate — may block projectiles
  as the scene requires. That is a deliberate, scene-specific ProjectileBlocker, not
  a side effect of a cliff.
  > **No ProjectileBlocker exists yet.** Today an arrow passes through buildings: it
  > connects `area_entered` only, and a building is a `StaticBody2D`, so the two can
  > never meet. Treat buildings as cover for characters, not for projectiles, until a
  > blocker layer is added. Do not "fix" this by adding the world bit to the arrow's
  > mask — that would make cliffs block arrows and silently delete section 7.
- The ramp's opening stays **traversable**. A boundary may be split into segments to
  leave the opening clear, and short ramp-side segments are allowed where they stop
  an actor clipping sideways through the edge.
- The high-ground **top surface carries no movement collision at all**.

## 6. Melee: same elevation, one shared rule

**A melee attack connects only when attacker and target are on the same elevation.**

| Attacker | Target | Result |
| --- | --- | --- |
| LOW | LOW | damage |
| HIGH | HIGH | damage |
| LOW | HIGH | **no damage** |
| HIGH | LOW | **no damage** |

**Hitbox overlap alone must never bypass this.** Two actors on opposite sides of a
cliff can have overlapping hitboxes and overlapping sprites; the elevation test
decides, and it is applied before damage.

The rule is implemented **once**, in a shared validation path. It must not be
re-implemented inside `Player`, `Follower`, `Enemy`, or any future melee actor.
Actor-specific copies are how the player and the enemies ended up disagreeing about
what a cliff means.

## 7. Ranged: may cross elevation, at most once

A ranged attack **may** cross elevation, but a projectile may cross **at most one**
LOW/HIGH boundary. An elevation difference never invalidates a ranged target by itself -
what stops a shot is the terrain its path runs through, not the difference between the
two ends.

| Attacker | Target | Crossings | Result |
| --- | --- | --- | --- |
| LOW | LOW, open ground | 0 | fires |
| HIGH | HIGH, same plateau | 0 | fires |
| LOW | HIGH | 1 | fires |
| HIGH | LOW | 1 | fires |
| LOW | over a plateau | 2 | **stopped at the second boundary** |
| HIGH | across a valley | 2 | **stopped at the second boundary** |

The budget is `EnemyArrow.ELEVATION_CROSSINGS_MAX`. Melee is 0 and is enforced on the
attacker, in the melee handler; an arrow is 1. A future piercing shot would be 2.

**This is what makes high ground cover as well as a firing position.** A player who drops
behind a plateau is out of an archer's line, with no cover system, crouch button or cover
node - the terrain is the cover system.

Three consequences worth stating rather than discovering:

- **A ramp is not a third elevation.** `level_at` returns LOW or HIGH and nothing else,
  so a path over a stair column crosses once and is not charged twice.
- **Two plateaus separated by a valley cannot shoot each other**, because that path
  crosses twice. Accepted for now in exchange for a rule that stays one sentence; a real
  flight-height model can replace it if the limitation bites in play.
- **The crossing is counted from the projectile's own position**, not its shooter's. A
  shooter spawns its arrow ahead of itself, so a shot fired from beside a plateau
  legitimately starts on top of it - and that must not be charged as a crossing.

The arrow is stopped by that budget, **not** by collision: it connects `area_entered`
only and never touches world geometry (section 5).

Ranged target *validity* is still decided by faction, range and target validity. **Not**
by elevation, and **not** by navigation reachability.

## 8. AI: CanReachTarget is not CanAttackTarget

Two separate questions. They were previously conflated, so an archer that could
happily shoot a player across a ravine refused to, because it could not walk there.

### CanReachTarget

*Can this actor physically get to a position where it could act?*

- Requires a walkable route between the actor's level and the target's level.
- The route must pass through a **declared ramp**. A cliff is never a route.
- If no route exists, the answer is `false` — and the actor must handle that
  **stably**, not by freezing or thrashing (§8.3).

### CanAttackTarget

*Is this actor allowed to damage that target from where it stands?*

- **Melee:** requires same elevation (§6) **and** being within melee reach.
- **Ranged:** requires range and line of fire. **Does not require CanReachTarget.**
  An archer that can already shoot must shoot rather than reposition.

### 8.3 No-route behaviour

When the target cannot be reached and cannot be attacked, an actor must settle into
a stable state. It must **not**:

- freeze permanently with no explanation;
- request a path every frame;
- walk into the cliff indefinitely;
- jitter back and forth on the boundary;
- retarget every frame looking for a reachable enemy.

A single declared fallback behaviour — hold clear of the cliff, wait, retry on a
timer — is correct. Magic offsets, magic timers and per-actor special cases layered
on a broken model are not (see §11).

## 9. Followers

A melee follower obeys every rule above and none of its own:

- it has the common elevation state;
- it is stopped by cliff boundaries;
- it navigates LOW ↔ HIGH through declared ramps only;
- it obeys the shared same-elevation melee rule;
- it keeps its existing lifecycle, formation, downed and revive behaviour unchanged.

A follower must not be able to reach the player by walking through a cliff, and must
not be able to melee across one. When it cannot reach the player, its existing
stuck-recovery behaviour applies — but recovery must never teleport it across an
elevation boundary, because that would bypass the model.

## 10. Invariants

These must hold at all times, in every scene. They are the acceptance criteria for
any elevation work.

| # | Invariant |
| --- | --- |
| 1 | An actor's level is one of exactly two values, `LOW` or `HIGH`. |
| 2 | An actor's level comes from the terrain authority, not from its own copy of the rules. |
| 3 | An actor cannot cross a cliff boundary in either direction. |
| 4 | An actor can cross LOW ↔ HIGH at a declared ramp, in both directions. |
| 5 | No actor can enter or leave high ground through any edge that is not a declared ramp. |
| 6 | The high-ground top surface is walkable and carries no movement collision. |
| 7 | A cliff boundary never blocks a projectile by collision. What stops a shot that changes level twice is the projectile's own crossing budget. |
| 8 | Melee requires same elevation, regardless of hitbox or sprite overlap. |
| 9 | Ranged attacks are valid across elevations, but a projectile may cross at most one LOW/HIGH boundary. |
| 10 | Ranged target validity never depends on navigation reachability. |
| 11 | An unreachable target produces a stable state, never a freeze or a per-frame retry storm. |
| 12 | A follower obeys the same elevation and melee rules as every other melee actor. |
| 13 | Where terrain looks traversable it is traversable, and where it looks blocked it is blocked. |

Invariant 13 is the visual half of the model. A terrain that satisfies 1–12 and
fails 13 is not finished — see `HIGHGROUND_TILE_GRAMMAR.md`.

## 11. Anti-patterns

Rejected by this design. If a change needs one of these, the change is wrong.

- Inferring elevation from Y, `z_index`, sprite order or art height.
- One giant collider covering the whole high-ground footprint.
- Walling only a plateau's bottom edge and leaving its sides and top open.
- Treating a cliff face as a generic wall-fill tile.
- Building terrain cliff-first, then making gameplay fit the picture.
- A separate elevation check inside each melee actor.
- Gating ranged target validity on being able to walk to the target.
- Magic offsets, magic timers, or magic distances compensating for a broken model.
- Special-casing one actor so it can cross a boundary others cannot.
- Migrating the main map before the isolated lab passes.

## 12. Verification

Elevation cannot be validated by reading code alone. Every elevation change needs
all three, in this order:

1. **Logic checks** — the binary rules: levels, ramp transitions, melee eligibility,
   ranged eligibility. Small, deterministic, one rule per check.
2. **Runtime scenarios** — spatial behaviour in the lab scene: walking a ramp,
   crossing a cliff, an enemy routing through a ramp, a projectile crossing a drop,
   a follower rejoining across a ramp. Too brittle to automate reliably; drive them
   and observe.
3. **Visual QA** — screenshots judged against the tile grammar. Automated assertions
   cannot decide whether a plateau reads as terrain or as a box.

A change is not verified by (1) alone, and never by "it loads without errors".
