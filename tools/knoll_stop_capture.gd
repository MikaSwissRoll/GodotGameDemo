extends SceneTree

## Walks the player into each of stage 1's four knoll barriers and saves a viewport
## capture per side, so the stop distance is judged on rendered pixels.
## Windowed on purpose: the captures read the rendered viewport.
##
##   godot --path . --script res://tools/knoll_stop_capture.gd

const SCENE := "res://scenes/main/run_game.tscn"
const STAGE := 1
const OUT := "res://screenshots/knoll_stop"
const TRIALS := [
    {"name": "north", "from": Vector2(416.0, 300.0), "action": "move_down"},
    {"name": "south", "from": Vector2(416.0, 620.0), "action": "move_up"},
    {"name": "west", "from": Vector2(240.0, 448.0), "action": "move_right"},
    {"name": "east", "from": Vector2(592.0, 448.0), "action": "move_left"},
]


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    var packed := load(SCENE) as PackedScene
    if packed == null:
        print("CAPTURE FAIL: cannot load ", SCENE)
        quit(1)
        return
    var game := packed.instantiate()
    root.add_child(game)
    current_scene = game
    for node in _with_signal(game, "start_requested"):
        node.emit_signal("start_requested")
    await _frames(6)

    var player := game.get_node_or_null("Player") as CharacterBody2D
    if player == null:
        print("CAPTURE FAIL: no Player")
        quit(2)
        return
    var arena := _find_arena(game)
    if arena != null:
        arena.call("configure", STAGE)
    await _frames(6)

    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
    var cam := player.get_node_or_null("Camera2D") as Camera2D
    for trial in TRIALS:
        player.global_position = trial["from"]
        player.velocity = Vector2.ZERO
        if cam != null:
            cam.reset_smoothing()
        await _frames(10)
        Input.action_press(trial["action"])
        # Physics frames, not idle frames: at high refresh rates 70 idle frames are
        # only ~29 physics frames, and the old probe stopped short of the wall for
        # lack of walking time, not because of the barrier.
        for _i in 120:
            await physics_frame
        Input.action_release(trial["action"])
        await _frames(10)
        var img: Image = root.get_texture().get_image()
        img.save_png(OUT + "/" + String(trial["name"]) + ".png")
        print("saved ", trial["name"], "  origin=", player.global_position)
    quit()


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


func _find_arena(node: Node) -> Node:
    if node.has_method("configure") and "stage" in node:
        return node
    for child in node.get_children():
        var hit := _find_arena(child)
        if hit != null:
            return hit
    return null
