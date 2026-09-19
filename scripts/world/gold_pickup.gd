extends Area2D
class_name GoldPickup

signal collected(value: int)

@export_range(1, 99) var value: int = 1


func _ready() -> void:
	body_entered.connect(_on_body_entered)

	var bob := create_tween().set_loops()
	bob.tween_property($Sprite2D, 'position:y', -7.0, 0.55)
	bob.tween_property($Sprite2D, 'position:y', 0.0, 0.55)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	collected.emit(value)
	queue_free()
