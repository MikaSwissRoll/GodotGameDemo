# Follower System Workflow

> **The automated test suite is frozen.** `tests/` is empty and there is no runner.
> Every `*_smoke` suite named in this document — including the three companion
> suites, `elevation_smoke` and `free_play_spawn_smoke` — **no longer exists**, and
> any step below that says to run one now means "reproduce it by hand in a running
> build". The workflow, invariants and failure signatures are all still valid; only
> the verification method changed. See [`TEST_WORKFLOW.md`](TEST_WORKFLOW.md).

## Purpose

How to add, modify, and debug recruitable companions in this project without
repeating the mistakes made while building the first one (Pawn_Knife).

This is the **process** document: what to inspect, what order to work in, what to
prove, and which failure signatures mean what.

For the **architecture** — layer tables, every tuned value, state-by-state behaviour —
see [`systems/FOLLOWER_SYSTEM.md`](systems/FOLLOWER_SYSTEM.md). The two are
deliberately separate: that one describes what exists, this one describes how to
change it safely.

Pawn_Knife took six commits and produced **ten gameplay bugs plus one testing failure**,
documented in full below. Only one was caught by reading the code. Plan the work so
each layer is run and observed before the next is built.

---

## Current Architecture

The minimum needed to reason about changes. Everything here was verified against the
code, not recalled.

### Files

| Concern | Path |
| --- | --- |
| Follower controller (states, follow, combat, downed) | `scripts/party/follower.gd` |
| Faction rules, layer constants | `scripts/systems/party.gd` |
| Follower scene (bodies, hitbox, hurtbox) | `scenes/party/follower.tscn` |
| Recruit NPC before hiring | `scripts/world/recruit_npc.gd`, `scenes/world/recruit_npc.tscn` |
| Recruitment transaction, companion ownership | `scripts/main/game.gd` |
| Free-play gating | `scripts/systems/classic_progression.gd` |
| Enemy-side targeting | `scripts/enemies/enemy.gd`, `scripts/enemies/archer.gd` |
| Arrow damage | `scripts/enemies/arrow.gd` |
| Contract tests | **Frozen and deleted.** The contract was carried by `companion_smoke`, `companion_integration_smoke` and `companion_archer_smoke`; see [`TEST_WORKFLOW.md`](TEST_WORKFLOW.md) |

### Recruitment

`Game.companion` (a single `Follower` reference, or `null`) is the **only**
recruitment state. It is owned by the game scene, not an autoload, and there is no
save system, so recruitment lasts one session.

Availability is gated on `ClassicProgression.Phase.FREE_PLAY`, set when the main
quest is handed in. `Game._on_main_quest_completed()` calls `pawn_knife.activate()`,
guarded by `is_instance_valid` because a recruited companion has already freed that
node and free play can be entered again.

The hire has **two independent gates** — the recruit node's `_interaction_active`
starts `false` and only `activate()` turns it on, and
`Game._on_pawn_knife_interacted()` independently refuses unless the phase is
`FREE_PLAY`. The transaction (check price → deduct gold → free the NPC → instantiate
the follower → `setup(player)`) is one non-yielding block, which is what makes double
hiring impossible rather than a checked flag.

### Faction

Enforced by **collision layers**, not by runtime checks. A friendly attack cannot
reach a friendly hurtbox because their masks do not intersect; no damage path has to
remember a faction test.

The authoritative table is in `party.gd`. Layers in use:

| Layer | Value | Carries |
| --- | --- | --- |
| 1 | 1 | player body |
| 2 | 2 | world geometry |
| 3 | 4 | enemy body |
| 4 | 8 | player attack hitbox |
| 5 | 16 | enemy hurtbox |
| 6 | 32 | player hurtbox |
| 7 | 64 | enemy attack hitbox |
| 8 | 128 | companion hurtbox |
| 9 | 256 | NPC body (Guard, Merchant, recruit) |
| 10 | 512 | companion body |

Companion scene values, which must stay mutually consistent:

```
Follower          layer 512   mask 262   (world + NPC bodies + enemy bodies)
  AttackHitbox    layer   8   mask  16   (enemy hurtbox only — never widen this)
  Hurtbox         layer 128   mask  64
```

`Party` exposes the three functions all targeting must go through:

- `is_party_member(node)` — `Player`, or anything implementing `is_party_member()`.
- `is_hostile(node)` — `Enemy` **or** `ArcherEnemy`. Never the Player, never a party
  member.
- `hostile_health(node)` — current health, or `0` for anything that is not a
  hostile. Use this instead of `.health` so a non-hostile reads as dead rather than
  as a live target.

### Follower behaviour

One state machine in `Follower`: `FOLLOW`, `COMBAT_APPROACH`, `ATTACK`, `RETURN`,
`DOWNED`. No per-state scripts.

- **Formation slot** is advanced by the *player's travel displacement*, not their
  facing, so it cannot snap left-and-right when the player taps a direction. Only
  updates when the player moved more than 0.5px.
- **Combat activation** is player-relative: an enemy must be within `assist_radius`
  of the **player**, not merely near the companion.
- **Leash**: past `leash_distance` from the player, the target is dropped and the
  state becomes `RETURN`.
- **Target stickiness**: the current target is kept while usable; a rival must be
  closer by a factor of `retarget_margin` to displace it.
- **Attack** is melee and its hitbox is enabled only for the swing. Overlap is
  polled after a physics frame, not left to `area_entered` alone.
- **`DOWNED`** freezes movement and attacks, makes the companion untargetable by
  enemies, and does not pause the game. Revival is automatic at 50% HP beside the
  player after `downed_seconds`.
- **Stuck recovery** needs two conditions together (far from the player **and** no
  progress), then escalates: recompute the slot, and only as a last resort — rate
  limited, and only when no enemy is alive — reposition.

`_perform_attack()` is the **only** class-specific hook. Everything above is
inherited.

### Elevation

`ENV.elevation_at(point)` reports whether a point is on high ground, and it samples
a **64px tile**. The player's melee has always refused to connect across a level
boundary; melee enemies now obey the same rule in three places (do not climb, do not
strike across, wait clear of a cliff they cannot cross). See
[`systems/FOLLOWER_SYSTEM.md`](systems/FOLLOWER_SYSTEM.md) for the detail.

