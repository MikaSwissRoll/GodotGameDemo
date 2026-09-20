extends SceneTree

## The regressions that slipped through: an archer is a different class from a
## melee bandit, and the arrow's collision mask never learned about companions.
##
## Both bugs survived the earlier suites because those only ever paired the
## companion with a melee enemy that had been placed on top of it. These checks use
## an archer, and let the companion find its own fight.

const INPUT_SETUP := preload("res://scripts/systems/input_setup.gd")
const PROG := preload("res://scripts/systems/classic_progression.gd")
const PARTY := preload("res://scripts/systems/party.gd")

var game: Node2D
var player: Player
var progress: ClassicProgression
var companion: Follower


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    create_timer(150.0).timeout.connect(func() -> void:
        push_error("companion archer test timed out")
        quit(1))
    INPUT_SETUP.ensure_actions()
    game = (load("res://scenes/main/game.tscn") as PackedScene).instantiate() as Node2D
    root.add_child(game)
    current_scene = game
    player = game.get_node("Player") as Player
    progress = game.get_node("ClassicProgression") as ClassicProgression
    (game.get_node("GameUI") as GameUI).start_requested.emit()
    await _wait(3)
    progress.start_free_play()
    game.gold = 40
    game._on_pawn_knife_interacted()
    game._on_recruit_accepted()
    companion = game.companion as Follower
    await _wait(10)

    _check_archer_is_hostile_classification()
    await _check_companion_attacks_archer()
    await _check_companion_engages_spawned_enemy()
    await _check_arrow_damages_companion()
    await _check_archer_targets_companion()
    await _check_archer_drops_three_gold()
    _check_npcs_have_bodies()
    await _check_player_is_blocked_by_npc()
    await _check_companion_is_blocked_by_enemy()

    print("COMPANION ARCHER PASS: archers and spawned enemies targetable, arrows hurt companions, archers pay 3, NPCs block, archers retarget")
    quit(0)


## The reported bug, in the form the player met it.
##
## A free-play enemy is created by instantiate(), which does not carry a group
## declared in the scene file. Those enemies used to arrive with no `bandits`
## membership, so a companion standing next to one picked nothing and simply
## followed the player around. Placement here is the situation, not a staged
## outcome: the enemy is put near the PLAYER and the companion is left to find it.
func _check_companion_engages_spawned_enemy() -> void:
    var progress := game.get_node("ClassicProgression") as ClassicProgression
    progress.start_free_play()
    await _wait(4)
    var spawned: Array = game._free_play_enemies
    assert(not spawned.is_empty(), "Setup: free play spawned nothing to fight")

    var foe: Node2D = spawned[0]
    assert(foe.is_in_group("bandits"),
        "A free-play enemy is not in the bandits group, so no companion can target it")

    # Explicit placement, so this check does not depend on whatever the previous
    # checks left behind. Every other bandit goes far out of range, which is exactly
    # the post-quest state the player was in when the bug was reported.
    for node in get_nodes_in_group("bandits"):
        if node != foe:
            (node as Node2D).global_position = Vector2(120, 3600)
    foe.global_position = Vector2(2760, 800)
    player.global_position = Vector2(2680, 800)
    companion.global_position = Vector2(2630, 830)
    companion.state = Follower.State.FOLLOW
    companion.target = null
    companion._attack_cooldown_left = 0.0
    companion._attack_phase = 0.0
    await _wait(10)

    assert(companion.target == foe,
        "The companion did not acquire a spawned free-play enemy (target=%s, state=%d, dist=%.0f, hp=%d)" % [
            companion.target, companion.state,
            companion.global_position.distance_to(foe.global_position), foe.get("health")])

    var before: int = foe.get("health")
    for frame in 600:
        await physics_frame
        if foe.get("health") < before:
            break
    assert(foe.get("health") < before,
        "The companion never damaged a spawned free-play enemy (hp=%d, state=%d, dist=%.0f)" % [
            foe.get("health"), companion.state,
            companion.global_position.distance_to(foe.global_position)])
    print("  companion acquired and damaged a spawned free-play enemy (%d -> %d)" % [
        before, foe.get("health")])


## An archer used to grab the player once in `_ready` and never look again, so it
## could not react to a companion at all. With the player far away and a companion
## close, it must switch.
func _check_archer_targets_companion() -> void:
    var archer := game.get_node("ArcherEnemy1") as ArcherEnemy
    var melee := game.get_node("MeleeEnemy1") as Enemy
    # Keep the melee enemy from interfering, and keep the companion standing still.
    melee.global_position = Vector2(120, 3600)
    player.global_position = Vector2(600, 300)
    archer.global_position = Vector2(3400, 1200)
    companion.global_position = archer.global_position + Vector2(-40, 0)
    companion.state = Follower.State.FOLLOW
    companion.health = companion.max_health
    # Longer than the archer's retarget interval.
    var waited := 0
    while companion.target == null and waited < 30:
        await physics_frame
        waited += 1
    var switched := false
    var elapsed := 0
    for frame in 200:
        await physics_frame
        elapsed = frame
        if archer.target == companion:
            switched = true
            break
    assert(switched,
        "The archer never targeted the far closer companion (target=%s)" % archer.target)
    print("  archer switched to the nearer companion after %d frames" % elapsed)


