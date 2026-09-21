extends "res://tests_v2/harness.gd"

## V2 SCENARIOS — melee, ranged and navigation across elevation, in ElevationLab.
##
## Every check drives the REAL handler or the real AI. None of them reimplement the
## elevation rule, because a check that restates a rule keeps passing after the rule
## changes.

const INPUT_SETUP := preload("res://scripts/systems/input_setup.gd")
const LAB_SCENE := "res://tests_v2/lab/ElevationLab.tscn"
const MELEE_SCENE := "res://scenes/enemies/melee_enemy.tscn"
const ARCHER_SCENE := "res://scenes/enemies/archer_enemy.tscn"
const FOLLOWER_SCENE := "res://scenes/party/follower.tscn"

const SUITE := "melee_elevation"

## Known-good positions in the lab. The terrace is cols 4-15, rows 1-3, with its wall
## row at 4 and its two official stairs at columns 4 and 15.
const HIGH_POINT := Vector2(384.0, 150.0)
const LOW_POINT := Vector2(640.0, 450.0)
## Clear of both stair openings, so a bandit here cannot stumble up one.
const RAMP_APPROACH := Vector2(400.0, 420.0)
const AWAY_FROM_STAIRS := Vector2(640.0, 420.0)
## Well outside detection_range (520) from HIGH_POINT, on the low ground.
const FAR_LOW_POINT := Vector2(1180.0, 660.0)

var _lab: Node2D
var _player: Player


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    arm_timeout(180.0, SUITE)
    INPUT_SETUP.ensure_actions()

    var packed := load_scene(LAB_SCENE)
    if packed == null:
        finish(SUITE)
        return
    _lab = packed.instantiate() as Node2D
    if not check_not_null(_lab, "ElevationLab did not instantiate"):
        finish(SUITE)
        return
    root.add_child(_lab)
    current_scene = _lab
    await wait_physics(6)

    _player = _lab.get_node_or_null("Player") as Player
    if not check_not_null(_player, "the lab has no Player"):
        finish(SUITE)
        return
    _player.controls_enabled = false

    # Known levels, asserted rather than assumed: every combat check below depends
    # on these two points really being on opposite levels.
    check_eq(Elevation.level_at(HIGH_POINT), Elevation.HIGH, "setup: HIGH_POINT must be HIGH")
    check_eq(Elevation.level_at(LOW_POINT), Elevation.LOW, "setup: LOW_POINT must be LOW")

    await _check_player_melee()
    await _check_player_dash_cleave()
    await _check_enemy_melee()
    await _check_follower_melee()
    await _check_cross_level_targets_are_unreachable_to_melee_followers()
    await _check_archer_fires_across_elevation()
    await _check_melee_navigates_through_the_ramp()
    await _check_distant_enemies_are_not_drawn_in()
    await _check_no_route_holds_instead_of_freezing()

    finish(SUITE)


## The regression check for the reported bug: the player steps onto the high ground
## and every enemy on the map sets off for a ramp.
##
## The router answers "which way", never "whether". Engagement is bounded by
## detection_range, so an enemy that never engaged does not move at all - whatever the
## levels are.
func _check_distant_enemies_are_not_drawn_in() -> void:
    section("a distant enemy is not drawn in by the high ground")
    await _place(_player, HIGH_POINT)
    check_eq(Elevation.level_at(_player.global_position), Elevation.HIGH,
        "setup: the player must be on the terrace")

    var enemy := _spawn_enemy(FAR_LOW_POINT)
    enemy.move_speed = 125.0
    enemy.damage = 0
    enemy.set_physics_process(true)
    await wait_physics(4)
    check_eq(Elevation.level_at(enemy.global_position), Elevation.LOW,
        "setup: the distant enemy must be on the low ground")
    check(enemy.global_position.distance_to(_player.global_position) > 520.0,
        "setup: the distant enemy must start outside detection_range (it is %.0fpx away)" % [
            enemy.global_position.distance_to(_player.global_position)])

    var before := enemy.global_position
    await wait_physics(180)
    var moved := enemy.global_position.distance_to(before)
    check(moved < 8.0,
        "a distant enemy walked %.0fpx toward the high ground, so the router is deciding engagement rather than direction" % moved)

    enemy.queue_free()
    await wait_physics(2)


func _place(node: Node2D, at: Vector2) -> void:
    node.global_position = at
    if node is CharacterBody2D:
        (node as CharacterBody2D).velocity = Vector2.ZERO
    await wait_physics(3)


func _spawn_enemy(at: Vector2) -> Enemy:
    var enemy := (load(MELEE_SCENE) as PackedScene).instantiate() as Enemy
    _lab.add_child(enemy)
    enemy.global_position = at
    # Parked and harmless: these checks are about eligibility, not about AI.
    enemy.move_speed = 0.0
    enemy.damage = 10
    enemy.set_physics_process(false)
    return enemy


