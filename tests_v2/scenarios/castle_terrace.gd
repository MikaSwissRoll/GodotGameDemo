extends "res://tests_v2/harness.gd"

## V2 SCENARIOS — the first migrated production region: CastleTerrace.
##
## The lab proves the model. This proves the migration: the real village terrace, in
## the real classic map, with the real player, is blocked everywhere along its wall
## except at the two official stairs. It is the acceptance check for one region, and
## it is deliberately narrow.

const INPUT_SETUP := preload("res://scripts/systems/input_setup.gd")
const CLASSIC_SCENE := "res://scenes/main/game.tscn"

const SUITE := "castle_terrace"

## CastleTerrace is cols 15-23, rows 2-7, so its wall row is row 8: the drop line is
## y = 512 and the wall's foot, where the village ground starts, is y = 576. The two
## stairs sit at the ends of the south wall, at columns 15 and 23.
const DROP_LINE := 512.0
const FACE_BOTTOM := 576.0
const STAIR_WEST_X := 992.0
const STAIR_EAST_X := 1504.0
## Inside the wall's span and clear of both stairs.
const WALL_PROBE_XS := [1120.0, 1376.0]
const LOW_GROUND_Y := 760.0
const TERRACE_Y := 300.0
## The middle of the wall row, where a player walks to reach a stair at its end.
const WALL_ROW_Y := 544.0

var _game: Node2D
var _player: Player


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    arm_timeout(180.0, SUITE)
    INPUT_SETUP.ensure_actions()

    var packed := load_scene(CLASSIC_SCENE)
    if packed == null:
        finish(SUITE)
        return
    _game = packed.instantiate() as Node2D
    if not check_not_null(_game, "the classic scene did not instantiate"):
        finish(SUITE)
        return
    root.add_child(_game)
    current_scene = _game
    await wait_physics(6)

    _player = _game.get_node_or_null("Player") as Player
    if not check_not_null(_player, "the classic scene has no Player"):
        finish(SUITE)
        return
    (_game.get_node("GameUI") as GameUI).start_requested.emit()
    _player.controls_enabled = true
    await wait_physics(4)

    section("the migrated terrace is high ground")
    check_eq(Elevation.level_at(Vector2(STAIR_WEST_X, TERRACE_Y)), Elevation.HIGH,
        "the terrace surface must register as HIGH")
    check_eq(Elevation.level_at(Vector2(STAIR_WEST_X, LOW_GROUND_Y)), Elevation.LOW,
        "the village ground below the wall must register as LOW")
    check(Elevation.is_ramp_tile(Vector2i(15, 7)), "the west stair's lip row must be registered")
    check(Elevation.is_ramp_tile(Vector2i(15, 8)), "the west stair's wall row must be registered")
    check(Elevation.is_ramp_tile(Vector2i(23, 8)), "the east stair's wall row must be registered")
    check(not Elevation.is_ramp_tile(Vector2i(16, 8)), "a stair must be exactly one column wide")
    check(Elevation.levels_are_connected(), "the terrace must be reachable through its stairs")

    await _check_both_stairs_climb()
    await _check_the_wall_blocks_elsewhere()
    await _check_the_lip_blocks_from_above()

    finish(SUITE)


func _place(at: Vector2) -> void:
    _player.global_position = at
    _player.velocity = Vector2.ZERO
    await wait_physics(4)


func _walk(action: String, frames: int) -> void:
    Input.action_press(action)
    await wait_physics(frames)
    Input.action_release(action)
    await wait_physics(2)


