extends SceneTree

## Classic Mode progression contract.
##
## Covers the four phases end to end without a human: order is enforced, every
## objective advances only on a real action, each reward is paid exactly once, the
## main quest keeps its own semantics, and completing it does NOT end the session.
##
## Drives the real signals and the real handlers, so a change to the quest logic or
## to the dialogue routing fails here rather than only in play.

const INPUT_SETUP := preload("res://scripts/systems/input_setup.gd")
const PROG := preload("res://scripts/systems/classic_progression.gd")

var game: Node2D
var player: Player
var quest: QuestManager
var progress: ClassicProgression
var ui: GameUI


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    create_timer(90.0).timeout.connect(func() -> void:
        push_error("classic progression test timed out")
        quit(1))
    INPUT_SETUP.ensure_actions()
    game = (load("res://scenes/main/game.tscn") as PackedScene).instantiate() as Node2D
    root.add_child(game)
    current_scene = game
    player = game.get_node("Player") as Player
    quest = game.get_node("QuestManager") as QuestManager
    progress = game.get_node("ClassicProgression") as ClassicProgression
    ui = game.get_node("GameUI") as GameUI
    var guard := game.get_node("VillageGuard")
    var merchant := game.get_node("Merchant")

    _check_starts_in_guard_tutorial()
    await _check_order_is_enforced(guard, merchant)
    await _check_guard_tutorial(guard)
    await _check_merchant_tutorial(guard, merchant)
    await _check_main_quest_unchanged()
    _check_health_potion_tutorial_rule()
    await _check_completion_does_not_end_session()

    print("CLASSIC PROGRESSION PASS: order enforced, real actions counted, one-shot rewards, free play reached")
    quit(0)


func _start() -> void:
    (game.get_node("GameUI") as GameUI).start_requested.emit()


func _check_starts_in_guard_tutorial() -> void:
    assert(progress.phase == PROG.Phase.GUARD_TUTORIAL,
        "A new game did not start in the Guard tutorial")
    assert(quest.state == QuestManager.QuestState.AVAILABLE,
        "The main quest was already running at the start")
    assert(ui.quest_label.text.contains("基础训练"),
        "The first objective is not the training quest: %s" % ui.quest_label.text)
    assert(game.gold == 0, "A new game did not start with no gold")
    print("  starts in the Guard tutorial, main quest unavailable, 0 gold")


## Talking to both NPCs out of order must not start a later quest.
func _check_order_is_enforced(guard: Node, merchant: Node) -> void:
    _start()
    await _wait(2)
    # Merchant first: he must not open the supply training.
    merchant.interacted.emit()
    await _wait(2)
    assert(progress.phase == PROG.Phase.GUARD_TUTORIAL,
        "The Merchant started a later phase before training finished")
    assert(not progress.merchant_briefed, "The Merchant briefed before training")
    assert(not progress.bought_health, "An early shop visit counted as a purchase")
    assert(ui.overlay_body.text.contains("先去把基础训练做完"),
        "The Merchant did not tell the player to train first: %s" % ui.overlay_body.text)
    game._on_shop_closed()
    await _wait(2)
    # Guard: briefs, but grants nothing yet.
    guard.interacted.emit()
    await _wait(2)
    assert(progress.guard_briefed, "The Guard did not brief the player")
    assert(game.gold == 0, "The Guard paid before training was done")
    assert(progress.phase == PROG.Phase.GUARD_TUTORIAL, "Training was skipped")
    print("  order enforced: early Merchant and Guard visits start nothing")


func _check_guard_tutorial(guard: Node) -> void:
    # Movement: three directions is not enough.
    player.moved.emit(Player.MoveDir.UP)
    player.moved.emit(Player.MoveDir.DOWN)
    player.moved.emit(Player.MoveDir.LEFT)
    await _wait(2)
    assert(not progress.guard_tutorial_done(), "Training completed on three directions")
    assert(ui.quest_label.text.contains("移动 3/4"),
        "The movement count is wrong: %s" % ui.quest_label.text)
    player.moved.emit(Player.MoveDir.RIGHT)
    await _wait(2)
    assert(ui.quest_label.text.contains("移动 4/4"),
        "Four directions did not register: %s" % ui.quest_label.text)

    # Attack, then guard: neither may be satisfied by the other.
    assert(not progress.guard_tutorial_done(), "Training completed without attacking")
    player.attack_started.emit()
    await _wait(2)
    assert(not progress.guard_tutorial_done(), "Training completed without guarding")
    player.guard_started.emit()
    await _wait(2)
    assert(progress.guard_tutorial_done(), "Training did not complete after all three steps")

    # The Guard pays once, and only now.
    guard.interacted.emit()
    await _wait(2)
    assert(game.gold == PROG.GUARD_REWARD,
        "The Guard reward was %d, expected %d" % [game.gold, PROG.GUARD_REWARD])
    assert(progress.phase == PROG.Phase.MERCHANT_TUTORIAL,
        "The phase did not advance to the Merchant tutorial")
    # Talking again must not pay twice.
    guard.interacted.emit()
    await _wait(2)
    assert(game.gold == PROG.GUARD_REWARD, "The Guard paid his reward twice")
    print("  guard tutorial: 4 directions + attack + guard, reward %d paid once" % game.gold)


