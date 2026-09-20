extends Node2D
class_name RunGame

const INPUT_SETUP := preload("res://scripts/systems/input_setup.gd")
const UPGRADES := preload("res://scripts/systems/run_upgrades.gd")
const MELEE := preload("res://scenes/enemies/melee_enemy.tscn")
const ARCHER := preload("res://scenes/enemies/archer_enemy.tscn")
const MERCHANT := preload("res://scenes/world/merchant.tscn")

const WAVES := {
    1: [["melee", "melee"], ["melee", "archer"]],
    2: [["melee", "melee", "archer"], ["melee", "archer", "archer"]],
    3: [["melee", "melee", "melee", "archer"], ["melee", "archer", "melee", "archer"]]
}
const SPAWNS := [
    Vector2(760, 470), Vector2(1010, 390), Vector2(750, 270),
    Vector2(1040, 560), Vector2(950, 220)
]

static var previous_first_variant: int = -1
static var auto_start_next: bool = false

@export var health_potion_price: int = 3
@export var stamina_potion_price: int = 3
@export var upgrade_price: int = 5
@export var health_potion_heal: int = 60

@onready var arena = $RunArena
@onready var player: Player = $Player
@onready var ui: RunUI = $RunUI

var rng := RandomNumberGenerator.new()
var phase := "menu"
var room_index := 0
var remaining_enemies := 0
var kills := 0
var gold := 0
var gold_earned := 0
var health_potions := 0
var stamina_potions := 0
var run_seconds := 0.0
var room_variants: Array[int] = []
var offered: Array[String] = []
var queued_wave: Array[String] = []
var shop_upgrade_id := ""
var _merchant: Node2D


func _ready() -> void:
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    INPUT_SETUP.ensure_actions()
    rng.randomize()
    player.movement_bounds = Rect2(76, 76, 1128, 568)
    player.camera.limit_left = 0
    player.camera.limit_top = 0
    player.camera.limit_right = 1280
    player.camera.limit_bottom = 720
    player.global_position = Vector2(240, 480)
    player.health_changed.connect(ui.set_health)
    player.stamina_changed.connect(ui.set_stamina)
    player.stamina_boost_changed.connect(ui.set_boost)
    player.stamina_warning.connect(ui._on_stamina_warning)
    player.stamina_denied.connect(ui._on_stamina_denied)
    player.guard_broken_exhausted.connect(ui._on_guard_broken_exhausted)
    player.attack_blocked.connect(_on_attack_blocked)
    player.died.connect(_on_player_died)
    ui.start_requested.connect(_on_start_requested)
    ui.classic_requested.connect(_on_classic_requested)
    ui.quit_requested.connect(_on_quit_requested)
    ui.reward_selected.connect(_on_reward_selected)
    ui.buy_health_requested.connect(_on_buy_health_requested)
    ui.buy_stamina_requested.connect(_on_buy_stamina_requested)
    ui.buy_upgrade_requested.connect(_on_buy_upgrade_requested)
    ui.shop_continue_requested.connect(_on_shop_continue_requested)
    ui.resume_requested.connect(_on_resume_requested)
    ui.restart_requested.connect(_on_restart_requested)
    ui.title_requested.connect(_on_title_requested)
    ui.set_health(player.health, player.max_health)
    ui.set_stamina(player.stamina, player.max_stamina)
    ui.set_boost(player.stamina_boost_left)
    ui.set_gold(gold)
    ui.set_inventory(health_potions, stamina_potions)
    ui.set_build(player.upgrades)
    arena.configure(0)
    get_tree().paused = true
    if auto_start_next:
        auto_start_next = false
        call_deferred("_on_start_requested")


func _process(delta: float) -> void:
    if phase == "combat":
        run_seconds += delta


func _unhandled_input(event: InputEvent) -> void:
    if get_tree().paused or phase != "combat":
        return
    if event.is_action_pressed("pause"):
        phase = "pause"
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
    _start_room(1)
    ui.show_toast("越过村庄边境，击退盗匪。")