## Each block below arms the real handler and feeds it the real hurtbox, so the
## elevation gate inside the handler is what decides the outcome.
func _check_player_melee() -> void:
    section("player melee across elevation")
    var enemy := _spawn_enemy(LOW_POINT)
    await wait_physics(3)

    await _place(_player, LOW_POINT + Vector2(50.0, 0.0))
    _player.facing = Vector2.RIGHT
    var before := enemy.health
    _player._attacking = true
    _player._attack_hits.clear()
    _player._on_attack_area_entered(enemy.get_node("Hurtbox"))
    await wait_physics(2)
    check(enemy.health < before,
        "a player swing on the SAME level did not damage the bandit (%d -> %d)" % [before, enemy.health])

    _player._attacking = true
    _player._attack_hits.clear()
    await _place(enemy, HIGH_POINT)
    var high_before := enemy.health
    _player._on_attack_area_entered(enemy.get_node("Hurtbox"))
    await wait_physics(2)
    check_eq(enemy.health, high_before,
        "a LOW player swing damaged a HIGH bandit, so melee crossed the cliff")

    _player._attacking = true
    _player._attack_hits.clear()
    await _place(_player, HIGH_POINT + Vector2(50.0, 0.0))
    await _place(enemy, LOW_POINT)
    var low_before := enemy.health
    _player._on_attack_area_entered(enemy.get_node("Hurtbox"))
    await wait_physics(2)
    check_eq(enemy.health, low_before,
        "a HIGH player swing damaged a LOW bandit, so melee crossed the cliff")

    _player._attacking = false
    enemy.queue_free()
    await wait_physics(2)


func _check_player_dash_cleave() -> void:
    section("player dash cleave across elevation")
    var enemy := _spawn_enemy(HIGH_POINT)
    await _place(_player, LOW_POINT)
    _player.upgrades["dash_cleave"] = true
    _player._dash_left = 1.0
    _player._dash_hits.clear()
    var before := enemy.health
    _player._on_dash_area_entered(enemy.get_node("Hurtbox"))
    await wait_physics(2)
    check_eq(enemy.health, before,
        "dash-cleave damaged across the cliff, so one melee path bypassed the rule")
    _player._dash_left = 0.0
    _player.upgrades.erase("dash_cleave")
    enemy.queue_free()
    await wait_physics(2)


func _check_enemy_melee() -> void:
    section("bandit melee across elevation")
    var enemy := _spawn_enemy(LOW_POINT + Vector2(50.0, 0.0))
    await _place(_player, LOW_POINT)
    _player.health = _player.max_health

    var before := _player.health
    enemy._attacking = true
    enemy._hit_this_swing = false
    enemy._on_attack_area_entered(_player.get_node("Hurtbox"))
    await wait_physics(2)
    check(_player.health < before,
        "a bandit on the SAME level did not damage the player (%d -> %d)" % [before, _player.health])

    await _place(enemy, HIGH_POINT)
    await _place(_player, LOW_POINT)
    _player.health = _player.max_health
    enemy._attacking = true
    enemy._hit_this_swing = false
    var cross_before := _player.health
    enemy._on_attack_area_entered(_player.get_node("Hurtbox"))
    await wait_physics(2)
    check_eq(_player.health, cross_before,
        "a HIGH bandit damaged a LOW player, so its blow crossed the cliff")

    enemy.queue_free()
    await wait_physics(2)


func _check_follower_melee() -> void:
    section("companion melee across elevation")
    var follower := (load(FOLLOWER_SCENE) as PackedScene).instantiate() as Follower
    _lab.add_child(follower)
    follower.setup(_player)
    var enemy := _spawn_enemy(LOW_POINT + Vector2(40.0, 0.0))
    await _place(follower, LOW_POINT)
    await _place(_player, LOW_POINT + Vector2(-40.0, 0.0))

    var before := enemy.health
    follower._on_attack_area_entered(enemy.get_node("Hurtbox"))
    await wait_physics(2)
    check(enemy.health < before,
        "the companion did not damage a bandit on the SAME level (%d -> %d)" % [before, enemy.health])

    await _place(enemy, HIGH_POINT)
    var cross_before := enemy.health
    follower._on_attack_area_entered(enemy.get_node("Hurtbox"))
    await wait_physics(2)
    check_eq(enemy.health, cross_before,
        "the companion damaged across the cliff, so it bypassed the elevation rule")

    follower.queue_free()
    enemy.queue_free()
    await wait_physics(2)


