extends SceneTree

const CLASSIC_SCENE := "res://scenes/main/game.tscn"
const MAIN_MENU_SCENE := "res://scenes/main/town_title.tscn"


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    create_timer(6.0).timeout.connect(_on_timeout)

    var packed := load(CLASSIC_SCENE) as PackedScene
    var game := packed.instantiate() as Node2D
    root.add_child(game)
    current_scene = game
    await process_frame
    await process_frame

    var ui := game.get_node("GameUI") as GameUI
    var quest := game.get_node("QuestManager") as QuestManager
    quest.accept_quest()
    await process_frame

    var quest_rect := ui.quest_label.get_global_rect()
    var gold_icon_rect := ui.gold_icon.get_global_rect()
    assert(quest_rect.end.x + 16.0 <= gold_icon_rect.position.x,
        "Classic quest objective overlaps the gold HUD group")

    ui.start_requested.emit()
    assert(not paused, "Classic start did not resume gameplay")
    ui.title_requested.emit()
    await process_frame
    await process_frame
    await process_frame

    assert(current_scene != null and current_scene.scene_file_path == MAIN_MENU_SCENE,
        "Classic title action did not open the unified main menu")
    assert(paused and current_scene.phase == "menu" and current_scene.menu.visible,
        "Unified main menu was not visible and paused")

    print("CLASSIC UI SMOKE PASS: HUD separation and unified title return")
    quit(0)


func _on_timeout() -> void:
    push_error("Classic UI smoke test timed out")
    quit(1)
