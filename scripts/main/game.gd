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

@onready var player: Player = $Player
@onready var quest: QuestManager = $QuestManager
@onready var guard: VillageGuard = $VillageGuard
@onready var merchant: Area2D = $Merchant
@onready var ui: GameUI = $GameUI

var gold: int = 0
var health_potions: int = 0
var stamina_potions: int = 0


func _ready() -> void:
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    INPUT_SETUP.ensure_actions()
    player.camera.limit_left = 0
    player.camera.limit_top = 0
    player.camera.limit_right = 4800
    player.camera.limit_bottom = 1500

    for enemy in get_tree().get_nodes_in_group("bandits"):
        enemy.defeated.connect(_on_enemy_defeated)

    player.health_changed.connect(ui.set_health)
    player.stamina_changed.connect(ui.set_stamina)
    player.stamina_boost_changed.connect(ui.set_stamina_boost)
    player.attack_blocked.connect(_on_attack_blocked)
    player.died.connect(_on_player_died)
    guard.interacted.connect(_on_guard_interacted)
    merchant.interacted.connect(_on_merchant_interacted)
    quest.quest_changed.connect(_on_quest_changed)
    quest.quest_completed.connect(_on_quest_completed)
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
    ui.set_quest(quest.get_objective_text())
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
    guard.prompt.hide()
    merchant.prompt.hide()
    get_tree().paused = true


func begin_from_title() -> void:
    $World.set_title_active(false)
    player.sprite.process_mode = Node.PROCESS_MODE_INHERIT
    player.controls_enabled = true
    ui.process_mode = Node.PROCESS_MODE_ALWAYS
    ui.show()
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
    match quest.state:
        QuestManager.QuestState.AVAILABLE:
            quest.accept_quest()
            ui.show_toast("守卫：盗匪袭击了村庄！请击败 5 名盗匪，并收集 5 枚金币。", 4.5)
        QuestManager.QuestState.ACTIVE:
            ui.show_toast("守卫：请阻止桥对面的盗匪。")
        QuestManager.QuestState.READY_TO_TURN_IN:
            quest.turn_in_quest()
        QuestManager.QuestState.COMPLETED:
            ui.show_toast("守卫：村庄感谢你！")


func _on_merchant_interacted() -> void:
    get_tree().paused = true
    ui.show_shop(gold, health_potion_price, stamina_potion_price)


func _on_shop_closed() -> void:
    ui.hide_overlay()
    get_tree().paused = false


func _on_buy_health_requested() -> void:
    if gold < health_potion_price:
        ui.set_shop_message("金币不足。")
        return
    gold -= health_potion_price
    health_potions += 1
    ui.set_gold(gold)
    ui.set_inventory(health_potions, stamina_potions)
    ui.set_shop_message("已购入生命药水。按 1 使用。")


func _on_buy_stamina_requested() -> void:
    if gold < stamina_potion_price:
        ui.set_shop_message("金币不足。")
        return
    gold -= stamina_potion_price
    stamina_potions += 1
    ui.set_gold(gold)
    ui.set_inventory(health_potions, stamina_potions)
    ui.set_shop_message("已购入精力药水。按 2 使用。")


func _use_health_potion() -> void:
    if health_potions <= 0:
        ui.show_toast("没有生命药水。")
    elif player.heal(health_potion_heal):
        health_potions -= 1
        ui.set_inventory(health_potions, stamina_potions)
        ui.show_toast("使用生命药水，恢复 %d 点生命。" % health_potion_heal)
    else:
        ui.show_toast("生命值已满。")


func _use_stamina_potion() -> void:
    if stamina_potions <= 0:
        ui.show_toast("没有精力药水。")
        return
    stamina_potions -= 1
    player.apply_stamina_boost(stamina_potion_duration, stamina_potion_multiplier)
    ui.set_inventory(health_potions, stamina_potions)
    ui.show_toast("精力恢复速度提升 %d 秒。" % ceili(stamina_potion_duration))


func _on_enemy_defeated(at: Vector2) -> void:
    quest.record_bandit_defeated()
    call_deferred("_spawn_gold", at)
    ui.show_toast("击败盗匪！记得拾取金币。", 1.8)


func _spawn_gold(at: Vector2) -> void:
    var pickup := GOLD_SCENE.instantiate() as GoldPickup
    add_child(pickup)
    pickup.global_position = at
    pickup.collected.connect(_on_gold_collected)


func _on_gold_collected(value: int) -> void:
    gold += value
    quest.record_gold_collected()
    ui.set_gold(gold)


func _on_quest_changed() -> void:
    ui.set_quest(quest.get_objective_text())
    if quest.state == QuestManager.QuestState.READY_TO_TURN_IN:
        ui.show_toast("任务完成！返回村庄向守卫复命。")


func _on_quest_completed() -> void:
    ui.show_toast("任务完成！感谢你，勇士。村庄安全了。", 1.8)
    get_tree().paused = true
    await get_tree().create_timer(1.8).timeout
    ui.show_complete()