## The player's route into the village castle: the official stairs at the ends of the
## wall.
##
## A stair sits at the END of the wall, so the way in is to walk along the wall row
## until the wall itself stops you - which lands you exactly on the stair's column -
## and then go up. That is also how the pieces are drawn: the west stair climbs west
## to east, the east stair east to west.
##
## The village is cluttered with houses and props, so the approach has to be probed
## for a spot the player can actually walk from. `_find_open_lateral` requires
## movement in the intended direction: a player spawned inside a house is pushed out
## by the physics engine, and counting that as movement would let a bad probe
## masquerade as a working one.
func _check_both_stairs_climb() -> void:
    section("both stairs are a way up")
    for probe in [
        {"xs": [880.0, 848.0, 912.0], "action": "move_right", "end": "west",
         "column_x": Vector2(960.0, 1024.0)},
        {"xs": [1616.0, 1584.0, 1648.0], "action": "move_left", "end": "east",
         "column_x": Vector2(1472.0, 1536.0)},
    ]:
        var start: Vector2 = await _find_open_lateral(probe["xs"], WALL_ROW_Y, probe["action"])
        check(start.x >= 0.0,
            "setup: no open approach to the %s stair among %s, so it is untested" % [
                probe["end"], probe["xs"]])
        if start.x < 0.0:
            continue
        check_eq(Elevation.level_at(_player.global_position), Elevation.LOW,
            "setup: should start LOW beside the %s stair" % probe["end"])

        # Along the wall; the wall stops the player on the stair's own column.
        await _walk(probe["action"], 60)
        var column: Vector2 = probe["column_x"]
        check(_player.global_position.x >= column.x and _player.global_position.x <= column.y,
            "walking to the %s stair left the player outside its column at x=%.0f (expected %.0f..%.0f)" % [
                probe["end"], _player.global_position.x, column.x, column.y])
        check(_player.global_position.y > DROP_LINE and _player.global_position.y < FACE_BOTTOM,
            "the player left the wall row while walking to the %s stair (y=%.0f)" % [
                probe["end"], _player.global_position.y])
        # Then up.
        await _walk("move_up", 90)
        check_eq(Elevation.level_at(_player.global_position), Elevation.HIGH,
            "the %s stair did not carry the player onto the terrace (ended at %s, %s)" % [
                probe["end"], _player.global_position.round(),
                Elevation.level_name(Elevation.level_at(_player.global_position))])


## Walk briefly in `action` from each candidate and report the first spot where the
## player makes headway in that direction. Returns (-1, -1) when none is open.
func _find_open_lateral(xs: Array, y: float, action: String) -> Vector2:
    var sign_expected := 1.0 if action == "move_right" else -1.0
    for x in xs:
        await _place(Vector2(x, y))
        var from := _player.global_position
        await _walk(action, 12)
        if (_player.global_position.x - from.x) * sign_expected > 8.0:
            return Vector2(x, y)
    return Vector2(-1.0, -1.0)


## Everywhere else along the wall is a cliff. This is the defect the old terrain had:
## only part of the bottom edge had collision, so the rest was open.
##
## The upper bound matters as much as the lower one. Without it, anything that stops
## the player early - a house, the castle itself - would make the check pass while
## proving nothing about the wall.
func _check_the_wall_blocks_elsewhere() -> void:
    section("the wall blocks away from the stairs")
    for probe_x in WALL_PROBE_XS:
        await _place(Vector2(probe_x, LOW_GROUND_Y))
        check_eq(Elevation.level_at(_player.global_position), Elevation.LOW,
            "setup: should start below the wall")
        await _walk("move_up", 120)
        check_eq(Elevation.level_at(_player.global_position), Elevation.LOW,
            "the player entered the terrace through the wall at x=%.0f" % probe_x)
        check(_player.global_position.y > FACE_BOTTOM - 8.0,
            "the player crossed the wall at x=%.0f (y=%.0f)" % [probe_x, _player.global_position.y])
        check(_player.global_position.y < FACE_BOTTOM + 100.0,
            "the player was stopped well short of the wall at x=%.0f (y=%.0f), so something else blocked him and this proves nothing" % [
                probe_x, _player.global_position.y])


## And from the top, the lip holds.
func _check_the_lip_blocks_from_above() -> void:
    section("the lip blocks from above")
    for probe_x in WALL_PROBE_XS:
        await _place(Vector2(probe_x, TERRACE_Y))
        check_eq(Elevation.level_at(_player.global_position), Elevation.HIGH,
            "setup: the player must start on the terrace")
        await _walk("move_down", 100)
        check(_player.global_position.y < DROP_LINE + 8.0,
            "the player walked off the castle terrace at x=%.0f (y=%.0f)" % [
                probe_x, _player.global_position.y])
        check_eq(Elevation.level_at(_player.global_position), Elevation.HIGH,
            "leaving through the wall changed the player's level")