func _check_merchant_tutorial(guard: Node, merchant: Node) -> void:
    assert(ui.quest_label.text.contains("准备补给"),
        "The objective did not move to the supply quest: %s" % ui.quest_label.text)

    # Buying is not using, and each kind is tracked separately.
    game.gold = 20
    game._on_buy_health_requested()
    await _wait(2)
    assert(progress.bought_health and not progress.bought_stamina,
        "Purchases are not tracked per kind")
    assert(not progress.merchant_tutorial_done(), "Buying alone completed the quest")
    game._on_buy_stamina_requested()
    await _wait(2)
    assert(not progress.merchant_tutorial_done(), "Buying alone completed the quest")

    # Using one kind is not using the other.
    game._use_health_potion()
    await _wait(2)
    assert(progress.used_health and not progress.used_stamina,
        "Uses are not tracked per kind")
    assert(not progress.merchant_tutorial_done(), "One potion use completed the quest")
    # The stamina potion must apply the real buff, not just tick a box.
    game._use_stamina_potion()
    await _wait(2)
    assert(player.stamina_boost_left > 0.0, "The stamina potion applied no buff")
    assert(progress.merchant_tutorial_done(), "The supply quest did not complete")

    # Hand in: reward once, and the phase moves on.
    var gold_before: int = game.gold
    merchant.interacted.emit()
    await _wait(2)
    assert(game.gold == gold_before + PROG.MERCHANT_REWARD,
        "The Merchant reward was not paid")
    assert(progress.phase == PROG.Phase.MAIN_QUEST,
        "The phase did not advance to the main quest")
    game._on_shop_closed()
    await _wait(2)
    merchant.interacted.emit()
    await _wait(2)
    assert(game.gold == gold_before + PROG.MERCHANT_REWARD,
        "The Merchant paid his reward twice")
    game._on_shop_closed()
    await _wait(2)
    print("  merchant tutorial: purchase and use tracked per kind, reward %d paid once" % PROG.MERCHANT_REWARD)


func _check_main_quest_unchanged() -> void:
    # The main quest still starts only by talking to the Guard, and keeps its own
    # counters and thresholds.
    var guard := game.get_node("VillageGuard")
    guard.interacted.emit()
    await _wait(2)
    assert(quest.state == QuestManager.QuestState.ACTIVE,
        "The main quest did not start from the Guard")
    assert(quest.required_bandits == 5 and quest.required_gold == 5,
        "The main quest thresholds changed")

    # Kills and gold only count while it is active, and the quest needs both. The
    # boundary is asserted on the counters rather than through a killed-enemy loop:
    # each kill drops gold via `call_deferred`, so waiting for the state would race
    # the pickup and prove nothing.
    for index in 5:
        game._on_enemy_defeated(player.global_position)
    await _wait(2)
    assert(quest.bandits_defeated == 5, "Kills did not count: %d" % quest.bandits_defeated)
    # One objective alone must not finish it. Drive the counters straight to the
    # kill threshold with no gold and confirm the state holds.
    quest.bandits_defeated = 5
    quest.gold_collected = 0
    quest.state = QuestManager.QuestState.ACTIVE
    quest._update_progress()
    assert(quest.state == QuestManager.QuestState.ACTIVE,
        "Five kills alone completed the quest; gold was not required")
    quest.bandits_defeated = 0
    quest.gold_collected = 5
    quest._update_progress()
    assert(quest.state == QuestManager.QuestState.ACTIVE,
        "Five gold alone completed the quest; kills were not required")
    # Both together, and it is ready.
    quest.bandits_defeated = 5
    quest.gold_collected = 5
    quest._update_progress()
    assert(quest.state == QuestManager.QuestState.READY_TO_TURN_IN,
        "The quest did not become ready with both objectives met")
    print("  main quest: needs 5 kills and 5 gold, thresholds untouched")


## A Health Potion at full health is refused in normal play but accepted during the
## supply tutorial, so the objective can be shown without the player being hurt.
func _check_health_potion_tutorial_rule() -> void:
    progress.phase = PROG.Phase.MERCHANT_TUTORIAL
    game.health_potions = 1
    player.health = player.max_health
    var used_before := progress.used_health
    game._use_health_potion()
    assert(game.health_potions == 0, "The tutorial did not consume the potion at full health")
    assert(progress.used_health, "The tutorial did not count the potion use")

    progress.phase = PROG.Phase.MAIN_QUEST
    game.health_potions = 1
    progress.used_health = used_before
    player.health = player.max_health
    game._use_health_potion()
    assert(game.health_potions == 1,
        "A Health Potion was consumed at full health outside the tutorial")
    print("  full-health potion: consumed during the tutorial only, refused otherwise")


func _check_completion_does_not_end_session() -> void:
    quest.state = QuestManager.QuestState.READY_TO_TURN_IN
    var guard := game.get_node("VillageGuard")
    guard.interacted.emit()
    await _wait(4)
    assert(quest.state == QuestManager.QuestState.COMPLETED, "The quest did not complete")
    assert(progress.phase == PROG.Phase.FREE_PLAY, "Free play did not begin")
    assert(not paused, "Completing the main quest paused the game")
    assert(not ui.overlay.visible, "A modal was shown on completion")
    assert(ui.current_mode() != "complete", "The old 试玩完成 modal appeared")
    assert(not ui.quest_label.visible and not ui.quest_icon.visible,
        "The quest tracker is still on screen during free play")
    assert(game.is_free_play_active(), "Free play was not activated")
    print("  completion: no pause, no modal, tracker hidden, free play active")


func _wait(count: int) -> void:
    for _i in count:
        await physics_frame
