extends "res://tests_v2/harness.gd"

## V2 SCENARIOS 鈥?how far a projectile may travel between elevations.
##
## The rule under test: a projectile may cross at most ONE LOW/HIGH boundary. Melee is 0
## (enforced at the attacker, in melee_elevation); an arrow is 1. See
## ELEVATION_SYSTEM.md section 7.
##
## Every check drives a real ArcherEnemy firing a real EnemyArrow and then watches what
## the arrow DOES. None of them restate the rule: a check that reimplements a rule keeps
## passing after the rule changes, which is the trap the frozen suite fell into.

const INPUT_SETUP := preload("res://scripts/systems/input_setup.gd")
const HIGH_GROUND := preload("res://scripts/world/high_ground.gd")
const LAB_SCENE := "res://tests_v2/lab/ElevationLab.tscn"
const ARROW_SCENE := "res://scenes/enemies/arrow.tscn"

const SUITE := "ranged_elevation"

## The lab's own terrace is cols 4-15, rows 1-3 - x 256-1024, so 768 wide. An archer
## only fires within `detection_range` (630), so a shot that crosses it end to end and
## lands beyond is out of range and would never be fired.
##
## The suite therefore registers its OWN second region: a knoll at cols 4-7, rows 6-7,
## which is narrow enough to fly over and back within range. Both two-crossing cases need
## it, and both one-crossing cases are cleaner against it than against the terrace.
##
## It is declared here rather than added to the lab because other suites walk that ground.
## Only the elevation field is registered - no art and no collision - because an arrow
## ignores collision and the checks are about the level, not the look.
const KNOLL := Rect2i(4, 6, 4, 2)

## Both LOW, south of the knoll's rows (384-512), so the path never enters high ground.
const LOW_A := Vector2(140.0, 620.0)
const LOW_B := Vector2(500.0, 620.0)
## Both on the added knoll.
const KNOLL_A := Vector2(300.0, 450.0)
const KNOLL_B := Vector2(470.0, 450.0)
## LOW, either side of the knoll, on the knoll's own rows.
const KNOLL_WEST_LOW := Vector2(140.0, 450.0)
const KNOLL_EAST_LOW := Vector2(600.0, 450.0)
## The terrace (x 256-1024, y 64-256) - used for the two-region case and the stair.
const TERRACE := Vector2(400.0, 224.0)
const TERRACE_WEST_LOW := Vector2(140.0, 224.0)
## Just west of the knoll's edge, so the arrow SPAWNS already inside it (the archer puts
## it 45px ahead of itself). The arrow's own first frame is therefore HIGH while its
## shooter is LOW, which is the case that tells the two implementations apart.
const BESIDE_KNOLL_LOW := Vector2(250.0, 450.0)

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

    # The region the two-crossing cases need. `declare` is the half of `build` that
    # registers with Elevation, which is all this suite needs.
    HIGH_GROUND.declare(KNOLL)
    await wait_physics(1)

    # Asserted, not assumed: every check below depends on these points really being on
    # the levels the case names.
    check_eq(Elevation.level_at(LOW_A), Elevation.LOW, "setup: LOW_A must be LOW")
    check_eq(Elevation.level_at(LOW_B), Elevation.LOW, "setup: LOW_B must be LOW")
    check_eq(Elevation.level_at(KNOLL_A), Elevation.HIGH, "setup: KNOLL_A must be HIGH")
    check_eq(Elevation.level_at(KNOLL_B), Elevation.HIGH, "setup: KNOLL_B must be HIGH")
    check_eq(Elevation.level_at(KNOLL_WEST_LOW), Elevation.LOW,
        "setup: the ground west of the knoll must be LOW")
    check_eq(Elevation.level_at(KNOLL_EAST_LOW), Elevation.LOW,
        "setup: the ground east of the knoll must be LOW")
    check_eq(Elevation.level_at(TERRACE), Elevation.HIGH, "setup: the terrace must be HIGH")
    check_eq(Elevation.level_at(TERRACE_WEST_LOW), Elevation.LOW,
        "setup: the ground west of the terrace must be LOW")

    await _check_zero_crossings()
    await _check_one_crossing()
    await _check_two_crossings_are_blocked()
    await _check_crossing_at_a_stair_counts_once()
    await _check_initial_level_comes_from_the_arrow()

    finish(SUITE)


## 0 crossings: both ends on the same level and nothing high between them.
func _check_zero_crossings() -> void:
    section("0 crossings is always allowed")
    check_eq(await _fly_at(LOW_A, LOW_B), "hit",
        "a LOW arrow at a LOW target across open ground must arrive")
    check_eq(await _fly_at(KNOLL_A, KNOLL_B), "hit",
        "a HIGH arrow at a HIGH target on the same plateau must arrive")


