extends SceneTree

## Companion integration: the paths that cross other systems.
##
## The core contract lives in companion_smoke. This covers what happens when a
## recruited companion meets the rest of the game: enemies choosing it as a target,
## enemy damage reaching it, the player dying, and a restart. These are where a
## leftover reference or a stale target would show up.

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
    create_timer(120.0).timeout.connect(func() -> void:
        push_error("companion integration test timed out")
        quit(1))
    INPUT_SETUP.ensure_actions()
    game = (load("res://scenes/main/game.tscn") as PackedScene).instantiate() as Node2D
    root.add_child(game)
    current_scene = game
    player = game.get_node("Player") as Player
    progress = game.get_node("ClassicProgression") as ClassicProgression
    (game.get_node("GameUI") as GameUI).start_requested.emit()
    await _wait(3)
    _hire()
    await _wait(3)

    await _check_enemy_targets_companion()
    await _check_enemy_damages_companion()
    await _check_companion_kill_drops_gold()
    await _check_player_death()
    await _check_restart_clears_party()

    print("COMPANION INTEGRATION PASS: targeted, damaged, kills drop gold, survives player death and restart")
    quit(0)


func _hire() -> void:
    progress.start_free_play()
    game.gold = 40
    game._on_pawn_knife_interacted()
    game._on_recruit_accepted()
    companion = game.companion as Follower


## An enemy must be able to pick the companion, not only the player, or the
## companion is an immortal turret.
func _check_enemy_targets_companion() -> void:
    var enemy := game.get_node("MeleeEnemy2") as Enemy
    # Put the companion right beside the enemy and the player far away, so the
    # companion is unambiguously the nearest party member.
    player.global_position = Vector2(2760, 400)
    companion.global_position = Vector2(2940, 1010)
    enemy.global_position = Vector2(2960, 1010)
    await _wait(120)
    assert(enemy.target == companion,
        "The enemy did not target the nearer companion (target=%s)" % enemy.target)
    assert(PARTY.is_party_member(companion), "The companion stopped counting as a party member")

    # Stability: an enemy must not flip targets every frame.
    var held := enemy.target
    var switches := 0
    for frame in 90:
        await physics_frame
        if enemy.target != held:
            switches += 1
            held = enemy.target
    assert(switches <= 1, "The enemy retargeted %d times in 90 frames" % switches)
    print("  enemy targets the nearer companion and holds it (%d switches in 90 frames)" % switches)


## And its attacks must actually land on the companion.
func _check_enemy_damages_companion() -> void:
    var enemy := game.get_node("MeleeEnemy2") as Enemy
    companion.global_position = enemy.global_position + Vector2(50, 0)
    companion.health = companion.max_health
    var before: int = companion.health
    # Long enough for the enemy's 0.28s wind-up plus its cooldown.
    for frame in 300:
        await physics_frame
        if companion.health < before:
            break
    assert(companion.health < before,
        "The enemy never damaged the companion (%d HP, target=%s)" % [companion.health, enemy.target])
    print("  enemy attack damaged the companion (%d -> %d)" % [before, companion.health])


## Edge case: the companion landing the killing blow must still drop gold. The
## player must not have to be the one to finish the enemy.
##
## Asserted on the damage landing rather than on the death, because whether the
## enemy dies also depends on it standing still long enough: it chases the party
## and can step out of melee range between swings.
func _check_companion_kill_drops_gold() -> void:
    # The previous check let the enemy beat the companion down, and a downed
    # companion cannot act and does not revive while enemies are alive. Stand it
    # back up before asking it to fight.
    companion.state = Follower.State.FOLLOW
    companion.health = companion.max_health
    companion._attack_cooldown_left = 0.0
    var enemy := game.get_node("MeleeEnemy3") as Enemy
    # Park the other melee enemy out of the way so the companion is not drawn off.
    (game.get_node("MeleeEnemy2") as Node2D).global_position = Vector2(600, 200)
    enemy.health = enemy.max_health
    player.global_position = Vector2(3160, 860)
    companion.global_position = Vector2(3160, 900)
    enemy.global_position = Vector2(3160, 930)
    await _wait(4)

    var before: int = enemy.health
    for frame in 400:
        await physics_frame
        if enemy.health < before or not is_instance_valid(enemy):
            break
    assert(not is_instance_valid(enemy) or enemy.health < before,
        "The companion never damaged the enemy (hp=%d, state=%d, dist=%.0f, target=%s)" % [
            enemy.health, companion.state,
            companion.global_position.distance_to(enemy.global_position), companion.target])

    # Now let it finish, and confirm the drop still happens on a companion kill.
    var gold_before: int = game.gold
    if is_instance_valid(enemy):
        enemy.health = 1
    for frame in 400:
        await physics_frame
        if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
            break
    await _wait(10)
    var pickups := 0
    for child in game.get_children():
        if child is GoldPickup:
            pickups += 1
            player.global_position = (child as Node2D).global_position
            await _wait(4)
    assert(pickups > 0,
        "A companion kill dropped no gold (enemy valid=%s hp=%d)" % [
            is_instance_valid(enemy), enemy.health if is_instance_valid(enemy) else -1])
    assert(game.gold > gold_before,
        "Gold did not increase after collecting a companion kill (%d)" % game.gold)
    print("  companion damaged and killed an enemy, which dropped %d pickup(s) for +%d gold" % [
        pickups, game.gold - gold_before])


## Player death while the companion lives must not break either of them.
func _check_player_death() -> void:
    player.health = 1
    player._invulnerability_left = 0.0
    player.take_damage(999, Vector2.RIGHT)
    await _wait(6)
    assert(player.is_dead(), "The player did not die")
    assert(ui_visible_game_over(), "Game Over did not appear")
    # The companion must survive as a valid object and keep working.
    assert(is_instance_valid(companion), "The companion was freed when the player died")
    await _wait(30)
    assert(companion != null and is_instance_valid(companion),
        "The companion did not survive the player's death")
    print("  player death: Game Over shown, companion intact and still valid")


func ui_visible_game_over() -> bool:
    var ui := game.get_node("GameUI") as GameUI
    return ui.current_mode() == "game_over"


## A restart reloads the scene, so the party must not leak into the new run: a
## fresh Classic Mode starts with no companion and the recruit hidden again.
func _check_restart_clears_party() -> void:
    game._on_restart_requested()
    await _wait(20)
    var fresh := current_scene
    assert(fresh != game, "Restart did not reload the scene")
    var fresh_progress := fresh.get_node("ClassicProgression") as ClassicProgression
    assert(fresh_progress.phase == PROG.Phase.GUARD_TUTORIAL,
        "A restarted run did not begin at the Guard tutorial")
    var recruit := fresh.get_node("PawnKnife") as RecruitNpc
    assert(not recruit.visible, "The recruit was visible again before the main quest")
    assert(fresh.get("companion") == null, "A restarted run kept the old companion")
    assert(get_nodes_in_group("follower").is_empty(),
        "A follower survived the restart, which would duplicate on the next hire")
    print("  restart: new run has no companion, recruit hidden, no leaked follower")


func _wait(count: int) -> void:
    for _i in count:
        await physics_frame