## The follower must not be able to reach a target it cannot walk to, and must not
## be teleported across the boundary by its own recovery either.
func _check_cross_level_targets_are_unreachable_to_melee_followers() -> void:
    section("a cross-level target is not reachable by melee")
    var follower := (load(FOLLOWER_SCENE) as PackedScene).instantiate() as Follower
    _lab.add_child(follower)
    follower.setup(_player)
    await _place(follower, LOW_POINT)
    await _place(_player, HIGH_POINT)
    var enemy := _spawn_enemy(HIGH_POINT + Vector2(40.0, 0.0))

    check(not Elevation.melee_allowed(follower, enemy),
        "the companion is a melee actor and must not be allowed to hit a HIGH target from LOW")
    check(Elevation.has_route(follower.global_position, _player.global_position),
        "with a ramp present, the companion must have a route to the player")

    follower.queue_free()
    enemy.queue_free()
    await wait_physics(2)


func _check_archer_fires_across_elevation() -> void:
    section("a ranged attacker fires across elevations")
    var archer := (load(ARCHER_SCENE) as PackedScene).instantiate() as ArcherEnemy
    _lab.add_child(archer)
    await _place(archer, HIGH_POINT)
    await _place(_player, LOW_POINT)

    check(Elevation.ranged_allowed(archer, _player),
        "a HIGH archer must be allowed to shoot a LOW player")
    check_eq(Elevation.level_at(archer.global_position), Elevation.HIGH,
        "setup: the archer must be on the terrace")
    check_eq(Elevation.level_at(_player.global_position), Elevation.LOW,
        "setup: the player must be below the cliff")

    archer.target = _player
    archer._shoot_left = 0.0
    var fired := false
    for _frame in 60:
        await physics_frame
        for child in _lab.get_children():
            if child is EnemyArrow:
                fired = true
                break
        if fired:
            break
    check(fired, "the archer never fired at a target one elevation level below it")

    archer.queue_free()
    await wait_physics(2)


## The headline navigation scenario: a LOW bandit must reach a HIGH player by taking
## the ramp, not by pressing into the cliff and not by climbing it.
func _check_melee_navigates_through_the_ramp() -> void:
    section("a LOW bandit reaches a HIGH player through the ramp")
    await _place(_player, HIGH_POINT)
    var enemy := _spawn_enemy(RAMP_APPROACH)
    enemy.move_speed = 125.0
    enemy.damage = 0
    enemy.set_physics_process(true)
    await wait_physics(4)

    check_eq(Elevation.level_at(enemy.global_position), Elevation.LOW,
        "setup: the bandit must start on the low ground")
    var ramp_center := Elevation.ramp_center(Elevation.nearest_ramp_to(enemy.global_position))
    var distance_before := enemy.global_position.distance_to(ramp_center)
    await wait_physics(90)
    var distance_after := enemy.global_position.distance_to(ramp_center)
    check(distance_after < distance_before - 20.0,
        "the bandit did not head for the ramp (%.0fpx -> %.0fpx)" % [distance_before, distance_after])

    var climbed := false
    for _frame in 300:
        await physics_frame
        if Elevation.level_at(enemy.global_position) == Elevation.HIGH:
            climbed = true
            break
    check(climbed,
        "the bandit never reached the high ground, so it could not use the ramp (ended at %s, %s)" % [
            enemy.global_position.round(), Elevation.level_name(Elevation.level_at(enemy.global_position))])

    enemy.queue_free()
    await wait_physics(2)


## With no ramp declared, the bandit must settle into a stable state: clear of the
## cliff, not changing level, not jittering, and not walking into the wall forever.
func _check_no_route_holds_instead_of_freezing() -> void:
    section("with no route the bandit holds clear instead of freezing")
    await _place(_player, HIGH_POINT)
    # Same geometry, but the registry forgets the ramp, so LOW and HIGH are joined by
    # nothing. This is the "no legal connection" case from the design.
    Elevation.begin_field()
    Elevation.register_high_region(Rect2i(1, 1, 11, 3))
    Elevation.register_high_region(Rect2i(12, 1, 7, 4))
    check(not Elevation.levels_are_connected(), "setup: the levels must not be connected")

    var enemy := _spawn_enemy(AWAY_FROM_STAIRS)
    enemy.move_speed = 125.0
    enemy.damage = 0
    enemy.set_physics_process(true)
    await wait_physics(120)

    check_eq(Elevation.level_at(enemy.global_position), Elevation.LOW,
        "the bandit crossed onto the high ground with no stair to use")
    var settled := enemy.global_position
    await wait_physics(60)
    var drift := enemy.global_position.distance_to(settled)
    check(drift < 8.0,
        "the bandit was still moving after the hold settled (%.1fpx of drift), so it is pacing rather than waiting" % drift)
    check(enemy.global_position.y > 320.0,
        "the bandit is pressed into the wall (y=%.0f)" % enemy.global_position.y)

    enemy.queue_free()
    await wait_physics(2)
