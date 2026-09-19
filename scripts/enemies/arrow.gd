extends Area2D
class_name EnemyArrow

const ENV := preload("res://scripts/world/tiny_swords_environment.gd")

@export var speed: float = 440.0
@export var damage: int = 10
@export var lifetime: float = 2.8

var direction: Vector2 = Vector2.RIGHT

## Elevation the shot was loosed from. `origin_plateau` is the plateau the archer
## stood on (zero size when firing from the low ground); `from_high_ground` is its
## shorthand. Together they let a high shot fall past its own cliff while a low
## shot still cannot reach a plateau.
var from_high_ground := false
var origin_plateau := Rect2i(0, 0, 0, 0)


func _ready() -> void:
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    rotation = direction.angle()
    area_entered.connect(_on_area_entered)
    body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
    global_position += direction * speed * delta
    lifetime -= delta
    if lifetime <= 0.0:
        queue_free()


func _on_area_entered(area: Area2D) -> void:
    var player := area.get_parent() as Player
    if player == null:
        return
    if not _may_strike(player.global_position):
        return
    player.take_damage(damage, direction)
    queue_free()


## A shot fired from a plateau drops over that plateau's own cliff, so the wall
## directly below the shooter must not stop it. Every other wall still blocks,
## including every wall for a shot fired from the low ground.
func _on_body_entered(body: Node2D) -> void:
    if not (body is StaticBody2D):
        return
    if from_high_ground and global_position.y < ENV.cliff_y_of(origin_plateau):
        return
    queue_free()


## Low ground cannot reach high ground: a shot loosed from below passes under a
## target standing on a plateau instead of hitting it. High ground hits anywhere.
func _may_strike(target_position: Vector2) -> bool:
    if from_high_ground:
        return true
    if not ENV.elevation_at(target_position):
        return true
    # The target is on a plateau. It is only reachable once the shot has already
    # crossed above that plateau's cliff line, i.e. the shooter was level with it.
    var rect := ENV.plateau_at(target_position)
    return global_position.y <= ENV.cliff_y_of(rect)
