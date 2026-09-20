extends SceneTree

## Ballistics regression.
##
## Current rule: **arrows are never stopped by terrain and do not care about
## elevation.** A shot fired from a plateau reaches the low ground, and a shot
## fired from below reaches a plateau. What cannot cross elevation levels is the
## player's melee swing, which is asserted here too by driving the player's attack
## hitbox against a target placed on each side of a cliff.
##
## The plateau registry is rebuilt per world, so this also guards against a stale
## registry leaking elevations between scenes.
##
## Note: damage popups need a Node2D parent. Arrows are added to the world (as the
## game does) rather than to the bare SceneTree root, whose root is a Window, so the
## run is free of harness errors.

const ENV := preload("res://scripts/world/tiny_swords_environment.gd")
const ARROW := preload("res://scenes/enemies/arrow.tscn")

## CastleTerrace footprint from world.gd.
const PLATEAU := Rect2i(15, 2, 9, 6)

var _world: Node2D


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    preload("res://scripts/systems/input_setup.gd").ensure_actions()
    create_timer(40.0).timeout.connect(_on_timeout)
    _world = (load("res://scenes/world/world.tscn") as PackedScene).instantiate() as Node2D
    root.add_child(_world)
    var player := (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as Player
    _world.add_child(player)
    await _wait_physics(3)

    var cliff_y := ENV.cliff_y_of(PLATEAU)
    var high_y := (PLATEAU.position.y + 3.0) * 64.0
    var low_y := cliff_y + 150.0

    assert(ENV.elevation_at(Vector2((PLATEAU.position.x + 2) * 64.0, high_y)),
        "Plateau surface was not registered as high ground")
    assert(not ENV.elevation_at(Vector2((PLATEAU.position.x + 2) * 64.0, low_y)),
        "Low ground was wrongly registered as a plateau")

    var clear_x := _clear_column(_world)
    assert(clear_x > 0.0, "No clear firing column found beside the plateau")

    # 1. High ground fires down onto the low ground.
    player.global_position = Vector2(clear_x, low_y)
    await _wait_physics(2)
    var before := player.health
    _fire(Vector2(clear_x, high_y), Vector2.DOWN)
    await _wait_physics(80)
    assert(player.health < before, "A shot from high ground did not reach the low ground")

    # 2. Low ground fires up onto a plateau. This used to be refused; arrows now
    #    ignore elevation entirely, for the player's enemies as much as for anyone.
    player.global_position = Vector2(clear_x, high_y)
    await _wait_physics(2)
    before = player.health
    _fire(Vector2(clear_x, low_y), Vector2.UP)
    await _wait_physics(80)
    assert(player.health < before, "A shot from low ground did not reach the plateau")

    # 3. Level ground still connects.
    player.global_position = Vector2(clear_x, low_y)
    await _wait_physics(2)
    before = player.health
    _fire(Vector2(clear_x, low_y + 180.0), Vector2.UP)
    await _wait_physics(80)
    assert(player.health < before, "A level shot failed to connect")

    # 4. An arrow crossing a cliff wall is not eaten by the terrain. Fire from the
    #    plateau across the wall's own column: the wall body sits exactly there.
    player.global_position = Vector2(clear_x, low_y)
    await _wait_physics(2)
    before = player.health
    _fire(Vector2(clear_x, high_y), Vector2.DOWN)
    await _wait_physics(60)
    assert(player.health < before,
        "An arrow was stopped by the cliff wall instead of flying over it")

    _check_melee_cannot_cross_elevation(player, clear_x, high_y, low_y)

    print("BALLISTICS PASS: arrows cross terrain in both directions, level shots land, melee cannot cross elevation")
    quit(0)


## The player's swing must not connect across an elevation boundary, in either
## direction. Driven through the real hit handler rather than by reimplementing the
## rule, so a change to the rule fails here.
func _check_melee_cannot_cross_elevation(player: Player, x: float, high_y: float, low_y: float) -> void:
    # The handler takes the enemy's hurtbox Area2D and reads `get_parent()` from it,
    # so the dummy needs a body with a child Area2D, matching the real enemy scenes.
    var dummy := _DummyTarget.new()
    var hurtbox := Area2D.new()
    dummy.add_child(hurtbox)
    _world.add_child(dummy)

    # Player below the cliff, target above it.
    player.global_position = Vector2(x, low_y)
    dummy.global_position = Vector2(x, high_y)
    await _wait_physics(2)
    dummy.health = 100
    player._attacking = true
    player._attack_hits.clear()
    player._on_attack_area_entered(hurtbox)
    assert(dummy.health == 100, "The player's swing crossed up onto a plateau")

    # Player on the plateau, target below.
    player.global_position = Vector2(x, high_y)
    dummy.global_position = Vector2(x, low_y)
    await _wait_physics(2)
    dummy.health = 100
    player._attack_hits.clear()
    player._on_attack_area_entered(hurtbox)
    assert(dummy.health == 100, "The player's swing crossed down off a plateau")

    # Same elevation still connects, so the rule is not simply blocking everything.
    player.global_position = Vector2(x, low_y)
    dummy.global_position = Vector2(x, low_y + 40.0)
    await _wait_physics(2)
    dummy.health = 100
    player._attack_hits.clear()
    player._on_attack_area_entered(hurtbox)
    assert(dummy.health < 100, "The player's swing missed a target on the same elevation")

    player._attacking = false
    dummy.queue_free()
    print("  melee: refused across the cliff both ways, connects on level ground")


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


func _fire(at: Vector2, dir: Vector2) -> void:
    var arrow := ARROW.instantiate() as EnemyArrow
    arrow.direction = dir
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


## Minimal damage target, so the melee rule can be exercised without an enemy's AI
## wandering off between the two assertions.
class _DummyTarget extends Node2D:
    var health := 100

    func take_damage(amount: int, _from: Vector2 = Vector2.ZERO) -> void:
        health -= amount
