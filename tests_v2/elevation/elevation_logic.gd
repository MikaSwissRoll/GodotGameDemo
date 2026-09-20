extends "res://tests_v2/harness.gd"

## V2 ELEVATION — the binary rules, with no scene involved.
##
## These are the deterministic parts of the contract: which level a point is on, what
## a ramp means, and the melee and ranged eligibility matrices. They register a
## synthetic field instead of loading the lab, so they are fast and cannot be
## affected by terrain composition.
##
## The lab-driven behaviour lives in `scenarios/melee_elevation`.

const SUITE := "elevation_logic"

const HIGH_REGION := Rect2i(10, 0, 4, 4)
const RAMP := Rect2i(9, 4, 2, 2)

var _high_actor: Node2D
var _low_actor: Node2D


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    arm_timeout(30.0, SUITE)

    _high_actor = Node2D.new()
    _low_actor = Node2D.new()
    root.add_child(_high_actor)
    root.add_child(_low_actor)
    _high_actor.global_position = Vector2(11 * 64 + 32, 64 + 32)
    _low_actor.global_position = Vector2(11 * 64 + 32, 8 * 64 + 32)

    _check_levels()
    _check_ramps()
    _check_melee_matrix()
    _check_ranged_matrix()
    _check_routing()

    finish(SUITE)


func _check_levels() -> void:
    section("levels")
    Elevation.begin_field()
    check_eq(Elevation.level_at(_low_actor.global_position), Elevation.LOW,
        "an empty field must be entirely LOW")
    Elevation.register_high_region(HIGH_REGION)
    check_eq(Elevation.level_at(_high_actor.global_position), Elevation.HIGH,
        "a point inside a registered high region must be HIGH")
    check_eq(Elevation.level_at(_low_actor.global_position), Elevation.LOW,
        "a point outside every high region must be LOW")
    check_eq(Elevation.level_of(_high_actor), Elevation.HIGH,
        "level_of must read the actor's own position")
    check_eq(Elevation.level_name(Elevation.HIGH), "HIGH", "level_name(HIGH)")
    check_eq(Elevation.level_name(Elevation.LOW), "LOW", "level_name(LOW)")
    check_eq(Elevation.level_of(null), Elevation.LOW,
        "level_of(null) must be safe and must not claim high ground")


func _check_ramps() -> void:
    section("ramps")
    check(not Elevation.levels_are_connected(),
        "with no ramp declared, LOW and HIGH must not be connected")
    check(not Elevation.could_reach_by_level(Elevation.LOW, Elevation.HIGH),
        "with no ramp, a low actor must not be able to reach a high target")
    check(not Elevation.has_route(_low_actor.global_position, _high_actor.global_position),
        "with no ramp, has_route must be false across levels")

    Elevation.register_ramp(RAMP)
    check(Elevation.is_ramp_tile(Vector2i(9, 4)), "a registered ramp tile must report as a ramp")
    check(not Elevation.is_ramp_tile(Vector2i(2, 2)), "an unregistered tile must not report as a ramp")
    check(Elevation.levels_are_connected(), "declaring a ramp must connect the levels")
    check(Elevation.could_reach_by_level(Elevation.LOW, Elevation.HIGH),
        "with a ramp, a low actor must be able to reach a high target")
    check(Elevation.has_route(_low_actor.global_position, _high_actor.global_position),
        "with a ramp, has_route must be true across levels")
    check_eq(Elevation.level_at(Elevation.ramp_center(RAMP)), Elevation.LOW,
        "a ramp sits on the low side of the boundary, so standing on it is LOW")


## The four cases of section 6 of the contract, in order.
func _check_melee_matrix() -> void:
    section("melee eligibility")
    check(Elevation.melee_allowed(_low_actor, _low_actor),
        "LOW attacker vs LOW target must be allowed")
    check(Elevation.melee_allowed(_high_actor, _high_actor),
        "HIGH attacker vs HIGH target must be allowed")
    check(not Elevation.melee_allowed(_low_actor, _high_actor),
        "LOW attacker vs HIGH target must be refused")
    check(not Elevation.melee_allowed(_high_actor, _low_actor),
        "HIGH attacker vs LOW target must be refused")
    check(not Elevation.melee_allowed(null, _low_actor), "a null attacker must be refused")
    check(not Elevation.melee_allowed(_low_actor, null), "a null target must be refused")


## Elevation difference never invalidates a ranged target, and reachability is never
## required. All four combinations must be allowed.
func _check_ranged_matrix() -> void:
    section("ranged eligibility")
    check(Elevation.ranged_allowed(_low_actor, _low_actor), "LOW vs LOW must be allowed")
    check(Elevation.ranged_allowed(_high_actor, _high_actor), "HIGH vs HIGH must be allowed")
    check(Elevation.ranged_allowed(_low_actor, _high_actor),
        "LOW ranged vs HIGH target must be allowed: elevation difference is not a gate")
    check(Elevation.ranged_allowed(_high_actor, _low_actor),
        "HIGH ranged vs LOW target must be allowed: elevation difference is not a gate")
    check(not Elevation.ranged_allowed(null, _low_actor), "a null attacker must be refused")

    # The strongest statement of the separation: with NO ramp at all, so the target
    # is physically unreachable, a ranged attack is still valid.
    Elevation.begin_field()
    Elevation.register_high_region(HIGH_REGION)
    check(not Elevation.has_route(_low_actor.global_position, _high_actor.global_position),
        "setup: with no ramp the high target must be unreachable")
    check(Elevation.ranged_allowed(_low_actor, _high_actor),
        "an unreachable target must still be a valid ranged target")
    Elevation.register_ramp(RAMP)


func _check_routing() -> void:
    section("routing")
    check_eq(Elevation.route_point(_low_actor.global_position, _low_actor.global_position),
        _low_actor.global_position, "a same-level route must be the target itself")
    var cross := Elevation.route_point(_low_actor.global_position, _high_actor.global_position)
    check_eq(cross, Elevation.ramp_center(RAMP),
        "a cross-level route must go via the nearest ramp")
    # Standing on the ramp, the actor is committed to the crossing.
    var on_ramp := Elevation.ramp_center(RAMP)
    check_eq(Elevation.route_point(on_ramp, _high_actor.global_position),
        _high_actor.global_position,
        "from the ramp, the route must head straight for the target rather than back at the ramp")
    # No ramp: the route degrades to the target, and the caller must notice there is
    # no path rather than pressing into the cliff.
    Elevation.begin_field()
    Elevation.register_high_region(HIGH_REGION)
    check(not Elevation.has_route(_low_actor.global_position, _high_actor.global_position),
        "with no ramp, the caller must be told there is no route")