func _start_room(index: int) -> void:
    phase = "combat"
    room_index = index
    _clear_previous_encounter()
    arena.configure(5 if index == 4 else index)
    player.global_position = Vector2(230, 485)
    player.velocity = Vector2.ZERO
    player.restore_stamina()
    player._invulnerability_left = 0.75
    remaining_enemies = 0
    queued_wave.clear()
    if index == 4:
        if player.health < player.max_health:
            player.heal(player.max_health - player.health)
        _spawn_elite()
        ui.show_toast("战前营火恢复全部生命。看清精英前摇，再寻找反击机会。", 3.0)
    else:
        var variant := rng.randi_range(0, WAVES[index].size() - 1)
        if index == 1 and variant == previous_first_variant:
            variant = 1 - variant
        if index == 1:
            previous_first_variant = variant
        room_variants.append(variant)
        var wave: Array = WAVES[index][variant]
        var initial_count := 2 if index == 3 else wave.size()
        for enemy_index in initial_count:
            if wave[enemy_index] == "melee":
                _spawn_melee(SPAWNS[enemy_index], 1.0 + (index - 1) * 0.08)
            else:
                _spawn_archer(SPAWNS[enemy_index], 1.0 + (index - 1) * 0.08)
        for enemy_index in range(initial_count, wave.size()):
            queued_wave.append(wave[enemy_index])
    ui.set_stage(index, remaining_enemies)


func _spawn_melee(at: Vector2, scale_factor: float) -> void:
    var enemy := MELEE.instantiate() as Enemy
    enemy.max_health = roundi(75.0 * scale_factor)
    enemy.damage = roundi(8.0 * scale_factor)
    enemy.add_to_group("run_enemy")
    add_child(enemy)
    enemy.global_position = at
    enemy.defeated.connect(_on_enemy_defeated)
    remaining_enemies += 1


func _spawn_archer(at: Vector2, scale_factor: float) -> void:
    var enemy := ARCHER.instantiate() as ArcherEnemy
    enemy.max_health = roundi(55.0 * scale_factor)
    enemy.projectile_damage = roundi(7.0 * scale_factor)
    enemy.add_to_group("run_enemy")
    add_child(enemy)
    enemy.global_position = at
    enemy.defeated.connect(_on_enemy_defeated)
    remaining_enemies += 1


func _spawn_elite() -> void:
    var enemy := MELEE.instantiate() as Enemy
    enemy.elite = true
    enemy.max_health = 190
    enemy.damage = 14
    enemy.move_speed = 145.0
    enemy.attack_cooldown = 1.1
    enemy.add_to_group("run_enemy")
    add_child(enemy)
    enemy.global_position = Vector2(920, 410)
    enemy.defeated.connect(_on_enemy_defeated)
    remaining_enemies += 1


func _on_enemy_defeated(_at: Vector2) -> void:
    if phase != "combat":
        return
    remaining_enemies -= 1
    kills += 1
    gold += 1
    gold_earned += 1
    player.on_enemy_defeated()
    ui.set_gold(gold)
    ui.set_stage(room_index, remaining_enemies)
    if remaining_enemies <= 0:
        if queued_wave.is_empty():
            call_deferred("_complete_room")
        else:
            call_deferred("_spawn_queued_wave")


func _spawn_queued_wave() -> void:
    if phase != "combat" or queued_wave.is_empty():
        return
    var wave := queued_wave.duplicate()
    queued_wave.clear()
    ui.show_toast("敌人援兵赶来！", 1.2)
    await get_tree().create_timer(0.8, false).timeout
    if phase != "combat":
        return
    for enemy_index in wave.size():
        if wave[enemy_index] == "melee":
            _spawn_melee(SPAWNS[enemy_index + 1], 1.16)
        else:
            _spawn_archer(SPAWNS[enemy_index + 1], 1.16)
    ui.set_stage(room_index, remaining_enemies)


func _complete_room() -> void:
    if phase != "combat":
        return
    if room_index == 4:
        _finish_run(true)
        return
    _clear_feedback()
    gold += 1
    gold_earned += 1
    ui.set_gold(gold)
    phase = "reward"
    get_tree().paused = true
    offered = UPGRADES.offers(player.upgrades, rng)
    ui.show_rewards(offered)


func _on_reward_selected(index: int) -> void:
    if phase != "reward" or index < 0 or index >= offered.size():
        return
    _grant_upgrade(offered[index])
    offered.clear()
    ui.hide_overlay()
    get_tree().paused = false
    if room_index == 2:
        _enter_shop()
    else:
        _start_room(room_index + 1)


func _grant_upgrade(id: String) -> void:
    player.add_upgrade(id)
    ui.set_build(player.upgrades)
    ui.show_toast("获得战技：%s" % UPGRADES.name_of(id), 2.0)


