extends RefCounted
class_name Party

## Who is on whose side, in one place.
##
## The hard rule is enforced by collision layers rather than by runtime checks: a
## friendly attack simply cannot reach a friendly hurtbox, because their masks do
## not intersect. That makes friendly fire impossible by construction instead of
## relying on every damage path remembering to test a faction.
##
## Layers, as the project already assigns them:
##   1 (1)    player body
##   2 (2)    world geometry
##   3 (4)    enemy body
##   4 (8)    player attack hitbox
##   5 (16)   enemy hurtbox
##   6 (32)   player hurtbox
##   7 (64)   enemy attack hitbox
##   8 (128)  companion hurtbox      <- added for followers
##
## So a companion carries a hurtbox on layer 8 and an attack hitbox that masks
## layer 5. The player's attack masks 5 only, so it can never touch a companion,
## and no code has to remember that.

const LAYER_WORLD := 2
const LAYER_ENEMY_BODY := 4
const LAYER_ENEMY_HURTBOX := 16
const LAYER_ENEMY_ATTACK := 64
## Companions take damage from things that mask this, and the player's attack
## deliberately does not.
const LAYER_COMPANION_HURTBOX := 128
## What a companion's own body sits on. Deliberately not layer 1 (the player's),
## so enemies do not treat a companion as a solid obstacle and shove it around.
const LAYER_COMPANION_BODY := 512
## Solid but non-hostile bodies: the Guard, the Merchant, the recruit. On its own
## layer so characters can be blocked by a person without masking the player's or
## the enemies' body layer, which would make everyone mutually collidable.
const LAYER_NPC_BODY := 256


## Whether a node belongs to the player's party. Companions opt in by implementing
## `is_party_member`, so the player does not need to be reclassified and no
## inheritance is forced on the existing player script.
static func is_party_member(node: Node) -> bool:
    if node == null or not is_instance_valid(node):
        return false
    if node is Player:
        return true
    return node.has_method("is_party_member") and node.is_party_member()


## Whether a node is a valid target for the party's attacks.
##
## Both hostile families count. `Enemy` and `ArcherEnemy` are separate classes with
## no shared base — the archer is a `CharacterBody2D` of its own — so testing only
## for `Enemy` silently excluded archers, which is a third of every free-play group.
static func is_hostile(node: Node) -> bool:
    if node == null or not is_instance_valid(node):
        return false
    if node is Player or is_party_member(node):
        return false
    return node is Enemy or node is ArcherEnemy


## Current health of anything the party may fight, or 0 if it is not a target.
static func hostile_health(node: Node) -> int:
    if node is Enemy:
        return (node as Enemy).health
    if node is ArcherEnemy:
        return (node as ArcherEnemy).health
    return 0


## Nearest living hostile to a point, or null. Used by companions and by the enemy
## retarget check, so both agree on what counts as a target.
static func nearest_hostile(from: Vector2, within: float) -> Node2D:
    var best: Node2D = null
    var best_distance := within
    for node in Engine.get_main_loop().root.get_tree().get_nodes_in_group("bandits"):
        if not is_hostile(node):
            continue
        if hostile_health(node) <= 0:
            continue
        var distance := from.distance_to((node as Node2D).global_position)
        if distance < best_distance:
            best_distance = distance
            best = node
    return best