**Consequence for spawn points:** an enemy spawn point on an unwalled plateau is
unreachable and therefore broken. `FREE_PLAY_SPAWNS` had one such point; it moved.

### Enemy-side targeting

Enemies find targets through the `party` group, and **group membership is set in
code** (`add_to_group("bandits")` in `Enemy._ready()` and `ArcherEnemy._ready()`),
never by a `groups=[...]` declaration in a scene file. Retargeting runs on a timer,
and a rival must be closer by `companion_preference` before an enemy switches away
from its current target.

---

## Follower Lifecycle

```
hidden recruit  --FREE_PLAY-->  active recruit  --hire (atomic)-->  follower
                                                                      |
                                          FOLLOW <--> COMBAT_APPROACH --> ATTACK
                                            ^                              |
                                            +---------- RETURN <-----------+
                                            
                                          any state --0 HP--> DOWNED --timer--> FOLLOW
```

Player death does not destroy the companion; a restart reloads the scene, so a new
run starts with `Game.companion == null` and the recruit hidden again.

---

## Follower System Invariants

Conditions any change must preserve. Each is enforced somewhere specific — the
"where" column is where to look when one breaks.

| # | Invariant | Enforced by |
| --- | --- | --- |
| 1 | At most one companion exists; `Game.companion` is the authority | `Game._on_recruit_accepted()` refuses when it is non-null |
| 2 | Hiring is atomic: no yield between the price check and the deduction | one straight-line block in `_on_recruit_accepted` |
| 3 | Hiring is impossible outside `FREE_PLAY` | both the node gate and the handler gate |
| 4 | The recruit NPC is removed on hire, never hidden | `pawn_knife.queue_free()` |
| 5 | A companion cannot damage the player, the Guard, the Merchant, or another companion | `AttackHitbox.collision_mask == 16` only |
| 6 | Anything asking "can the party hit this" goes through `Party.is_hostile()` / `hostile_health()` | `party.gd`; covers `Enemy` **and** `ArcherEnemy` |
| 7 | Anything asking "may the hostile side hit this" goes through `Party.is_party_member()` | `enemy.gd` `_nearest_party_actor`, `arrow.gd` |
| 8 | Enemy attack sources must be able to reach the companion hurtbox (layer 128) | melee hitbox mask 160, arrow mask 162 |
| 9 | The companion body must not sit on the player's body layer | `follower.tscn` layer 512, mask 262 |
| 10 | Companion targeting must not read `.health` directly on a candidate | `follower.gd` `_pick_target` / `_is_target_usable` |
| 11 | `"bandits"` membership is set in code, never by a scene declaration | `enemy.gd` / `archer.gd` `_ready()` |
| 12 | Follow logic uses the tracked formation slot, never raw `player.global_position` | `_advance_slot()` |
| 13 | Combat pursuit has a player-relative leash | `leash_distance`, checked in `_consider_combat` |
| 14 | Target selection is not recomputed blindly every frame | stickiness in `_consider_combat` |
| 15 | The attack hitbox is live only during a swing | `_perform_attack()` sets monitoring true then false |
| 16 | A `DOWNED` companion cannot move, attack, or be selected as a target | `_process_downed`, `enemy.gd` `_is_target_valid` |
| 17 | Revival restores a valid state and undoes the downed *pose*, not just the colour | `_process_downed()` (rotation, speed_scale, modulate) |
| 18 | A companion kill uses the normal enemy death pipeline and drops normal gold | `Enemy._die()` → `defeated`; no companion-specific path |
| 19 | Free-play kills must not advance the finished main quest | `Game._on_enemy_defeated` checks `quest.state == ACTIVE` |
| 20 | Companion targeting only ever considers the `"bandits"` group | `follower.gd` `_pick_target` |
| 21 | Enemy spawn points must be reachable (no unwalled plateau) | level layout + `FREE_PLAY_SPAWNS` |

---

## What We Learned from Pawn_Knife

Eleven failures, each a symptom → root cause → rule to carry forward: **ten gameplay
bugs** (Problems 1, 2, 4–11) and **one testing failure** (Problem 3) that let two of
the gameplay bugs through unnoticed.

Where the ten gameplay bugs came from is the point of the workflow below:

| Found by | Count | Which |
| --- | --- | --- |
| The user, playing the game | 7 | Problems 2, 4, 5, 6, 7, 8, 10 |
| A test run that failed | 2 | Problems 1, 9 |
| Reading the code while writing tests | 1 | Problem 11 |

**Nothing was found by reasoning about the implementation in the abstract.** Every bug
that mattered needed either a running game or a failing check.

Problem 6 was reported in the same message as Problem 5 and is a separate fault
(archers never re-evaluated their target, independent of group membership). Problems
3, 5, 9 and 10 are the most instructive overall, because in each case the obvious
reading of the symptom pointed at the wrong subsystem.

---

### Problem 1 — The companion never landed a hit

**Symptom.** The companion closed to melee range, entered `ATTACK`, played the
swing animation, and the enemy's health never moved. Repeatably.

**Root cause.** Two independent faults, both in the swing, neither in the AI:

1. `_begin_attack()` never faced the target. The hitbox is offset 44px *in front of*
   the companion using `_facing`, which was still whatever direction the companion
   last walked. It swung past the target's shoulder.
2. The hitbox was enabled and never disabled, and the result was read from
   `area_entered` alone. `area_entered` does **not** fire for an area that is
   already overlapping at the moment monitoring is enabled, so a target that was
   already in the box was never struck. Leaving monitoring on also meant an enemy
   walking into range later took damage with no swing at all.

**Misleading interpretation.** The obvious read is "the AI is not reaching the
target". It was reaching the target. Distance, state and target were all correct —
which is exactly why the diagnostic that mattered was *"did the enemy's HP go down"*
and not *"is the enemy in range"*.

**Failed / weak fixes.** None. The first fix attempt was the two above, applied
together, and it worked.

**Final fix.** `_begin_attack()` calls `_face(target.global_position - global_position)`
before playing the swing. `_perform_attack()` enables monitoring, awaits one physics
frame, polls `get_overlapping_areas()`, then sets monitoring back to `false`.

**Reusable rule.** When an attack "does not work", assert on **damage dealt**, never
on range or state. Then check, in order: is the hitbox positioned where the visual
says it is, is it actually live during the swing, and does the engine report the
overlap the geometry implies.

