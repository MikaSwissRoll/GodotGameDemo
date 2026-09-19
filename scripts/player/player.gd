class_name Player
extends CharacterBody2D

const SPRITES := preload("res://scripts/systems/sprite_frames_factory.gd")
const FEEDBACK := preload("res://scripts/systems/combat_feedback.gd")
const BLUE_WARRIOR := "res://asset/Units/Blue Units/Warrior/"

signal health_changed(current: int, maximum: int)
signal stamina_changed(current: float, maximum: float)
signal stamina_boost_changed(remaining: float)
signal attack_blocked
signal died

@export var move_speed: float = 220.0
@export var movement_bounds := Rect2(24.0, 24.0, 4752.0, 1452.0)
@export var max_health: int = 100
@export var max_stamina: float = 100.0
@export var stamina_regen_rate: float = 22.0
@export var attack_stamina_cost: float = 20.0
@export var dash_stamina_cost: float = 30.0
@export var guard_block_cost: float = 8.0
@export var guard_min_stamina: float = 10.0
@export_range(0.0, 360.0, 1.0) var guard_arc_degrees: float = 240.0
@export var attack_damage: int = 25
@export var attack_cooldown: float = 0.5
@export var dash_speed: float = 650.0
@export var dash_duration: float = 0.16
@export var dash_cooldown: float = 1.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var camera: Camera2D = $Camera2D
@onready var attack_hitbox: Area2D = $AttackHitbox
@onready var dash_hitbox: Area2D = $DashHitbox
@onready var hurtbox: Area2D = $Hurtbox

var health: int
var stamina: float
var stamina_boost_left: float = 0.0
var stamina_boost_multiplier: float = 1.0
var controls_enabled := true
var facing := Vector2.RIGHT
var guarding := false
var upgrades: Dictionary = {}
var counter_ready := false
var _guard_broken := false
var _dead := false
var _attacking := false
var _attack_cooldown_left := 0.0
var _dash_cooldown_left := 0.0
var _dash_left := 0.0
var _invulnerability_left := 0.0
var _flash_left := 0.0
var _shake_left := 0.0
var _knockback := Vector2.ZERO
var _attack_hits: Dictionary = {}
var _dash_hits: Dictionary = {}


func _ready() -> void:
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    add_to_group("player")
    health = max_health
    stamina = max_stamina
    var frames := SpriteFrames.new()
    frames.remove_animation("default")
    SPRITES.add_strip(frames, "idle", BLUE_WARRIOR + "Warrior_Idle.png", 8, Vector2i(192, 192), 8.0)
    SPRITES.add_strip(frames, "run", BLUE_WARRIOR + "Warrior_Run.png", 6, Vector2i(192, 192), 10.0)
    SPRITES.add_strip(frames, "attack", BLUE_WARRIOR + "Warrior_Attack1.png", 4, Vector2i(192, 192), 12.0)
    SPRITES.add_strip(frames, "guard", BLUE_WARRIOR + "Warrior_Guard.png", 6, Vector2i(192, 192), 8.0)
    frames.set_animation_loop("attack", false)
    sprite.sprite_frames = frames
    sprite.play("idle")
    attack_hitbox.area_entered.connect(_on_attack_area_entered)
    dash_hitbox.area_entered.connect(_on_dash_area_entered)
    health_changed.emit(health, max_health)
    stamina_changed.emit(stamina, max_stamina)


func _physics_process(delta: float) -> void:
    _attack_cooldown_left = maxf(0.0, _attack_cooldown_left - delta)
    _dash_cooldown_left = maxf(0.0, _dash_cooldown_left - delta)
    _dash_left = maxf(0.0, _dash_left - delta)
    _invulnerability_left = maxf(0.0, _invulnerability_left - delta)
    _flash_left = maxf(0.0, _flash_left - delta)
    _shake_left = maxf(0.0, _shake_left - delta)
    _knockback = _knockback.move_toward(Vector2.ZERO, 900.0 * delta)
    if _dead:
        sprite.modulate = Color(0.55, 0.55, 0.6)
    else:
        sprite.modulate = Color(1.0, 0.55, 0.55) if _flash_left > 0.0 else Color.WHITE
    camera.offset = Vector2(randi_range(-3, 3), randi_range(-3, 3)) if _shake_left > 0.0 else Vector2.ZERO

    if stamina_boost_left > 0.0:
        stamina_boost_left = maxf(0.0, stamina_boost_left - delta)
        if stamina_boost_left == 0.0:
            stamina_boost_multiplier = 1.0
        stamina_boost_changed.emit(stamina_boost_left)

    if _dead or not controls_enabled:
        velocity = Vector2.ZERO
        guarding = false
        dash_hitbox.monitoring = false
        return

    var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
    if not Input.is_action_pressed("guard"):
        _guard_broken = false
    guarding = Input.is_action_pressed("guard") and not _guard_broken and not _attacking and _dash_left <= 0.0 and stamina >= guard_min_stamina

    # Keep the shield aimed where it was raised while allowing strafing.
    if direction != Vector2.ZERO and _dash_left <= 0.0 and not guarding:
        facing = direction.normalized()
        sprite.flip_h = facing.x < -0.1

    if Input.is_action_just_pressed("dash") and _dash_cooldown_left <= 0.0 and not _attacking and not guarding and stamina >= get_dash_cost():
        _change_stamina(-get_dash_cost())
        _dash_left = dash_duration
        _dash_cooldown_left = dash_cooldown - (0.25 if upgrades.has("swift_step") else 0.0)
        _invulnerability_left = dash_duration + 0.08
        if direction != Vector2.ZERO:
            facing = direction.normalized()
        _shake_left = 0.08
        _dash_hits.clear()
        dash_hitbox.monitoring = upgrades.has("dash_cleave")

    if Input.is_action_just_pressed("attack") and _attack_cooldown_left <= 0.0 and _dash_left <= 0.0 and not guarding and stamina >= get_attack_cost():
        _change_stamina(-get_attack_cost())
        _start_attack()

    if not guarding and not _attacking and _dash_left <= 0.0:
        _change_stamina(stamina_regen_rate * stamina_boost_multiplier * delta)

    if _dash_left > 0.0:
        velocity = facing * dash_speed
    elif guarding:
        velocity = direction * move_speed * 0.6 + _knockback
    else:
        velocity = direction * move_speed + _knockback
    move_and_slide()
    global_position = global_position.clamp(movement_bounds.position, movement_bounds.end)
    if _dash_left <= 0.0 and dash_hitbox.monitoring:
        dash_hitbox.monitoring = false

    if _attacking:
        return
    if guarding:
        if sprite.animation != "guard":
            sprite.play("guard")
    elif direction != Vector2.ZERO or _dash_left > 0.0:
        if sprite.animation != "run":
            sprite.play("run")
    elif sprite.animation != "idle":
        sprite.play("idle")


