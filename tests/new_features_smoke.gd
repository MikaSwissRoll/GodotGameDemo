extends SceneTree


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    create_timer(12.0).timeout.connect(_on_timeout)
    var game := (load("res://scenes/main/game.tscn") as PackedScene).instantiate() as Node2D
    root.add_child(game)
    current_scene = game
    var player := game.get_node("Player") as Player
    var ui := game.get_node("GameUI") as GameUI
    var merchant := game.get_node("Merchant") as Area2D
    ui.start_requested.emit()

    assert(InputMap.has_action("guard"), "Right-click guard action is missing")
    assert(InputMap.has_action("use_health_potion") and InputMap.has_action("use_stamina_potion"), "Potion actions are missing")
    assert(ui.health_label.text.contains("生命") and ui.gold_label.text.contains("金币"), "HUD was not translated")

    player._change_stamina(50.0 - player.stamina)
    var held_stamina := player.stamina
    Input.action_press("guard")
    for frame_index in 12:
        await physics_frame
    assert(player.guarding, "Holding guard did not raise the shield")
    assert(is_equal_approx(player.stamina, held_stamina), "Holding guard spent stamina without blocking")
    var health_before := player.health
    player.facing = Vector2.RIGHT
    player.take_damage(12, Vector2.LEFT)
    assert(player.health == health_before, "Front attack was not blocked")
    assert(is_equal_approx(player.stamina, held_stamina - player.guard_block_cost), "Successful block spent the wrong stamina")
    var wide_arc_stamina := player.stamina
    var side_rear_incoming := Vector2.from_angle(deg_to_rad(110.0))
    player.take_damage(12, -side_rear_incoming)
    assert(player.health == health_before, "Attack inside the 240-degree guard arc was not blocked")
    assert(is_equal_approx(player.stamina, wide_arc_stamina - player.guard_block_cost), "Wide-arc block spent the wrong stamina")
    var after_block := player.stamina
    player.take_damage(12, Vector2.RIGHT)
    assert(player.health == health_before - 12, "Direct rear attack was blocked")
    assert(is_equal_approx(player.stamina, after_block), "Unblocked hit spent stamina")
    Input.action_release("guard")
    await physics_frame
    assert(not player.guarding, "Releasing guard did not lower the shield")

    player._change_stamina(-player.stamina)
    Input.action_press("attack")
    await physics_frame
    await physics_frame
    Input.action_release("attack")
    assert(not player._attacking, "Attack started without stamina")
    var empty_stamina := player.stamina
    # A refused action does not itself hold regeneration, but the successful blocks
    # above did, and that hold is still running. Assert the hold suppresses regen
    # while it lasts, then that regen resumes once it clears. The loop tests the
    # hold rather than counting frames, so the boundary frame cannot be missed.
    var guard_frames := 0
    while player._regen_hold_left > 0.0 and guard_frames < 120:
        assert(is_equal_approx(player.stamina, empty_stamina),
            "Stamina regenerated while the post-action hold was still running")
        await physics_frame
        guard_frames += 1
    assert(guard_frames < 120, "the post-action hold never cleared")
    for frame_index in 20:
        await physics_frame
    assert(player.stamina > empty_stamina, "Stamina did not regenerate after the hold")
    player._change_stamina(player.max_stamina)
    var before_attack := player.stamina
    Input.action_press("attack")
    await physics_frame
    await physics_frame
    Input.action_release("attack")
    assert(player._attacking and player.stamina < before_attack - 10.0, "Attack did not spend stamina")
    for frame_index in 28:
        await physics_frame
    var before_dash := player.stamina
    Input.action_press("dash")
    await physics_frame
    await physics_frame
    Input.action_release("dash")
    assert(player._dash_left > 0.0 and player.stamina < before_dash - 20.0, "Dash did not spend stamina")
    for frame_index in 16:
        await physics_frame

    player._change_stamina(50.0 - player.stamina)
    var baseline_start := player.stamina
    for frame_index in 10:
        await physics_frame
    var baseline_gain := player.stamina - baseline_start
    player._change_stamina(50.0 - player.stamina)
    player.apply_stamina_boost(0.5, 2.0)
    var boosted_start := player.stamina
    for frame_index in 10:
        await physics_frame
    assert(player.stamina - boosted_start > baseline_gain * 1.5, "Stamina potion did not accelerate regeneration")
    for frame_index in 35:
        await physics_frame
    assert(player.stamina_boost_left == 0.0 and player.stamina_boost_multiplier == 1.0, "Stamina boost did not expire")

    game.set("gold", 6)
    ui.set_gold(6)
    player.global_position = merchant.global_position + Vector2(-35, 0)
    await physics_frame
    await physics_frame
    assert(merchant.get("player_nearby"), "Merchant proximity was not detected")
    var interact := InputEventAction.new()
    interact.action = "interact"
    interact.pressed = true
    merchant.call("_unhandled_input", interact)
    assert(paused and ui._mode == "shop" and ui.overlay_title.text == "村庄商人", "Merchant shop did not open")
    ui.buy_health_requested.emit()
    ui.buy_stamina_requested.emit()
    assert(game.get("gold") == 0 and game.get("health_potions") == 1 and game.get("stamina_potions") == 1, "Potion purchase or gold deduction failed")
    ui.buy_health_requested.emit()
    assert(game.get("health_potions") == 1, "Insufficient gold still allowed purchase")
    ui.shop_closed.emit()
    assert(not paused and ui._mode == "", "Closing shop did not resume game")

    player.health = 20
    player.health_changed.emit(player.health, player.max_health)
    var health_event := InputEventAction.new()
    health_event.action = "use_health_potion"
    health_event.pressed = true
    game._unhandled_input(health_event)
    assert(player.health == 80 and game.get("health_potions") == 0, "Health potion did not restore 60 health and consume")
    var stamina_event := InputEventAction.new()
    stamina_event.action = "use_stamina_potion"
    stamina_event.pressed = true
    game._unhandled_input(stamina_event)
    assert(player.stamina_boost_left > 0.0 and game.get("stamina_potions") == 0, "Stamina potion did not apply and consume")
    print("FEATURES PASS: guard, directional block, stamina costs and recovery, merchant purchases, potions, Chinese HUD")
    quit(0)


func _on_timeout() -> void:
    push_error("Feature test timed out")
    quit(1)