## The classification bug in one assertion: `ArcherEnemy` shares no base with
## `Enemy`, so a check written against `Enemy` alone excludes every archer.
func _check_archer_is_hostile_classification() -> void:
    var archer := game.get_node("ArcherEnemy1") as ArcherEnemy
    assert(archer != null, "Setup: no archer in the scene")
    # Proving the two classes are unrelated, so the shared helper has to cover
    # both. Done through a Node handle because a typed ArcherEnemy can never be an
    # Enemy, which is exactly the point.
    var as_node: Node = archer
    assert(not (as_node is Enemy),
        "Setup changed: the archer now derives from Enemy, revisit the shared helper")
    assert(PARTY.is_hostile(archer),
        "An archer is not classified as hostile, so the companion cannot target it")
    assert(PARTY.hostile_health(archer) > 0, "Archer health is not readable through the helper")
    print("  archers classify as hostile despite being a separate class")


## The companion must engage an archer it was never placed next to.
func _check_companion_attacks_archer() -> void:
    var archer := game.get_node("ArcherEnemy1") as ArcherEnemy
    var melee := game.get_node("MeleeEnemy1") as Enemy
    # Move every melee bandit far away so the archer is the only candidate.
    for node in get_nodes_in_group("bandits"):
        if node is Enemy:
            (node as Node2D).global_position = Vector2(4600, 300)
    player.global_position = Vector2(3400, 900)
    companion.global_position = Vector2(3340, 900)
    archer.global_position = Vector2(3480, 900)
    var before: int = archer.health
    await _wait(6)

    assert(companion.target == archer,
        "The companion did not pick the archer as its target (target=%s)" % companion.target)

    for frame in 600:
        await physics_frame
        if archer.health < before:
            break
    assert(archer.health < before,
        "The companion never damaged the archer (hp=%d, state=%d, dist=%.0f)" % [
            archer.health, companion.state,
            companion.global_position.distance_to(archer.global_position)])
    assert(melee.health == melee.max_health, "Setup: the melee enemy was not meant to be involved")
    print("  companion engaged and damaged an archer (%d -> %d)" % [before, archer.health])


## The arrow's mask must reach companion hurtboxes, or a companion is immune to the
## one enemy that attacks from range.
func _check_arrow_damages_companion() -> void:
    # Fire one straight into the companion, with the player far away so the arrow
    # can only reach the companion. Without that, the player's hurtbox is on the
    # arrow's path and absorbs the hit, which is what made this look like a
    # companion-immune bug when it was the test aiming at the wrong body.
    #
    # Live archers are parked for this check: they keep shooting the player from
    # range, and their arrows land on the player, which would make the
    # "player untouched" assertion below meaningless rather than wrong.
    for node in get_nodes_in_group("bandits"):
        if node is ArcherEnemy:
            (node as Node2D).global_position = Vector2(600, 200)
    player.global_position = Vector2(600, 300)
    player.health = player.max_health
    companion.global_position = Vector2(3400, 1200)
    companion.state = Follower.State.FOLLOW
    companion.health = companion.max_health
    await _wait(4)
    var before: int = companion.health
    var arrow_scene := load("res://scenes/enemies/arrow.tscn") as PackedScene
    var arrow := arrow_scene.instantiate() as EnemyArrow
    assert(arrow.collision_mask & PARTY.LAYER_COMPANION_HURTBOX,
        "The arrow's mask %d does not include the companion hurtbox layer %d" % [
            arrow.collision_mask, PARTY.LAYER_COMPANION_HURTBOX])
    game.add_child(arrow)
    arrow.direction = Vector2.RIGHT
    arrow.global_position = companion.global_position + Vector2(-40, 0)
    # Aim the arrow at the companion's hurtbox, which sits above its origin.
    arrow.global_position += Vector2(0, -28)
    await _wait(40)
    assert(companion.health < before,
        "An arrow passed through the companion without damaging it (%d HP)" % companion.health)
    print("  arrow damaged the companion (%d -> %d)" % [before, companion.health])


## An archer is the harder kill and pays accordingly.
func _check_archer_drops_three_gold() -> void:
    var archer := game.get_node("ArcherEnemy2") as ArcherEnemy
    archer.health = 1
    var gold_before: int = game.gold
    archer.take_damage(999, Vector2.RIGHT)
    await _wait(10)
    var collected := 0
    for child in game.get_children():
        if child is GoldPickup:
            var pickup := child as GoldPickup
            collected = maxi(collected, pickup.value)
            player.global_position = pickup.global_position
            await _wait(4)
    assert(collected == 3, "An archer dropped %d gold, expected 3" % collected)
    assert(game.gold == gold_before + 3,
        "Collecting an archer's drop gave %d gold, expected 3" % (game.gold - gold_before))
    print("  archer dropped 3 gold and it was collected")