func get_attack_cost() -> float:
    return attack_stamina_cost + (10.0 if upgrades.has("heavy_blade") else 0.0)


func get_dash_cost() -> float:
    return dash_stamina_cost - (10.0 if upgrades.has("swift_step") else 0.0)


func add_upgrade(id: String) -> void:
    upgrades[id] = true


func on_enemy_defeated() -> void:
    if upgrades.has("kill_flow"):
        _change_stamina(18.0)


func _change_stamina(amount: float) -> void:
    var next_stamina := clampf(stamina + amount, 0.0, max_stamina)
    if not is_equal_approx(next_stamina, stamina):
        stamina = next_stamina
        stamina_changed.emit(stamina, max_stamina)


func restore_stamina() -> void:
    _change_stamina(max_stamina - stamina)


func heal(amount: int) -> bool:
    if _dead or health >= max_health:
        return false
    health = mini(max_health, health + amount)
    health_changed.emit(health, max_health)
    FEEDBACK.popup(get_parent(), global_position, "+%d" % amount, Color("#76e49a"))
    return true


func apply_stamina_boost(duration: float, multiplier: float) -> void:
    stamina_boost_left = duration
    stamina_boost_multiplier = multiplier
    stamina_boost_changed.emit(stamina_boost_left)


func _start_attack() -> void:
    _attacking = true
    _attack_cooldown_left = attack_cooldown
    _attack_hits.clear()
    sprite.play("attack")
    await get_tree().create_timer(0.09, false).timeout
    if _dead or not is_inside_tree():
        return
    attack_hitbox.position = facing * 66.0 + Vector2(0.0, -25.0)
    attack_hitbox.monitoring = true
    await get_tree().physics_frame
    for area in attack_hitbox.get_overlapping_areas():
        _on_attack_area_entered(area)
    await get_tree().create_timer(0.15, false).timeout
    attack_hitbox.monitoring = false
    await get_tree().create_timer(0.1, false).timeout
    if not _dead:
        _attacking = false


func _on_attack_area_entered(area: Area2D) -> void:
    if not _attacking:
        return
    var enemy := area.get_parent()
    if not enemy.has_method("take_damage"):
        return
    var identifier := enemy.get_instance_id()
    if _attack_hits.has(identifier):
        return
    _attack_hits[identifier] = true
    var amount := attack_damage + (20 if upgrades.has("heavy_blade") else 0)
    if counter_ready:
        amount += 20
        counter_ready = false
    enemy.take_damage(amount, facing)
    _shake_left = 0.12


func _on_dash_area_entered(area: Area2D) -> void:
    if _dash_left <= 0.0 or not upgrades.has("dash_cleave"):
        return
    var enemy := area.get_parent()
    if not enemy.has_method("take_damage"):
        return
    var identifier := enemy.get_instance_id()
    if _dash_hits.has(identifier):
        return
    _dash_hits[identifier] = true
    enemy.take_damage(18, facing)


func take_damage(amount: int, source_direction: Vector2) -> void:
    if _dead or _invulnerability_left > 0.0:
        return
    var incoming := -source_direction.normalized()
    var block_cost := guard_block_cost - (4.0 if upgrades.has("iron_guard") else 0.0)
    var half_arc_radians := deg_to_rad(guard_arc_degrees * 0.5)
    var arc_threshold := cos(half_arc_radians)
    var inside_guard_arc := incoming == Vector2.ZERO or facing.dot(incoming) >= arc_threshold
    if guarding and stamina >= block_cost and inside_guard_arc:
        _change_stamina(-block_cost)
        if stamina < guard_min_stamina:
            guarding = false
            _guard_broken = true
        if upgrades.has("shield_counter"):
            counter_ready = true
        _shake_left = 0.08
        FEEDBACK.popup(get_parent(), global_position, "反击就绪" if counter_ready else "格挡", Color("#9be9ed"))
        attack_blocked.emit()
        return
    health = maxi(0, health - amount)
    _invulnerability_left = 0.6
    _flash_left = 0.2
    _shake_left = 0.18
    _knockback = source_direction.normalized() * 240.0
    FEEDBACK.popup(get_parent(), global_position, "-%d" % amount, Color("#ff8b80"))
    health_changed.emit(health, max_health)
    if health <= 0:
        _die()


func _die() -> void:
    _dead = true
    controls_enabled = false
    guarding = false
    attack_hitbox.monitoring = false
    dash_hitbox.monitoring = false
    sprite.play("guard")
    sprite.modulate = Color(0.55, 0.55, 0.6)
    died.emit()


func is_dead() -> bool:
    return _dead



