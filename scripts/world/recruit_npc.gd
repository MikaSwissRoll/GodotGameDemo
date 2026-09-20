extends Area2D
class_name RecruitNpc

## A hireable companion standing in the village, before he is hired.
##
## Built on the same pattern as VillageGuard and Merchant: an Area2D that notices
## the player, raises the shared [E] prompt, and emits `interacted`. It deliberately
## does not own its own dialogue UI or its own gold handling; the game decides what
## he says and whether the hire can be afforded.
##
## He is hidden until Classic Mode reaches free play, and he is removed the moment
## he is hired, so there is never a spare copy standing in the village.

const UI := preload("res://scripts/ui/tiny_swords_ui.gd")
const FRAMES := preload("res://scripts/systems/sprite_frames_factory.gd")
const SHEET_DIR := "res://asset/Units/Blue Units/Pawn_Knife/"

signal interacted

## Shown in the prompt, so the same component can offer several companions.
@export var prompt_text: String = "E 交谈"
## Idle animation speed. The pawn sheets are authored for 8 fps like the others.
@export var idle_fps: float = 8.0

var player_nearby: bool = false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var prompt: Label = $Prompt

var _marker: Sprite2D
var _bob_time := 0.0
## Off by default. The game turns it on when free play begins. Without this a
## hidden recruit standing in the village would still detect the player and still
## accept an interact, which is how an invisible NPC can open a dialogue.
var _interaction_active := false


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	FRAMES.add_strip(frames, "idle", SHEET_DIR + "Pawn_Idle Knife.png", 8, Vector2i(192, 192), idle_fps)
	FRAMES.add_strip(frames, "run", SHEET_DIR + "Pawn_Run Knife.png", 6, Vector2i(192, 192), 10.0)
	sprite.sprite_frames = frames
	sprite.play("idle")
	prompt.text = prompt_text
	prompt.position.y = UI.INTERACT_PROMPT_Y
	_marker = UI.add_interact_marker(self, wrapf(float(get_instance_id() % 628) / 100.0, 0.0, TAU))
	_refresh_interact_visuals()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


## Bring the recruit into the world. Called when Classic Mode reaches free play.
## Until then he is neither visible nor listening, so a hidden NPC cannot be
## talked to by walking over the spot he will later occupy.
func activate() -> void:
	visible = true
	player_nearby = false
	set_interaction_active(true)


func set_interaction_active(active: bool) -> void:
	_interaction_active = active
	_refresh_interact_visuals()


func _refresh_interact_visuals() -> void:
	var show_marker := _interaction_active and not player_nearby
	prompt.visible = _interaction_active and player_nearby
	UI.set_interact_marker_visible(_marker, show_marker)


func _process(delta: float) -> void:
	_bob_time += delta
	UI.animate_interact_marker(_marker, _bob_time)


func _unhandled_input(event: InputEvent) -> void:
	if not _interaction_active:
		return
	if player_nearby and event.is_action_pressed("interact"):
		interacted.emit()
		get_viewport().set_input_as_handled()


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_nearby = true
		_refresh_interact_visuals()


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_nearby = false
		_refresh_interact_visuals()
