# Follower system

## Purpose

How a recruited companion works in Classic Mode: who can be hired, gated on what,
how it follows and fights, and where a new companion class plugs in.

The first companion is **Pawn_Knife**, a melee hire from the village who becomes
available once the main quest is handed in.

## Recruitment lifecycle

```
main quest handed in  ->  FREE_PLAY  ->  recruit appears  ->  talk
   ->  (gold < 25: refused, nothing spent)
   ->  (gold >= 25: offer, confirm)  ->  25 gold deducted  ->  NPC freed
   ->  follower spawned at the NPC's position  ->  walks to the player
```

**The transaction is atomic, and there are two gates.** The recruit node is inert
until free play (`RecruitNpc._interaction_active` starts false, `activate()` turns
it on), and `Game._on_pawn_knife_interacted()` independently refuses unless the
phase is `FREE_PLAY`. Hiring is the only unrepeatable transaction in Classic Mode,
so it does not rely on the signal only ever arriving from the intended place.

Double hire is impossible by construction rather than by a flag: on success the
recruit node is `queue_free()`d and `Game.companion` is set, so there is no second
stall to talk to and `_on_recruit_accepted()` refuses if a companion already
exists. Gold is deducted in the same non-yielding block that frees the NPC, so
there is no window in which a second confirmation could spend twice.

The follower spawns **at the stall he was standing at**, not on the player, and
then walks over under its own follow behaviour. That avoids both a teleport pop and
a duplicate pawn appearing.

### Gating

Availability is driven by `ClassicProgression.phase == FREE_PLAY`, which the main
quest's turn-in sets. The recruit is hidden and inert before that, so there is
nothing to explain to a player who wanders past the spot early.

## Faction rules

Enforced by collision layers, not by runtime checks, so friendly fire is impossible
by construction. `scripts/systems/party.gd` holds the table.

| Layer | Value | Carries |
| --- | --- | --- |
| 1 | 1 | player body |
| 2 | 2 | world geometry |
| 3 | 4 | enemy body |
| 4 | 8 | player attack hitbox |
| 5 | 16 | enemy hurtbox |
| 6 | 32 | player hurtbox |
| 7 | 64 | enemy attack hitbox |
| 8 | 128 | **companion hurtbox** |
| 9 | 256 | **NPC body** (Guard, Merchant, recruit) |
| 10 | 512 | **companion body** |

- A companion's attack hitbox masks **16 only**, so it can reach enemy hurtboxes and
  nothing else. It cannot damage the player, the Guard, the Merchant, or itself.
- A companion's hurtbox is on **128**, which the player's attack mask (16) does not
  include, so the player cannot hit their own companion.
- Enemy attack sources were widened to see companions: the melee hitbox mask is
  **160** (player hurtbox + companion hurtbox) and the arrow's is **162**
  (world + both hurtboxes).
- NPC bodies are on their own layer **256** rather than the world layer or the
  player's layer, so characters can be blocked by a person without making every
  character mutually collidable.
- A companion's body is on **512**, deliberately *not* the player's layer 1, so it
  never pushes the player. Mutual collision is arranged by naming each other
  explicitly: the companion's mask is **262** (world + NPC bodies + enemy bodies)
  and the enemy's mask is **772** (player + world + companion bodies). So a
  companion is blocked by scenery, people and enemies exactly as the player is,
  without any two party members shoving each other.

The `Enemy` and `ArcherEnemy` classes share **no base class**. Everything that asks
"is this a valid target" goes through `Party.is_hostile()` / `Party.hostile_health()`,
which cover both — see the bug list below for why that matters.

`Party.is_party_member()` decides who the hostile side may target: the `Player`, plus
anything implementing `is_party_member()`. Friendly NPCs are deliberately **not**
party members, so they stay out of enemy targeting.

The Guard, the Merchant and the recruit are `Area2D`s for interaction, so a solid
`StaticBody2D` sits alongside each on layer 256. Without it the player and the
enemies walk straight through a person. The interaction radius is 78px, far larger
than the body, so being blocked never prevents talking to them.

## Enemy targeting

Enemies find their target through the `party` group: the `Player`, plus anything
implementing `is_party_member()`. Friendly NPCs are deliberately **not** party
members, so they stay out of enemy targeting.

Both hostile classes retarget on a timer (`retarget_interval`, 1.6s), never per
frame, so neither can flicker between the player and a companion mid-swing. A rival
must be clearly closer before a switch (`companion_preference`, 0.6).

