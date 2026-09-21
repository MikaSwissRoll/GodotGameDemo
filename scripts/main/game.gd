extends Node2D

const INPUT_SETUP := preload("res://scripts/systems/input_setup.gd")
const GOLD_SCENE := preload("res://scenes/world/gold_pickup.tscn")
const MAIN_MENU_SCENE := "res://scenes/main/town_title.tscn"
static var restart_into_play := false

@export var health_potion_price: int = 3
@export var stamina_potion_price: int = 3
@export var health_potion_heal: int = 60
@export var stamina_potion_duration: float = 12.0
@export var stamina_potion_multiplier: float = 2.0

## Free-play enemy respawn. Outer groups come back only after this long, capped, so
## the post-main loop is sustainable without accumulating enemies.
@export var respawn_delay: float = 28.0
@export var max_free_play_enemies: int = 6
## Spawn points east of the river, out of the village. Taken from the bandit camp
## the main quest already sends the player to.
const FREE_PLAY_SPAWNS := [
    Vector2(2760, 790), Vector2(2940, 1020), Vector2(3160, 810),
    # (3890, 600) used to sit on the camp rise, which enemies can no longer climb.
    # An enemy spawned up there could never reach the player, so this point moved
    # below the cliff wall (which spans y 640..698) onto the low ground.
    Vector2(3590, 850), Vector2(3890, 760), Vector2(4400, 830),
    Vector2(3300, 1150), Vector2(4100, 1150),
]
const MELEE_ENEMY := preload("res://scenes/enemies/melee_enemy.tscn")
const ARCHER_ENEMY := preload("res://scenes/enemies/archer_enemy.tscn")
const FOLLOWER_SCENE := preload("res://scenes/party/follower.tscn")

## What a companion costs to hire. One price, one currency: the same `gold` the
## Merchant spends, so there is no second purse to keep in step.
const COMPANION_PRICE := 25
## Gold dropped per kill. Archers pay more because they are the harder target.
const BANDIT_GOLD_DROP := 1
const ARCHER_GOLD_DROP := 3

@onready var player: Player = $Player
@onready var quest: QuestManager = $QuestManager
@onready var progress: ClassicProgression = $ClassicProgression
@onready var guard: VillageGuard = $VillageGuard
@onready var merchant: Area2D = $Merchant
@onready var pawn_knife: RecruitNpc = $PawnKnife
@onready var ui: GameUI = $GameUI

var gold: int = 0
var health_potions: int = 0
var stamina_potions: int = 0
## Free-play respawn bookkeeping.
var _free_play_active := false
var _respawn_left := 0.0
var _free_play_enemies: Array[Node] = []
## The recruited companion, once hired. Null before that, which is also what makes
## a second hire impossible: the recruit NPC is freed on success.
var companion: Follower = null


func _ready() -> void:
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    INPUT_SETUP.ensure_actions()
    player.camera.limit_left = 0
    player.camera.limit_top = 0
    player.camera.limit_right = 4800
    player.camera.limit_bottom = 1500

    for enemy in get_tree().get_nodes_in_group("bandits"):
        _watch_enemy(enemy)

    player.health_changed.connect(ui.set_health)
    player.stamina_changed.connect(ui.set_stamina)
    player.stamina_boost_changed.connect(ui.set_stamina_boost)
    player.stamina_warning.connect(ui._on_stamina_warning)
    player.stamina_denied.connect(ui._on_stamina_denied)
    player.guard_broken_exhausted.connect(ui._on_guard_broken_exhausted)
    player.attack_blocked.connect(_on_attack_blocked)
    player.died.connect(_on_player_died)
    guard.interacted.connect(_on_guard_interacted)
    merchant.interacted.connect(_on_merchant_interacted)
    pawn_knife.interacted.connect(_on_pawn_knife_interacted)
    ui.recruit_accepted.connect(_on_recruit_accepted)
    ui.recruit_declined.connect(_on_recruit_declined)
    ui.dismiss_requested.connect(_on_dismiss_requested)
    quest.quest_changed.connect(_on_quest_changed)
    quest.quest_completed.connect(_on_quest_completed)
    progress.changed.connect(_on_progress_changed)
    progress.phase_changed.connect(_on_phase_changed)
    progress.main_quest_completed.connect(_on_main_quest_completed)
    # The tutorial counts what the player actually does.
    player.moved.connect(_on_player_moved)
    player.attack_started.connect(_on_player_attacked)
    player.guard_started.connect(_on_player_guarded)
    ui.start_requested.connect(_on_start_requested)
    ui.resume_requested.connect(_on_resume_requested)
    ui.restart_requested.connect(_on_restart_requested)
    ui.title_requested.connect(_on_title_requested)
    ui.quit_requested.connect(_on_quit_requested)
    ui.buy_health_requested.connect(_on_buy_health_requested)
    ui.buy_stamina_requested.connect(_on_buy_stamina_requested)
    ui.shop_closed.connect(_on_shop_closed)

    ui.set_health(player.health, player.max_health)
    ui.set_stamina(player.stamina, player.max_stamina)
    ui.set_gold(gold)
    ui.set_inventory(health_potions, stamina_potions)
    _refresh_quest_ui()
    get_tree().paused = true
    if restart_into_play:
        restart_into_play = false
        call_deferred("_on_start_requested")


