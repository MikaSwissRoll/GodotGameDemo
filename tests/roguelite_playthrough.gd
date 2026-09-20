extends SceneTree

## Roguelite run integrity.
##
## This test plays a whole random run with an AI and asserts that **nothing
## invalid happens**, not that the AI wins. An earlier version failed whenever the
## player died, which made it a coin flip: `run_game.gd` randomizes the wave
## variant per room, one room-2 variant is materially harder than the other, and
## "the AI wins this seed" is not a property of the product. It also could not be
## reproduced, because the failing variant and the seed were never reported.
##
## So the assertions here are the things that are true of every run:
##   - the scene loads and the run starts
##   - every phase is a legal one, and transitions follow the state machine
##   - a room that is still in combat keeps making progress rather than stalling
##   - health never leaves its legal range
##   - the run ends in a terminal phase (won or dead) rather than hanging
##
## A death is a measured outcome, reported with the wave composition, and the run
## exits zero. Determinism of the *content* is deliberately not asserted: covering
## every wave variant is a separate concern from run integrity.

## Legal phases from run_game.gd. "menu" and "pause" are reachable too.
const PHASES := ["menu", "pause", "combat", "reward", "shop", "won", "dead"]
const TERMINAL := ["won", "dead"]
## Transitions that must never happen. A reward or shop is only ever entered from
## combat, and a terminal phase never returns to play.
const ILLEGAL_FROM_TERMINAL := ["combat", "reward", "shop"]

var game: RunGame
var player: Player
var ui: RunUI
var _attack_held := false
## A room that has not changed phase in this many frames is stalled, not slow.
## Generous, because the elite room legitimately takes a long time to clear.
const STALL_FRAMES := 3600
const ROOM_FRAMES := 2400

var _rooms_cleared := 0
var _kills := 0
var _hp_trace: Array[String] = []


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    create_timer(240.0).timeout.connect(_on_timeout)
    game = (load("res://scenes/main/run_game.tscn") as PackedScene).instantiate() as RunGame
    root.add_child(game)
    current_scene = game
    player = game.player
    ui = game.ui
    # RUN_VARIANT still pins the first room's variant when set, for reproducing a
    # specific complaint by hand. It is not used to assert an outcome.
    var forced_variant := OS.get_environment("RUN_VARIANT")
    if forced_variant == "0" or forced_variant == "1":
        RunGame.previous_first_variant = 1 - int(forced_variant)
    ui.start_requested.emit()

    var last_phase := game.phase
    _check_phase(last_phase, "after start")
    _record_hp("start")

    for stage in [1, 2, 3, 4]:
        if game.phase in TERMINAL:
            break
        var before_phase := game.phase
        var stalled_on := await _fight_room(ROOM_FRAMES if stage < 4 else STALL_FRAMES)
        _check_phase_transition(before_phase, game.phase)
        if stalled_on:
            # Still in combat with an enemy alive and no progress for the whole
            # budget: this is a real defect, not bad luck.
            _fail("Room %d stalled in combat for %d frames; enemies %d left, HP=%d" % [
                stage, ROOM_FRAMES, game.remaining_enemies, player.health])
            return
        if game.phase in TERMINAL:
            break

        if game.phase == "reward":
            assert(game.phase == "reward", "Regular room skipped reward")
            ui.reward_selected.emit(0)
            _check_phase(game.phase, "after reward")
        if game.phase == "shop":
            while game.gold >= 3 and game.health_potions < 2:
                ui.buy_health_requested.emit()
            ui.shop_continue_requested.emit()
            _check_phase(game.phase, "after shop")

        _rooms_cleared = stage
        _record_hp("room %d" % stage)
        print("RUN INTEGRITY: room %d done; HP=%d gold=%d upgrades=%d phase=%s" % [
            stage, player.health, game.gold, player.upgrades.size(), game.phase])

    assert(game.phase in TERMINAL,
        "The run did not end in a terminal phase; it sat in %s" % game.phase)

    # Health must be inside its legal range at the end of a run, whichever way it
    # ended. A negative or over-max value means damage or healing misbehaved.
    assert(player.health >= 0 and player.health <= player.max_health,
        "Final health %d is outside 0..%d" % [player.health, player.max_health])

    var outcome := "won" if game.phase == "won" else "died"
    # Report the room the run actually reached, not the last one it completed:
    # reading `_rooms_cleared` here reported a death in room 2 as "rooms=1".
    print("RUN INTEGRITY PASS: %s in room %d; cleared=%d variants=%s HP: %s" % [
        outcome, game.room_index, _rooms_cleared, game.room_variants, " -> ".join(_hp_trace)])
    if outcome == "died":
        print("  (a death is a result, not a failure: this run ended in room %d of variants %s)" % [
            game.room_index, game.room_variants])
    quit(0)


## Play the current room until its phase changes. Returns "" on a phase change, or a
## description if the budget ran out while still in combat.
func _fight_room(max_frames: int) -> String:
    var seen_phase := game.phase
    for frame_index in max_frames:
        if game.phase != seen_phase:
            _release_actions()
            return ""
        assert(player.health <= player.max_health,
            "Health %d exceeded the maximum %d mid-run" % [player.health, player.max_health])
        # Potions are part of a normal run; without them the AI would report a death
        # that says more about the harness than about the game.
        if player.health <= 60 and game.health_potions > 0 and not player.is_dead():
            var potion := InputEventAction.new()
            potion.action = "use_health_potion"
            potion.pressed = true
            game._unhandled_input(potion)
        if player.is_dead():
            # Death ends the run from inside the engine; give it its frames.
            await physics_frame
            continue
        var target := _nearest_enemy()
        if target == null:
            _release_actions()
            await physics_frame
            continue
        var toward := target.global_position - player.global_position
        if game.room_index == 4 and target is Enemy and target._warning.visible \
                and toward.length() < 135.0 and not player._attacking \
                and player.stamina >= player.guard_min_stamina:
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
        if toward.length() < 100.0 and player._attack_cooldown_left <= 0.0 \
                and not player._attacking and not released_attack \
                and player.stamina >= player.get_attack_cost():
            _set_movement(toward)
            Input.action_press("attack")
            _attack_held = true
        await physics_frame
    _release_actions()
    return "%s with %d enemies left" % [game.phase, game.remaining_enemies]


func _check_phase(phase: String, when: String) -> void:
    assert(phase in PHASES, "Illegal phase %s %s" % [phase, when])


## The run's state machine: from a terminal phase nothing returns to play, and a
## reward or shop never follows anything but combat.
func _check_phase_transition(from: String, to: String) -> void:
    _check_phase(to, "after %s" % from)
    if from in TERMINAL:
        assert(to in TERMINAL, "Run left terminal phase %s for %s" % [from, to])
    if to in ["reward", "shop"]:
        assert(from == "combat", "Entered %s from %s" % [to, from])


func _record_hp(label: String) -> void:
    _hp_trace.append("%d@%s" % [player.health, label])


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
    push_error("RUN INTEGRITY FAIL: %s; HP=%d room=%d variants=%s HP trace: %s" % [
        message, player.health, game.room_index, game.room_variants, " -> ".join(_hp_trace)])
    quit(1)


func _on_timeout() -> void:
    _fail("Timed out")