**Group membership is set in code, not in the scene.** `Enemy._ready()` and
`ArcherEnemy._ready()` call `add_to_group("bandits")`. A `groups=[...]` declared in
a `.tscn` belongs to that placed instance and is *not* carried by `instantiate()`,
so relying on it meant every runtime-spawned enemy was invisible to companions,
target queries and the alive count. This is a property of the class, so it lives in
the class.

## Gold drops

| Enemy | Drop |
| --- | --- |
| Melee bandit | 1 |
| **Archer** | **3** |

The amount is bound per enemy when its `defeated` signal is connected, not looked up
from a shared "last defeated" field: two enemies can die in the same frame, and a
shared field would pay the wrong amount to one of them. An archer pays more because
it is the harder kill, shooting back from range.

## Elevation is a boundary for melee enemies

`ENV.elevation_at(point)` answers whether a point is on high ground, sampling a
**64px tile**, so a point a few pixels above a cliff line is still on the plateau's
last tile row. Two things follow from that:

- The player's melee has always refused to connect across a level boundary.
- Melee enemies now obey the same rule, in three places:
  1. **They do not climb.** `Enemy._physics_process` will not step toward a target
     on another level, and `ArcherEnemy` will not reposition across one. Arrows still
     fly over terrain in both directions; only the archer's own feet are restricted.
  2. **They do not strike across.** `_on_attack_area_entered` refuses a victim on the
     other level. This is separate from (1): the melee hitbox sits 55px in front of
     the enemy, so it can cross a line the enemy's feet have not crossed.
  3. **They wait clear of a cliff they cannot cross.** There is no pathfinding, so an
     unreachable target would otherwise leave the enemy pressed against the wall.
     It backs off until `cliff_hold_distance` (110px) away and pauses
     `approach_retry_seconds` (1.6s) before trying again — the pause is what stops a
     target standing on the edge from making it oscillate.

The plateau builder only walls a cliff's **bottom edge**; the sides and top of a
plateau are open. That is why the rule lives in the characters rather than in the
terrain, and why the camp rise was crossable from three directions.

Free-play spawn points must therefore be on the low ground or reachable by a ramp.
`FREE_PLAY_SPAWNS` had one point on the camp rise, which would have stranded an
enemy where it could never reach the player; it moved below the cliff wall.

**Expedition stages are flat.** `RunArena` paints its landmark patch with
`ENV.add_ground_rect`, so no plateau is registered and `elevation_at()` is `false`
everywhere. The same stranding bug had already shipped there: stage 2's landmark
covered tile `(14, 3)`, and `SPAWNS[4]` is `Vector2(950, 220)` — an archer spawned
on a plateau it would never step off. Elevation remains a Classic Mode feature
only; it is not a rule the arena should be re-tested against.

## Follower states

One state machine in `Follower` (`scripts/party/follower.gd`), no per-state scripts:

| State | Behaviour |
| --- | --- |
| `FOLLOW` | Walk to the formation slot; stop once inside `follow_stop_distance` |
| `COMBAT_APPROACH` | Close on the current target, or re-evaluate / give up |
| `ATTACK` | Stand still through the swing; the hit window opens near its end |
| `RETURN` | Triggered when the leash is exceeded; drops the target |
| `DOWNED` | Frozen, untargetable, waiting to revive |

## Formation and following

The slot is **advanced by the player's own displacement**, not by their facing:

```
slot = player + travel_direction * follow_offset.x + perpendicular * follow_offset.y
```

Following facing would make the formation snap violently left-to-right every time
the player taps a direction. Basing it on actual travel keeps the companion behind
whatever direction the player really moved, and it only updates when the player has
moved more than 0.5px, so a standing player leaves the slot alone.

Defaults (`follow_offset = (-46, 30)`) put the companion **behind and slightly to
one side**: about 55px away at rest, never on the same pixels.

- `follow_stop_distance` (14px) is the dead zone that prevents micro-adjust jitter.
- `catch_up_distance` (260px) multiplies speed by `catch_up_multiplier` (1.5) so a
  left-behind companion closes the gap instead of trailing forever.

## Combat activation and leash

A companion only fights what is close to **the player**, not what is closest to
itself:

- `assist_radius` (340px) — an enemy further than this from the player is ignored
  however close it is to the companion.
- `detect_radius` (300px) — how far the companion will look.
- `leash_distance` (420px) — if the companion itself gets further than this from the
  player, it drops the target and returns.

That is what stops it being pulled across the map by one fleeing enemy.

## Target selection

Nearest qualifying hostile, with **stickiness**:

- The current target is kept while it is alive, valid, and within the leash.
- A rival is only adopted when it is closer than `retarget_margin` (0.7) times the
  current distance — clearly more important, not merely marginally nearer.