func prepare_title_view() -> void:
    player.controls_enabled = false
    player.camera.enabled = false
    player.sprite.process_mode = Node.PROCESS_MODE_ALWAYS
    ui.hide_overlay()
    ui.hide()
    ui.process_mode = Node.PROCESS_MODE_DISABLED
    $World.set_title_active(true)
    # No interaction affordances on the title backdrop: the player cannot move,
    # so a marker would advertise something they cannot act on yet.
    guard.set_interaction_active(false)
    merchant.set_interaction_active(false)
    guard.prompt.hide()
    merchant.prompt.hide()
    get_tree().paused = true


func begin_from_title() -> void:
    $World.set_title_active(false)
    player.sprite.process_mode = Node.PROCESS_MODE_INHERIT
    player.controls_enabled = true
    ui.process_mode = Node.PROCESS_MODE_ALWAYS
    ui.show()
    # Control is handed over and the camera settles on the player, so the markers
    # may now guide them toward the NPCs.
    guard.set_interaction_active(true)
    merchant.set_interaction_active(true)
    _on_start_requested()


func _unhandled_input(event: InputEvent) -> void:
    if get_tree().paused:
        return
    if event.is_action_pressed("pause"):
        get_tree().paused = true
        ui.show_pause()
        get_viewport().set_input_as_handled()
    elif event.is_action_pressed("use_health_potion"):
        _use_health_potion()
        get_viewport().set_input_as_handled()
    elif event.is_action_pressed("use_stamina_potion"):
        _use_stamina_potion()
        get_viewport().set_input_as_handled()


func _on_start_requested() -> void:
    ui.hide_overlay()
    get_tree().paused = false
    ui.show_toast("先与守卫交谈，再穿过桥梁。")


func _on_resume_requested() -> void:
    ui.hide_overlay()
    get_tree().paused = false


func _on_restart_requested() -> void:
    get_tree().paused = false
    restart_into_play = true
    get_tree().change_scene_to_file("res://scenes/main/game.tscn")


func _on_title_requested() -> void:
    get_tree().paused = false
    get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _on_quit_requested() -> void:
    get_tree().quit()


func _on_player_died() -> void:
    ui.show_game_over()
    get_tree().paused = true


func _on_attack_blocked() -> void:
    ui.show_toast("格挡成功！", 0.7)


func _on_guard_interacted() -> void:
    match progress.phase:
        ClassicProgression.Phase.GUARD_TUTORIAL:
            _guard_training_talk()
        ClassicProgression.Phase.MERCHANT_TUTORIAL:
            ui.show_npc_line("守卫：先去找商人准备些补给吧。", 3.0)
        ClassicProgression.Phase.MAIN_QUEST:
            _guard_main_quest_talk()
        _:
            ui.show_npc_line("守卫：干得不错。外围还有敌人活动，想练手就去清理他们。", 4.0)


