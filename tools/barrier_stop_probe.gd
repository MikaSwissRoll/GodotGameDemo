extends SceneTree

## Walks the player into each of stage 1's four knoll barriers and reports where it
## actually stops, against the visible edge on that side. Turns "the sides feel
## different" into a table.
##
##   godot --path . --script res://tools/barrier_stop_probe.gd
##
## Stage 1's knoll is Rect2i(5, 6, 3, 2), so the visible geometry is:
##   surface   x 320-512, y 384-512
##   stone row x 320-512, y 512-576   (the south barrier, and it is DRAWN)
## The other three barriers are 8px wide and invisible, with their outer face on the
## surface's own edge.

const SCENE := "res://scenes/main/run_game.tscn"
const STAGE := 1
## Where the visible ground ends on the side being approached, and along which axis.
const TRIALS := [
    {"from": Vector2(416.0, 300.0), "action": "move_down", "edge": 384.0, "axis": "y", "dir": 1.0},
    {"from": Vector2(416.0, 620.0), "action": "move_up", "edge": 576.0, "axis": "y", "dir": -1.0},
    {"from": Vector2(240.0, 448.0), "action": "move_right", "edge": 320.0, "axis": "x", "dir": 1.0},
    {"from": Vector2(592.0, 448.0), "action": "move_left", "edge": 512.0, "axis": "x", "dir": -1.0},
]
## The player's visible feet sit this far below its origin. Midpoint of the run
## cycle, measured frame by frame in tools/sprite_feet_audit.gd: the feet oscillate
## between 6px above the origin and 0.4px below it. The earlier value (2.8, from a
## mis-measured idle frame) understated every gap this tool prints by about 4px.
const FEET_OFFSET := -3.0


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
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
    await _frames(6)

    var player := game.get_node_or_null("Player") as CharacterBody2D
    if player == null:
        print("PROBE FAIL: no Player")
        quit(2)
        return
    var arena: Node = _find_arena(game)
    if arena != null:
        arena.call("configure", STAGE)
    await _frames(6)

    print("=== stage %d: where the player actually stops ===" % STAGE)
    print("    %-8s  %-9s  %-9s  %-9s  %-9s" % [
        "side", "stops at", "collider", "feet", "feet->edge"])
    for trial in TRIALS:
        player.global_position = trial["from"]
        player.velocity = Vector2.ZERO
        await _frames(2)
        Input.action_press(trial["action"])
        await _frames(70)
        Input.action_release(trial["action"])
        await _frames(2)
        var p := player.global_position
        var axis: String = trial["axis"]
        var edge: float = trial["edge"]
        var centre := p.y if axis == "y" else p.x
        # The movement circle is radius 10 centred at (0, -10): its leading edge is
        # 10px past the origin on x, and exactly at the origin going down / 20px up.
        var lead := centre + 10.0 * float(trial["dir"]) - (10.0 if axis == "y" else 0.0)
        var feet := (centre + FEET_OFFSET) if axis == "y" else centre
        var gap := absf(edge - feet)
        print("    %-8s  %-9.1f  %-9.1f  %-9.1f  %-9.1f" % [
            trial["action"].replace("move_", ""), centre, lead, feet, gap])
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
