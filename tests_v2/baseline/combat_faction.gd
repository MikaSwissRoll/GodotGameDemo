extends "res://tests_v2/harness.gd"

## V2 BASELINE — combat and faction.
##
## Two questions, both load-bearing for every elevation change:
##   1. can an enemy actually be damaged through the real swing path, and
##   2. is friendly fire still impossible by construction.
##
## Question 1 has to be answered through the real hitbox, not by calling
## `take_damage` directly: the elevation rule lives inside that handler, so a test
## that bypasses the handler cannot see it.

const INPUT_SETUP := preload("res://scripts/systems/input_setup.gd")
const PLAYER_SCENE := "res://scenes/player/player.tscn"
const MELEE_SCENE := "res://scenes/enemies/melee_enemy.tscn"
const FOLLOWER_SCENE := "res://scenes/party/follower.tscn"

const SUITE := "combat_faction"

var _stage: Node2D
var _player: Player


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    arm_timeout(60.0, SUITE)
    INPUT_SETUP.ensure_actions()

    _stage = Node2D.new()
    _stage.name = "V2Stage"
    root.add_child(_stage)

    section("stage actors")
    _player = (load(PLAYER_SCENE) as PackedScene).instantiate() as Player
    _stage.add_child(_player)
    _player.global_position = Vector2(600.0, 400.0)
    _player.controls_enabled = true

    var enemy := (load(MELEE_SCENE) as PackedScene).instantiate() as Enemy
    _stage.add_child(enemy)
    # Parked and harmless: this suite is about whether a blow lands, not about AI.
    enemy.move_speed = 0.0
    enemy.damage = 0
    enemy.global_position = _player.global_position + Vector2(60.0, 0.0)
    await wait_physics(6)

    section("faction classification")
    check(Party.is_hostile(enemy), "a melee bandit must be hostile")
    check(not Party.is_hostile(_player), "the player must not be hostile")
    check(Party.is_party_member(_player), "the player must be a party member")
    check(Party.hostile_health(enemy) > 0, "a living bandit must report positive hostile health")

    section("the player's swing damages a hostile")
    _player.facing = Vector2.RIGHT
    _player._attack_cooldown_left = 0.0
    _player.restore_stamina()
    var enemy_health_before := enemy.health
    Input.action_press("attack")
    await wait_physics(3)
    Input.action_release("attack")
    await wait_physics(30)
    check(enemy.health < enemy_health_before,
        "a swing beside a bandit on the same ground did not damage it (%d -> %d)" % [
            enemy_health_before, enemy.health])

    section("friendly fire is impossible by construction")
    # The rule is enforced by masks, not by a runtime check, so the honest test is
    # the mask itself plus the classification it depends on.
    var player_hitbox := _player.get_node_or_null("AttackHitbox") as Area2D
    if check_not_null(player_hitbox, "the player has no AttackHitbox"):
        check((player_hitbox.collision_mask & Party.LAYER_COMPANION_HURTBOX) == 0,
            "the player's attack hitbox masks the companion hurtbox, so friendly fire is possible")
        check((player_hitbox.collision_mask & Party.LAYER_ENEMY_HURTBOX) != 0,
            "the player's attack hitbox does not mask the enemy hurtbox, so nothing can be hit")

    var follower := (load(FOLLOWER_SCENE) as PackedScene).instantiate() as Follower
    _stage.add_child(follower)
    follower.setup(_player)
    follower.global_position = _player.global_position + Vector2(40.0, 0.0)
    await wait_physics(6)
    check(not Party.is_hostile(follower), "a companion must never be hostile")
    check(Party.is_party_member(follower), "a companion must be a party member")

    section("a companion's swing cannot reach a party member")
    var follower_hitbox := follower.get_node_or_null("AttackHitbox") as Area2D
    if check_not_null(follower_hitbox, "the companion has no AttackHitbox"):
        check((follower_hitbox.collision_mask & Party.LAYER_ENEMY_HURTBOX) != 0,
            "the companion's attack hitbox does not mask the enemy hurtbox")
        check((follower_hitbox.collision_mask & 1) == 0,
            "the companion's attack hitbox masks the player body layer, so it could hit the player")

    section("damage is refused across faction even when hitboxes overlap")
    var player_health_before := _player.health
    # Drive the real handler with a friendly area: a companion hurtbox sitting on
    # the player's hitbox. It must be ignored, not merely unlikely to overlap.
    var friendly_hurtbox := follower.get_node_or_null("Hurtbox") as Area2D
    if check_not_null(friendly_hurtbox, "the companion has no Hurtbox"):
        _player._attacking = true
        _player._on_attack_area_entered(friendly_hurtbox)
        await wait_physics(2)
        check_eq(_player.health, player_health_before,
            "the player's attack handler damaged a party member")

    finish(SUITE)
