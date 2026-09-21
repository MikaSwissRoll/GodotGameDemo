extends "res://tests_v2/harness.gd"

## V2 SCENARIOS — terrain and player traversal in ElevationLab.
##
## Terrain first: nothing else is added until these scenarios are stable. The
## geometry below is the lab's, and it follows the official grammar: the wall is ONE
## row, and each stair is ONE column wide spanning the lip row and the wall row.

const INPUT_SETUP := preload("res://scripts/systems/input_setup.gd")
const LAB_SCENE := "res://tests_v2/lab/ElevationLab.tscn"

const SUITE := "terrain_traversal"

## The terrace is rows 1-3, so the wall row is row 4: the drop line is y = 256 and the
## wall's foot, where the low ground starts, is y = 320.
const DROP_LINE := 256.0
const FACE_BOTTOM := 320.0
const STAIR_WEST_X := 288.0
const STAIR_EAST_X := 992.0

## The wall spans the footprint's columns, so a "beside the stair" probe has to be
## inside that span. The column just outside it is ordinary low ground leading to the
## stair's own low-side approach, which is the entrance rather than a hole.
const BESIDE_WEST_STAIR_X := 352.0
const BESIDE_EAST_STAIR_X := 928.0
const LOW_APPROACH_Y := 400.0

var _lab: Node2D
var _player: Player


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    arm_timeout(150.0, SUITE)
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

    _check_registry()
    await _scenario_a_cliff_blocks_from_below()
    await _scenario_b_cliff_blocks_from_above()
    await _scenario_c_stairs_carry_the_player_up()
    await _scenario_d_stairs_carry_the_player_down()
    await _scenario_e_no_entry_beside_a_stair()
    await _scenario_f_the_top_is_walkable()
    _check_the_stair_is_the_level_boundary()

    finish(SUITE)


func _check_registry() -> void:
    section("the terrain registry agrees with the geometry")
    check_eq(Elevation.level_at(Vector2(640.0, 150.0)), Elevation.HIGH,
        "the terrace surface must be HIGH")
    check_eq(Elevation.level_at(Vector2(640.0, 450.0)), Elevation.LOW,
        "the ground below the wall must be LOW")
    # The stair spans the lip row (inside the footprint) and the wall row.
    check(Elevation.is_ramp_tile(Vector2i(4, 3)), "the west stair's lip row must be registered")
    check(Elevation.is_ramp_tile(Vector2i(4, 4)), "the west stair's wall row must be registered")
    check(Elevation.is_ramp_tile(Vector2i(15, 4)), "the east stair's wall row must be registered")
    check(Elevation.levels_are_connected(), "LOW and HIGH must be connected by the stairs")
    # A stair is one column wide, so its neighbours are ordinary wall.
    check(not Elevation.is_ramp_tile(Vector2i(3, 4)),
        "the west stair is wider than one column")
    check(not Elevation.is_ramp_tile(Vector2i(5, 4)),
        "the west stair is wider than one column")


func _place(at: Vector2) -> void:
    _player.global_position = at
    _player.velocity = Vector2.ZERO
    await wait_physics(3)


func _walk(action: String, frames: int) -> void:
    Input.action_press(action)
    await wait_physics(frames)
    Input.action_release(action)
    await wait_physics(2)


## A — a player on the low ground cannot cross the wall directly.
func _scenario_a_cliff_blocks_from_below() -> void:
    section("A: the wall blocks from below")
    await _place(Vector2(640.0, 450.0))
    check_eq(Elevation.level_at(_player.global_position), Elevation.LOW,
        "setup: the player should start on the low ground")
    await _walk("move_up", 70)
    check(_player.global_position.y > FACE_BOTTOM - 8.0,
        "the player crossed into the wall row (y=%.0f)" % _player.global_position.y)
    check(_player.global_position.y < FACE_BOTTOM + 80.0,
        "the player was stopped well short of the wall (y=%.0f), so this proves nothing" % _player.global_position.y)
    check_eq(Elevation.level_at(_player.global_position), Elevation.LOW,
        "walking into the wall changed the player's level, so the logical and physical edges disagree")


