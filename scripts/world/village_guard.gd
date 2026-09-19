extends Area2D
class_name VillageGuard

signal interacted

var player_nearby: bool = false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var prompt: Label = $Prompt


func _ready() -> void:
	var frames := SpriteFrames.new()
	frames.add_animation("idle")
	frames.set_animation_speed("idle", 8.0)
	frames.set_animation_loop("idle", true)
	var sheet: Texture2D = load("res://asset/Units/Blue Units/Pawn/Pawn_Idle.png")
	for frame_index in 8:
		var frame := AtlasTexture.new()
		frame.atlas = sheet
		frame.region = Rect2(frame_index * 192, 0, 192, 192)
		frames.add_frame("idle", frame)
	sprite.sprite_frames = frames
	sprite.play("idle")
	prompt.visible = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _unhandled_input(event: InputEvent) -> void:
	if player_nearby and event.is_action_pressed("interact"):
		interacted.emit()
		get_viewport().set_input_as_handled()


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_nearby = true
		prompt.visible = true


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_nearby = false
		prompt.visible = false
