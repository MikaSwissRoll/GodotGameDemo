extends "res://tests_v2/harness.gd"

## V2 SCENARIOS — terrain and player traversal in ElevationLab.
##
## Scenarios A-F from the elevation plan, driven with real input against the real
## lab scene. Terrain first: nothing else is added until these six are stable.

const INPUT_SETUP := preload("res://scripts/systems/input_setup.gd")
const LAB_SCENE := "res://tests_v2/lab/ElevationLab.tscn"

const SUITE := "terrain_traversal"

## Tile geometry of the lab. The west terrace is rows 1-3 with its face at rows 4-5,
## the east terrace is rows 1-4 with its face at rows 5-6, and the ramp is a
## staggered stair in the west face.
const DROP_LINE := 256.0
const FACE_BOTTOM := 384.0
const RAMP_CENTRE_X := 384.0
const BESIDE_RAMP_LEFT_X := 224.0
const BESIDE_RAMP_RIGHT_X := 544.0

var _lab: Node2D
var _player: Player


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    arm_timeout(120.0, SUITE)
    INPUT_SETUP.ensure_actions()

    section("lab builds")
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
    _player.controls_enabled = true

    section("the terrain registry agrees with the geometry")
    check_eq(Elevation.level_at(Vector2(150.0, 430.0)), Elevation.LOW,
        "the ground below the cliff should be LOW")
    check_eq(Elevation.level_at(Vector2(150.0, 150.0)), Elevation.HIGH,
        "the west terrace surface should be HIGH")
    check_eq(Elevation.level_at(Vector2(960.0, 150.0)), Elevation.HIGH,
        "the east terrace surface should be HIGH")
    check_eq(Elevation.level_at(Vector2(960.0, 290.0)), Elevation.HIGH,
        "the east terrace's deeper row should still be HIGH, not a separate level")
    check(Elevation.is_ramp_tile(Vector2i(5, 4)), "the upper ramp tread should be registered")
    check(Elevation.is_ramp_tile(Vector2i(4, 5)), "the lower ramp tread should be registered")
    check(Elevation.levels_are_connected(), "LOW and HIGH should be connected by the ramp")

    await _scenario_a_cliff_blocks_from_below()
    await _scenario_b_cliff_blocks_from_above()
    await _scenario_c_ramp_up()
    await _scenario_d_ramp_down()
    await _scenario_e_no_entry_beside_the_ramp()
    await _scenario_f_the_top_is_walkable()
    await _scenario_g_adjacent_terraces_are_one_level()

    finish(SUITE)


func _place(at: Vector2) -> void:
    _player.global_position = at
    _player.velocity = Vector2.ZERO
    await wait_physics(3)


func _walk(action: String, frames: int) -> void:
    Input.action_press(action)
    await wait_physics(frames)
    Input.action_release(action)
    await wait_physics(2)


## A — a player on the low ground cannot cross the cliff directly.
func _scenario_a_cliff_blocks_from_below() -> void:
    section("A: cliff blocks from below")
    await _place(Vector2(150.0, 520.0))
    check_eq(Elevation.level_at(_player.global_position), Elevation.LOW,
        "setup: the player should start on the low ground")
    await _walk("move_up", 70)
    check(_player.global_position.y > FACE_BOTTOM - 8.0,
        "the player crossed into the cliff face (y=%.0f)" % _player.global_position.y)
    check_eq(Elevation.level_at(_player.global_position), Elevation.LOW,
        "walking into the cliff changed the player's level, so the logical and physical edges disagree")


## B — a player on the terrace cannot leave through the cliff edge.
func _scenario_b_cliff_blocks_from_above() -> void:
    section("B: cliff blocks from above")
    await _place(Vector2(150.0, 150.0))
    check_eq(Elevation.level_at(_player.global_position), Elevation.HIGH,
        "setup: the player should start on the terrace")
    await _walk("move_down", 70)
    check(_player.global_position.y < DROP_LINE + 8.0,
        "the player walked off the cliff (y=%.0f)" % _player.global_position.y)
    check_eq(Elevation.level_at(_player.global_position), Elevation.HIGH,
        "leaving via the cliff changed the player's level")


