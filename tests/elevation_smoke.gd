extends SceneTree

## Melee enemies must treat a cliff as a boundary, the same way the player's melee
## already does.
##
## The plateau builder only walls a cliff's bottom edge, and the camp rise's sides
## and top are completely open, so an enemy used to walk up a cliff face onto the
## high ground and attack from there. `elevation_at()` says which level a point is
## on, so the rule is simply that an enemy may not change level.

const INPUT_SETUP := preload("res://scripts/systems/input_setup.gd")
const ENV := preload("res://scripts/world/tiny_swords_environment.gd")

## The camp rise in world.tscn: the plateau whose sides and top are unwalled.
const CAMP := Rect2i(53, 1, 19, 9)


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    create_timer(150.0).timeout.connect(func() -> void:
        push_error("elevation test timed out")
        quit(1))
    INPUT_SETUP.ensure_actions()
    var game := (load("res://scenes/main/game.tscn") as PackedScene).instantiate() as Node2D
    root.add_child(game)
    current_scene = game
    var player := game.get_node("Player") as Player
    (game.get_node("GameUI") as GameUI).start_requested.emit()
    await physics_frame
    await physics_frame

    _check_registry()
    await _check_enemy_cannot_climb(game, player)
    await _check_enemy_cannot_strike_across_levels(game, player)
    await _check_hit_refused_across_levels_directly(
        game, player,
        Vector2((CAMP.position.x + CAMP.size.x * 0.5) * 64.0, ENV.cliff_y_of(CAMP) - 200.0),
        Vector2((CAMP.position.x + CAMP.size.x * 0.5) * 64.0, ENV.cliff_y_of(CAMP) + 120.0))
    await _check_same_level_still_fights(game, player)
    await _check_holds_clear_of_the_cliff(game, player)

    print("ELEVATION PASS: melee enemies cannot climb a cliff or strike across one, wait clear of a cliff they cannot cross, and still fight on one level")
    quit(0)


## An unreachable target must not leave the enemy pressed against the wall looking
## broken. It has no pathfinding, so it backs off until it is clear and waits there.
func _check_holds_clear_of_the_cliff(game: Node2D, player: Player) -> void:
    var cx := (CAMP.position.x + CAMP.size.x * 0.5) * 64.0
    var bottom := ENV.cliff_y_of(CAMP)
    var enemy := game.get_node("MeleeEnemy1") as Enemy
    for node in get_nodes_in_group("bandits"):
        if node != enemy:
            (node as Node2D).global_position = Vector2(200, 3600)
    # Player on the plateau, enemy just below the cliff wall. The wall built at the
    # cliff line is 58px tall starting at cliff_y, so the enemy is placed clear of it
    # rather than inside it: a body spawned overlapping the wall gets ejected upward,
    # which would look like it had climbed the cliff.
    player.global_position = Vector2(cx, bottom - 160.0)
    player._invulnerability_left = 9999.0
    enemy.global_position = Vector2(cx, bottom + 80.0)
    enemy.target = player
    await physics_frame
    var closest := enemy.global_position.distance_to(player.global_position)

    for frame in 400:
        await physics_frame
        closest = minf(closest, enemy.global_position.distance_to(player.global_position))
    var final := enemy.global_position.distance_to(player.global_position)
    assert(not ENV.elevation_at(enemy.global_position),
        "The enemy ended up on the plateau it was not supposed to be able to reach")
    assert(final > enemy.cliff_hold_distance * 0.8,
        "The enemy stayed pressed against the cliff (%.0fpx away, expected clear of %.0f)" % [
            final, enemy.cliff_hold_distance])
    print("  an unreachable target left the enemy waiting %.0fpx clear of the cliff" % final)


## The rule is only meaningful if the registry agrees about which points are high.
func _check_registry() -> void:
    var cx := (CAMP.position.x + CAMP.size.x * 0.5) * 64.0
    assert(ENV.elevation_at(Vector2(cx, 320.0)), "The camp rise centre is not registered as high ground")
    assert(not ENV.elevation_at(Vector2(cx, ENV.cliff_y_of(CAMP) + 120.0)),
        "The low ground below the camp rise is registered as high ground")
    print("  registry: camp rise is high ground, the ground below it is not")


## Player on the plateau, enemy below and outside attack range. The enemy must never
## change elevation while chasing, from any side.
func _check_enemy_cannot_climb(game: Node2D, player: Player) -> void:
    var cx := (CAMP.position.x + CAMP.size.x * 0.5) * 64.0
    var top := CAMP.position.y * 64.0
    var bottom := ENV.cliff_y_of(CAMP)
    var left := CAMP.position.x * 64.0
    var right := (CAMP.position.x + CAMP.size.x) * 64.0
    var mid_y := (top + bottom) * 0.5

    # The camp rise is open from below, the left, the right and above, so each of
    # these is a real approach an enemy could have taken.
    var approaches := [
        ["from below", Vector2(cx, bottom + 200.0), Vector2(cx, top + 160.0)],
        ["from the left", Vector2(left - 200.0, mid_y), Vector2(cx, mid_y)],
        ["from the right", Vector2(right + 200.0, mid_y), Vector2(cx, mid_y)],
        ["from above", Vector2(cx, top - 200.0), Vector2(cx, mid_y)],
    ]
    var enemy := game.get_node("MeleeEnemy1") as Enemy
    for approach in approaches:
        var from: Vector2 = approach[1]
        var player_at: Vector2 = approach[2]
        player.global_position = player_at
        player._invulnerability_left = 9999.0
        enemy.global_position = from
        enemy.target = player
        enemy.health = enemy.max_health
        await physics_frame

        var start_high := ENV.elevation_at(enemy.global_position)
        var changed := false
        for frame in 700:
            await physics_frame
            if ENV.elevation_at(enemy.global_position) != start_high:
                changed = true
                break
        assert(not changed,
            "Enemy %s climbed the cliff: %s (high=%s) -> %s (high=%s)" % [
                approach[0], from.round(), start_high,
                enemy.global_position.round(), ENV.elevation_at(enemy.global_position)])
        print("  %-14s stayed on its own level" % approach[0])


