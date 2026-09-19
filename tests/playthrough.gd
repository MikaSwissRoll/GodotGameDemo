extends SceneTree

const INPUT_SETUP := preload("res://scripts/systems/input_setup.gd")

var game: Node2D
var player: Player
var quest: QuestManager
var guard: VillageGuard


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    create_timer(150.0).timeout.connect(_on_timeout)
    INPUT_SETUP.ensure_actions()
    game = (load("res://scenes/main/game.tscn") as PackedScene).instantiate() as Node2D
    root.add_child(game)
    current_scene = game
    player = game.get_node("Player") as Player
    quest = game.get_node("QuestManager") as QuestManager
    guard = game.get_node("VillageGuard") as VillageGuard
    (game.get_node("GameUI") as GameUI).start_requested.emit()

    if not await _walk_to(guard.global_position + Vector2(-38, 0), 250):
        _fail("Could not reach the Guard")
        return
    _talk()
    if quest.state != QuestManager.QuestState.ACTIVE:
        _fail("Quest did not start")
        return

    for enemy_name in ["MeleeEnemy1", "MeleeEnemy2", "MeleeEnemy3", "MeleeEnemy4", "MeleeEnemy5"]:
        if enemy_name == "MeleeEnemy3":
            if not await _walk_to(Vector2(2250, 800), 600):
                _fail("Could not reach bridge west bank")
                return
            if not await _walk_to(Vector2(2630, 800), 300):
                _fail("Could not cross bridge")
                return
        var enemy := game.get_node(enemy_name) as Enemy
        if not await _fight(enemy, 800):
            _fail("Could not defeat " + enemy_name)
            return
        var coin := _nearest_gold(enemy.global_position)
        if coin != null:
            if not await _walk_to(coin.global_position, 180):
                _fail("Could not collect gold from " + enemy_name)
                return
        print("PLAYTHROUGH: ", enemy_name, " defeated; HP=", player.health,
            " enemies=", quest.bandits_defeated, " gold=", quest.gold_collected)

    if quest.state != QuestManager.QuestState.READY_TO_TURN_IN:
        _fail("Quest did not become ready")
        return
    if not await _walk_to(Vector2(2630, 800), 900):
        _fail("Could not reach bridge east bank")
        return
    if not await _walk_to(Vector2(2250, 800), 300):
        _fail("Could not cross bridge on return")
        return
    if not await _walk_to(guard.global_position + Vector2(-38, 0), 1100):
        _fail("Could not return to the Guard")
        return
    _talk()
    if quest.state != QuestManager.QuestState.COMPLETED:
        _fail("Quest did not complete on return")
        return
    print("PLAYTHROUGH PASS: walked the route, fought five raiders, picked up gold, and returned to Guard; HP=", player.health)
    quit(0)


func _walk_to(destination: Vector2, max_frames: int) -> bool:
    for frame_index in max_frames:
        if player.is_dead():
            _release_actions()
            return false
        var delta := destination - player.global_position
        if delta.length() < 28.0:
            _release_actions()
            await physics_frame
            return true
        _set_movement(delta)
        await physics_frame
    _release_actions()
    return false


func _fight(enemy: Enemy, max_frames: int) -> bool:
    var attack_held := false
    for frame_index in max_frames:
        if player.is_dead():
            _release_actions()
            return false
        if not is_instance_valid(enemy) or enemy.health <= 0:
            _release_actions()
            await physics_frame
            return true
        var toward := enemy.global_position - player.global_position
        var released_attack := false
        if attack_held:
            Input.action_release("attack")
            attack_held = false
            released_attack = true
        if player._attacking:
            _set_movement(Vector2.ZERO)
        elif toward.length() > 76.0:
            _set_movement(toward)
        else:
            _set_movement(Vector2.ZERO)
        if toward.length() < 100.0 and player._attack_cooldown_left <= 0.0 and not player._attacking and not released_attack:
            _set_movement(toward)
            Input.action_press("attack")
            attack_held = true
        await physics_frame
    _release_actions()
    return false

func _nearest_gold(point: Vector2) -> GoldPickup:
    var closest: GoldPickup
    var best_distance := INF
    for child in game.get_children():
        if child is GoldPickup:
            var candidate := child as GoldPickup
            var distance := point.distance_to(candidate.global_position)
            if distance < best_distance:
                best_distance = distance
                closest = candidate
    return closest


func _talk() -> void:
    var event := InputEventAction.new()
    event.action = "interact"
    event.pressed = true
    guard._unhandled_input(event)


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
    Input.action_release("dash")


func _fail(message: String) -> void:
    _release_actions()
    push_error("PLAYTHROUGH FAIL: " + message + "; HP=" + str(player.health))
    quit(1)


func _on_timeout() -> void:
    _fail("Timed out")
