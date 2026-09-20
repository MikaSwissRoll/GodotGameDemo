extends "res://tests_v2/harness.gd"

## V2 BASELINE — core player.
##
## The four things a player does every session: move, dash, guard, swing. If a
## refactor breaks one of these, nothing else in the game matters. Deliberately not
## a feature test: no enemies, no quests, no UI.

const INPUT_SETUP := preload("res://scripts/systems/input_setup.gd")
const PLAYER_SCENE := "res://scenes/player/player.tscn"

const SUITE := "player_core"

var _stage: Node2D
var _player: Player


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    arm_timeout(45.0, SUITE)
    INPUT_SETUP.ensure_actions()

    section("instantiate")
    _stage = Node2D.new()
    _stage.name = "V2Stage"
    root.add_child(_stage)
    var packed := load_scene(PLAYER_SCENE)
    if packed == null:
        finish(SUITE)
        return
    _player = packed.instantiate() as Player
    if not check_not_null(_player, "player.tscn did not instantiate as Player"):
        finish(SUITE)
        return
    _stage.add_child(_player)
    _player.global_position = Vector2(600.0, 400.0)
    await wait_physics(3)
    check_eq(_player.health, _player.max_health, "player should start at full health")
    check(_player.controls_enabled, "player should start with controls enabled")

    section("movement")
    var start := _player.global_position
    Input.action_press("move_right")
    await wait_physics(14)
    Input.action_release("move_right")
    check(_player.global_position.x > start.x + 10.0,
        "holding move_right for 14 physics frames did not move the player right")

    section("dash")
    await wait_physics(6)
    _player._dash_cooldown_left = 0.0
    _player.restore_stamina()
    var before_dash := _player.global_position
    Input.action_press("dash")
    await wait_physics(6)
    Input.action_release("dash")
    check(_player.global_position.x > before_dash.x + 20.0, "dash did not move the player")
    check(_player._dash_cooldown_left > 0.0, "dash did not start its cooldown")

    section("guard")
    await wait_physics(24)
    _player.restore_stamina()
    Input.action_press("guard")
    await wait_physics(3)
    check(_player.guarding, "holding guard did not raise the shield")
    Input.action_release("guard")
    await wait_physics(3)
    check(not _player.guarding, "releasing guard did not lower the shield")

    section("attack")
    await wait_physics(36)
    _player.restore_stamina()
    _player._attack_cooldown_left = 0.0
    var stamina_before := _player.stamina
    Input.action_press("attack")
    await wait_physics(3)
    Input.action_release("attack")
    check(_player._attacking, "pressing attack did not start a swing")
    check(_player.stamina < stamina_before, "a swing did not spend stamina")

    # Let the swing finish so nothing is left mid-coroutine when the tree tears down.
    await wait_physics(30)
    check(not _player._attacking, "the swing never ended")

    finish(SUITE)