## The Guard briefing, then ongoing reminders, then the hand-in. Split by training
## step so he never repeats the introduction once the player is under way.
func _guard_training_talk() -> void:
    if progress.guard_tutorial_done():
        _pay_guard_reward()
        return
    if not progress.guard_briefed:
        progress.guard_briefed = true
        progress.changed.emit()
        ui.show_npc_line("守卫：第一次来到边境吧？出发之前，先确认你掌握了基本动作。", 5.0)
        return
    match progress.training_step():
        ClassicProgression.Training.MOVE:
            ui.show_npc_line("守卫：先用 WASD 走一走，四个方向都试试。")
        ClassicProgression.Training.ATTACK:
            ui.show_npc_line("守卫：很好。左键挥一刀给我看看。")
        _:
            ui.show_npc_line("守卫：最后，右键举盾架住一次。")


func _pay_guard_reward() -> void:
    if progress.guard_reward_paid:
        ui.show_npc_line("守卫：去和商人谈谈吧。")
        return
    progress.guard_reward_paid = true
    gold += ClassicProgression.GUARD_REWARD
    ui.set_gold(gold)
    ui.show_npc_line("守卫：不错，基本动作已经掌握了。记住，不要把精力全用在进攻上。", 5.0)
    ui.show_reward_feedback("获得 %d 金币" % ClassicProgression.GUARD_REWARD)
    progress.start_merchant_tutorial()


func _guard_main_quest_talk() -> void:
    match quest.state:
        QuestManager.QuestState.AVAILABLE:
            quest.accept_quest()
            ui.show_npc_line("守卫：训练结束了。敌人已经在村外集结，击败 5 名敌兵，把他们抢走的金币带回来。", 5.5)
        QuestManager.QuestState.ACTIVE:
            ui.show_npc_line("守卫：请阻止桥对面的盗匪。")
        QuestManager.QuestState.READY_TO_TURN_IN:
            quest.turn_in_quest()
        _:
            ui.show_npc_line("守卫：这一带暂时安全了。")


func _on_merchant_interacted() -> void:
    # The supply quest is handed in on arrival, then the shop opens as usual, so the
    # reward toast is not buried under the shop panel.
    if progress.phase == ClassicProgression.Phase.MERCHANT_TUTORIAL \
            and progress.merchant_tutorial_done():
        _on_merchant_tutorial_turn_in()
    if progress.phase == ClassicProgression.Phase.MERCHANT_TUTORIAL \
            and not progress.merchant_briefed:
        progress.merchant_briefed = true
        progress.changed.emit()
        ui.show_npc_line("商人：准备出发了吗？真正的战斗可不只靠挥剑。", 4.5)
    get_tree().paused = true
    ui.show_shop(gold, health_potion_price, stamina_potion_price, progress.merchant_dialogue())


func _on_shop_closed() -> void:
    ui.hide_overlay()
    get_tree().paused = false
    _supply_tutorial_nudge()


## The Merchant's two follow-up lines, said once the shop is out of the way.
##
## They are spoken on close rather than from inside the shop because the overlay hides
## the NPC line panel: anything said while it is open is never seen.
func _supply_tutorial_nudge() -> void:
    if progress.phase != ClassicProgression.Phase.MERCHANT_TUTORIAL:
        return
    if not progress.merchant_tutorial_done():
        if progress.bought_health and progress.bought_stamina \
                and not progress.used_health and not progress.used_stamina:
            ui.show_npc_line("商人：请按下数字1、2喝下生命药水和精力药水。喝玩告诉你感觉怎么样？", 6.0)
        return
    if not progress.supply_nudge_sent:
        progress.supply_nudge_sent = true
        ui.show_npc_line("商人：很好，去找守卫吧，他会给你安排任务。", 5.0)


func _on_buy_health_requested() -> void:
    if gold < health_potion_price:
        ui.set_shop_message("金币不足。")
        return
    gold -= health_potion_price
    health_potions += 1
    ui.set_gold(gold)
    ui.set_inventory(health_potions, stamina_potions)
    ui.set_shop_message("已购入生命药水。按 1 使用。")
    progress.record_purchase("health")


