extends Node2D
## Keep the exact classic scene alive through the title-to-game camera move.
const RUN := preload("res://scripts/main/run_game.gd")
@export_range(0.2, 5.0) var transition_seconds := 1.8
@export var overview_center := Vector2(1260, 750)
@export var overview_zoom := Vector2(0.58, 0.58)
@onready var game = $Game
@onready var camera: Camera2D = $OverviewCamera
@onready var menu = $TownMenu
var phase := "menu"
var transition: Tween

func _ready() -> void:
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    game.prepare_title_view()
    camera.position = overview_center
    camera.zoom = overview_zoom
    camera.make_current()
    camera.reset_smoothing()
    menu.classic_requested.connect(start_classic)
    menu.expedition_requested.connect(start_expedition)
    menu.quit_requested.connect(quit_game)

func start_classic() -> void:
    if phase != "menu":
        return
    phase = "transition"
    menu.set_locked(true)
    var target: Vector2 = game.player.camera.global_position
    # Match the player's limit-clamped camera center before switching cameras.
    var half := get_viewport_rect().size * 0.5
    target = target.clamp(Vector2(half.x, half.y), Vector2(4800, 1500) - half)
    transition = create_tween().set_parallel(true)
    transition.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
    transition.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
    transition.tween_property(camera, "position", target, transition_seconds)
    transition.tween_property(camera, "zoom", Vector2.ONE, transition_seconds)
    transition.tween_property(menu.root, "modulate:a", 0.0, transition_seconds * 0.4)
    transition.chain().tween_callback(_finish_classic)

func _finish_classic() -> void:
    phase = "classic"
    menu.hide()
    menu.process_mode = Node.PROCESS_MODE_DISABLED
    game.player.camera.enabled = true
    game.player.camera.make_current()
    game.player.camera.reset_smoothing()
    camera.enabled = false
    game.begin_from_title()
    # The title no longer needs a running input or process owner.
    process_mode = Node.PROCESS_MODE_PAUSABLE

func start_expedition() -> void:
    if phase != "menu":
        return
    phase = "leaving"
    menu.set_locked(true)
    RUN.auto_start_next = true
    get_tree().paused = false
    get_tree().change_scene_to_file("res://scenes/main/run_game.tscn")

func quit_game() -> void:
    if phase == "menu":
        get_tree().quit()

func _unhandled_input(_event: InputEvent) -> void:
    if phase != "classic":
        get_viewport().set_input_as_handled()
