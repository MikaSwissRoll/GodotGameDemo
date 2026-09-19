extends SceneTree

var game: RunGame
var player: Player
var ui: RunUI
var _attack_held := false


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    create_timer(150.0).timeout.connect(_on_timeout)
    game = (load("res://scenes/main/run_game.tscn") as PackedScene).instantiate() as RunGame
    root.add_child(game)
    current_scene = game
    player = game.player
    ui = game.ui
    var forced_variant := OS.get_environment("RUN_VARIANT")
    if forced_variant == "0" or forced_variant == "1":
        RunGame.previous_first_variant = 1 - int(forced_variant)
    ui.start_requested.emit()

    for stage in [1, 2, 3]:
        if not await _fight_room(1500):
            _fail("Could not finish room %d" % stage)
            return
        assert(game.phase == "reward", "Regular room skipped reward")
        ui.reward_selected.emit(0)
        if stage == 2:
            assert(game.phase == "shop", "Shop was skipped")
            while game.gold >= 3 and game.health_potions < 2:
                ui.buy_health_requested.emit()
            ui.shop_continue_requested.emit()
        print("RUN PLAYTHROUGH: room ", stage, " complete; HP=", player.health,
            " gold=", game.gold, " upgrades=", player.upgrades.size())

    if not await _fight_room(2100):
        _fail("Could not defeat elite room")
        return
    assert(game.phase == "won" and paused, "Victory did not end the run")
    print("RUN PLAYTHROUGH PASS: player attacks cleared all rooms and elite; HP=", player.health)
    quit(0)


func _fight_room(max_frames: int) -> bool:
    for frame_index in max_frames:
        if player.is_dead():
            _release_actions()
            return false
        if player.health <= 60 and game.health_potions > 0:
            var potion := InputEventAction.new()
            potion.action = "use_health_potion"
            potion.pressed = true
            game._unhandled_input(potion)
        if game.phase != "combat":
            _release_actions()
            return game.phase == "reward" or game.phase == "won"
        var target := _nearest_enemy()
        if target == null:
            _release_actions()
            await physics_frame
            continue
        var toward := target.global_position - player.global_position
        if game.room_index == 4 and target is Enemy and target._warning.visible and toward.length() < 135.0 and not player._attacking and player.stamina >= player.guard_min_stamina:
            _release_actions()
            Input.action_press("guard")
            await physics_frame
            continue
        Input.action_release("guard")
        var released_attack := false
        if _attack_held:
            Input.action_release("attack")
            _attack_held = false
            released_attack = true
        if player._attacking:
            _set_movement(Vector2.ZERO)
        elif toward.length() > 76.0:
            _set_movement(toward)
        else:
            _set_movement(Vector2.ZERO)
        if toward.length() < 100.0 and player._attack_cooldown_left <= 0.0 and not player._attacking and not released_attack and player.stamina >= player.get_attack_cost():
            _set_movement(toward)
            Input.action_press("attack")
            _attack_held = true
        await physics_frame
    _release_actions()
    return false


func _nearest_enemy() -> Node2D:
    var closest: Node2D
    var best := INF
    for candidate in get_nodes_in_group("run_enemy"):
        if not is_instance_valid(candidate) or candidate.get("health") <= 0:
            continue
        var distance := player.global_position.distance_to(candidate.global_position)
        if distance < best:
            best = distance
            closest = candidate
    return closest


func _set_movement(direction: Vector2) -> void:
    for action in ["move_left", "move_right", "move_up", "move_down"]:
        Input.action_release(action)
    if direction.x > 10.0:
        Input.action_press("move_right")
    elif direction.x < -10.0:
        Input.action_press("move_left")
    if direction.y > 10.0:
        Input.action_press("move_down")
    elif direction.y < -10.0:
        Input.action_press("move_up")


func _release_actions() -> void:
    _set_movement(Vector2.ZERO)
    Input.action_release("attack")
    Input.action_release("guard")
    _attack_held = false


func _fail(message: String) -> void:
    _release_actions()
    push_error("RUN PLAYTHROUGH FAIL: " + message + "; HP=" + str(player.health) +
        " room=" + str(game.room_index) + " remaining=" + str(game.remaining_enemies))
    quit(1)


func _on_timeout() -> void:
    _fail("Timed out")