func _on_buy_stamina_requested() -> void:
    if gold < stamina_potion_price:
        ui.set_shop_message("金币不足。")
        return
    gold -= stamina_potion_price
    stamina_potions += 1
    ui.set_gold(gold)
    ui.set_inventory(health_potions, stamina_potions)
    ui.set_shop_message("已购入精力药水。按 2 使用。")
    progress.record_purchase("stamina")


func _use_health_potion() -> void:
    if health_potions <= 0:
        ui.show_toast("没有生命药水。")
        return
    if player.heal(health_potion_heal):
        health_potions -= 1
        ui.set_inventory(health_potions, stamina_potions)
        ui.show_toast("使用生命药水，恢复 %d 点生命。" % health_potion_heal)
        progress.record_potion_used("health")
        return
    # At full health the potion has nothing to restore. During the supply tutorial
    # it is accepted and consumed anyway, so the player can demonstrate the action
    # without having to go and get hurt first. Outside the tutorial the old refusal
    # stands and nothing is consumed.
    if progress.phase == ClassicProgression.Phase.MERCHANT_TUTORIAL:
        health_potions -= 1
        ui.set_inventory(health_potions, stamina_potions)
        ui.show_toast("使用生命药水。生命已满，先留个印象。")
        progress.record_potion_used("health")
        return
    ui.show_toast("生命值已满。")


func _use_stamina_potion() -> void:
    if stamina_potions <= 0:
        ui.show_toast("没有精力药水。")
        return
    stamina_potions -= 1
    player.apply_stamina_boost(stamina_potion_duration, stamina_potion_multiplier)
    ui.set_inventory(health_potions, stamina_potions)
    ui.show_toast("精力恢复速度提升 %d 秒。" % ceili(stamina_potion_duration))
    progress.record_potion_used("stamina")


## Only an active main quest counts kills and gold. Free-play respawns and anything
## the player killed or picked up before the quest started must not advance its
## counters, or the quest could arrive already finished.
##
## The drop is bound per enemy at connection time rather than looked up from a
## shared "last defeated" field: two enemies can die in the same frame, and a shared
## field would pay the wrong amount to one of them.
func _on_enemy_defeated(at: Vector2, drop: int) -> void:
    if quest.state == QuestManager.QuestState.ACTIVE:
        quest.record_bandit_defeated()
    call_deferred("_spawn_gold", at, drop)


func _gold_for(enemy: Node) -> int:
    # An archer is the harder kill: it shoots back from range, so it pays more than
    # a melee bandit for the risk of closing on it.
    if enemy is ArcherEnemy:
        return ARCHER_GOLD_DROP
    return BANDIT_GOLD_DROP


## Connects one enemy's defeat to the drop its type is worth.
func _watch_enemy(enemy: Node) -> void:
    if enemy == null or not enemy.has_signal("defeated"):
        return
    var drop := _gold_for(enemy)
    enemy.defeated.connect(func(at: Vector2) -> void: _on_enemy_defeated(at, drop))


func _spawn_gold(at: Vector2, amount: int) -> void:
    var pickup := GOLD_SCENE.instantiate() as GoldPickup
    add_child(pickup)
    pickup.global_position = at
    pickup.value = maxi(1, amount)
    pickup.collected.connect(_on_gold_collected)


func _on_gold_collected(value: int) -> void:
    gold += value
    # Same rule as kills: only an active quest counts what is picked up. Spending
    # gold at the Merchant deliberately does not undo this, because the counter is
    # a record of what was collected, not of the current balance.
    if quest.state == QuestManager.QuestState.ACTIVE:
        quest.record_gold_collected()
    ui.set_gold(gold)


func _on_quest_changed() -> void:
    _refresh_quest_ui()
    if quest.state == QuestManager.QuestState.READY_TO_TURN_IN:
        ui.show_toast("任务完成！返回村庄向守卫复命。")