- Invalid means: freed, dead, or without `take_damage`.

There is no per-frame switching; re-evaluation only happens on the paths above.

## Combat

Melee, following the enemy's swing convention so both read the same way:

```
approach -> in attack_range (62px) -> stop -> attack_windup (0.22s)
        -> hit window opens for attack_active (0.12s) -> attack_cooldown (1.15s)
```

The hitbox is **only momentarily live** each swing, and overlap is polled after a
physics frame rather than relying on `area_entered` alone. Leaving it monitoring
would let an enemy that walked into range afterwards be struck with no swing, and
an enemy already inside when it was enabled reports no entry event at all — that
second case was a real bug during implementation.

## Downed and revival

A companion can be reduced to 0 HP but **never dies permanently**. On reaching 0:

- state becomes `DOWNED`; it cannot move or attack,
- the sprite is **turned 90°, greyed and darkened**, which reads as "down" and needs
  no new art,
- it stops being a valid enemy target, and
- it does not pause the game.

After `downed_seconds` (6s) it revives at `revive_health_ratio` (50%) **beside the
player**, not where it fell, so it is not dropped back into whatever downed it.
The pose and colour are undone on revival.

## Out-of-combat recovery

`regen_per_second` (3 HP/s) once no hostile is alive, after a `regen_delay` (4s)
hold. Regeneration is suppressed entirely while any hostile lives, so a fight still
costs something and the player is not asked to manage companion health.

## Stuck recovery

Two conditions must hold together — being far away alone is normal:

- further than `stuck_distance` (220px) from the player, **and**
- no progress beyond `stuck_progress_epsilon` (12px) for `stuck_check_seconds` (2.5s)

Recovery escalates in order of intrusiveness:

1. recompute the formation slot and return to `FOLLOW`;
2. only if that has already been tried within `reposition_cooldown` (12s) **and** no
   enemy is alive, move the companion to a free point near the player.

Step 2 picks a point that is not inside world geometry. Combined with the cooldown
and the "nobody is fighting" condition, the fallback can never look like teleport
spam or yank the companion out of a fight.

## Initial balance

Chosen against the existing numbers (player: 100 HP, 25 damage, 0.5s cooldown;
melee enemy: 75 HP, 12 damage, 1.3s cooldown):

| Value | Pawn_Knife | Reasoning |
| --- | --- | --- |
| `max_health` | 60 | Below the player, above one enemy hit |
| `move_speed` | 150 | Faster than an enemy (125), slower than the player (220) so it never outruns them |
| `attack_damage` | 14 | Just over one enemy hit; the player's 25 stays the main source |
| `attack_cooldown` | 1.15 | Slower than the player's 0.5s, so the player remains primary |
| `attack_range` | 62 | Short of the enemy's 90, so it has to commit |

The intent is that a companion noticeably improves a fight without soloing it.

## Extension points for a future class

A new companion class should only need to change **what it does when it arrives**.
Everything else is inherited:

| Concern | Where it lives | A new class changes it? |
| --- | --- | --- |
| Recruitment, price, gating | `Game` + `ClassicProgression` | No |
| Formation, follow, catch-up | `Follower._advance_slot`, `_process_follow` | No |
| Combat activation, leash | `Follower._consider_combat`, `_pick_target` | Maybe (radii) |
| Target stickiness | `Follower._consider_combat` | No |
| Faction and collision | `party.gd` + the scene's masks | No |
| Downed, revival, regen, stuck | `Follower` | No |
| **The attack itself** | **`Follower._perform_attack()`** | **Yes** |

`_perform_attack()` is the single class-specific hook. An archer overrides it to
spawn a projectile instead of opening a melee hitbox; a healer overrides it to act
on an ally. `attack_range`, `attack_damage` and `attack_cooldown` are already
`@export`, so a class is mostly a scene with different values and masks plus that
one method.

To add one: duplicate `scenes/party/follower.tscn`, point it at the new class's
script, set the sprite sheets and the exported values, add a `RecruitNpc` instance
with its own price and dialogue branch, and hand it to the same hire path.

## Known limitations

- **One companion.** `Game.companion` is a single reference; there is no party
  container, no formation slots beyond the first, and no way to have two.
- **No companion stamina**, potions, equipment, levels or skills. Deliberate.
- **No companion HUD.** Health is shown only by the flash on a hit; there is no
  portrait, bar, or downed timer. Judged not yet necessary — the state is readable
  in the world because the companion changes pose and colour.
- **No pathfinding.** Movement is direct steering with world collision, so a
  companion can be briefly separated by a building and rely on stuck recovery
  rather than routing around it.
