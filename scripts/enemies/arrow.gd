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
	player.take_damage(damage, direction)
	queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body is StaticBody2D:
		queue_free()