## The main quest no longer ends the session. Classic Mode keeps going into free
## play: the reward is paid, the story state moves on, and the player stays in the
## world. The old 试玩完成 modal and its pause are gone.
func _on_quest_completed() -> void:
    # Speaks as the Guard, because this fires from his hand-in. It used to be the
    # only one of his lines with no speaker prefix, which read as narration.
    ui.show_npc_line("守卫：感谢你，勇士。村庄安全了。", 3.0)
    progress.start_free_play()


func _on_progress_changed() -> void:
    _refresh_quest_ui()
    if progress.phase == ClassicProgression.Phase.MERCHANT_TUTORIAL \
            and progress.merchant_tutorial_done():
        ui.show_toast("补给训练完成，返回商人处。", 4.0)


func _on_phase_changed(phase: int) -> void:
    match phase:
        ClassicProgression.Phase.MAIN_QUEST:
            ui.show_npc_line("守卫：训练结束了，现在该处理真正的问题了。", 4.5)
        ClassicProgression.Phase.FREE_PLAY:
            ui.show_toast("边境暂时安全了。外围仍有敌人出没，随时可以去清理。", 5.0)


## One place that builds the objective line, so the phase and the main quest's own
## counters are combined consistently wherever the quest UI is refreshed.
func _refresh_quest_ui() -> void:
    ui.set_quest_visible(progress.tracker_visible())
    if progress.tracker_visible():
        ui.set_quest(progress.objective_text(quest.get_objective_text()))


func _on_player_moved(direction: int) -> void:
    progress.record_direction(direction)


func _on_player_attacked() -> void:
    progress.record_attack()


func _on_player_guarded() -> void:
    progress.record_guard()


## The main quest is finished and free play begins. The story enemies are gone and
## the outer camp becomes a sustainable loop: clear it, earn gold, buy supplies,
## come back. Nothing here counts toward the finished quest.
##
## The first group appears at once: the quest's own enemies are already dead by
## now, so waiting out a respawn delay would leave the camp empty for half a minute
## right when the player walks over to look at it.
func _on_main_quest_completed() -> void:
    _free_play_active = true
    _respawn_free_play_group()
    _respawn_left = respawn_delay
    # Hiring opens only now. Before this the companion is not in the world at all,
    # so there is nothing to talk to rather than a locked door to explain.
    #
    # The recruit may already be gone: this runs on every entry into free play, and
    # a recruited companion has freed the NPC. Reaching it would be a use-after-free.
    if is_instance_valid(pawn_knife):
        pawn_knife.activate()


## ---- Companion recruitment -------------------------------------------------
##
## The transaction is atomic in one place: affordability is checked, gold is
## deducted, the NPC is freed and the follower is created, all without yielding.
## That is what makes a double hire impossible; there is no window in which the
## player could confirm twice, and the node that offers the hire no longer exists
## once it succeeds.

func _on_pawn_knife_interacted() -> void:
    # Two gates, deliberately: the recruit node is inert until free play, and this
    # also refuses to act before then. The node gate alone would be enough in play,
    # but hiring is the one unrepeatable transaction in Classic Mode, so it does not
    # rely on a signal only ever arriving from the intended place.
    if progress.phase != ClassicProgression.Phase.FREE_PLAY:
        return
    if companion != null:
        # Already hired. The recruit node is gone by now, so this is only reachable
        # through a stale reference, but it must still never charge again.
        return
    if gold < COMPANION_PRICE:
        ui.show_recruit_notice("雇佣兵", "你现在的金币还不够。\n准备好 %d 枚金币再来找我吧。" % COMPANION_PRICE)
        return
    ui.show_recruit_offer(
        "听说你解决了村外的麻烦。\n如果你还准备继续往外走，我可以和你一起。\n\n价格：%d 金币" % COMPANION_PRICE,
        "雇佣 — %d 金币" % COMPANION_PRICE,
        true)


func _on_recruit_accepted() -> void:
    if progress.phase != ClassicProgression.Phase.FREE_PLAY \
            or companion != null or gold < COMPANION_PRICE:
        # Refuse rather than half-commit: nothing has been spent at this point.
        ui.hide_overlay()
        get_tree().paused = false
        return
    gold -= COMPANION_PRICE
    ui.set_gold(gold)
    _hire_companion()
    ui.hide_overlay()
    get_tree().paused = false
    ui.show_npc_line("雇佣兵：成交。接下来的路，我和你一起走。", 4.0)


