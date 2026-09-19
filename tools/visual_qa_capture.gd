extends SceneTree

const VIEWPORT_SIZE := Vector2i(1280, 720)
const RUN_SCENE := "res://scenes/main/run_game.tscn"
const CLASSIC_SCENE := "res://scenes/main/game.tscn"
const VALID_TARGETS := [
    "main_menu",
    "village",
    "wilderness",
    "enemy_camp",
    "combat",
    "merchant_shop",
    "dialogue_ui",
    "pause_menu",
    "shop_overlay",
    "result_dead",
]

var _target := "main_menu"
var _output_path := ""


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    if not _parse_arguments():
        quit(2)
        return

    DisplayServer.window_set_size(VIEWPORT_SIZE)
    root.size = VIEWPORT_SIZE
    var scene_path := CLASSIC_SCENE if _target in [
        "village", "wilderness", "enemy_camp", "dialogue_ui"
    ] else RUN_SCENE
    var packed := load(scene_path) as PackedScene
    if packed == null:
        push_error("Visual QA could not load scene: %s" % scene_path)
        quit(3)
        return

    var game := packed.instantiate()
    root.add_child(game)
    current_scene = game
    await _wait_frames(3)
    await _configure_target(game)
    await _wait_frames(8)
    RenderingServer.force_draw(false)
    await process_frame

    var image := root.get_texture().get_image()
    if image == null or image.is_empty():
        push_error("Visual QA captured an empty viewport image")
        quit(4)
        return

    var absolute_output := ProjectSettings.globalize_path(_output_path)
    var directory_error := DirAccess.make_dir_recursive_absolute(absolute_output.get_base_dir())
    if directory_error != OK:
        push_error("Visual QA could not create output directory: %s" % error_string(directory_error))
        quit(5)
        return
    var save_error := image.save_png(absolute_output)
    if save_error != OK:
        push_error("Visual QA could not save screenshot: %s" % error_string(save_error))
        quit(6)
        return

    print("VISUAL_QA_CAPTURED target=%s path=%s size=%dx%d" % [
        _target, absolute_output, image.get_width(), image.get_height()
    ])
    paused = false
    quit(0)


func _parse_arguments() -> bool:
    var arguments := OS.get_cmdline_user_args()
    var index := 0
    while index < arguments.size():
        match arguments[index]:
            "--target":
                if index + 1 >= arguments.size():
                    push_error("--target requires a value")
                    return false
                _target = arguments[index + 1]
                index += 2
            "--output":
                if index + 1 >= arguments.size():
                    push_error("--output requires a value")
                    return false
                _output_path = arguments[index + 1]
                index += 2
            _:
                push_error("Unknown visual QA argument: %s" % arguments[index])
                return false
    if _target not in VALID_TARGETS:
        push_error("Unknown visual QA target '%s'. Valid targets: %s" % [_target, ", ".join(VALID_TARGETS)])
        return false
    if _output_path.is_empty():
        _output_path = "res://screenshots/visual_qa/%s.png" % _target
    return true


func _configure_target(game: Node) -> void:
    if _target in ["main_menu", "combat", "merchant_shop", "pause_menu", "shop_overlay", "result_dead"]:
        await _configure_run_target(game)
    else:
        await _configure_classic_target(game)


func _configure_run_target(game: Node) -> void:
    var ui := game.get_node("RunUI")
    match _target:
        "main_menu":
            paused = true
        "combat":
            ui.start_requested.emit()
            await _wait_frames(10)
            paused = true
        "merchant_shop":
            game.gold = 12
            ui.set_gold(12)
            game.call("_enter_shop")
        "pause_menu":
            ui.start_requested.emit()
            await _wait_frames(5)
            game.phase = "pause"
            ui.show_pause()
            paused = true
        "shop_overlay":
            # The real four-button shop modal, which is the tallest the shared
            # overlay gets and the layout that drives the adaptive panel height.
            ui.start_requested.emit()
            await _wait_frames(6)
            game.gold = 12
            ui.set_gold(12)
            game.call("_enter_shop")
            ui.call("show_shop", 12, game.shop_upgrade_id,
                game.health_potion_price, game.stamina_potion_price, game.upgrade_price)
            paused = true
        "result_dead":
            # Drive a real death so the result overlay is reached the way the
            # game reaches it, which also proves the HUD is hidden behind it.
            # Clear the spawn invulnerability, otherwise take_damage no-ops.
            ui.start_requested.emit()
            await _wait_frames(6)
            var hero := game.get_node("Player")
            hero._invulnerability_left = 0.0
            hero.take_damage(hero.max_health, Vector2.RIGHT)
            await _wait_frames(6)
            paused = true


func _configure_classic_target(game: Node) -> void:
    var ui := game.get_node("GameUI")
    var player := game.get_node("Player")
    var camera := player.get_node("Camera2D") as Camera2D
    camera.position_smoothing_enabled = false
    ui.start_requested.emit()
    match _target:
        "village":
            player.global_position = Vector2(760, 790)
        "wilderness":
            player.global_position = Vector2(2050, 800)
        "enemy_camp":
            player.global_position = Vector2(4000, 800)
        "dialogue_ui":
            player.global_position = Vector2(760, 790)
            ui.show_toast("守卫：盗匪袭击了村庄！请击败 5 名盗匪，并收集 5 枚金币。", 30.0)
    camera.reset_smoothing()
    if _target != "dialogue_ui":
        ui.toast_label.visible = false
    await _wait_frames(4)
    paused = true


func _wait_frames(count: int) -> void:
    for _frame in count:
        await process_frame