## B — a player on the terrace cannot leave through the wall edge.
func _scenario_b_cliff_blocks_from_above() -> void:
    section("B: the wall blocks from above")
    await _place(Vector2(640.0, 150.0))
    check_eq(Elevation.level_at(_player.global_position), Elevation.HIGH,
        "setup: the player should start on the terrace")
    await _walk("move_down", 70)
    check(_player.global_position.y < DROP_LINE + 8.0,
        "the player walked off the terrace (y=%.0f)" % _player.global_position.y)
    check_eq(Elevation.level_at(_player.global_position), Elevation.HIGH,
        "leaving via the wall changed the player's level")


## C — both official stairs carry the player from LOW to HIGH.
func _scenario_c_stairs_carry_the_player_up() -> void:
    section("C: stairs carry the player up")
    for probe in [
        {"x": STAIR_WEST_X, "end": "west"},
        {"x": STAIR_EAST_X, "end": "east"},
    ]:
        await _place(Vector2(probe["x"], LOW_APPROACH_Y))
        check_eq(Elevation.level_at(_player.global_position), Elevation.LOW,
            "setup: should start below the %s stair" % probe["end"])
        await _walk("move_up", 110)
        check_eq(Elevation.level_at(_player.global_position), Elevation.HIGH,
            "the %s stair did not carry the player onto the terrace (y=%.0f)" % [
                probe["end"], _player.global_position.y])


## D — the stairs work downward too.
func _scenario_d_stairs_carry_the_player_down() -> void:
    section("D: stairs carry the player down")
    for probe in [
        {"x": STAIR_WEST_X, "end": "west"},
        {"x": STAIR_EAST_X, "end": "east"},
    ]:
        await _place(Vector2(probe["x"], 150.0))
        check_eq(Elevation.level_at(_player.global_position), Elevation.HIGH,
            "setup: should start on the terrace above the %s stair" % probe["end"])
        await _walk("move_down", 110)
        check_eq(Elevation.level_at(_player.global_position), Elevation.LOW,
            "the %s stair did not carry the player down (y=%.0f)" % [
                probe["end"], _player.global_position.y])


## E — the wall beside a stair is still a wall. This is the defect the old terrain
## had: only part of the bottom edge had collision, so the sides were free entry.
func _scenario_e_no_entry_beside_a_stair() -> void:
    section("E: no entry beside a stair")
    for probe in [
        {"x": BESIDE_WEST_STAIR_X, "side": "east of the west stair"},
        {"x": BESIDE_EAST_STAIR_X, "side": "west of the east stair"},
    ]:
        await _place(Vector2(probe["x"], LOW_APPROACH_Y))
        check_eq(Elevation.level_at(_player.global_position), Elevation.LOW,
            "setup: should start LOW %s" % probe["side"])
        await _walk("move_up", 70)
        check_eq(Elevation.level_at(_player.global_position), Elevation.LOW,
            "the player entered the terrace through the wall %s" % probe["side"])
        check(_player.global_position.y > FACE_BOTTOM - 8.0,
            "the player crossed the wall %s (y=%.0f)" % [
                probe["side"], _player.global_position.y])


## F — the terrace top is ordinary walkable ground.
func _scenario_f_the_top_is_walkable() -> void:
    section("F: the terrace top is walkable")
    await _place(Vector2(384.0, 150.0))
    var start_x := _player.global_position.x
    await _walk("move_right", 50)
    check(_player.global_position.x > start_x + 40.0,
        "the player could not walk along the terrace (%.0f -> %.0f)" % [
            start_x, _player.global_position.x])
    check_eq(Elevation.level_at(_player.global_position), Elevation.HIGH,
        "walking along the terrace changed the player's level")


## The stair's two rows straddle the level boundary exactly: the lower row is still
## low ground, the upper row is the terrace. That is what makes it a transition rather
## than decoration.
func _check_the_stair_is_the_level_boundary() -> void:
    section("the stair straddles the boundary")
    check_eq(Elevation.level_at(Vector2(STAIR_WEST_X, 288.0)), Elevation.LOW,
        "the stair's lower row (the wall row) must still be LOW")
    check_eq(Elevation.level_at(Vector2(STAIR_WEST_X, 224.0)), Elevation.HIGH,
        "the stair's upper row (the lip row) must be HIGH")