func _on_recruit_declined() -> void:
    ui.hide_overlay()
    get_tree().paused = false


func _on_dismiss_requested() -> void:
    ui.hide_overlay()
    get_tree().paused = false


## Turns the recruit standing in the village into the follower walking beside the
## player. The NPC node is removed rather than hidden, so no duplicate pawn is left
## behind and no interaction prompt survives on a unit that is no longer an NPC.
func _hire_companion() -> void:
    var spawn_at := pawn_knife.global_position
    pawn_knife.queue_free()
    companion = FOLLOWER_SCENE.instantiate() as Follower
    add_child(companion)
    companion.setup(player)
    # Start from where he was standing so the transition does not pop him across
    # the village; setup() already places him on the player's formation slot, so
    # put him back at the stall and let the follow behaviour walk him over.
    companion.global_position = spawn_at
    companion.downed.connect(_on_companion_downed)
    companion.revived.connect(_on_companion_revived)


func _on_companion_downed() -> void:
    ui.show_toast("雇佣兵倒下了，稍后会重新站起来。", 3.0)


func _on_companion_revived() -> void:
    ui.show_toast("雇佣兵重新站了起来。", 2.0)


func _process(delta: float) -> void:
    if not _free_play_active or get_tree().paused:
        return
    _refresh_free_play_enemies()
    if not _free_play_enemies.is_empty():
        # Something is still standing, so the wait has not started.
        _respawn_left = respawn_delay
        return
    _respawn_left = maxf(0.0, _respawn_left - delta)
    if _respawn_left > 0.0:
        return
    _respawn_free_play_group()
    _respawn_left = respawn_delay


## Drop dead and freed references so the count reflects what is actually alive.
func _refresh_free_play_enemies() -> void:
    var alive: Array[Node] = []
    for enemy in _free_play_enemies:
        if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
            alive.append(enemy)
    _free_play_enemies = alive


## Spawn a small group at outer points, never exceeding the cap and never on top of
## the player. The delay lives in `_process`, so this cannot run every frame and the
## population cannot run away.
func _respawn_free_play_group() -> void:
    var room := max_free_play_enemies - _free_play_enemies.size()
    if room <= 0:
        return
    var group_size := mini(room, 4)
    var candidates := _free_play_spawn_points()
    if candidates.is_empty():
        return
    for index in group_size:
        var point: Vector2 = candidates[index % candidates.size()]
        # Reuse the existing enemy scenes; a third of the group is archers so ranged
        # pressure stays in the mix without introducing a new type.
        var scene := ARCHER_ENEMY if index % 3 == 2 else MELEE_ENEMY
        var enemy := scene.instantiate() as Node2D
        add_child(enemy)
        enemy.global_position = point
        _watch_enemy(enemy)
        _free_play_enemies.append(enemy)


## Outer spawn points clear of the player, so nothing materialises in front of them.
## The camp is east of the river, well away from the village.
func _free_play_spawn_points() -> Array[Vector2]:
    var usable: Array[Vector2] = []
    for point in FREE_PLAY_SPAWNS:
        if player != null and is_instance_valid(player) \
                and player.global_position.distance_to(point) < 320.0:
            continue
        usable.append(point)
    return usable


## Exposed for the free-play regression, which checks the cap and the placement
## rules without waiting out a real respawn delay.
func free_play_enemy_count() -> int:
    return _free_play_enemies.size()


func is_free_play_active() -> bool:
    return _free_play_active


## The Merchant pays once, when both potions have been bought and used.
func _on_merchant_tutorial_turn_in() -> void:
    if progress.merchant_reward_paid:
        return
    progress.merchant_reward_paid = true
    gold += ClassicProgression.MERCHANT_REWARD
    ui.set_gold(gold)
    ui.show_reward_feedback("获得 %d 金币" % ClassicProgression.MERCHANT_REWARD)
    progress.start_main_quest()