## Being unable to climb is not enough: it must also not reach across the cliff.
##
## `elevation_at` samples the 64px tile a point falls in, so a point a few pixels
## above the cliff line is still on the plateau's last tile row. The player is
## therefore placed well inside the plateau, and the setup is asserted, or this
## check would silently end up testing two actors on the same level.
func _check_enemy_cannot_strike_across_levels(game: Node2D, player: Player) -> void:
    var cx := (CAMP.position.x + CAMP.size.x * 0.5) * 64.0
    var bottom := ENV.cliff_y_of(CAMP)
    var enemy := game.get_node("MeleeEnemy2") as Enemy
    # Park every other hostile far away. Their arrows reach the player from range and
    # would show up as damage this check would blame on the melee enemy; without
    # this the assertion was passing judgement on the wrong attacker.
    for node in get_nodes_in_group("bandits"):
        if node != enemy:
            (node as Node2D).global_position = Vector2(200, 3600)
    # Two full tiles inside the plateau, so there is no tile-boundary ambiguity:
    # `elevation_at` samples a 64px tile, so a point just above the cliff line is
    # still on the plateau's last tile row.
    player.global_position = Vector2(cx, bottom - 128.0)
    player._invulnerability_left = 0.0
    player.health = player.max_health
    enemy.global_position = Vector2(cx, bottom + 20.0)
    enemy.target = player
    await physics_frame
    assert(ENV.elevation_at(player.global_position),
        "Setup: the player is not actually on the plateau")
    assert(not ENV.elevation_at(enemy.global_position),
        "Setup: the enemy is not actually on the low ground")

    var before: int = player.health
    for frame in 400:
        await physics_frame
    assert(player.health == before,
        "The enemy struck the player across the cliff (%d -> %d); enemy at %s high=%s, player at %s high=%s" % [
            before, player.health, enemy.global_position.round(),
            ENV.elevation_at(enemy.global_position),
            player.global_position.round(), ENV.elevation_at(player.global_position)])
    print("  no strike crossed the cliff across 400 frames (%d HP held)" % player.health)


## The walk rule alone does not cover the blow.
##
## The melee hitbox sits 55px in front of the enemy, so it can cross a cliff line the
## enemy's own feet have not crossed. `_on_attack_area_entered` therefore refuses a
## victim on the other level, the same way the player's melee always has. This
## drives that handler directly, because an enemy kept away by the walk rule would
## never reach the geometry that exposes it.
func _check_hit_refused_across_levels_directly(game: Node2D, player: Player, high_at: Vector2, low_at: Vector2) -> void:
    var enemy := game.get_node("MeleeEnemy3") as Enemy
    assert(ENV.elevation_at(high_at), "Setup: high_at is not high ground")
    assert(not ENV.elevation_at(low_at), "Setup: low_at is not low ground")
    # Enemy on the low ground, victim on the plateau: its swing must be refused.
    enemy.global_position = low_at
    enemy.target = player
    enemy._attacking = true
    enemy._hit_this_swing = false
    await physics_frame
    enemy._on_attack_area_entered(player.hurtbox)
    assert(not enemy._hit_this_swing,
        "A swing was allowed to land on a victim on the other side of the cliff")

    # And on the same level the very same handler must still connect, so the refusal
    # is about elevation and not about the handler being broken.
    enemy.global_position = low_at
    player.global_position = low_at + Vector2(40, 0)
    player.health = player.max_health
    enemy._hit_this_swing = false
    await physics_frame
    enemy._on_attack_area_entered(player.hurtbox)
    assert(enemy._hit_this_swing or player.health < player.max_health,
        "A swing on the same level was refused, so the elevation rule is too broad")
    print("  the blow itself is refused across a cliff but lands on one level")


## The rule must not simply stop all combat: on one level the enemy still closes and
## still lands hits.
func _check_same_level_still_fights(game: Node2D, player: Player) -> void:
    var cx := (CAMP.position.x + CAMP.size.x * 0.5) * 64.0
    var low_y := ENV.cliff_y_of(CAMP) + 160.0
    var enemy := game.get_node("MeleeEnemy2") as Enemy
    player.global_position = Vector2(cx, low_y)
    player._invulnerability_left = 0.0
    player.health = player.max_health
    enemy.global_position = Vector2(cx + 220.0, low_y)
    enemy.target = player
    await physics_frame

    var closed := false
    var before: int = player.health
    var hit := false
    for frame in 700:
        await physics_frame
        if enemy.global_position.distance_to(player.global_position) < 90.0:
            closed = true
        if player.health < before:
            hit = true
            break
    assert(closed, "The enemy did not close on a target on its own level")
    assert(hit, "The enemy never landed a hit on its own level")
    print("  on one level it still closed to range and landed a hit (%d -> %d)" % [before, player.health])
