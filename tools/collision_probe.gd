extends SceneTree

## List every world collider on Expedition stage 0 and print it against the rectangles it
## is supposed to match.
##
## Collision shapes are invisible in a screenshot and cannot be read out of the source
## with confidence, so this prints what the physics engine actually has - the only
## authority on where the player really gets stopped. It found that stage 0's player.spawn sits inside the knoll's footprint.
##
##   godot --path . --script res://tools/collision_probe.gd
##
## The point is that collision shapes are invisible in a screenshot and cannot be read
## out of the source with confidence - this prints what the physics engine actually
## has, which is the only authority on where the player really gets stopped.

const SCENE := "res://scenes/main/run_game.tscn"
const STAGE := 0
## MainGround = Rect2i(1, 1, 18, 10)
const GROUND := Rect2(64.0, 64.0, 1152.0, 640.0)
## KNOLL_RECTS[0] = Rect2i(3, 7, 2, 2) -> surface, then the four derived bands
const KNOLL := Rect2(192.0, 448.0, 128.0, 128.0)
const KNOLL_BANDS := {
    "south (drawn wall)": Rect2(192.0, 576.0, 128.0, 64.0),
    "north (no art)": Rect2(192.0, 384.0, 128.0, 64.0),
    "west  (no art)": Rect2(128.0, 448.0, 64.0, 128.0),
    "east  (no art)": Rect2(320.0, 448.0, 64.0, 128.0),
}


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    var packed := load(SCENE) as PackedScene
    if packed == null:
        print("PROBE FAIL: cannot load ", SCENE)
        quit(1)
        return
    var scene := packed.instantiate()
    root.add_child(scene)
    current_scene = scene
    for node in _with_signal(scene, "start_requested"):
        node.emit_signal("start_requested")
    await _frames(6)

    var arena := _find_arena(scene)
    if arena == null:
        print("PROBE FAIL: no arena")
        quit(2)
        return
    arena.call("configure", STAGE)
    await _frames(8)

    print("=== player ===")
    var player := scene.get_node_or_null("Player")
    if player != null:
        print("  at ", (player as Node2D).global_position)
        for child in player.get_children():
            _print_shape(child as Node, "    ")

    print("=== every collider in the scene (world rects) ===")
    var bodies: Array[Node] = _all_bodies(scene)
    print("  total StaticBody2D: ", bodies.size())
    var rows: Array = []
    for body in bodies:
        var rect: Rect2 = _body_rect(body as Node2D)
        if rect.size == Vector2.ZERO:
            continue
        rows.append([rect, (body as Node).name, _owner_name(body as Node)])
    rows.sort_custom(func(a: Array, b: Array) -> bool:
        if not is_equal_approx(a[0].position.y, b[0].position.y):
            return a[0].position.y < b[0].position.y
        return a[0].position.x < b[0].position.x)
    for row in rows:
        var r: Rect2 = row[0]
        print("  x %7.1f..%7.1f   y %7.1f..%7.1f   %-22s  (%s)" % [
            r.position.x, r.end.x, r.position.y, r.end.y, row[1], row[2]])

    print("=== reference ===")
    print("  MainGround      x %7.1f..%7.1f   y %7.1f..%7.1f" % [
        GROUND.position.x, GROUND.end.x, GROUND.position.y, GROUND.end.y])
    print("  Knoll surface   x %7.1f..%7.1f   y %7.1f..%7.1f" % [
        KNOLL.position.x, KNOLL.end.x, KNOLL.position.y, KNOLL.end.y])
    for label in KNOLL_BANDS:
        var b: Rect2 = KNOLL_BANDS[label]
        print("  Knoll %-20s x %7.1f..%7.1f   y %7.1f..%7.1f" % [
            label, b.position.x, b.end.x, b.position.y, b.end.y])

    quit()


func _frames(count: int) -> void:
    for _i in count:
        await process_frame


func _print_shape(node: Node, indent: String) -> void:
    if node == null or not (node is CollisionShape2D):
        return
    var shape := (node as CollisionShape2D).shape
    if shape is CircleShape2D:
        print("%scircle r=%.1f at %s" % [indent, (shape as CircleShape2D).radius,
            (node as Node2D).global_position])
    elif shape is RectangleShape2D:
        var s := (shape as RectangleShape2D).size
        var c := (node as Node2D).global_position
        print("%srect x %.1f..%.1f  y %.1f..%.1f" % [indent,
            c.x - s.x * 0.5, c.x + s.x * 0.5, c.y - s.y * 0.5, c.y + s.y * 0.5])


func _body_rect(body: Node2D) -> Rect2:
    for child in body.get_children():
        if child is CollisionShape2D:
            var shape := (child as CollisionShape2D).shape
            if shape is RectangleShape2D:
                var s := (shape as RectangleShape2D).size
                var c := (child as Node2D).global_position
                return Rect2(c - s * 0.5, s)
            if shape is CircleShape2D:
                var r := (shape as CircleShape2D).radius
                var cc := (child as Node2D).global_position
                return Rect2(cc - Vector2(r, r), Vector2(r, r) * 2.0)
    return Rect2()


func _owner_name(node: Node) -> String:
    var walk := node.get_parent()
    while walk != null:
        if walk.has_method("configure") and "stage" in walk:
            return "arena"
        walk = walk.get_parent()
    return "other"


func _all_bodies(node: Node) -> Array[Node]:
    var found: Array[Node] = []
    if node is StaticBody2D:
        found.append(node)
    for child in node.get_children():
        found.append_array(_all_bodies(child))
    return found


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
