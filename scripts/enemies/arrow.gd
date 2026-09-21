extends Area2D
class_name EnemyArrow

const PARTY := preload("res://scripts/systems/party.gd")

@export var speed: float = 440.0
@export var damage: int = 10
@export var lifetime: float = 2.8

var direction: Vector2 = Vector2.RIGHT


func _ready() -> void:
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    rotation = direction.angle()
    area_entered.connect(_on_area_entered)


## How many LOW/HIGH boundaries this projectile may cross before the terrain stops it.
##
## Melee is 0, enforced at the attacker. An arrow is 1: it may be shot up onto a plateau
## or down off one, but a path that changes level twice is stopped at the second
## boundary. That is what makes high ground cover as well as a firing position - an
## archer on the low ground cannot shoot past a plateau at someone behind it.
##
## A future piercing shot would raise this to 2; a fireball would not have a budget.
const ELEVATION_CROSSINGS_MAX := 1

## Crossings counted so far, and the level the arrow was last seen on.
##
## `-1` means "not known yet", and it is filled in on the first physics frame rather than
## in `_ready`. The shooter assigns this node's position AFTER `add_child`, and `_ready`
## runs inside that call - so reading the level there would read the default (0, 0) and
## get it wrong for every shot.
var _crossings := 0
var _level := -1


func _physics_process(delta: float) -> void:
    global_position += direction * speed * delta
    if not _track_elevation():
        return
    lifetime -= delta
    if lifetime <= 0.0:
        queue_free()


## Counts a crossing when the arrow's own tile changes level. Returns false once the
## budget is spent and the arrow has been destroyed.
##
## Polling the position each frame is sufficient, and no raycast or shape cast is needed.
## A tile is 64px and the arrow covers 440 / 60 = 7.3px per physics frame, so it cannot
## skip a region: the thinnest possible one is a whole tile, eight times its own step.
## Re-check that arithmetic before raising `speed` much past 3000.
##
## The level comes from `Elevation` and never from the art or the z-order, so retiling a
## map cannot change what an arrow does.
func _track_elevation() -> bool:
    var here := Elevation.level_at(global_position)
    if _level < 0:
        # The arrow's own position is authoritative, not its shooter's. The archer spawns
        # it 45px ahead of itself, so a shot fired from beside a plateau starts already
        # on top of it - and that must not be charged as a crossing.
        _level = here
        return true
    if here == _level:
        return true
    _crossings += 1
    if _crossings > ELEVATION_CROSSINGS_MAX:
        queue_free()
        return false
    _level = here
    return true


## Hits any member of the player's party, not only the player, so a recruited
## companion is a real participant rather than an ignored bystander.
func _on_area_entered(area: Area2D) -> void:
    var victim := area.get_parent()
    if not PARTY.is_party_member(victim):
        return
    victim.take_damage(damage, direction)
    queue_free()


## An arrow crosses elevation, but only once. A cliff boundary is a **character
## movement** blocker rather than a projectile blocker, so a shot from high ground
## reaches the low ground and one from below reaches a plateau - but the arrow carries a
## budget of one LOW/HIGH crossing (ELEVATION_CROSSINGS_MAX above), and a path that
## changes level twice is stopped at the second boundary. That is what makes a plateau
## cover as well as a firing position. See `docs/environment/ELEVATION_SYSTEM.md`
## section 7.
##
## The arrow still does not collide with terrain, and that has not changed. It connects
## `area_entered` only, and world geometry is a `StaticBody2D`, so the two can never
## meet: the scene's mask used to carry the world bit, which looked like cliffs blocked
## arrows but could never fire, and it was removed so the mask says what the arrow
## really does. The budget is what actually stops a shot, and it reads `Elevation` -
## never the art, never the z-order.
##
## If a scene ever needs a real projectile blocker - a closed gate, a fortress wall -
## give it its own layer and connect the arrow to that. Do not reuse the cliff boundary:
## that would silently change what terrain means for every ranged attacker.
##
## The rule for melee is 0 crossings and lives on the melee paths instead, because a
## melee blow cannot cross at all.
