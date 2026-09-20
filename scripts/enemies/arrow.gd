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


func _physics_process(delta: float) -> void:
    global_position += direction * speed * delta
    lifetime -= delta
    if lifetime <= 0.0:
        queue_free()


## Hits any member of the player's party, not only the player, so a recruited
## companion is a real participant rather than an ignored bystander.
func _on_area_entered(area: Area2D) -> void:
    var victim := area.get_parent()
    if not PARTY.is_party_member(victim):
        return
    victim.take_damage(damage, direction)
    queue_free()


## Arrows fly over terrain. A cliff boundary is a **character movement** blocker, not
## a projectile blocker, so a shot fired from high ground reaches the low ground and
## one fired from below reaches a plateau. See
## `docs/environment/ELEVATION_SYSTEM.md` section 5.
##
## That separation is now stated rather than accidental. The scene's mask used to
## include the world-geometry bit, which looked like cliffs blocked arrows; they did
## not, because this script only ever connected `area_entered` and world geometry is
## a `StaticBody2D`, so the bit could never fire. It has been removed, so the mask
## says exactly what the arrow does: it hits party hurtboxes and nothing else.
##
## If a scene ever needs a real projectile blocker - a closed gate, a fortress wall -
## give it its own layer and add that bit here. Do not reuse the cliff boundary:
## that would silently change what terrain means for every ranged attacker.
##
## The elevation rule for melee lives on the melee paths instead, because a melee
## blow cannot cross between levels.
