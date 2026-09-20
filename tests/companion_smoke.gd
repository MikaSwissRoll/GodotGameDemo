extends SceneTree

## Companion contract: recruitment, following, combat, faction safety and the
## downed cycle.
##
## Drives the real node, the real signals and the real handlers rather than
## restating their rules, so a change to any of them fails here.

const INPUT_SETUP := preload("res://scripts/systems/input_setup.gd")
const PROG := preload("res://scripts/systems/classic_progression.gd")
const PARTY := preload("res://scripts/systems/party.gd")

var game: Node2D
var player: Player
var progress: ClassicProgression
var ui: GameUI
var npc: RecruitNpc


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    create_timer(120.0).timeout.connect(func() -> void:
        push_error("companion test timed out")
        quit(1))
    INPUT_SETUP.ensure_actions()
    game = (load("res://scenes/main/game.tscn") as PackedScene).instantiate() as Node2D
    root.add_child(game)
    current_scene = game
    player = game.get_node("Player") as Player
    progress = game.get_node("ClassicProgression") as ClassicProgression
    ui = game.get_node("GameUI") as GameUI
    npc = game.get_node("PawnKnife") as RecruitNpc
    (game.get_node("GameUI") as GameUI).start_requested.emit()
    await _wait(3)

    _check_hidden_before_free_play()
    await _check_available_after_free_play()
    await _check_insufficient_gold()
    await _check_hire()
    await _check_following()
    await _check_faction_safety()
    await _check_combat_and_downed()

    print("COMPANION PASS: gated, atomic hire, follows, fights, cannot hurt friendlies, revives")
    quit(0)


## Before the main quest is handed in the companion is not in the world at all, so
## there is nothing to hire and nothing to explain.
##
## Deliberately synchronous: an `await` inside a check this cheap lets the
## coroutine resume after later sections have changed the phase, which makes the
## assertion observe a state it was never meant to test.
func _check_hidden_before_free_play() -> void:
    assert(progress.phase != PROG.Phase.FREE_PLAY, "Setup: free play already active")
    assert(not npc.visible, "The recruit was visible before the main quest finished")
    ui.hide_overlay()
    var gold_before: int = game.gold
    ui.overlay.visible = false
    game._on_pawn_knife_interacted()
    assert(progress.phase == PROG.Phase.GUARD_TUTORIAL,
        "The recruit interaction advanced the phase before free play")
    assert(not ui.overlay.visible, "Talking to the recruit opened a dialogue early")
    assert(game.gold == gold_before, "Gold changed before any hire")
    assert(game.companion == null, "A companion existed before free play")
    print("  gated: hidden and inert before the main quest")


func _check_available_after_free_play() -> void:
    progress.start_free_play()
    await _wait(3)
    assert(npc.visible, "The recruit did not appear in free play")
    assert(npc.is_inside_tree(), "The recruit was not in the scene")
    print("  available: recruit appears once free play begins")


## Below the price: a refusal, and crucially nothing is spent.
func _check_insufficient_gold() -> void:
    game.gold = 24
    ui.set_gold(game.gold)
    game._on_pawn_knife_interacted()
    await _wait(2)
    assert(ui.overlay_body.text.contains("金币还不够"),
        "The refusal did not say the gold was short: %s" % ui.overlay_body.text)
    assert(game.gold == 24, "An unaffordable hire changed the gold: %d" % game.gold)
    assert(game.companion == null, "An unaffordable hire created a companion")
    # Confirming anyway must still spend nothing.
    game._on_recruit_accepted()
    await _wait(2)
    assert(game.gold == 24, "Confirming an unaffordable hire spent gold: %d" % game.gold)
    assert(game.companion == null, "Confirming an unaffordable hire hired him")
    print("  refused at 24 gold, nothing deducted, no companion created")


func _check_hire() -> void:
    game.gold = 40
    ui.set_gold(game.gold)
    game._on_pawn_knife_interacted()
    await _wait(2)
    assert(ui.overlay.visible, "The hire offer did not appear with enough gold")
    assert(ui.overlay_body.text.contains("25"), "The offer did not state the price")

    var gold_before: int = game.gold
    game._on_recruit_accepted()
    await _wait(3)
    assert(game.gold == gold_before - 25,
        "The hire charged %d, expected 25" % (gold_before - game.gold))
    assert(game.companion != null, "The hire did not create a companion")
    assert(PARTY.is_party_member(game.companion), "The companion is not a party member")
    assert(game.companion.is_inside_tree(), "The companion was not added to the scene")

    # The recruit NPC must be gone, so there is no second stall and no prompt left.
    await _wait(4)
    assert(not is_instance_valid(npc) or npc.is_queued_for_deletion(),
        "The recruit NPC survived the hire, leaving a duplicate pawn")
    var followers := get_nodes_in_group("follower")
    assert(followers.size() == 1, "Expected exactly one follower, found %d" % followers.size())

    # A second hire must be impossible, and must not charge again.
    var after: int = game.gold
    game._on_pawn_knife_interacted()
    game._on_recruit_accepted()
    await _wait(2)
    assert(game.gold == after, "A second hire charged again: %d" % game.gold)
    assert(get_nodes_in_group("follower").size() == 1, "A duplicate companion was created")
    print("  hired for exactly 25 gold, NPC removed, one follower, second hire refused")


