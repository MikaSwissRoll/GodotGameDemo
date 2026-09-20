extends SceneTree


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    create_timer(15.0).timeout.connect(_on_timeout)
    var packed := load("res://scenes/main/run_game.tscn") as PackedScene
    assert(packed != null, "Run scene failed to load")
    var game := packed.instantiate() as RunGame
    root.add_child(game)
    current_scene = game
    var player := game.get_node("Player") as Player
    var ui := game.get_node("RunUI") as RunUI
    assert(paused and game.phase == "menu", "Run title did not pause")
    ui.start_requested.emit()
    assert(not paused and game.room_index == 1 and game.remaining_enemies == 2, "First room did not begin")
    var first_variant: int = game.room_variants[0]

    player.facing = Vector2.RIGHT
    var start_position := player.global_position
    Input.action_press("guard")
    Input.action_press("move_left")
    await physics_frame
    await physics_frame
    assert(player.guarding and player.facing == Vector2.RIGHT, "Shield facing changed while strafing")
    assert(player.global_position.x < start_position.x, "Guard strafe did not move")
    Input.action_release("guard")
    Input.action_release("move_left")
    await physics_frame
    await physics_frame

    await _clear_room(game)
    assert(game.phase == "reward" and paused and ui.reward_options.size() == 3, "First reward did not offer three choices")
    ui.reward_selected.emit(0)
    assert(game.room_index == 2 and player.upgrades.size() == 1, "Second room or temporary upgrade failed")
    await _clear_room(game)
    assert(game.phase == "reward" and game.gold == 7, "Second reward or run gold failed")
    ui.reward_selected.emit(0)
    assert(game.phase == "shop" and paused, "Shop did not appear after second room")
    assert(game.shop_upgrade_id != "", "Shop has no run upgrade")
    ui.buy_upgrade_requested.emit()
    assert(game.gold == 2 and player.upgrades.size() == 3, "Shop upgrade purchase failed")
    ui.buy_upgrade_requested.emit()
    assert(game.gold == 2 and player.upgrades.size() == 3, "Shop upgrade was bought twice")

    game.gold = 6
    ui.set_gold(6)
    ui.buy_health_requested.emit()
    ui.buy_stamina_requested.emit()
    assert(game.gold == 0 and game.health_potions == 1 and game.stamina_potions == 1, "Shop potion exchange failed")
    ui.shop_continue_requested.emit()
    assert(not paused and game.room_index == 3 and game.phase == "combat", "Shop did not continue to room three")
    var potion_event := InputEventAction.new()
    potion_event.action = "use_stamina_potion"
    potion_event.pressed = true
    game._unhandled_input(potion_event)
    assert(game.stamina_potions == 0 and player.stamina_boost_left > 0.0, "Stamina potion did not apply")
    assert(ui.boost_label.visible and ui.boost_label.text.contains("精力恢复加速"), "Stamina boost timer did not appear")
    player.health = 20
    player.health_changed.emit(player.health, player.max_health)
    var health_event := InputEventAction.new()
    health_event.action = "use_health_potion"
    health_event.pressed = true
    game._unhandled_input(health_event)
    assert(player.health == 80 and game.health_potions == 0, "Run health potion did not restore 60 health")
    await _clear_room(game)
    assert(game.phase == "reward", "Third reward did not appear")
    ui.reward_selected.emit(0)
    assert(game.room_index == 4 and game.remaining_enemies == 1, "Elite room did not begin")
    var elite_found := false
    for foe in get_nodes_in_group("run_enemy"):
        if foe is Enemy and foe.elite:
            elite_found = true
            assert(foe.health == 190, "Elite health was not configured")
    assert(elite_found, "Elite enemy was not spawned")
    await _clear_room(game)
    assert(paused and game.phase == "won" and ui.mode == "win", "Win summary did not appear")

    ui.restart_requested.emit()
    await process_frame
    await process_frame
    var fresh := current_scene as RunGame
    assert(fresh != null and fresh != game and fresh.phase == "combat", "Quick restart did not start a new run")
    assert(fresh.player.upgrades.is_empty() and fresh.gold == 0, "Run upgrades or gold survived restart")
    assert(fresh.room_variants[0] != first_variant, "Consecutive runs repeated the opening encounter")
    fresh.player._invulnerability_left = 0.0
    fresh.player.take_damage(999, Vector2.RIGHT)
    assert(paused and fresh.phase == "dead" and fresh.ui.mode == "dead", "Death summary did not appear")
    fresh.ui.title_requested.emit()
    await process_frame
    await process_frame
    var title = current_scene
    assert(title.scene_file_path == "res://scenes/main/town_title.tscn" and title.phase == "menu" and paused,
        "Return to live town title failed")
    title.transition_seconds = 0.2
    title.menu.buttons[0].pressed.emit()
    await create_timer(0.4).timeout
    assert(title.game.has_node("QuestManager") and not paused, "Classic adventure is inaccessible")
    print("ROGUELITE PASS: guard strafe, rooms, rewards, shop, elite, win, reset, variation, death, classic entry")
    quit(0)


func _clear_room(game: RunGame) -> void:
    for attempt in 5:
        for foe in get_nodes_in_group("run_enemy"):
            if is_instance_valid(foe) and foe.get("health") > 0:
                foe.take_damage(999, Vector2.LEFT)
        await process_frame
        await process_frame
        if game.phase != "combat":
            return
        await create_timer(0.9).timeout


func _on_timeout() -> void:
    push_error("Roguelite smoke test timed out")
    quit(1)





