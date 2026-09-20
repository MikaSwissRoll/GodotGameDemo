extends "res://tests_v2/harness.gd"

## V2 BASELINE — the Pawn_Knife foundation.
##
## The elevation reset is about to touch every melee actor, and the companion is one
## of them. Before that work starts, this records what "already working" means: he
## instantiates, he joins the party, he follows, and he is a valid target for the
## hostiles. It asserts the architecture is not already broken — not that the
## companion is finished.

const INPUT_SETUP := preload("res://scripts/systems/input_setup.gd")
const PLAYER_SCENE := "res://scenes/player/player.tscn"
const FOLLOWER_SCENE := "res://scenes/party/follower.tscn"
const MELEE_SCENE := "res://scenes/enemies/melee_enemy.tscn"

const SUITE := "follower_foundation"

var _stage: Node2D
var _player: Player
var _follower: Follower


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    arm_timeout(60.0, SUITE)
    INPUT_SETUP.ensure_actions()

    _stage = Node2D.new()
    _stage.name = "V2Stage"
    root.add_child(_stage)

    section("instantiate and set up")
    _player = (load(PLAYER_SCENE) as PackedScene).instantiate() as Player
    _stage.add_child(_player)
    _player.global_position = Vector2(900.0, 500.0)

    var packed := load_scene(FOLLOWER_SCENE)
    if packed == null:
        finish(SUITE)
        return
    _follower = packed.instantiate() as Follower
    if not check_not_null(_follower, "follower.tscn did not instantiate as Follower"):
        finish(SUITE)
        return
    _stage.add_child(_follower)
    _follower.setup(_player)
    _follower.global_position = _player.global_position + Vector2(-120.0, 0.0)
    await wait_physics(6)

    section("lifecycle")
    check(_follower.health > 0, "the companion should start alive")
    check(_follower.health <= _follower.max_health, "companion health must stay within its maximum")
    check_eq(_follower.state, Follower.State.FOLLOW,
        "a fresh companion should be in the FOLLOW state")

    section("party membership")
    check(_follower.is_party_member(), "the companion must report itself a party member")
    check(Party.is_party_member(_follower), "Party must classify the companion as a party member")
    check(not Party.is_hostile(_follower), "Party must never classify the companion as hostile")
    check(not Party.is_party_member(null), "Party must not crash or accept null")

    section("it follows")
    # Measure the gap AFTER displacing the player, not before. Teleporting the
    # player instantly opens the gap, so a before/after comparison across the
    # teleport scores the displacement itself as a failure to follow. The rule
    # worth asserting is: once the player is somewhere else, the companion closes.
    _player.global_position += Vector2(160.0, 0.0)
    await wait_physics(2)
    var gap_after_teleport := _follower.global_position.distance_to(_player.global_position)
    await wait_physics(40)
    var gap_after_chasing := _follower.global_position.distance_to(_player.global_position)
    check(gap_after_chasing < gap_after_teleport - 20.0,
        "the companion did not close on the player (%.0fpx -> %.0fpx after 40 frames)" % [
            gap_after_teleport, gap_after_chasing])
    check(gap_after_chasing < _follower.leash_distance,
        "the companion fell outside its leash distance (%.0fpx)" % gap_after_chasing)

    section("it cannot push the player around")
    # The companion's body layer must stay off the player's body layer, so contact
    # cannot displace the player.
    check((_follower.collision_layer & 1) == 0,
        "the companion body is on the player body layer, so it can shove the player")

    section("hostiles treat it as a valid target")
    var enemy := (load(MELEE_SCENE) as PackedScene).instantiate() as Enemy
    _stage.add_child(enemy)
    enemy.move_speed = 0.0
    enemy.damage = 0
    enemy.global_position = _follower.global_position + Vector2(40.0, 0.0)
    await wait_physics(30)
    check(enemy._is_target_valid(_follower),
        "a melee bandit does not accept the companion as a target")
    check(enemy._is_target_valid(_player),
        "a melee bandit does not accept the player as a target")

    section("it is damageable and can be downed without dying")
    var health_before := _follower.health
    _follower.take_damage(10, Vector2.RIGHT)
    await wait_physics(2)
    check(_follower.health < health_before, "the companion took no damage from a direct hit")
    _follower.take_damage(9999, Vector2.RIGHT)
    await wait_physics(4)
    check_eq(_follower.state, Follower.State.DOWNED,
        "a lethal hit must down the companion, not leave it standing")
    check(_follower.health <= 0 or _follower.state == Follower.State.DOWNED,
        "the downed companion should be out of the fight")

    finish(SUITE)