func _check_following() -> void:
    var companion := game.companion as Follower
    # Park the story enemies far away first. With one standing next to the player
    # the companion is correctly in combat, and a formation check would be
    # measuring the wrong state.
    for node in get_nodes_in_group("bandits"):
        (node as Node2D).global_position = Vector2(4400, 830)
    await _wait(6)
    # Walk the player a long way and give the companion time to catch up.
    player.global_position = Vector2(1600, 900)
    await _wait(120)
    var separation := companion.global_position.distance_to(player.global_position)
    assert(separation > 8.0,
        "The companion stood on top of the player (%.1fpx)" % separation)
    assert(separation < companion.leash_distance,
        "The companion failed to keep up (%.1fpx away)" % separation)
    assert(companion.state == Follower.State.FOLLOW or companion.state == Follower.State.RETURN,
        "The companion was not following with no enemy nearby (state %d)" % companion.state)

    # Settled: once it is on station it must hold, not oscillate around the slot.
    var settled := companion.global_position
    await _wait(30)
    var drift := companion.global_position.distance_to(settled)
    assert(drift < 20.0,
        "The companion drifted %.1fpx while the player stood still" % drift)
    var on_station := companion.global_position.distance_to(player.global_position)
    assert(on_station < companion.catch_up_distance,
        "The companion settled %.1fpx away, outside its catch-up range" % on_station)

    # It must not shove the player. The mask deliberately includes other
    # character bodies (the Guard, the Merchant, the recruit), so it cannot be
    # "world only"; the property that matters is that it does not include the
    # player's own body layer, which is what would make the two push each other.
    assert(companion.collision_mask & PARTY.LAYER_WORLD,
        "The companion does not collide with world geometry")
    assert(not (companion.collision_mask & 1),
        "The companion masks the player body layer, so it can shove the player")
    assert(not (companion.collision_mask & PARTY.LAYER_ENEMY_BODY),
        "The companion masks the enemy body layer, so it can shove enemies")
    print("  follows: %.0fpx behind, settles without jitter, cannot push the player" % separation)


## The hard rule. A companion's attack masks only the enemy hurtbox layer, so it
## physically cannot reach a friendly, and the guards prove it.
func _check_faction_safety() -> void:
    var companion := game.companion as Follower
    assert(companion._attack_hitbox.collision_mask == PARTY.LAYER_ENEMY_HURTBOX,
        "The companion's attack mask is %d, expected only the enemy hurtbox (%d)" % [
            companion._attack_hitbox.collision_mask, PARTY.LAYER_ENEMY_HURTBOX])
    assert(not PARTY.is_hostile(player), "The player was classified as hostile")
    assert(not PARTY.is_hostile(game.get_node("VillageGuard")), "The Guard was classified as hostile")
    assert(not PARTY.is_hostile(game.get_node("Merchant")), "The Merchant was classified as hostile")
    assert(PARTY.is_party_member(player), "The player is not a party member")
    assert(not PARTY.is_party_member(game.get_node("VillageGuard")),
        "The Guard was treated as a party member; friendly NPCs must stay separate")
    # A swing must not scratch the player even when adjacent.
    player.global_position = companion.global_position
    player.health = player.max_health
    companion._facing = Vector2.RIGHT
    companion._perform_attack()
    await _wait(6)
    assert(player.health == player.max_health, "The companion damaged the player")
    print("  faction: attack mask reaches enemies only; player, Guard and Merchant unharmed")


func _check_combat_and_downed() -> void:
    var companion := game.companion as Follower
    # Put a live enemy right beside the player so assist range is satisfied.
    var enemy := game.get_node("MeleeEnemy1") as Enemy
    enemy.global_position = player.global_position + Vector2(70, 0)
    enemy.health = enemy.max_health
    await _wait(30)
    assert(companion.target == enemy,
        "The companion did not engage a nearby enemy (target=%s)" % companion.target)

    # Stickiness: the target must hold across frames rather than flickering.
    var held := companion.target
    var switches := 0
    for frame in 30:
        await physics_frame
        if companion.target != held:
            switches += 1
            held = companion.target
    assert(switches <= 1, "The companion changed target %d times in 30 frames" % switches)

    # It must actually land damage.
    var enemy_health_before: int = enemy.health
    for frame in 180:
        await physics_frame
        if enemy.health < enemy_health_before:
            break
    assert(enemy.health < enemy_health_before,
        "The companion never damaged the enemy (enemy HP %d)" % enemy.health)

    # Leash: a target far from the player must be abandoned.
    enemy.global_position = player.global_position + Vector2(3000, 0)
    await _wait(30)
    assert(companion.target == null or companion.target != enemy,
        "The companion kept chasing an enemy far outside the leash")
    print("  combat: engages nearby, holds its target, lands damage, abandons far targets")

    # Downed: reaches 0, stops acting, and comes back without ending the game.
    companion.take_damage(9999, Vector2.RIGHT)
    await _wait(2)
    assert(companion.health == 0, "Damage did not reach zero")
    assert(companion.state == Follower.State.DOWNED, "The companion did not enter DOWNED")
    assert(not paused, "Downing the companion paused the game")
    # Enemies must stop treating a downed companion as a target.
    assert(not enemy._is_target_valid(companion), "A downed companion is still a valid target")
    assert(enemy._is_target_valid(player), "The player stopped being a valid target")
    # And it must not attack while down.
    var downed_swing: int = companion._attack_cooldown_left
    companion._begin_attack()
    assert(companion.state == Follower.State.DOWNED, "A downed companion began an attack")

    # Revival.
    var waited := 0.0
    while companion.state == Follower.State.DOWNED and waited < companion.downed_seconds + 4.0:
        await physics_frame
        waited += 1.0 / 60.0
    assert(companion.state != Follower.State.DOWNED, "The companion never revived")
    assert(companion.health > 0, "The companion revived with no health")
    assert(not paused, "Revival paused the game")
    print("  downed: stops acting and targeting, revives after %.1fs with %d HP, game continues" % [
        waited, companion.health])


func _wait(count: int) -> void:
    for _i in count:
        await physics_frame