func _enter_shop() -> void:
    phase = "shop"
    _clear_previous_encounter()
    arena.configure(4)
    player.global_position = Vector2(230, 485)
    _merchant = MERCHANT.instantiate() as Node2D
    add_child(_merchant)
    _merchant.global_position = Vector2(630, 450)
    var available := UPGRADES.offers(player.upgrades, rng, 1)
    shop_upgrade_id = available[0] if not available.is_empty() else ""
    ui.show_shop(gold, shop_upgrade_id, health_potion_price, stamina_potion_price, upgrade_price)
    get_tree().paused = true


func _on_buy_health_requested() -> void:
    if phase != "shop":
        return
    if gold < health_potion_price:
        ui.refresh_shop(gold, "金币不足。")
        return
    gold -= health_potion_price
    health_potions += 1
    _refresh_shop("购入生命药水。按 1 使用。")


func _on_buy_stamina_requested() -> void:
    if phase != "shop":
        return
    if gold < stamina_potion_price:
        ui.refresh_shop(gold, "金币不足。")
        return
    gold -= stamina_potion_price
    stamina_potions += 1
    _refresh_shop("购入精力药水。按 2 使用。")


func _on_buy_upgrade_requested() -> void:
    if phase != "shop" or shop_upgrade_id.is_empty():
        return
    if gold < upgrade_price:
        ui.refresh_shop(gold, "金币不足，无法购买战技。")
        return
    gold -= upgrade_price
    _grant_upgrade(shop_upgrade_id)
    shop_upgrade_id = ""
    ui.mark_shop_upgrade_sold()
    _refresh_shop("购入本局战技。")


func _refresh_shop(message: String) -> void:
    ui.set_gold(gold)
    ui.set_inventory(health_potions, stamina_potions)
    ui.refresh_shop(gold, message)


func _on_shop_continue_requested() -> void:
    if phase != "shop":
        return
    ui.hide_overlay()
    get_tree().paused = false
    if is_instance_valid(_merchant):
        _merchant.queue_free()
    _start_room(3)


func _use_health_potion() -> void:
    if health_potions <= 0:
        ui.show_toast("没有生命药水。")
    elif player.heal(health_potion_heal):
        health_potions -= 1
        ui.set_inventory(health_potions, stamina_potions)
        ui.show_toast("恢复 %d 点生命。" % health_potion_heal)
    else:
        ui.show_toast("生命已满。")


func _use_stamina_potion() -> void:
    if stamina_potions <= 0:
        ui.show_toast("没有精力药水。")
        return
    stamina_potions -= 1
    player.apply_stamina_boost(12.0, 2.0)
    ui.set_inventory(health_potions, stamina_potions)
    ui.show_toast("精力恢复加速 12 秒。")


func _on_attack_blocked() -> void:
    ui.show_toast("反击就绪！下一击强化。" if player.counter_ready else "格挡成功！", 0.9)


func _on_player_died() -> void:
    if phase == "combat":
        _finish_run(false)


func _finish_run(won: bool) -> void:
    _clear_feedback()
    phase = "won" if won else "dead"
    var names: Array[String] = []
    for id in player.upgrades.keys():
        names.append(UPGRADES.name_of(id))
    var summary := "用时 %d:%02d  ·  击败 %d 人  ·  获得 %d 金币\n本局战技：%s" % [
        floori(run_seconds / 60.0), int(run_seconds) % 60,
        kills, gold_earned, " · ".join(names) if not names.is_empty() else "无"
    ]
    ui.show_end(won, summary)
    get_tree().paused = true


func _clear_previous_encounter() -> void:
    _clear_feedback()
    for enemy in get_tree().get_nodes_in_group("run_enemy"):
        enemy.queue_free()
    for child in get_children():
        if child is EnemyArrow:
            child.queue_free()


func _clear_feedback() -> void:
    for popup in get_tree().get_nodes_in_group("combat_feedback"):
        popup.queue_free()


func _on_resume_requested() -> void:
    if phase != "pause":
        return
    phase = "combat"
    ui.hide_overlay()
    get_tree().paused = false


func _on_restart_requested() -> void:
    auto_start_next = true
    get_tree().paused = false
    get_tree().reload_current_scene()


func _on_title_requested() -> void:
    auto_start_next = false
    get_tree().paused = false
    get_tree().change_scene_to_file("res://scenes/main/town_title.tscn")


func _on_classic_requested() -> void:
    get_tree().paused = false
    get_tree().change_scene_to_file("res://scenes/main/town_title.tscn")


func _on_quit_requested() -> void:
    get_tree().quit()










