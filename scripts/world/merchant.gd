extends Area2D
class_name Merchant

const UI := preload("res://scripts/ui/tiny_swords_ui.gd")

signal interacted

var player_nearby := false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var prompt: Label = $Prompt

var _marker: Sprite2D
var _bob_time := 0.0
## Armed by default so playing the classic scene directly still shows the guide
## markers; the title backdrop turns them off explicitly, because there the player
## cannot move and a marker would advertise something they cannot act on.
var _interaction_active := true


func _ready() -> void:
    var frames := SpriteFrames.new()
    frames.add_animation("idle")
    frames.set_animation_speed("idle", 8.0)
    frames.set_animation_loop("idle", true)
    var sheet: Texture2D = load("res://asset/Units/Yellow Units/Pawn/Pawn_Idle Gold.png")
    for frame_index in 8:
        var frame := AtlasTexture.new()
        frame.atlas = sheet
        frame.region = Rect2(frame_index * 192, 0, 192, 192)
        frames.add_frame("idle", frame)
    sprite.sprite_frames = frames
    sprite.play("idle")
    prompt.position.y = UI.INTERACT_PROMPT_Y
    _marker = UI.add_interact_marker(self, wrapf(float(get_instance_id() % 628) / 100.0, 0.0, TAU))
    _refresh_interact_visuals()
    body_entered.connect(_on_body_entered)
    body_exited.connect(_on_body_exited)


## Call when control is handed to the player. The bubble is a guide to where to
## go, so it shows from a distance and hands over to the key prompt up close.
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

