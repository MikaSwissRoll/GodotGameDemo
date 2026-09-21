extends SceneTree

## Frames an arbitrary world position in a scene and saves a screenshot, so a
## migrated region can be judged against docs/environment/HIGHGROUND_TILE_GRAMMAR.md
## without depending on wherever the player happens to be standing.
##
##   godot --path . --script res://tests_v2/lab/capture_region.gd -- \
##         --scene=classic --x=1248 --y=380 --output=res://screenshots/visual_qa/x.png
##
## `--scene` is `classic` (scenes/main/game.tscn), `lab` (the ElevationLab), or `run`
## (an Expedition stage). `run` also takes `--stage=N` to build a particular stage.
##
## Expedition stages are rebuilt through the arena's own `configure(stage)`, found by
## shape - a node with both `configure` and `stage` - rather than by node name, so
## renaming it in the scene does not silently capture the wrong stage.

const SCENES := {
    "classic": "res://scenes/main/game.tscn",
    "lab": "res://tests_v2/lab/ElevationLab.tscn",
    "run": "res://scenes/main/run_game.tscn",
}
const INPUT_SETUP := preload("res://scripts/systems/input_setup.gd")
const VIEWPORT_SIZE := Vector2i(1280, 720)

var _scene_name := "classic"
var _at := Vector2(1248.0, 380.0)
var _zoom := 1.0
var _output := "res://screenshots/visual_qa/region.png"
var _stage := 0


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--scene="):
            _scene_name = arg.split("=")[1]
        elif arg.begins_with("--x="):
            _at.x = float(arg.split("=")[1])
        elif arg.begins_with("--y="):
            _at.y = float(arg.split("=")[1])
        elif arg.begins_with("--zoom="):
            _zoom = float(arg.split("=")[1])
        elif arg.begins_with("--stage="):
            _stage = int(arg.split("=")[1])
        elif arg.begins_with("--output="):
            _output = arg.split("=")[1]

    if not SCENES.has(_scene_name):
        push_error("unknown scene '%s'; valid: %s" % [_scene_name, ", ".join(SCENES.keys())])
        quit(2)
        return

    DisplayServer.window_set_size(VIEWPORT_SIZE)
    root.size = VIEWPORT_SIZE
    INPUT_SETUP.ensure_actions()

    var packed := load(SCENES[_scene_name]) as PackedScene
    if packed == null:
        push_error("could not load %s" % SCENES[_scene_name])
        quit(3)
        return
    var scene := packed.instantiate()
    root.add_child(scene)
    current_scene = scene
    # Unpause and hand control over, so the scene settles into its play state rather
    # than its menu backdrop, which hides the HUD and freezes ambient actors.
    # Dismiss the front-end card, whichever scene owns one. Both the Classic and the
    # Expedition scenes open on a menu that covers the whole viewport, so a capture
    # taken without this is a picture of the menu. Found by the signal it emits rather
    # than by node name, because the two scenes name their UI differently.
    for node in _all_with_signal(scene, "start_requested"):
        node.emit_signal("start_requested")
    var player := scene.get_node_or_null("Player") as Player
    if player != null:
        player.controls_enabled = true
        player.camera.enabled = false
    await _wait_frames(6)

    if _scene_name == "run":
        var arena := _find_arena(scene)
        if arena == null:
            push_error("no Expedition arena found: no node with both `configure` and `stage`")
            quit(7)
            return
        arena.call("configure", _stage)
        await _wait_frames(6)

    # Every camera the scene owns has to let go, or it takes the viewport back the
    # moment the capture camera is made current.
    for existing in _all_cameras(scene):
        existing.enabled = false

    var camera := Camera2D.new()
    camera.position = _at
    camera.zoom = Vector2.ONE * _zoom
    scene.add_child(camera)
    camera.make_current()
    await _wait_frames(10)

    RenderingServer.force_draw(false)
    await process_frame
    var image := root.get_texture().get_image()
    if image == null or image.is_empty():
        push_error("captured an empty viewport image")
        quit(4)
        return
    var absolute := ProjectSettings.globalize_path(_output)
    var dir_error := DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
    if dir_error != OK:
        push_error("could not create the output directory: %s" % error_string(dir_error))
        quit(5)
        return
    var save_error := image.save_png(absolute)
    if save_error != OK:
        push_error("could not save the screenshot: %s" % error_string(save_error))
        quit(6)
        return
    print("REGION_CAPTURED scene=%s at=(%.0f,%.0f) zoom=%.2f path=%s" % [
        _scene_name, _at.x, _at.y, _zoom, absolute])
    quit(0)


func _wait_frames(count: int) -> void:
    for _i in count:
        await process_frame


## The Expedition arena, found by what it can do rather than by its node name.
func _find_arena(node: Node) -> Node:
    if node.has_method("configure") and "stage" in node:
        return node
    for child in node.get_children():
        var found := _find_arena(child)
        if found != null:
            return found
    return null


func _all_cameras(node: Node) -> Array[Camera2D]:
    var found: Array[Camera2D] = []
    if node is Camera2D:
        found.append(node as Camera2D)
    for child in node.get_children():
        found.append_array(_all_cameras(child))
    return found


func _all_with_signal(node: Node, signal_name: String) -> Array[Node]:
    var found: Array[Node] = []
    if node.has_signal(signal_name):
        found.append(node)
    for child in node.get_children():
        found.append_array(_all_with_signal(child, signal_name))
    return found
