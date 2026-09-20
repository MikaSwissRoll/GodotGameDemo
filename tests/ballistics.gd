extends SceneTree

## Ballistics regression: high ground may shoot down, low ground may not shoot up.
##
## The plateau registry is rebuilt per world, so this test also guards against a
## stale registry leaking elevations between scenes.
##
## Note: damage popups need a Node2D parent. Arrows are added to the world (as the
## game does) rather than to the bare SceneTree root, whose root is a Window, so
## the run is free of harness errors.

const ENV := preload("res://scripts/world/tiny_swords_environment.gd")
const ARROW := preload("res://scenes/enemies/arrow.tscn")

## CastleTerrace footprint from world.gd.
const PLATEAU := Rect2i(15, 2, 9, 6)

var _world: Node2D


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    preload("res://scripts/systems/input_setup.gd").ensure_actions()
    create_timer(30.0).timeout.connect(_on_timeout)
    _world = (load("res://scenes/world/world.tscn") as PackedScene).instantiate() as Node2D
    root.add_child(_world)
    var player := (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as Player
    _world.add_child(player)
    await _wait_physics(3)

    var cliff_y := ENV.cliff_y_of(PLATEAU)
    var high_y := (PLATEAU.position.y + 3.0) * 64.0

    assert(ENV.elevation_at(Vector2((PLATEAU.position.x + 2) * 64.0, high_y)),
        "Plateau surface was not registered as high ground")
    assert(not ENV.elevation_at(Vector2((PLATEAU.position.x + 2) * 64.0, cliff_y + 150.0)),
        "Low ground was wrongly registered as a plateau")

    var clear_x := _clear_column(_world)
    assert(clear_x > 0.0, "No clear firing column found beside the plateau")

    # High ground fires down onto the low ground.
    player.global_position = Vector2(clear_x, cliff_y + 150.0)
    await _wait_physics(2)
    var before := player.health
    _fire(Vector2(clear_x, high_y), Vector2.DOWN, true)
    await _wait_physics(80)
    assert(player.health < before, "A shot from high ground did not reach the low ground")

    # Low ground may not fire up onto a plateau.
    player.global_position = Vector2(clear_x, high_y)
    await _wait_physics(2)
    before = player.health
    _fire(Vector2(clear_x, cliff_y + 150.0), Vector2.UP, false)
    await _wait_physics(80)
    assert(player.health == before, "A shot from low ground wrongly reached the plateau")

    # Level ground still connects.
    player.global_position = Vector2(clear_x, cliff_y + 150.0)
    await _wait_physics(2)
    before = player.health
    _fire(Vector2(clear_x, cliff_y + 330.0), Vector2.UP, false)
    await _wait_physics(80)
    assert(player.health < before, "A level shot failed to connect")

    print("BALLISTICS PASS: high-to-low hits, low-to-high is refused, level hits")
    quit(0)


## A plateau column with no prop collision below the cliff, so the cliff wall is
## the only thing a descending shot could meet.
func _clear_column(world: Node) -> float:
    var props := _all_static(world)
    for x in range(PLATEAU.position.x + 1, PLATEAU.position.x + PLATEAU.size.x - 1):
        var wx := (x + 0.5) * 64.0
        var blocked := false
        for body in props:
            if absf(body.global_position.x - wx) < 46.0 and body.global_position.y > 600.0:
                blocked = true
                break
        if not blocked:
            return wx
    return -1.0


func _fire(at: Vector2, dir: Vector2, from_high: bool) -> void:
    var arrow := ARROW.instantiate() as EnemyArrow
    arrow.direction = dir
    arrow.from_high_ground = from_high
    arrow.origin_plateau = ENV.plateau_at(at)
    _world.add_child(arrow)
    arrow.global_position = at


func _all_static(node: Node) -> Array:
    var found: Array = []
    for child in node.get_children():
        if child is StaticBody2D:
            found.append(child)
        found.append_array(_all_static(child))
    return found


func _wait_physics(count: int) -> void:
    for _i in count:
        await physics_frame


func _on_timeout() -> void:
    push_error("Ballistics test timed out")
    quit(1)
