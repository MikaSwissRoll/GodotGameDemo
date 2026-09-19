extends SceneTree


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    print("SMOKE: loading game")
    create_timer(12.0).timeout.connect(_on_timeout)
    var packed := load("res://scenes/main/game.tscn") as PackedScene
    var game := packed.instantiate() as Node2D
    root.add_child(game)
    current_scene = game
    var player := game.get_node("Player") as Player
    var quest := game.get_node("QuestManager") as QuestManager
    var ui := game.get_node("GameUI") as GameUI
    var guard := game.get_node("VillageGuard") as VillageGuard
    assert(paused and ui._mode == "menu", "Main menu did not pause gameplay")

    ui.start_requested.emit()
    assert(not paused, "Start did not resume gameplay")
    var start := player.global_position
    Input.action_press("move_right")
    for frame_index in 12:
        await physics_frame
    Input.action_release("move_right")
    assert(player.global_position.x > start.x + 5.0, "Player did not move right")

    var dash_start := player.global_position
    Input.action_press("dash")
    for frame_index in 6:
        await physics_frame
    Input.action_release("dash")
    assert(player.global_position.x > dash_start.x + 20.0, "Dash did not move the player")
    assert(player._dash_cooldown_left > 0.0, "Dash cooldown did not start")

    var pause_event := InputEventAction.new()
    pause_event.action = "pause"
    pause_event.pressed = true
    game._unhandled_input(pause_event)
    assert(paused and ui._mode == "pause", "Pause did not stop gameplay")
    ui._unhandled_input(pause_event)
    assert(not paused, "Esc did not resume gameplay")

    for frame_index in 12:
        await physics_frame
    var first_enemy := game.get_node("MeleeEnemy1") as Enemy
    player.global_position = first_enemy.global_position + Vector2(-64.0, 0.0)
    player.facing = Vector2.RIGHT
    var initial_enemy_health := first_enemy.health
    Input.action_press("attack")
    await physics_frame
    Input.action_release("attack")
    for frame_index in 30:
        await physics_frame
    assert(first_enemy.health < initial_enemy_health, "Player attack did not damage enemy")

    player.global_position = Vector2(4300, 1020)
    player._invulnerability_left = 0.0
    player._knockback = Vector2.ZERO
    var initial_player_health := player.health
    for frame_index in 110:
        await physics_frame
    assert(player.health < initial_player_health, "Archer projectile did not damage player")

    player.global_position = guard.global_position + Vector2(-40, 0)
    await physics_frame
    await physics_frame
    assert(guard.player_nearby, "Guard proximity was not detected")
    var talk_event := InputEventAction.new()
    talk_event.action = "interact"
    talk_event.pressed = true
    guard._unhandled_input(talk_event)
    assert(quest.state == QuestManager.QuestState.ACTIVE, "Guard did not start quest")
    var bandits := get_nodes_in_group("bandits")
    assert(bandits.size() >= 5, "Too few bandits for the quest")
    for bandit in bandits:
        bandit.take_damage(999, Vector2.RIGHT)
    await process_frame
    await process_frame
    player._invulnerability_left = 100.0
    for child in game.get_children():
        if child is GoldPickup:
            player.global_position = child.global_position
            await physics_frame
            await physics_frame
    assert(quest.state == QuestManager.QuestState.READY_TO_TURN_IN, "Quest progress did not reach turn in")
    assert(game.gold >= 5, "Gold pickups were not counted")
    player.global_position = guard.global_position + Vector2(-40, 0)
    await physics_frame
    await physics_frame
    guard._unhandled_input(talk_event)
    assert(quest.state == QuestManager.QuestState.COMPLETED, "Guard did not complete quest")
    await create_timer(2.0).timeout
    assert(ui._mode == "complete" and paused, "Demo Complete did not appear")

    ui.resume_requested.emit()
    assert(not paused, "Continue Exploring did not resume gameplay")
    player._invulnerability_left = 0.0
    player.take_damage(999, Vector2.RIGHT)
    assert(ui._mode == "game_over" and paused, "Game Over did not appear")

    ui.restart_requested.emit()
    await process_frame
    await process_frame
    var fresh := current_scene
    assert(fresh != null and fresh != game, "Restart did not reload the scene")
    var fresh_ui := fresh.get_node("GameUI") as GameUI
    assert(fresh_ui._mode == "menu" and paused, "Restart did not return to the main menu")
    fresh_ui.start_requested.emit()
    fresh_ui.title_requested.emit()
    await process_frame
    await process_frame
    assert(current_scene != fresh, "Classic title action did not leave the classic scene")
    assert(current_scene.scene_file_path == "res://scenes/main/run_game.tscn",
        "Classic title action did not open the unified main menu")
    var run_ui := current_scene.get_node("RunUI")
    assert(paused and run_ui.mode == "menu",
        "Unified main menu was not visible and paused after leaving classic mode")

    print("SMOKE PASS: menu, movement, dash, pause, combat, archer, quest, gold, completion, death, restart, unified title")
    quit(0)


func _on_timeout() -> void:
    push_error('Smoke test timed out')
    quit(1)