**Verification.** `companion_smoke._check_combat_and_downed` loops until the enemy's
health drops, and fails with enemy HP in the message.

---

### Problem 2 — The companion ignored every archer (reported by the user)

**Symptom.** "随从不会自主攻击敌人，完全不攻击." Sometimes the companion fought;
sometimes it stood and watched. In free-play camps it often did nothing.

**Root cause.** `ArcherEnemy` is its own `CharacterBody2D` class and shares **no base
class** with `Enemy`. Targeting read `Enemy.health` directly, so every archer failed
the health check and was skipped. A third of every free-play group is archers.

**Misleading interpretation.** "The follower AI is broken" or "the detection radius is
too small". Both wrong: it fought melee bandits perfectly. It fought *only* melee
bandits.

**Failed / weak fixes.** The arrow's damage handler had been extended to companions
in an earlier commit, and that was believed to have covered archers. It had not:
the handler can only run for a body the mask can see, and separately the companion
could not even select an archer as a target.

**Final fix.** All target queries go through `Party.is_hostile()` and
`Party.hostile_health()`, which cover both hostile families.

**Reusable rule.** In this project there are **two** enemy families with no shared
base. Never test `is Enemy` or read `.health` on a candidate. Route every
target question through `Party`.

**Verification.** `companion_archer_smoke._check_archer_is_hostile_classification`
asserts the two classes are unrelated (`not (archer as Node is Enemy)`) and that the
shared helper accepts it anyway;
`_check_companion_attacks_archer` moves every melee enemy away and requires the
companion to engage an archer it was never placed next to.

---

### Problem 3 — The tests shared the blind spot

This is a testing failure rather than a gameplay bug, and it is included because it is
what let Problems 2 and 5 reach the user at all.

**Symptom.** None — the tests were green. The bug was in the field.

**Root cause.** Every companion test only ever paired the companion with a melee
enemy that the test itself had placed adjacent to it. That proved a swing could land.
It never proved the companion would **seek** a fight, and it never exercised the
other enemy class at all. Problem 2 hid behind this for a full round.

**Misleading interpretation.** "The companion is well covered by tests."

**Final fix.** `companion_archer_smoke` places the enemy near the **player** and lets
the companion find it; `_check_companion_engages_spawned_enemy` uses an enemy the
free-play respawner created, not one the test placed.

**Reusable rule.** Stage the **situation**, not the **outcome**. If a test moves the
enemy onto the unit under test, it has assumed away the behaviour it claims to check.
Ask of every AI test: *would this still pass if the seeking logic were deleted?*

**Verification.** The new checks fail if `_pick_target` is stubbed to return `null`.

---

### Problem 4 — Arrows could not damage a companion (reported by the user)

**Symptom.** Enemy arrows passed through the companion with no damage.

**Root cause.** The arrow's `collision_mask` was `34` — world geometry plus the
**player's** hurtbox. The companion hurtbox is on layer 128, so the arrow had no
overlap with it and `area_entered` never fired. The handler had already been widened
to accept party members, which could never help: the handler is unreachable for a
body the mask cannot see.

**Misleading interpretation.** "The arrow handler does not know about companions." It
did. It was simply never called.

**Final fix.** Arrow mask `34 → 162` (world + player hurtbox + companion hurtbox).

**Reusable rule.** Widening a faction is **two** changes: the handler **and** the
mask. Assert the mask on the instantiated node, because the mask is what actually
gates the signal.

**Verification.** `companion_archer_smoke._check_arrow_damages_companion` asserts the
mask includes `LAYER_COMPANION_HURTBOX`, then fires one arrow at an isolated
companion and requires its health to drop.

---

### Problem 5 — Free-play enemies were not in the `bandits` group (reported by the user)

**Symptom.** "随从在经典模式被雇佣后依旧不攻击不追踪敌方单位." It appeared to work
right after hiring, then stopped once the player moved on to the respawning camp.

**Root cause.** `groups=["bandits"]` was declared in `game.tscn` on the seven
**placed** story enemies, and **no script anywhere called `add_to_group`**. In Godot
a scene-declared group belongs to that instance and is **not** carried by
`instantiate()`, so every enemy created at runtime — including the entire free-play
loop — arrived with no group at all.

Measured: **0 of 4** spawned enemies in the group, before the fix; **4 of 4** after.

`Follower._pick_target()` iterates that group, so the companion had nothing it was
allowed to target. The same omission was silently starving
`_count_alive_enemies()`, so a companion regenerated mid-fight because it believed no
enemies existed.

**Misleading interpretation.** "The companion's detection or leash is misconfigured."
The numbers were fine; the candidate list was empty. The clue is the *shape* of the
report — working, then stopping at a specific progression point. That points at a
population change, not at tuning.

**Failed / weak fixes.** None implemented, but it is worth recording what would not
have worked: raising `detect_radius` or `assist_radius`, and adding group membership
to the spawner only rather than to the class.

**Final fix.** `add_to_group("bandits")` in `Enemy._ready()` and
`ArcherEnemy._ready()`. It is a property of the **class**, not of a placement, so it
belongs in the class. The scene declarations remain and are harmless — Godot ignores
a duplicate group add.

**Reusable rule.** Any group a system queries at runtime must be assigned **in
code**, in `_ready()`, on every class that can belong to it. A `groups=[...]` in a
`.tscn` covers only the instances placed in that scene. Grep for the group name and
confirm at least one `add_to_group` exists — a scene-file declaration does not count.

**Verification.** `free_play_spawn_smoke` now asserts `is_in_group("bandits")` for
every spawned enemy — the spawner's own array was the wrong thing to check, and it
was exactly what the old test checked. `companion_archer_smoke` acquires a
**spawned** free-play enemy.

---

### Problem 6 — Archers never retargeted (same report as Problem 5)

**Symptom.** Archers shot the player and never the companion, even with a companion
standing much closer.

**Root cause.** `ArcherEnemy._ready()` took the player once
(`get_first_node_in_group("player")`) and never re-evaluated. The melee `Enemy` had
gained a timer-based `_retarget`; the archer had not. So fixing the arrow mask
(Problem 4) only did half the job: an arrow *could* hit a companion, but no archer
ever aimed at one.