## C — the ramp carries the player from LOW to HIGH.
func _scenario_c_ramp_up() -> void:
    section("C: ramp LOW to HIGH")
    await _place(Vector2(RAMP_CENTRE_X, 470.0))
    check_eq(Elevation.level_at(_player.global_position), Elevation.LOW,
        "setup: the player should start at the foot of the ramp")
    await _walk("move_up", 110)
    check_eq(Elevation.level_at(_player.global_position), Elevation.HIGH,
        "the player did not reach the terrace through the ramp (y=%.0f)" % _player.global_position.y)
    check(_player.global_position.y < DROP_LINE,
        "the player is still below the drop line (y=%.0f)" % _player.global_position.y)


## D — the ramp carries the player from HIGH to LOW.
func _scenario_d_ramp_down() -> void:
    section("D: ramp HIGH to LOW")
    await _place(Vector2(RAMP_CENTRE_X, 200.0))
    check_eq(Elevation.level_at(_player.global_position), Elevation.HIGH,
        "setup: the player should start on the terrace")
    await _walk("move_down", 110)
    check_eq(Elevation.level_at(_player.global_position), Elevation.LOW,
        "the player did not come down through the ramp (y=%.0f)" % _player.global_position.y)
    check(_player.global_position.y > FACE_BOTTOM,
        "the player is still above the cliff face (y=%.0f)" % _player.global_position.y)


## E — the edge beside the ramp is not an entrance. This is the old defect: only the
## bottom edge was walled, so any unwalled column was a legal way up.
func _scenario_e_no_entry_beside_the_ramp() -> void:
    section("E: no entry beside the ramp")
    for probe in [
        {"x": BESIDE_RAMP_LEFT_X, "side": "left"},
        {"x": BESIDE_RAMP_RIGHT_X, "side": "right"},
    ]:
        await _place(Vector2(probe["x"], 440.0))
        check_eq(Elevation.level_at(_player.global_position), Elevation.LOW,
            "setup: should start LOW beside the ramp (%s)" % probe["side"])
        await _walk("move_up", 70)
        check_eq(Elevation.level_at(_player.global_position), Elevation.LOW,
            "the player entered the terrace through the cliff %s of the ramp" % probe["side"])
        check(_player.global_position.y > FACE_BOTTOM - 8.0,
            "the player crossed the face %s of the ramp (y=%.0f)" % [
                probe["side"], _player.global_position.y])


## F — the terrace top is ordinary walkable ground.
func _scenario_f_the_top_is_walkable() -> void:
    section("F: the terrace top is walkable")
    await _place(Vector2(150.0, 150.0))
    var start_x := _player.global_position.x
    await _walk("move_right", 50)
    check(_player.global_position.x > start_x + 40.0,
        "the player could not walk along the terrace (%.0f -> %.0f)" % [
            start_x, _player.global_position.x])
    check_eq(Elevation.level_at(_player.global_position), Elevation.HIGH,
        "walking along the terrace changed the player's level")


## G — two high regions at the same level are one continuous walkable surface. The
## builder must not wall the seam between them, or the terrace is split in two.
func _scenario_g_adjacent_terraces_are_one_level() -> void:
    section("G: adjacent terraces are one level")
    await _place(Vector2(700.0, 150.0))
    check_eq(Elevation.level_at(_player.global_position), Elevation.HIGH,
        "setup: the player should start on the west terrace")
    var start_x := _player.global_position.x
    await _walk("move_right", 60)
    check(_player.global_position.x > start_x + 150.0,
        "the player was stopped crossing the join between the two terraces (%.0f -> %.0f)" % [
            start_x, _player.global_position.x])
    check_eq(Elevation.level_at(_player.global_position), Elevation.HIGH,
        "crossing the join changed the player's level")
