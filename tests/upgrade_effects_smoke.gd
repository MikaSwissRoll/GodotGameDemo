extends SceneTree


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    create_timer(12.0).timeout.connect(_on_timeout)
    var game := (load("res://scenes/main/run_game.tscn") as PackedScene).instantiate() as RunGame
    root.add_child(game)
    current_scene = game
    var player := game.player
    game.ui.start_requested.emit()
    player.add_upgrade("iron_guard")
    player.add_upgrade("shield_counter")
    player.facing = Vector2.RIGHT
    Input.action_press("guard")
    await physics_frame
    await physics_frame
    player._invulnerability_left = 0.0
    var before_block := player.stamina
    player.take_damage(12, Vector2.LEFT)
    assert(player.health == player.max_health and player.counter_ready, "Shield counter did not arm")
    assert(is_equal_approx(player.stamina, before_block - 4.0), "Iron guard did not reduce block cost to four")
    Input.action_release("guard")
    await physics_frame
    await physics_frame

    var first: Enemy
    for candidate in get_nodes_in_group("run_enemy"):
        if candidate is Enemy:
            first = candidate
            break
    assert(first != null, "First room has no melee enemy")
    first.move_speed = 0.0
    player.add_upgrade("heavy_blade")
    assert(player.get_attack_cost() == 30.0, "Heavy blade did not raise attack cost")
    player.global_position = first.global_position + Vector2(-72, 0)
    player.facing = Vector2.RIGHT
    var enemy_health := first.health
    Input.action_press("attack")
    await physics_frame
    await physics_frame
    Input.action_release("attack")
    for frame_index in 18:
        await physics_frame
    assert(first.health <= enemy_health - 65, "Shield counter and heavy blade did not boost hit")
    assert(not player.counter_ready, "Shield counter was not consumed")
    player.add_upgrade("kill_flow")
    player._change_stamina(40.0 - player.stamina)
    var before_kill := player.stamina
    first.take_damage(999, Vector2.RIGHT)
    assert(player.stamina >= before_kill + 18.0, "Kill flow did not restore stamina")

    for frame_index in 18:
        await physics_frame
    player.add_upgrade("swift_step")
    assert(player.get_dash_cost() == 20.0, "Swift step did not reduce dash cost")
    player.global_position = Vector2(220, 500)
    player.restore_stamina()
    player._dash_cooldown_left = 0.0
    Input.action_press("move_right")
    Input.action_press("dash")
    await physics_frame
    await physics_frame
    Input.action_release("dash")
    Input.action_release("move_right")
    assert(player.stamina <= 80.1 and player._dash_cooldown_left <= 0.75 and player._dash_left > 0.0, "Swift step dash did not spend or cool down correctly")
    for frame_index in 15:
        await physics_frame

    var second: Node2D
    for candidate in get_nodes_in_group("run_enemy"):
        if is_instance_valid(candidate) and candidate.get("health") > 0:
            second = candidate
            break
    assert(second != null, "No target for dash cleave")
    second.set("move_speed", 0.0)
    player.add_upgrade("dash_cleave")
    player.restore_stamina()
    player._dash_cooldown_left = 0.0
    player.global_position = second.global_position + Vector2(-100, 0)
    player.facing = Vector2.RIGHT
    var before_cleave: int = second.get("health")
    Input.action_press("move_right")
    Input.action_press("dash")
    await physics_frame
    await physics_frame
    Input.action_release("dash")
    for frame_index in 12:
        await physics_frame
    Input.action_release("move_right")
    assert(second.get("health") < before_cleave, "Dash cleave did not damage the crossed enemy")
    print("UPGRADES PASS: counter, guard efficiency, heavy attack, kill refund, swift dash, dash cleave")
    quit(0)


func _on_timeout() -> void:
    push_error("Upgrade effect test timed out")
    quit(1)