**Misleading interpretation.** "The arrow fix covered archers." It covered their
projectiles, not their aim.

**Final fix.** `ArcherEnemy` gained the same stable retargeting — a 1.6s interval and
a `companion_preference` bias so the player stays the default target.

**Reusable rule.** When you extend faction or targeting behaviour, enumerate **every**
class that acquires a target. Here that is `Enemy`, `ArcherEnemy`, and `Follower`, and
they are three separate implementations.

**Verification.** `companion_archer_smoke._check_archer_targets_companion` puts the
player far away and the companion close, and requires the archer to switch.

---

### Problem 7 — The enemy punched through invisible NPCs (reported by the user)

**Symptom.** "增加NPC，敌人的碰撞体积." The player and enemies walked straight through
the Guard, the Merchant, and the recruit.

**Root cause.** All three were `Area2D` only — that is all the interaction pattern
needs — so none of them had a physical body.

**Final fix.** A `StaticBody2D` (`Body`) added to each, on a **new** NPC body layer
(256). Putting them on the world layer would have worked but would also have made
every character mutually collidable; a dedicated layer means a character can be
blocked by a person without changing how characters collide with each other. The
interaction radius is 78px, far larger than the body, so being blocked never prevents
talking to an NPC.

**Reusable rule.** An `Area2D` NPC has no presence in the physics world. If it should
be solid, it needs a separate body node, and that body needs its own layer unless the
existing ones are genuinely correct.

**Verification.** `companion_archer_smoke._check_npcs_have_bodies` checks the node,
its layer, and its shape; `_check_player_is_blocked_by_npc` proves the clamp with
`move_and_collide` — a 90px push into the Guard ends 30px from his centre, which is
exactly the two capsule radii (16 + 14).

---

### Problem 8 — The companion and enemies passed through each other

**Symptom.** After the companion body moved to its own layer (512, so it could not
shove the player), enemies started walking through it.

**Root cause.** Mutual collision in Godot requires **both** sides to name the other.
The companion's mask excluded the enemy body layer, and the enemy's mask excluded
the companion body layer.

**Decision.** The user chose that a companion *should* be blocked by enemies. Applied
symmetrically: companion mask `258 → 262` (+ enemy body), enemy mask `3 → 772`
(+ companion body).

**Reusable rule.** After moving a body to a new layer, find every actor that should
still collide with it and add the layer to **both** masks. A one-sided mask produces
an actor that is pushed but cannot push — or, as here, silently passes through.

