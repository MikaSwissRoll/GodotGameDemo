extends SceneTree

## Screenshot capture for ElevationLab, judged against
## docs/environment/HIGHGROUND_TILE_GRAMMAR.md.
##
##   godot --path . --script res://tests_v2/lab/capture_lab.gd -- \
##         --target=overview --output=res://screenshots/visual_qa/lab_overview.png
##
## `overview` disables the player camera so the whole lab is framed at once; that is
## the view the terrain grammar is judged from. `ramp` puts a zoomed camera on the
## legal entrance to check that it reads as a way up.

const LAB_SCENE := "res://tests_v2/lab/ElevationLab.tscn"
const INPUT_SETUP := preload("res://scripts/systems/input_setup.gd")
const VIEWPORT_SIZE := Vector2i(1280, 720)
const VALID_TARGETS := ["overview", "ramp", "cliff_lip"]

var _target := "overview"
var _output := ""


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--target="):
            _target = arg.split("=")[1]
        elif arg.begins_with("--output="):
            _output = arg.split("=")[1]
    if not VALID_TARGETS.has(_target):
        push_error("unknown lab capture target '%s'; valid: %s" % [_target, ", ".join(VALID_TARGETS)])
        quit(2)
        return
    if _output.is_empty():
        _output = "res://screenshots/visual_qa/lab_%s.png" % _target

    DisplayServer.window_set_size(VIEWPORT_SIZE)
    root.size = VIEWPORT_SIZE
    # Without these the Player logs missing-action errors on every physics frame,
    # which buries real diagnostics in noise.
    INPUT_SETUP.ensure_actions()

    var packed := load(LAB_SCENE) as PackedScene
    if packed == null:
        push_error("could not load the lab scene")
        quit(3)
        return
    var lab := packed.instantiate()
    root.add_child(lab)
    current_scene = lab
    await _wait_frames(4)

    var player := lab.get_node_or_null("Player") as Player
    if player != null:
        # No camera, so the viewport shows the lab from its origin.
        player.camera.enabled = false

    match _target:
        "overview":
            pass
        "ramp":
            _add_camera(lab, Vector2(640.0, 330.0), 2.0)
        "cliff_lip":
            _add_camera(lab, Vector2(400.0, 300.0), 2.0)

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

    print("LAB_CAPTURED target=%s path=%s size=%dx%d" % [
        _target, absolute, image.get_width(), image.get_height()])
    quit(0)


func _add_camera(parent: Node, at: Vector2, zoom_level: float) -> void:
    var camera := Camera2D.new()
    camera.position = at
    camera.zoom = Vector2.ONE * zoom_level
    camera.limit_left = 0
    camera.limit_top = 0
    camera.limit_right = 1280
    camera.limit_bottom = 704
    parent.add_child(camera)
    camera.make_current()


func _wait_frames(count: int) -> void:
    for _i in count:
        await process_frame
