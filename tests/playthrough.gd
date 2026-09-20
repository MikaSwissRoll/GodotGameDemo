extends SceneTree

const INPUT_SETUP := preload("res://scripts/systems/input_setup.gd")

var game: Node2D
var player: Player
var quest: QuestManager
var guard: VillageGuard

## Measured route from the village to the eastern camp.
##
## A straight line does not work here and is not supposed to: the terrain is
## designed to block it. Measured by probing eastbound lanes with move_and_collide
## and then walking each leg:
##
##   - moving east from the guard, the village houses stop the player near x=1630
##     on the enemy lane (y~800) and near x=1470 on y~700..750
##   - the river bank stops it near x=2286 on the y=900..1000 lanes
##   - only the y~850 lane runs clear from the village through to the camp, and
##     the bridge deck spans y 704..896 at x 2280..2608, so it crosses on that lane
##   - the enemies start at x=2760 and chase, reaching the bridge's east end, so
##     the route stops at x=2500, on the deck. Walking even 150px further gets the
##     player killed before any fight starts.
##
## If the layout changes again, re-measure rather than editing these by eye.
const CAMP_ROUTE: Array[Vector2] = [
    Vector2(1560, 850),   # step off the guard's lane into the clear lane
    Vector2(2200, 850),   # run east past the village frontage
    Vector2(2500, 850),   # stop on the bridge deck, short of the enemy camp
]
## The crossing reversed, then a staging point west of the guard: the guard ends
## the route with a tight tolerance, and approaching on the same lane keeps the
## last leg a straight walk.
const RETURN_ROUTE: Array[Vector2] = [
    Vector2(2200, 850),
    Vector2(1560, 850),
    Vector2(1470, 940),
]


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

    # Cross the bridge only. The enemies chase the player, so the route must not
    # try to walk deep into the camp: _walk_to presses toward a fixed point and
    # will keep pushing against a blocking enemy while taking hits, which killed
    # the player before any fight began. _fight() owns closing the distance.
    if not await _walk_route(CAMP_ROUTE, "Could not cross to the east bank"):
        return

    for enemy_name in ["MeleeEnemy1", "MeleeEnemy2", "MeleeEnemy3", "MeleeEnemy4", "MeleeEnemy5"]:
        var enemy := game.get_node(enemy_name) as Enemy
        # Stay in the clear bridge lane rather than trailing a chasing enemy into
        # whatever terrain it happens to stand on.
        if player.global_position.distance_to(enemy.global_position) > 420.0:
            if not await _walk_to(Vector2(2300, 850), 400):
                _fail("Could not return to the bridge lane before fighting %s" % enemy_name)
                return
        if not await _fight(enemy, 1800):
            _fail("Could not defeat %s; player at %s, enemy at %s, HP=%d stamina=%.1f enemyHP=%.1f" % [
                enemy_name, player.global_position, enemy.global_position,
                player.health, player.stamina, enemy.health])
            return
        var coin := _nearest_gold(enemy.global_position)
        if coin != null:
            if not await _walk_to(coin.global_position, 180):
                _fail("Could not collect gold from %s; player at %s, coin at %s" % [
                    enemy_name, player.global_position, coin.global_position])
                return
        print("PLAYTHROUGH: ", enemy_name, " defeated; HP=", player.health,
            " enemies=", quest.bandits_defeated, " gold=", quest.gold_collected)

    if quest.state != QuestManager.QuestState.READY_TO_TURN_IN:
        _fail("Quest did not become ready")
        return
    var home_route: Array[Vector2] = RETURN_ROUTE.duplicate()
    home_route.append(guard.global_position + Vector2(-38, 0))
    if not await _walk_route(home_route, "Could not return to the Guard"):
        return
    _talk()
    if quest.state != QuestManager.QuestState.COMPLETED:
        _fail("Quest did not complete on return")
        return
    print("PLAYTHROUGH PASS: walked the route, fought five raiders, picked up gold, and returned to Guard; HP=", player.health)
    quit(0)


## Walk a list of waypoints in order. Used where the terrain makes a straight line
## impossible: the village houses block the direct east exit and the river bank
## blocks everything except the bridge lane, so the route has to be stated rather
## than assumed. See docs/SCENE_WORKFLOW.md.
func _walk_route(route: Array[Vector2], failure: String) -> bool:
    var index := 0
    for point in route:
        index += 1
        # Waypoints only need to be reached closely enough to line up the next leg;
        # too tight a tolerance stalls the walk a pixel or two short, which reads
        # as being stuck rather than as a route problem.
        if not await _walk_to(point, 700, 20.0):
            _fail("%s (leg %d/%d to %s; player at %s)" % [
                failure, index, route.size(), point, player.global_position])
            return false
    return true


func _walk_to(destination: Vector2, max_frames: int, tolerance: float = 30.0) -> bool:
    for frame_index in max_frames:
        if player.is_dead():
            _release_actions()
            _fail("Player died while walking to %s" % destination)
            return false
        var delta := destination - player.global_position
        if delta.length() < tolerance:
            _release_actions()
            await physics_frame
            return true
        _set_movement(delta)
        await physics_frame
    _release_actions()
    return false


func _fight(enemy: Enemy, max_frames: int) -> bool:
    ## Swings only while it can still afford a second one. Spending the bar to
    ## empty is what triggers a guard break, and a broken guard cannot block, so
    ## an aggressive loop now loses the fight it used to win. Holding a reserve is
    ## what a competent player does once stamina gates attacks.
    var reserve := player.get_attack_cost() * 2.0
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
        var may_swing := player.stamina >= reserve
        if player._attacking:
            _set_movement(Vector2.ZERO)
        elif toward.length() > 76.0:
            # Back off while spent, so incoming blows land on a raised shield
            # rather than on a player with nothing left to block with.
            _set_movement(toward if may_swing else -toward)
        else:
            _set_movement(Vector2.ZERO)
        if toward.length() < 100.0 and may_swing and player._attack_cooldown_left <= 0.0 \
                and not player._attacking and not released_attack:
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