**Verification.** `_check_companion_is_blocked_by_enemy` asserts both masks and proves
the clamp (90px push → 38px from the enemy's centre).

---

### Problem 9 — A hidden NPC could still be talked to

**Symptom.** Before the main quest was finished, walking over the recruit's future
position opened his dialogue.

**Root cause.** The recruit was made invisible, but invisibility does not stop an
`Area2D` detecting the player, and `_unhandled_input` still accepted the interact.
The node's own `_interaction_active` also defaulted to `true`.

**Final fix.** `_interaction_active` now defaults to `false`; `activate()` sets
visibility and re-enables interaction together; `_unhandled_input` returns early while
inactive. The hire handler also refuses outside `FREE_PLAY`, because this is the one
unrepeatable transaction in the mode.

**Misleading interpretation.** "Invisible means inactive." It does not. Visibility
and participation are separate switches.

**Reusable rule.** Gate on an explicit **active** flag, not on `visible`. Add the
second gate anyway when the action is destructive or unrepeatable.

**Verification.** `companion_smoke._check_hidden_before_free_play`.

---

### Problem 10 — The swing alone does not cover a cliff

**Symptom.** Enemies climbed cliff faces onto the high ground and attacked the
player from the other side of a cliff.

**Root cause.** Two things. `add_plateau` walls only a cliff's **bottom** edge, so
the sides and top of a plateau are open; and enemy movement had no elevation check at
all, though the player's melee already refused to cross a level boundary.

**Final fix.** Three rules on melee enemies: do not step toward a target on another
level; refuse a victim on another level in `_on_attack_area_entered`; and wait clear of
a cliff they cannot cross instead of pressing against it.

The hit guard is **separate** from the movement guard and must stay: the melee hitbox
sits 55px in front of the enemy, so it can cross a line the enemy's feet have not
crossed.

**Reusable rule.** Geometry that only walls one face of a region is not a boundary.
When a rule applies to "an attack between A and B", gate the **hit**, not just the
decision to attack.

**Verification.** `elevation_smoke` — four approach directions, a cross-level strike,
and a direct call to the hit handler for the case the movement rule prevents from
arising naturally.

---

### Problem 11 — Free-play kills fed a finished quest

**Symptom.** Not observed in play; found while writing the progression tests.

**Root cause.** `_on_enemy_defeated` recorded a kill unconditionally, so a free-play
respawn could advance the main quest or make it arrive pre-completed.

**Final fix.** The handler records only while `quest.state == ACTIVE`. Both the story
and free-play paths funnel through the same handler, so the check lives there once.

**Reusable rule.** A shared reward handler that outlives the content that introduced
it needs an explicit state gate. Write the gate where the handler is, not at each
call site.

**Verification.** `classic_progression_smoke` asserts the quest is not ready on kills
alone and not on gold alone.

---

### Test and tooling traps

Not gameplay bugs, but each cost real time and will recur.

**A scene-declared group is not a class property.** See Problem 5. Groups a system
queries at runtime must be assigned in `_ready()`.

**`elevation_at` samples a 64px tile.** A test that placed the player 10px above the
cliff line was still on the plateau's **last tile row**, so its "across the cliff"
check was silently testing two actors on the same level. *Assert your setup, not just
your result.*

**A body spawned inside a wall gets ejected.** The cliff wall spans `cliff_y` to
`cliff_y + 58`. An enemy placed at `cliff_y + 8` was pushed out and looked like it
had climbed the cliff. Place test actors in clear space, and assert the setup.

**`Control.position` is derived from anchors.** Assigning `position.x` on an
anchor-centred `Control` is overwritten on the next layout pass — the toast panel
landed hard against the left screen edge instead of under the text. Set
`offset_left` / `offset_right`.

**A `Label` wider than its parent can fail to paint.** With `AUTOWRAP_OFF` a Label's
minimum width is its content width. The toast label measured 838px inside a 780px
panel and rendered nothing at all — no error, no clipping, just nothing. Size the
container from the measured text.

**`await` inside a cheap assertion makes it observe a later state.** A test helper
containing `await` resumed after later sections had changed the progression phase, so
it failed against a state it was never meant to test. Keep synchronous checks
synchronous.

**A downed companion cannot revive while enemies live** — by design. A test that asks
a downed companion to land a killing blow will fail, correctly. Reset the state
explicitly first.

**PowerShell `Set-Content -Encoding utf8` writes a BOM,** and Godot refuses to parse a
`.tscn` beginning with `\ufeff`. This took the enemy scene down entirely. Use the file
tools for scene files, or strip the BOM afterwards.

**Line-filtering scripts corrupt files.** Cleaning debug prints out of the capture
tool with a hand-written line filter silently deleted four target branches and a
function. Prefer targeted edits; re-read and diff after any scripted rewrite.

---

## Common vs Class-Specific Behavior

The split matters more than any individual value, because getting it wrong means every
new follower re-implements the hard parts.

### Common — inherited from `Follower`, do not re-implement

Recruitment and gating; companion lifetime; the state machine; formation and
following; catch-up; player association; faction membership; target **validity**;
combat activation; the leash; target **stickiness**; stuck recovery; the downed cycle
and revival; out-of-combat regeneration; animation selection.

### Class-specific — the intended extension points

| Class | Owns | Must not duplicate |
| --- | --- | --- |
| **Pawn_Knife** (current) | melee approach distance, attack range, swing timing, hitbox placement | anything above |
| **Archer** (future) | preferred range, retreat when a target closes, projectile spawn | target selection, leash, downed, recovery |
| **Healer** (future) | ally evaluation, heal priority, support positioning | target *validity* helpers — extend `Party` instead |

**`_perform_attack()` is the one hook a new class must override.** It is called
exactly when the hit window opens, with the companion already stopped and facing the
target. An archer overrides it to spawn a projectile; a healer overrides it to act on
an ally. Nothing else in the state machine assumes a melee swing.

**It is a coroutine, and the call site relies on that.** `_process_attack` calls it
without `await`, and the implementation suspends on
`await get_tree().physics_frame` to poll overlap. Two consequences for anyone
overriding it:

- The `ATTACK` state is not held open by the hook. `_attack_phase` is what holds it,
  and it keeps ticking down while the hook is suspended. A hook that needs longer
  than the wind-up plus `attack_active` must drive its own timing; it cannot extend
  the state.
- Anything the override does *before* its first `await` runs synchronously, and
  anything after it runs a frame later. The current melee hook relies on this: the
  hitbox is enabled before suspending and disabled after.

An archer's override has no need to suspend at all — spawn the projectile and return —
which is why the hook is written as a plain method rather than an awaited one.

An archer will additionally need to **override or extend target selection**, because
`_pick_target()` returns the nearest hostile and an archer wants a preferred distance
band rather than the closest enemy. Extend by making the scoring a method, not by
copying `_consider_combat`.

A healer needs a concept the current code does not have — target selection over
**allies**. That is a genuine extension, not a copy. Put the ally query in `Party` so
faction rules stay in one place.

---

## Convergence Rule

If **the same symptom returns after a fix**, stop patching and re-derive the fault
from authoritative state. Do not reach for another threshold, timer, or offset.

### The trigger that actually happened here

The user reported "the companion does not attack" twice, in different words:

1. First: *"随从不会自主攻击敌人，完全不攻击"* → the cause was archer targeting
   (Problem 2). A correction was made to the target queries.
2. Then: *"随从在经典模式被雇佣后依旧不攻击不追踪敌方单位"* → the cause was **group
   membership** (Problem 5), an entirely different subsystem, in the same symptom.

Between those two reports, an agent could easily have spent the interval tuning
`detect_radius`, `assist_radius`, and the leash — all of which were already correct.
The state machine, the distances, and the target validity were all fine. The candidate
**list** was empty.

### The rule

When a follower symptom does not yield to one correct-looking fix, do **not** adjust a
number. Enumerate and verify, in this order, printing real values:

1. **Authoritative state** — `Follower.state`, `_attack_phase`, `_attack_cooldown_left`
2. **Target identity** — is `target` non-null, and is it the node you expect?
3. **Candidate list** — what does the query the follower actually uses return *right
   now*? At least one of this project's bugs was an empty candidate list.
4. **Target position** and distance against the relevant radius
5. **Faction and masks** — `Party.is_hostile`, hitbox mask, hurtbox layer
6. **Collision** — is something physically blocking the approach?
7. **Lifecycle** — `DOWNED`? no player reference? scene reloaded?

Change code only after one of those seven is proven wrong by output, not by reading.

### Corollary: a fix in one place is a question about every other place

Three of this project's bugs were **one fault present in more than one location**, and
each was found only after the first instance was fixed:

| Fault | Fixed first in | Also present in |
| --- | --- | --- |
| Targeting excluded a class | `Follower._pick_target` | `_is_target_usable`, `_count_alive_enemies` |
| Attack source could not reach companions | melee hitbox mask | arrow mask |
| Targeting read a stale class assumption | `Follower` | `ArcherEnemy` (never retargeted at all) |

After fixing any targeting or faction fault, immediately ask: **which other class,
state, or mask has the same shape of bug?** Grep for the pattern rather than waiting
for the next report.

### What is worth patching locally

Threshold tuning is legitimate when the *behaviour* is right and only the *feel* is
wrong — a companion that trails slightly too far, or a stop dead zone that is a few
pixels too tight. It is not legitimate as a response to a unit that is not acting at
all, because that is a state or identity fault wearing a movement costume.

---

## Workflow for Adding a New Follower

Incremental, with a runtime check at each step. **Do not build recruitment + follow +
combat + targeting + recovery and then test.** Pawn_Knife was built that way and the
result was ten gameplay bugs, none of which a per-step runtime check would have
missed.

**1. Inspect the foundation.** Read `follower.gd`, `party.gd`, `follower.tscn`, and
`game.gd`'s recruitment section. Identify what is already common.

**2. Inspect the actual assets.** List the character's PNGs and measure them. Do not
assume an animation exists. Pawn_Knife ships exactly three strips — Idle (8 frames),
Run (6), Attack (4), all 192×192, no directional variants, no hurt or death art. For
a new character, note the frame counts and whether a hurt/death sheet exists, because
that determines how downed is represented.

**3. Decide the split.** Write down, before coding, which behaviour is common and
which is class-specific. If the answer is "all of it is class-specific", the
foundation is being bypassed.

**4. Add the scene.** Duplicate `follower.tscn`. Set the sprite sheets in
`_build_frames()` via `sprite_frames_factory.add_strip(frames, name, path, count,
Vector2i(192,192), fps)`. Verify the layer values (`512 / 262`, hitbox `8 / 16`,
hurtbox `128 / 64`) before moving on — a wrong mask here produces a bug that surfaces
much later as "friendly fire" or "cannot be hit".

**5. Implement the attack hook only.** Override `_perform_attack()`. Leave everything
else alone.

**6. Run it as a follower first, with no recruitment.** Instantiate it in the game
scene next to the player and confirm it walks to formation. A follower that cannot
follow is not ready to fight.

**7. Add the recruit NPC.** Copy `recruit_npc.gd` / `.tscn`. Set `prompt_text`.
Confirm it is listed in the scene with `visible = false`.

**8. Add the hire path.** Add a second gate on the phase, a price constant, and a
`_hire_*` that frees the NPC and instantiates the follower. Keep the transaction in
one non-yielding block.

**9. Test recruitment before combat exists.** Gating, insufficient gold spending
nothing, exact deduction, no second charge, no duplicate node. The cheapest bugs to
find are here.

**10. Verify the faction and collision matrix against a live enemy.** Companion
cannot hurt the player/Guard/Merchant; the enemy can hurt the companion; the enemy can
still hurt the player; both bodies block each other. Assert masks *and* prove one
clamp with a real move.

**11. Verify enemy-side targeting.** The enemy must be able to choose the new
companion. If there is more than one companion, confirm enemies do not all pile onto
one.

**12. Verify combat end to end.** Engage, land damage, drop the target when the leash
breaks, return to formation. Assert **damage dealt**, not state.

**13. Verify downed and revival.** Reach 0 HP, stop acting, stop being targeted, no
pause, revive at the right health, pose and colour restored, back to following.

**14. Verify stuck recovery.** Separate it from the player with geometry and confirm
it returns. Confirm the teleport fallback is rate-limited and refuses while enemies
are alive.

**15. Check the economy and progression.** Its kills must drop normal gold and must
not touch a completed quest.

**16. Stress it.** Several enemies, rapid direction changes, a target dying during
approach and during the swing, the player retreating mid-fight, the player dying,
pause/resume, restart.

**17. Visual QA.** Capture formation, combat and the recruit dialogue. See
[Visual QA](#visual-qa).

**18. Full regression.** All suites. Adding a companion touches enemy targeting and
collision masks, which are load-bearing for unrelated features.

---

## Workflow for Modifying Existing Follower AI

1. **Read the invariants table above first.** Most regressions here are a violated
   invariant, not a missing feature.
2. **Reproduce before changing.** Reduce the bug to a reliable manual reproduction
   first — a fixed position, a fixed enemy, a fixed order of actions. Every bug in
   this document that was understood quickly was first reduced to a failing check;
   with no suite, the reproduction *is* the check.
3. **Classify before tuning.** Decide whether the fault is in **state**, **target
   identity**, **target position**, **faction**, **collision**, or **presentation**.
   Tuning a threshold is only valid once the state transition is proven correct.
4. **Change one layer.** If the change is to targeting, do not also retune movement in
   the same step; you will not know which one fixed or broke it.
5. **Re-check the shared surfaces by hand.** Enemy targeting and the `bandits` group
   are shared, so after any follower change also watch a melee enemy and an archer
   pick their target in a running build — the same fault usually exists in both
   hostile families.
6. **If a bug is found, record how to catch it.** Note the situation that exposes it —
   which enemy, which distance, which side — so the next person can reproduce it
   without rediscovering the setup. Problems 2, 4, 5 and 6 were all one fault present
   in more than one place.

---

## Debugging Decision Tree

### The companion is not moving

Check in this order, and stop at the first that is wrong:

1. **Is `_player` valid?** `_physics_process` returns early when it is not.
2. **Is `state == DOWNED`?** Downed returns before any movement.
3. **Is `_attack_phase > 0.0`?** A swing in progress returns before movement, and
   this is the **most likely cause of a "frozen" companion that still animates** —
   the swing is playing, so it looks alive, but `state` never leaves `ATTACK`. Check
   whether `_attack_phase` is decrementing at all. It only decrements inside
   `_process_attack`, so anything that returns earlier while a swing is pending
   strands it. A target that dies mid-swing is the usual trigger.
4. **What is `_slot`, and how far is the companion from it?** Inside
   `follow_stop_distance` means it correctly stops.
5. **Is `velocity` non-zero?** If it is, physics is the problem — check that the body
   mask (`262`) matches the layer of whatever is blocking.
6. **Is the stuck timer accumulating?** `_check_stuck` needs *both* distance and no
   progress.

### The companion is moving strangely

Separate the layers before changing anything:

- **Jitter at rest** → the stop dead zone. `follow_stop_distance` exists to prevent
  exactly this; a small residual drift while still catching up is not jitter.
- **Snapping side to side when the player changes direction** → slot derivation.
  Confirm `_advance_slot` uses travel displacement and not facing.
- **Trailing too far behind** → `catch_up_distance` / `catch_up_multiplier`.
- **Walking into a wall and stopping** → collision mask, or the target is genuinely
  unreachable and stuck recovery is about to intervene.
- **Visually sliding without the run animation** → presentation only; check
  `_animate()` and the `speed_scale` left by the downed state.

### The companion does not attack

Check in this order. The first three are structural and are where every real bug in
this project lived:

1. **Is the candidate list actually populated?** `_pick_target()` iterates the
   `bandits` group. Is the enemy in it? (Problem 5 — the most expensive bug in this
   system.)
2. **Does `Party.is_hostile()` accept the enemy?** Both `Enemy` and `ArcherEnemy`
   must pass. (Problem 2.)
3. **Does `Party.hostile_health()` return > 0?** Never read `.health` directly.
4. **Is the enemy within `assist_radius` of the *player*?** A companion beside a
   distant enemy still will not engage.
5. **Is it within `detect_radius` of the companion?**
6. **Is `_attack_cooldown_left` still running?**
7. **Is the hitbox mask still `16`, and is the target's hurtbox on layer 16?**
8. **Does damage actually land?** Assert on the enemy's HP. If the enemy is in range,
   in state `ATTACK`, animating, and unharmed, look at hitbox **position** and
   whether monitoring is genuinely toggling. (Problem 1.)

### The enemy ignores the companion

1. **Faction:** is the companion in the `party` group, and does
   `Party.is_party_member()` return true? `Follower` adds itself in `_ready()`.
2. **Candidate list:** `_nearest_party_actor()` iterates the `party` group.
3. **Validity:** `Enemy._is_target_valid` rejects a downed companion and any
   `health <= 0`. Confirm the companion is neither.
4. **Retarget timer:** an enemy holds its target for `retarget_interval`. Within that
   window it will not switch, by design.
5. **Preference:** the player is the default; a companion must be closer by
   `companion_preference`.
6. **Damage:** the enemy's attack mask must include layer 128, and the arrow's mask
   too (Problem 4).

### The companion attacks the wrong units

**Check faction before touching movement or targeting.** If the companion can damage
the player or an NPC, the fault is a collision mask, and no amount of AI tuning will
fix it:

- `AttackHitbox.collision_mask` must be **exactly 16**.
- `Party.is_hostile()` must reject the victim.
- Confirm the victim's hurtbox layer is not accidentally 16.

### The companion will not come back after combat

1. Is the target actually invalid now? A live enemy outside the leash is dropped by
   `_consider_combat`; a live enemy *inside* it is not.
2. Is the companion itself beyond `leash_distance`? That forces `RETURN`.
3. Is stuck recovery needed? It will not teleport while enemies are alive.

### Gold or quest counters behave oddly after a companion kill

The death pipeline is shared. Check `Game._on_enemy_defeated`: it gates the quest
counter on `quest.state == ACTIVE`, and the drop amount is bound per enemy at
signal-connection time. A companion kill should be indistinguishable from a player
kill.

---

## Runtime Validation Strategy

**The suites are frozen and deleted.** What follows is what they used to answer,
kept as a checklist: these are the situations a companion change has to be watched
in, by hand, in a running Classic Mode build. Read it as "go and look at this",
not "go and run this".

| Formerly a suite | The situation to reproduce by hand |
| --- | --- |
| `companion_smoke` | recruitment, gating, gold, following, faction, combat, downed |
| `companion_integration_smoke` | enemy targeting, enemy damage, kill → gold, player death, restart |
| `companion_archer_smoke` | archers targetable, arrows hurt companions, spawned enemies, NPC bodies, blocking clamps |
| `elevation_smoke` | enemies respect cliff boundaries |

Also load-bearing for companion work: free-play group membership and spawn
placement, and the quest counters behind them.

### Rules that came out of this work

- **Stage the situation, not the outcome.** Put the enemy near the player and let the
  companion decide. Placing the enemy on the companion proves only that a swing can
  land.
- **Judge the effect.** Damage dealt, health changed, node freed, group membership —
  not state enums or distances that merely imply them.
- **Check the setup too.** A misplaced actor makes a claim true for the wrong reason,
  silently. The old elevation suite twice "proved" a climb because the actors had been
  placed inside the cliff they were meant to be beside.
- **Drill through the real path.** Drive the actual signal or handler rather than
  restating its rule in the check, or the check will keep passing after the rule
  changes.
- **When a test fails, check the test before the code.** Four of this project's
  "failures" were the test's fault: an enemy placed adjacent during a following check,
  a player a hair above the cliff line, an enemy spawned inside a wall, and a helper
  with a stray `await`.
- **Never assert on `visible` for activity.** Assert the flag that actually gates the
  behaviour.

---

## Test Matrix

### Recruitment

- [ ] unavailable before the intended story state
- [ ] available after it
- [ ] insufficient gold: the offer is refused **and spends nothing**
- [ ] confirming an unaffordable hire still spends nothing
- [ ] successful purchase
- [ ] exactly the configured price deducted
- [ ] cannot hire twice; no second deduction
- [ ] exactly one follower node after hiring
- [ ] the recruit NPC is freed, not merely hidden
- [ ] no interaction prompt survives on a hired companion

### Following

- [ ] idle near the player: settles, does not drift
- [ ] long-distance travel: keeps up
- [ ] catches up when far behind
- [ ] rapid player direction changes: no violent formation snap
- [ ] does not stand on the player (measurable separation)
- [ ] narrow path / obstacle: passes or recovers
- [ ] separated by geometry: stuck recovery returns it
- [ ] cannot push the player around

### Combat

- [ ] activates for an enemy near the player
- [ ] ignores an enemy far from the player
- [ ] accepts **both** hostile classes
- [ ] holds one target without per-frame switching
- [ ] drops a target beyond the leash
- [ ] target dies during approach
- [ ] target dies during the swing
- [ ] lands damage (the assertion that matters)
- [ ] returns to formation after combat
- [ ] a companion kill drops normal gold and is collectable

### Faction

- [ ] cannot hurt the player
- [ ] cannot hurt the Guard, Merchant, or recruit
- [ ] can hurt enemies
- [ ] an enemy can target the companion
- [ ] an enemy can still target the player
- [ ] an arrow can damage the companion
- [ ] companion and enemy bodies block each other

### Downed / recovery

- [ ] reaches 0 HP
- [ ] AI stops
- [ ] cannot attack while downed
- [ ] enemies stop treating it as a target
- [ ] the game does not pause
- [ ] revives at the configured ratio
- [ ] pose and colour restored (rotation, speed_scale, modulate)
- [ ] returns to following
- [ ] does not permanently disappear

### Regression

- [ ] player combat and stamina
- [ ] enemy AI against the player alone
- [ ] NPC interaction and dialogue
- [ ] gold and the shop
- [ ] quest counters (and that free-play kills do not advance a finished quest)
- [ ] free-play spawning: count cap, placement, group membership
- [ ] pause / resume
- [ ] death and restart
- [ ] existing companions still behave

---

## Visual QA

Capture through `tools/capture_visual_qa.ps1`. Companion targets are declared in
`tools/visual_qa_capture.gd`: `recruit_offer`, `companion_follow`,
`companion_combat`, `npc_line`, `toast_plain`.

Screenshots caught things the logs did not. What to look for:

- **Formation separation.** In `companion_follow` the companion settles roughly 80px
  behind and to one side of the knight, and the two silhouettes stay distinct. If they
  read as one blob, the formation offset is wrong — do not fix it from numbers alone.
- **Combat readability.** In `companion_combat` a damage popup over the enemy is the
  visual proof the companion is contributing; if the popups are absent while the
  companion is clearly swinging, that is Problem 1.
- **Downed representation.** The downed pose is the **idle frame rotated 90°** with a
  grey-dark `modulate` (`0.45, 0.44, 0.48`) and frozen animation. **Rotate the
  `AnimatedSprite2D`, never the `CharacterBody2D`** — rotating the body would drag its
  `CollisionShape2D` round with it and leave a standing capsule lying on its side.
- **Recruit dialogue.** `recruit_offer` shows the hire modal in the shared panel
  style. NPC speech sits on a `#26362f` 82% panel with a 2px gold border; plain status
  toasts do not. If a speech line renders with no panel, or a status line renders with
  one, check which call was used (`show_npc_line` versus `show_toast`).
- **Chinese text.** Always check the rendered frame. A `Label` whose minimum width
  exceeds its container renders **nothing**, with no error — that is how the toast
  panel silently lost its text once.

Capture the full viewport for context, and crop only to measure.

---

## Known Failure Patterns

Recurring shapes to recognise quickly.

| Symptom | Most likely cause | First check |
| --- | --- | --- |
| Works near the village, stops in free play | group membership | `add_to_group("bandits")` present? |
| Ignores one type of enemy | class hierarchy | does `Party.is_hostile()` cover it? |
| Swings and misses | hitbox position / monitoring | assert damage, not range |
| Companion is invulnerable | mask does not reach layer 128 | attacker masks |
| Companion or NPC walks through people | missing body node or one-sided mask | both masks name each other |
| Invisible NPC still talks | gating on `visible` | an explicit active flag |
| Two swings' worth of damage, or a hit with no swing | hitbox left monitoring | monitoring toggled per swing |
| Body snapped to a wrong position on spawn | spawned inside geometry | the ejection is silent |
| Test passes but the feature is broken | the test staged the outcome | would it pass with the seek logic deleted? |
| Test fails and the code looks right | the test's own setup | assert the setup |

### Known tech debt (verified, currently present)

- `enemy.gd` `_is_target_valid` compares `candidate.state != 4` against a **literal**
  for `Follower.State.DOWNED`. It works, but it will break silently if the enum is
  reordered, and it couples the enemy to the follower's enum ordering. Prefer a named
  query such as `is_down()` on the companion.
- `party.gd`'s header doc comment still lists only layers 1–8; the table above
  includes 256 and 512. The **constants** are correct and are the authority; the
  comment is stale.
- `Party.nearest_hostile()` is **dead code** — nothing calls it. Do not assume it
  participates in any live path, and do not "fix" behaviour by editing it. Either
  delete it or route a real caller through it; the live target queries are
  `Follower._pick_target`, `Follower._count_alive_enemies`,
  `Enemy._nearest_party_actor`, and `Game._respawn_free_play_group`.

---

## Future Extension Notes

- **A second simultaneous companion is not supported.** `Game.companion` is a single
  reference. Multiple companions need a container and a formation-slot allocation
  scheme — `_advance_slot()` currently hardcodes one offset.
- **Archer.** Override `_perform_attack()` to spawn a projectile, and extend target
  selection to prefer a distance band rather than the nearest enemy. Keep the leash,
  downed, and recovery inherited. Arrows already ignore elevation, for everyone.
  Three archer-specific gotchas, each paid for once already:
  - The projectile is a **separate scene** with its own `collision_mask`. It must
    include the layer of everything it should hit, or it silently passes through.
    `arrow.tscn` needed widening twice, once per faction it was expected to reach.
  - The **firing unit's own target acquisition** is separate from its projectile's
    mask. `ArcherEnemy` originally took the player once in `_ready` and never
    re-evaluated, so fixing the arrow's mask alone changed nothing.
  - A ranged follower can sustain fire from outside an enemy's reach, which the
    current melee balance does not anticipate. It should probably be squishier than
    Pawn_Knife, and its `detect_radius` matters more than its movement speed.
- **Healer.** Needs ally-target evaluation, which does not exist yet. Add the ally
  query to `Party`, not to the follower, so faction rules stay in one place.
- **Persistence.** There is no save system; recruitment is per-session by design.
  Adding one would mean persisting `Game.companion`'s identity, not the node.
- **Enemy `state != 4`.** If a third companion class is added, replace the literal
  with a named method before the enum ordering becomes load-bearing.

---

## Generic Skill Candidates

Lessons here that appear project-independent and could become a reusable skill later.
**Not created during this task.**

1. **Scene-declared groups are not class properties.** A `groups=[...]` in a `.tscn`
   applies only to instances placed in that scene; `instantiate()` does not carry it.
   Any group a system queries at runtime must be assigned in `_ready()`. Symptom
   shape: "works for placed objects, silently fails for spawned ones."

2. **Widening a faction is two changes.** The damage handler *and* the collision mask.
   A widened handler is dead code for a body the mask cannot see.

3. **Godot `Control.position` is derived from anchors.** Assign `offset_*` on an
   anchor-positioned control; assigning `position` is overwritten on the next layout
   pass.

4. **An attack test must assert damage.** Asserting range or state proves the decision
   to attack, not the attack. Applies to any engine.

5. **Stage the situation, not the outcome.** A test that places the subject at the
   goal line proves nothing about the path to it. Applies to any AI.

6. **Sibling classes with no shared base.** Before writing a type test over a game's
   entities, enumerate the actual class hierarchy. Two visually similar units are
   often unrelated classes.

7. **PowerShell `Set-Content -Encoding utf8` writes a BOM,** and BOM-sensitive
   parsers reject the file. Applies to any tooling that edits files PowerShell-side.

Items 1–3 and 7 are Godot/PowerShell-specific and would belong in a Godot skill;
items 4–6 are general agent-debugging discipline.