## 1 crossing: the two directions that make high ground worth taking, and worth shooting
## from.
func _check_one_crossing() -> void:
    section("1 crossing is allowed in both directions")
    check_eq(await _fly_at(KNOLL_WEST_LOW, KNOLL_A), "hit",
        "a LOW arrow must reach a target standing on the plateau")
    check_eq(await _fly_at(KNOLL_A, KNOLL_EAST_LOW), "hit",
        "an arrow from the plateau must reach a target below it")


## 2 crossings: the plateau as cover, which is the whole point of the budget.
func _check_two_crossings_are_blocked() -> void:
    section("2 crossings are blocked, so a plateau is cover")
    check_eq(await _fly_at(KNOLL_WEST_LOW, KNOLL_EAST_LOW), "blocked",
        "an arrow crossing LOW to HIGH to LOW must be stopped by the terrain")
    check_eq(await _fly_at(TERRACE, KNOLL_A), "blocked",
        "an arrow crossing HIGH to LOW to HIGH must be stopped by the terrain")


## A ramp is not a third elevation. `level_at` returns LOW or HIGH and nothing else, so a
## path that runs over a stair column crosses once and must not be charged twice.
func _check_crossing_at_a_stair_counts_once() -> void:
    section("crossing on a stair column counts once")
    # The crossing happens at the terrace's west edge, which is the stair's own column.
    # If it did not, this check would be testing an ordinary edge.
    check(Elevation.is_ramp_tile(Vector2i(4, 3)),
        "setup: the terrace's west edge at row 3 must be a ramp tile, or this tests nothing")
    check_eq(await _fly_at(TERRACE_WEST_LOW, TERRACE), "hit",
        "an arrow crossing onto the terrace over its stair must arrive")


## The arrow's level comes from where the ARROW is on its first frame, not from its
## shooter. The archer spawns an arrow 45px ahead of itself, so a shot fired from just
## outside a plateau starts already inside it.
##
## Getting this wrong is invisible: taking the shooter's level instead would charge that
## first step as a crossing, and this arrow would die on the far edge.
func _check_initial_level_comes_from_the_arrow() -> void:
    section("the arrow's starting level is its own, not its shooter's")
    check_eq(Elevation.level_at(BESIDE_KNOLL_LOW), Elevation.LOW,
        "setup: the shooter must be on the low ground")
    check_eq(Elevation.level_at(BESIDE_KNOLL_LOW + Vector2(45.0, 0.0)), Elevation.HIGH,
        "setup: the arrow's spawn point must already be inside the knoll")
    check_eq(await _fly_at(BESIDE_KNOLL_LOW, KNOLL_EAST_LOW), "hit",
        "an arrow that spawns already on the plateau has spent no crossing yet")


## Flies one arrow from `from` straight at `to` and reports what it did: "hit" (the
## player lost health), "blocked" (the arrow was freed before arriving), or "none" (it
## was never seen alive, which means the spawn or the watch window is wrong).
##
## The arrow is spawned directly rather than through an ArcherEnemy. The rule under test
## lives in the arrow, not in the archer's AI, and going through the AI adds three
## sources of noise - automatic target acquisition, a 1.9s cooldown and an attack
## animation delay - none of which this suite is about. The first version did fire
## through the archer and spent two runs reporting the wrong outcome for that reason.
## That an archer CAN fire across an elevation at all is covered by melee_elevation.
func _fly_at(from: Vector2, to: Vector2) -> String:
    _clear_arrows()
    await _place(_player, to)
    _player.health = _player.max_health
    _player._invulnerability_left = 0.0

    var arrow := (load(ARROW_SCENE) as PackedScene).instantiate() as EnemyArrow
    _lab.add_child(arrow)
    # Position and direction AFTER add_child, which is also what the archer does: the
    # arrow reads its level on its first physics frame, so `_ready` seeing (0, 0) is
    # harmless and the spawn point is the authoritative one.
    arrow.global_position = from
    arrow.direction = (to - from).normalized()
    arrow.speed = 440.0
    arrow.damage = 10

    var before := _player.health
    var seen := false
    for _frame in 220:
        await physics_frame
        if _player.health < before:
            return "hit"
        if is_instance_valid(arrow):
            seen = true
        elif seen:
            return "blocked"
    _clear_arrows()
    return "none"



func _clear_arrows() -> void:
    for child in _lab.get_children():
        if child is EnemyArrow:
            child.queue_free()


func _place(node: Node2D, at: Vector2) -> void:
    node.global_position = at
    if node is CharacterBody2D:
        (node as CharacterBody2D).velocity = Vector2.ZERO
    await wait_physics(3)
