extends Area2D
class_name EnemyArrow

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


func _on_area_entered(area: Area2D) -> void:
    var player := area.get_parent() as Player
    if player == null:
        return
    player.take_damage(damage, direction)
    queue_free()


## Arrows fly over terrain. They are not stopped by cliffs, plateau walls, or any
## other static body, and they do not distinguish elevation: a shot fired from a
## plateau reaches the low ground and a shot fired from below reaches a plateau.
##
## The terrain restriction lives on the player's melee attack instead, which cannot
## cross between elevation levels. Keeping it here as well made enemy archers stop
## at a wall the player could simply walk around.
