extends "res://tests_v2/harness.gd"

## V2 SCENARIOS — the first migrated production region: CastleTerrace.
##
## The lab proves the model. This proves the migration: the real village terrace, in
## the real classic map, with the real player, is blocked everywhere except its
## stair. It is the acceptance check for one region, and it is deliberately narrow.

const INPUT_SETUP := preload("res://scripts/systems/input_setup.gd")
const CLASSIC_SCENE := "res://scenes/main/game.tscn"

const SUITE := "castle_terrace"

## CastleTerrace is cols 15-23, rows 2-7, so its drawn stone face is rows 8-9 and the
## drop line is y = 512. The composed stair sits in front of where the player walks
## in from the village.
const STAIR_X := 1088.0
const AWAY_FROM_STAIR_X := 1400.0
const LOW_GROUND_Y := 700.0
const TERRACE_Y := 300.0
const DROP_LINE := 512.0
const FACE_BOTTOM := 640.0

var _game: Node2D
var _player: Player


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    arm_timeout(150.0, SUITE)
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
    check_eq(Elevation.level_at(Vector2(STAIR_X, TERRACE_Y)), Elevation.HIGH,
        "the terrace surface must register as HIGH")
    check_eq(Elevation.level_at(Vector2(STAIR_X, LOW_GROUND_Y)), Elevation.LOW,
        "the village ground below the face must register as LOW")
    check(Elevation.is_ramp_tile(Vector2i(17, 8)), "the stair's upper tread must be registered")
    check(Elevation.is_ramp_tile(Vector2i(15, 9)), "the stair's lower tread must be registered")
    check(Elevation.levels_are_connected(), "the terrace must be reachable through its stair")

    await _check_climbs_the_stair()
    await _check_cliff_blocks_away_from_the_stair()
    await _check_lip_blocks_from_above()

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


## The player's route into the village castle: up the composed stair.
func _check_climbs_the_stair() -> void:
    section("the stair is the way up")
    await _place(Vector2(STAIR_X, LOW_GROUND_Y))
    check_eq(Elevation.level_at(_player.global_position), Elevation.LOW,
        "setup: the player must start below the terrace")
    await _walk("move_up", 130)
    check_eq(Elevation.level_at(_player.global_position), Elevation.HIGH,
        "the player could not climb the castle stair (ended at y=%.0f, %s)" % [
            _player.global_position.y,
            Elevation.level_name(Elevation.level_at(_player.global_position))])


## Everywhere else along the face is a cliff. This is the defect the old terrain had:
## only one hand-placed wall covered part of the bottom edge, so the rest was open.
func _check_cliff_blocks_away_from_the_stair() -> void:
    section("the cliff blocks away from the stair")
    await _place(Vector2(AWAY_FROM_STAIR_X, LOW_GROUND_Y))
    check_eq(Elevation.level_at(_player.global_position), Elevation.LOW,
        "setup: the player must start below the terrace")
    await _walk("move_up", 100)
    check_eq(Elevation.level_at(_player.global_position), Elevation.LOW,
        "the player entered the terrace through the cliff, away from the stair")
    check(_player.global_position.y > FACE_BOTTOM - 8.0,
        "the player crossed the cliff face away from the stair (y=%.0f)" % _player.global_position.y)


## And from the top, the lip holds.
func _check_lip_blocks_from_above() -> void:
    section("the lip blocks from above")
    await _place(Vector2(AWAY_FROM_STAIR_X, TERRACE_Y))
    check_eq(Elevation.level_at(_player.global_position), Elevation.HIGH,
        "setup: the player must start on the terrace")
    await _walk("move_down", 100)
    check(_player.global_position.y < DROP_LINE + 8.0,
        "the player walked off the castle cliff (y=%.0f)" % _player.global_position.y)
    check_eq(Elevation.level_at(_player.global_position), Elevation.HIGH,
        "leaving through the cliff changed the player's level")
