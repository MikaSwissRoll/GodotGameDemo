extends SceneTree

## List every world collider on an Expedition stage and print it against the rectangles
## the code derives. Collision shapes are invisible in a screenshot and cannot be read
## out of the source with confidence, so this asks the physics engine instead.
##
##   godot --path . --script res://tools/collision_probe.gd -- --stage=1
##
## The expected rectangles are computed from the arena's own KNOLL_RECTS and from
## HighGround's own constants, so they cannot drift away from the code they describe.

const SCENE := "res://scenes/main/run_game.tscn"
const ARENA := preload("res://scripts/world/run_arena.gd")
const HG := preload("res://scripts/world/high_ground.gd")
const TILE := 64.0
## MainGround = Rect2i(1, 1, 18, 10)
const GROUND := Rect2(64.0, 64.0, 1152.0, 640.0)

var _stage := 0


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--stage="):
            _stage = int(arg.split("=")[1])
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
    arena.call("configure", _stage)
    await _frames(8)

    print("=== stage %d ===" % _stage)
    var player := scene.get_node_or_null("Player")
    if player != null:
        print("  player at ", (player as Node2D).global_position)
        for child in player.get_children():
            _print_shape(child as Node, "    ")

    print("=== every collider in the scene (world rects) ===")
    var rows: Array = []
    for body in _all_bodies(scene):
        var rect: Rect2 = _body_rect(body as Node2D)
        if rect.size == Vector2.ZERO:
            continue
        rows.append([rect, (body as Node).name])
    rows.sort_custom(func(a: Array, b: Array) -> bool:
        if not is_equal_approx(a[0].position.y, b[0].position.y):
            return a[0].position.y < b[0].position.y
        return a[0].position.x < b[0].position.x)
    for row in rows:
        var r: Rect2 = row[0]
        print("  x %7.1f..%7.1f   y %7.1f..%7.1f   %-20s   size %5.1f x %5.1f" % [
            r.position.x, r.end.x, r.position.y, r.end.y, row[1], r.size.x, r.size.y])

    print("=== reference ===")
    print("  MainGround   x %7.1f..%7.1f   y %7.1f..%7.1f" % [
        GROUND.position.x, GROUND.end.x, GROUND.position.y, GROUND.end.y])
    var knoll: Rect2i = ARENA.KNOLL_RECTS[_stage]
    var fc := float(knoll.position.x)
    var lc := float(knoll.position.x + knoll.size.x)
    var fr := float(knoll.position.y)
    var lr := float(knoll.position.y + knoll.size.y)
    var side: float = HG.SIDE_BARRIER_THICKNESS
    print("  knoll %s -> cols %d-%d rows %d-%d" % [knoll, knoll.position.x,
        knoll.position.x + knoll.size.x - 1, knoll.position.y,
        knoll.position.y + knoll.size.y - 1])
    print("  surface      x %7.1f..%7.1f   y %7.1f..%7.1f" % [
        fc * TILE, lc * TILE, fr * TILE, lr * TILE])
    print("  south wall   x %7.1f..%7.1f   y %7.1f..%7.1f   size %5.1f x %5.1f" % [
        fc * TILE, lc * TILE, lr * TILE, lr * TILE + TILE, (lc - fc) * TILE, TILE])
    print("  north band   x %7.1f..%7.1f   y %7.1f..%7.1f   size %5.1f x %5.1f" % [
        fc * TILE, lc * TILE, fr * TILE, fr * TILE + side,
        (lc - fc) * TILE, side])
    print("  west band    x %7.1f..%7.1f   y %7.1f..%7.1f   size %5.1f x %5.1f" % [
        fc * TILE, fc * TILE + side, fr * TILE, lr * TILE + TILE,
        side, (lr - fr + 1.0) * TILE])
    print("  east band    x %7.1f..%7.1f   y %7.1f..%7.1f   size %5.1f x %5.1f" % [
        lc * TILE - side, lc * TILE, fr * TILE, lr * TILE + TILE,
        side, (lr - fr + 1.0) * TILE])
    print("  -> a body approaching from the north stops at y = %.1f" % (fr * TILE - 18.0))
    print("  -> the visible grass starts at y = %.1f, so its edge is 0.0 px short" % (fr * TILE))
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