- **Recruitment is not persisted.** There is no save system, so it lasts for the
  session: a restart replays the tutorials and the hire. This matches how the rest
  of Classic Mode progression already behaves.
- **No companion dialogue** beyond the hire, and no issued commands.

## Problems found during implementation

Recorded because each cost real time and would repeat:

1. **A BOM broke the enemy scene.** Writing a `.tscn` through PowerShell's
   `Set-Content -Encoding utf8` prepends a byte-order mark, and Godot refuses to
   parse `\ufeff[gd_scene`. One masked change to a collision mask took the whole
   enemy scene down. Edit scene files with the file tools, or strip the BOM after.
2. **A hidden NPC could still be talked to.** Making the recruit node invisible was
   not enough: its Area2D still detected the player and its handler still ran. Fixed
   by gating both the node and the transaction.
3. **The companion never landed a hit.** `area_entered` does not fire for an area
   already overlapping when monitoring is enabled, so a target standing in the
   hitbox from the start was never struck. Now the swing polls
   `get_overlapping_areas()` after a physics frame.
4. **`await` inside a cheap assertion made it observe the wrong state.** A test
   helper with an `await` resumed after later sections had advanced the phase, so it
   failed against a state it was never meant to test. Keep synchronous checks
   synchronous.
5. **The companion swung without facing its target.** The hitbox is offset in front
   of the companion, so attacking while still facing the last travel direction put
   the blow past the target's shoulder. It closed to range, entered `ATTACK`, and
   missed every time — the tests showed a valid target in range with the enemy's
   health never dropping. `_begin_attack()` now turns to face the target first.
6. **A downed companion cannot revive while enemies live**, by design, which made a
   test look like a failure: it asked a downed companion to land a killing blow.
   Worth knowing when writing anything that depends on the companion acting.
7. **The companion ignored every archer.** `ArcherEnemy` is a `CharacterBody2D` with
   its own class, sharing no base with `Enemy`. Targeting read `Enemy.health`
   directly, so archers were silently excluded — and in free play a third of each
   group is archers. Because the companion still fought melee bandits, the earlier
   tests passed: they only ever paired it with a melee enemy. Everything now goes
   through `Party.is_hostile()` / `Party.hostile_health()`.
8. **An arrow could not touch a companion.** The arrow's mask was `34` — world plus
   the *player's* hurtbox — so it simply had no overlap with the companion hurtbox
   on layer 128. Adding companion support to `arrow.gd`'s hit handler was not
   enough, because the handler is never reached for a body the mask cannot see. The
   mask is now `162`. When widening a faction, change the **mask** as well as the
   handler, and assert the mask on the instantiated node.
9. **A test that put the enemy on top of the companion proved nothing.** It showed a
   swing could land, but never that the companion would seek a fight. The real bug
   above hid behind it for a whole round. Pair the unit with the situation it will
   actually meet, and let it act rather than staging the outcome.
10. **The companion ignored every free-play enemy, and this was the reported
    "hired but never attacks".** A group declared in a scene file
    (`groups=["bandits"]` on the seven placed story enemies) belongs to *that
    instance*. `instantiate()` does **not** carry it, and no enemy script called
    `add_to_group`, so every enemy spawned at runtime arrived with no group at all.
    `Follower._pick_target()` searches that group, so it found only the surviving
    story enemies — which is why the companion seemed to work right after hiring and
    then stopped as soon as the player moved on to the respawning camp. Fixed by
    adding membership in `_ready()` of both enemy classes, where it belongs, since
    it is a property of the class and not of a placement. The same omission was
    silently starving `_count_alive_enemies()` (so a companion regenerated mid-fight)
    and `Party.nearest_hostile()`.
11. **An archer could not target a companion at all.** It took the player once in
    `_ready` and never re-evaluated, unlike the melee enemy which retargets on a
    timer. Fixing the arrow mask alone left that half inert: the arrow could hit a
    companion, but no archer ever aimed at one. The archer now retargets on the same
    stable interval, preferring the player unless a companion is markedly closer.
12. **`_on_main_quest_completed()` was not safe to run twice.** It called
    `activate()` on the recruit unconditionally, but entering free play again after
    the companion has been hired touches a freed node. Guarded with
    `is_instance_valid`.

## See also

- [UI visual rules](../art/UI_VISUAL_RULES.md) — the recruit dialogue follows the
  shared modal and Chinese typography rules.
- [Test workflow](../TEST_WORKFLOW.md) — `tests/companion_smoke.gd` covers this
  contract.
- [Current task](../CURRENT_TASK.md) — the implementation plan and assumptions.