func _wait(count: int) -> void:
    for _i in count:
        await physics_frame


## The Guard, the Merchant and the recruit must be solid, not walk-through. They
## are Area2Ds for interaction, so a solid body has to be added alongside: without
## it the player and the enemies pass straight through a person.
func _check_npcs_have_bodies() -> void:
    for npc_name in ["VillageGuard", "Merchant", "PawnKnife"]:
        var npc := game.get_node_or_null(npc_name) as Node2D
        # The recruit is freed the moment he is hired, which is correct: a hired
        # companion must not leave a duplicate body standing in the village.
        if npc == null and npc_name == "PawnKnife":
            print("    note: the recruit has been hired and removed, as intended")
            continue
        assert(npc != null, "%s is missing from the scene" % npc_name)
        var body := npc.get_node_or_null("Body") as StaticBody2D
        assert(body != null, "%s has no solid body, so it can be walked through" % npc_name)
        assert(body.collision_layer & PARTY.LAYER_NPC_BODY,
            "%s's body is not on the NPC body layer, so characters will not collide with it" % npc_name)
        assert(body.get_node_or_null("CollisionShape2D") != null,
            "%s's body has no shape" % npc_name)
    # And the party must actually collide with that layer.
    assert(companion.collision_mask & PARTY.LAYER_NPC_BODY,
        "The companion does not collide with NPC bodies, so it would walk through people")
    assert(companion.collision_mask & PARTY.LAYER_WORLD,
        "The companion does not collide with world geometry")
    assert(player.collision_mask & PARTY.LAYER_WORLD,
        "The player does not collide with world geometry")
    # The companion's own body must stay off the player's layer, or enemies would
    # treat the companion as a solid obstacle and shove it around the map.
    assert(not (companion.collision_layer & 1),
        "The companion's body is on the player body layer, so enemies will push it")
    print("  Guard, Merchant and recruit are solid; player and companion collide with them")


## The companion must be stopped by an enemy body, the same way the player is. It
## sits on its own layer rather than the player's, so both sides have to name each
## other: the companion masks the enemy body layer, and enemies mask the companion
## body layer.
func _check_companion_is_blocked_by_enemy() -> void:
    var enemy := game.get_node("MeleeEnemy2") as Enemy
    player.global_position = Vector2(600, 300)
    enemy.global_position = Vector2(3400, 1200)
    companion.global_position = enemy.global_position + Vector2(-60, 0)
    companion.state = Follower.State.FOLLOW
    companion.velocity = Vector2.ZERO
    await _wait(4)
    var before := companion.global_position.distance_to(enemy.global_position)
    companion.move_and_collide(Vector2(90, 0))
    await physics_frame
    var after := companion.global_position.distance_to(enemy.global_position)
    assert(after > 8.0,
        "A 90px push from %.0fpx away left the companion %.1fpx from the enemy, so enemies do not block it" % [
            before, after])
    # And the enemy side must name the companion, or the enemy walks through it.
    assert(enemy.collision_mask & PARTY.LAYER_COMPANION_BODY,
        "The enemy's mask %d does not include the companion body layer %d, so it walks through companions" % [
            enemy.collision_mask, PARTY.LAYER_COMPANION_BODY])
    assert(companion.collision_mask & PARTY.LAYER_ENEMY_BODY,
        "The companion's mask %d does not include the enemy body layer, so it walks through enemies"
        % companion.collision_mask)
    print("  enemy bodies block the companion too: %.0fpx -> %.0fpx from the enemy" % [before, after])


## The layers say the player should be blocked, but only a real move proves it.
##
## Stands the player just outside the Guard and asks for far more movement than the
## remaining gap. A solid body clamps the result; without one the player would end
## up past the Guard's centre. Uses `move_and_collide`, because assigning
## `global_position` teleports straight through geometry and would report success
## no matter how the collision is set up.
func _check_player_is_blocked_by_npc() -> void:
    var guard := game.get_node("VillageGuard") as Node2D
    player.global_position = guard.global_position + Vector2(-60, 0)
    player.velocity = Vector2.ZERO
    await _wait(4)
    var before := player.global_position.distance_to(guard.global_position)
    player.move_and_collide(Vector2(90, 0))
    await physics_frame
    var after := player.global_position.distance_to(guard.global_position)
    assert(after > 8.0,
        "A 90px push from %.0fpx away left the player %.1fpx from the Guard's centre, so he is not solid" % [
            before, after])
    assert(after > before - 90.0,
        "The player moved the full 90px through the Guard (%.0f -> %.0f)" % [before, after])
    print("  the Guard's body clamped a 90px push: %.0fpx -> %.0fpx from his centre" % [before, after])
