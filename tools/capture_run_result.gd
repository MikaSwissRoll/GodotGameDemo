extends SceneTree

## Captures the Expedition result screen in the two states that matter: a run that
## bought things, and a run that bought nothing. The empty case is the one that reads as
## a missing section if it is not designed for.
##
##   godot --path . --script res://tools/capture_run_result.gd
##
## Both outputs are kept in screenshots/visual_qa as references for the screen.

const SCENE := "res://scenes/main/run_game.tscn"
const OUT := "res://screenshots/visual_qa/run_result_%s.png"
const VIEWPORT_SIZE := Vector2i(1280, 720)


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    DisplayServer.window_set_size(VIEWPORT_SIZE)
    root.size = VIEWPORT_SIZE
    var packed := load(SCENE) as PackedScene
    if packed == null:
        print("PROBE FAIL: cannot load ", SCENE)
        quit(1)
        return
    var game := packed.instantiate()
    root.add_child(game)
    current_scene = game
    for node in _with_signal(game, "start_requested"):
        node.emit_signal("start_requested")
    await _frames(8)

    # A plausible finished run, so the screen is judged with real-length content.
    RunStats.record_damage(137)
    RunStats.record_damage(66)
    RunStats.record_purchase("??????", 3)
    RunStats.record_purchase("??????", 3)
    RunStats.record_purchase("???????????, 5)
    game.set("run_seconds", 214.0)
    game.set("kills", 7)
    game.set("gold_earned", 26)
    game.call("_finish_run", true)
    await _frames(12)
    await _shot("win")

    # Then the run that bought nothing: it has to read as "spent nothing", not as a
    # section that failed to draw.
    RunStats.reset()
    game.set("run_seconds", 46.0)
    game.set("kills", 2)
    game.set("gold_earned", 5)
    game.call("_finish_run", false)
    await _frames(12)
    await _shot("dead")
    quit()


func _shot(tag: String) -> void:
    RenderingServer.force_draw(false)
    await process_frame
    var image := root.get_texture().get_image()
    if image == null or image.is_empty():
        print("PROBE FAIL: empty viewport for ", tag)
        return
    var path := ProjectSettings.globalize_path(OUT % tag)
    DirAccess.make_dir_recursive_absolute(path.get_base_dir())
    image.save_png(path)
    print("CAPTURED ", path)


func _frames(count: int) -> void:
    for _i in count:
        await process_frame


func _with_signal(node: Node, signal_name: String) -> Array[Node]:
    var found: Array[Node] = []
    if node.has_signal(signal_name):
        found.append(node)
    for child in node.get_children():
        found.append_array(_with_signal(child, signal_name))
    return found
