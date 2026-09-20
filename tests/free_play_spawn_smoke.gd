extends SceneTree

## Free-play respawn contract for Classic Mode.
##
## The post-main loop must be sustainable without running away, so this checks the
## properties that matter rather than any particular timing: a hard active cap,
## enemies placed outside the village and never on top of the player, a group spawn
## rather than a trickle, and kills during free play not counting toward the main
## quest that is already finished.

const INPUT_SETUP := preload("res://scripts/systems/input_setup.gd")
const PROG := preload("res://scripts/systems/classic_progression.gd")

## Village extent: the starting area west of the river. Nothing may spawn here.
const VILLAGE := Rect2(0.0, 0.0, 2300.0, 1500.0)

var game: Node2D
var player: Player


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    create_timer(90.0).timeout.connect(func() -> void:
        push_error("free play spawn test timed out")
        quit(1))
    INPUT_SETUP.ensure_actions()
    game = (load("res://scenes/main/game.tscn") as PackedScene).instantiate() as Node2D
    root.add_child(game)
    current_scene = game
    player = game.get_node("Player") as Player
    (game.get_node("GameUI") as GameUI).start_requested.emit()
    await _wait(3)

    _check_idle_before_free_play()
    await _check_group_spawn_and_cap()
    await _check_delay_gates_respawn()
    _check_kills_do_not_count()

    print("FREE PLAY PASS: capped, spawned outside the village and clear of the player, delayed, uncounted")
    quit(0)


## Nothing spawns until the main quest is finished.
func _check_idle_before_free_play() -> void:
    assert(not game.is_free_play_active(), "Free play was active before the main quest")
    for frame in 120:
        await physics_frame
    assert(game.free_play_enemy_count() == 0,
        "Enemies spawned before free play began: %d" % game.free_play_enemy_count())
    print("  idle before the main quest: no respawns")


func _check_group_spawn_and_cap() -> void:
    game._on_main_quest_completed()
    await _wait(2)
    var spawned: int = game.free_play_enemy_count()
    assert(spawned >= 3 and spawned <= 6,
        "A respawn group was %d, expected 3..6" % spawned)

    # Group membership is what every consumer actually queries, and it is a separate
    # thing from the array the spawner keeps. Declaring `groups=["bandits"]` in
    # game.tscn only ever tagged the seven placed story enemies: instantiate() does
    # not carry a scene-declared group, so spawned enemies used to arrive with no
    # group at all and a companion had nothing it was allowed to target.
    for enemy in game._free_play_enemies:
        assert(enemy.is_in_group("bandits"),
            "A spawned enemy is not in the bandits group, so companions and target queries cannot see it")
    for node in get_nodes_in_group("bandits"):
        assert(node is Enemy or node is ArcherEnemy,
            "Something that is not an enemy is in the bandits group: %s" % node)

    # Placement: outside the village, and not on top of the player.
    for enemy in game._free_play_enemies:
        var at: Vector2 = enemy.global_position
        assert(not VILLAGE.has_point(at),
            "An enemy respawned inside the village at %s" % at)
        assert(at.distance_to(player.global_position) >= 320.0,
            "An enemy respawned %0.fpx from the player" % at.distance_to(player.global_position))

    # The cap holds even if the spawner is driven far beyond its delay. Each call
    # clears the timer, so this simulates the loop running for a long time.
    for attempt in 40:
        game._respawn_left = 0.0
        game._respawn_free_play_group()
    await _wait(4)
    var total: int = game.free_play_enemy_count()
    assert(total <= game.max_free_play_enemies,
        "The active count %d exceeded the cap %d" % [total, game.max_free_play_enemies])
    print("  group of %d spawned outside the village; cap %d held after 40 forced spawns" % [
        spawned, game.max_free_play_enemies])


## The delay is what stops a spawn per frame, so assert it actually gates.
func _check_delay_gates_respawn() -> void:
    # Clear the field, then confirm nothing appears until the timer runs out.
    for enemy in game._free_play_enemies.duplicate():
        if is_instance_valid(enemy):
            enemy.queue_free()
    await _wait(4)
    game._refresh_free_play_enemies()
    game._respawn_left = 1.0
    for frame in 40:
        await physics_frame
    assert(game.free_play_enemy_count() == 0,
        "Enemies spawned while the respawn delay was still running")

    # Let the real delay elapse and confirm a fresh group appears.
    var waited := 0.0
    while game.free_play_enemy_count() == 0 and waited < game.respawn_delay + 3.0:
        await physics_frame
        waited += 1.0 / 60.0
    assert(game.free_play_enemy_count() > 0,
        "No enemies respawned within %.0fs of the area being cleared" % (game.respawn_delay + 3.0))
    print("  respawn gated by the %.0fs delay, then a fresh group appeared" % game.respawn_delay)


## Edge case 12: a finished quest must not be advanced by free-play kills, and gold
## picked up in free play must not re-open it.
func _check_kills_do_not_count() -> void:
    var quest := game.get_node("QuestManager") as QuestManager
    # Finish the main quest through the real hand-in, so the state is genuinely
    # COMPLETED rather than assumed.
    quest.state = QuestManager.QuestState.READY_TO_TURN_IN
    (game.get_node("VillageGuard") as Node).interacted.emit()
    await _wait(3)
    assert(quest.state == QuestManager.QuestState.COMPLETED,
        "Setup: the main quest did not complete")
    var kills_before: int = quest.bandits_defeated
    var gold_before: int = quest.gold_collected
    var free_enemy: Node = null
    for enemy in game._free_play_enemies:
        if is_instance_valid(enemy):
            free_enemy = enemy
            break
    assert(free_enemy != null, "Setup: no free-play enemy to kill")
    game._on_enemy_defeated(free_enemy.global_position)
    game._on_gold_collected(1)
    await _wait(2)
    assert(quest.bandits_defeated == kills_before,
        "A free-play kill advanced the finished main quest")
    assert(quest.gold_collected == gold_before,
        "Free-play gold advanced the finished main quest")
    assert(quest.state == QuestManager.QuestState.COMPLETED,
        "The finished main quest changed state")
    print("  free-play kills and gold do not touch the finished main quest")


func _wait(count: int) -> void:
    for _i in count:
        await physics_frame
