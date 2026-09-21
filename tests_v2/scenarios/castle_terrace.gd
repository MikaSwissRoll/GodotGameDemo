extends "res://tests_v2/harness.gd"

## V2 SCENARIOS ??the first migrated production region: CastleTerrace.
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
## stairs sit in the side notches beside the south wall, at columns 14 and 24.
const DROP_LINE := 512.0
const FACE_BOTTOM := 576.0
const STAIR_WEST_X := 928.0
const STAIR_EAST_X := 1568.0
## Inside the wall's span and clear of both stairs.
const WALL_PROBE_XS := [1120.0, 1376.0]
const LOW_GROUND_Y := 760.0
const TERRACE_Y := 300.0
## The stair's upper row, where the player crosses the side boundary horizontally.
const STAIR_APPROACH_Y := 480.0
## The forecourt's own span in world x (cols 15-23). Used to assert that a player who
## crossed a stair ended up ON the terrace, rather than a castle-shaped window that
## only held while the castle's collision was there to stop him.
const TERRACE_X := Vector2(896.0, 1600.0)

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
    # The terrace currently carries NO stairs. Whether it does or not changes what the
    # right invariant is, so the suite states both rather than being skipped: with
    # stairs, they must carry the player up; without, the terrace must be sealed.
    if Elevation.levels_are_connected():
        await _check_both_stairs_climb()
    else:
        await _check_the_terrace_is_sealed()
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


## The player's routes into the village castle use the side notches beside the wall.
##
## The west stair climbs from west to east and opens the forecourt's west boundary.
## The east stair mirrors it. The south wall remains continuous between them.
##
## The village is cluttered with houses and props, so the approach has to be probed
## for a spot the player can actually walk from. `_find_open_lateral` requires
## movement in the intended direction: a player spawned inside a house is pushed out
## by the physics engine, and counting that as movement would let a bad probe
## masquerade as a working one.
## With no stair declared, the terrace is sealed: the wall spans its full width and all
## four edges carry collision. That is the invariant to assert instead of climbing.
##
## The side probes stand one column clear of the wall body itself, because standing
## inside it would have the physics engine eject the player and prove nothing.
func _check_the_terrace_is_sealed() -> void:
    section("the terrace is sealed")
    check(not Elevation.levels_are_connected(), "setup: no stair should be declared")
    for probe in [
        {"at": Vector2(1120.0, LOW_GROUND_Y), "action": "move_up", "side": "the south"},
        {"at": Vector2(790.0, STAIR_APPROACH_Y), "action": "move_right", "side": "the west side"},
        {"at": Vector2(1700.0, STAIR_APPROACH_Y), "action": "move_left", "side": "the east side"},
    ]:
        await _place(probe["at"])
        check_eq(Elevation.level_at(_player.global_position), Elevation.LOW,
            "setup: should start LOW on %s" % probe["side"])
        await _walk(probe["action"], 90)
        check_eq(Elevation.level_at(_player.global_position), Elevation.LOW,
            "the player reached the terrace from %s with no stair (ended at %s)" % [
                probe["side"], _player.global_position.round()])


func _check_both_stairs_climb() -> void:
    section("both stairs are a way up")
    for probe in [
        {"xs": [840.0, 808.0, 872.0], "action": "move_right", "end": "west"},
        {"xs": [1624.0, 1640.0, 1608.0], "action": "move_left", "end": "east"},
    ]:
        var start: Vector2 = await _find_open_lateral(
            probe["xs"], STAIR_APPROACH_Y, probe["action"])
        check(start.x >= 0.0,
            "setup: no open approach to the %s stair among %s, so it is untested" % [
                probe["end"], probe["xs"]])
        if start.x < 0.0:
            continue
        check_eq(Elevation.level_at(_player.global_position), Elevation.LOW,
            "setup: should start LOW beside the %s stair" % probe["end"])

        await _walk(probe["action"], 80)
        # The player must end up ON the terrace and still on the stair's row. An
        # earlier version narrowed this to the columns the castle used to block, which
        # meant the check was really asserting that the castle was still there.
        check(_player.global_position.x > TERRACE_X.x
                and _player.global_position.x < TERRACE_X.y,
            "crossing the %s stair did not leave the player on the terrace (x=%.0f, expected %.0f..%.0f)" % [
                probe["end"], _player.global_position.x, TERRACE_X.x, TERRACE_X.y])
        check(
            _player.global_position.y > DROP_LINE - 64.0
                and _player.global_position.y < DROP_LINE,
            "the player left the stair row while crossing the %s entrance (y=%.0f)" % [
                probe["end"], _player.global_position.y])
        check_eq(Elevation.level_at(_player.global_position), Elevation.HIGH,
            "the %s stair did not carry the player onto the terrace (ended at %s, %s)" % [
                probe["end"], _player.global_position.round(),
                Elevation.level_name(Elevation.level_at(_player.global_position))])


## Walk briefly in `action` from each candidate and report the first spot where the
## player makes headway in that direction. Returns (-1, -1) when none is open.
##
## The player is put back on the chosen spot before returning. Without that, the caller
## inspects a position already walked 12 frames - close to half a tile - which is fine
## while the next terrain edge happens to be far away and reads as "should start LOW"
## failing the moment it is not.
func _find_open_lateral(xs: Array, y: float, action: String) -> Vector2:
    var sign_expected := 1.0 if action == "move_right" else -1.0
    for x in xs:
        await _place(Vector2(x, y))
        var from := _player.global_position
        await _walk(action, 12)
        if (_player.global_position.x - from.x) * sign_expected > 8.0:
            await _place(Vector2(x, y))
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
