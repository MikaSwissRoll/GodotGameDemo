class_name Enemy
extends CharacterBody2D

const SPRITES := preload("res://scripts/systems/sprite_frames_factory.gd")
const FEEDBACK := preload("res://scripts/systems/combat_feedback.gd")
const RED_WARRIOR := "res://asset/Units/Red Units/Warrior/"

signal defeated(at: Vector2)
signal health_changed(current: int, maximum: int)

@export var max_health: int = 75
@export var move_speed: float = 125.0
@export var damage: int = 12
@export var detection_range: float = 520.0
@export var attack_range: float = 90.0
@export var attack_cooldown: float = 1.3
@export var elite: bool = false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hurtbox: Area2D = $Hurtbox
@onready var attack_hitbox: Area2D = $AttackHitbox
@onready var body_shape: CollisionShape2D = $CollisionShape2D

var target: Player
var health: int
var _warning: Polygon2D
var _alive := true
var _attack_left := 0.0
var _attacking := false
var _hit_this_swing := false
var _flash_left := 0.0
var _knockback := Vector2.ZERO
var _facing := Vector2.LEFT
var _attack_direction := Vector2.LEFT


func _ready() -> void:
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    health = max_health
    target = get_tree().get_first_node_in_group("player") as Player
    var frames := SpriteFrames.new()
    frames.remove_animation("default")
    SPRITES.add_strip(frames, "idle", RED_WARRIOR + "Warrior_Idle.png", 8, Vector2i(192, 192), 8.0)
    SPRITES.add_strip(frames, "run", RED_WARRIOR + "Warrior_Run.png", 6, Vector2i(192, 192), 10.0)
    SPRITES.add_strip(frames, "attack", RED_WARRIOR + "Warrior_Attack1.png", 4, Vector2i(192, 192), 12.0)
    frames.set_animation_loop("attack", false)
    sprite.sprite_frames = frames
    sprite.play("idle")
    if elite:
        sprite.scale *= 1.2
        var badge := Label.new()
        badge.text = "精英"
        badge.position = Vector2(-24, -114)
        badge.add_theme_font_size_override("font_size", 21)
        badge.add_theme_color_override("font_color", Color("#ffe292"))
        add_child(badge)
    _warning = Polygon2D.new()
    _warning.position = Vector2(0, -25)
    _warning.polygon = PackedVector2Array([Vector2.ZERO, Vector2(98, -42), Vector2(98, 42)])
    _warning.color = Color(1.0, 0.15, 0.10, 0.38)
    _warning.z_index = 1
    _warning.visible = false
    add_child(_warning)
    attack_hitbox.area_entered.connect(_on_attack_area_entered)
    health_changed.emit(health, max_health)


func _physics_process(delta: float) -> void:
    if not _alive:
        return
    _attack_left = maxf(0.0, _attack_left - delta)
    _flash_left = maxf(0.0, _flash_left - delta)
    _knockback = _knockback.move_toward(Vector2.ZERO, 750.0 * delta)
    var base_color := Color("#ffe0a2") if elite else Color.WHITE
    sprite.modulate = Color(1.0, 0.42, 0.42) if _flash_left > 0.0 else base_color
    if not is_instance_valid(target) or target.is_dead():
        velocity = _knockback
        move_and_slide()
        return

    var to_player := target.global_position - global_position
    var distance := to_player.length()
    var direction := to_player.normalized()
    if distance < detection_range:
        _facing = direction
        sprite.flip_h = direction.x < 0.0

    if _attacking:
        velocity = _knockback
    elif distance <= attack_range and _attack_left <= 0.0:
        velocity = _knockback
        _start_attack()
    elif distance < detection_range and distance > attack_range * 0.82:
        velocity = direction * move_speed + _knockback
        if sprite.animation != "run":
            sprite.play("run")
    else:
        velocity = _knockback
        if sprite.animation != "idle":
            sprite.play("idle")
    move_and_slide()


func _start_attack() -> void:
    _attacking = true
    _attack_left = attack_cooldown
    _hit_this_swing = false
    _attack_direction = _facing
    _warning.rotation = _attack_direction.angle()
    _warning.visible = true
    sprite.play("attack")
    await get_tree().create_timer(0.28, false).timeout
    if not _alive or not is_inside_tree():
        return
    _warning.visible = false
    attack_hitbox.position = _attack_direction * 55.0 + Vector2(0.0, -25.0)
    attack_hitbox.monitoring = true
    await get_tree().physics_frame
    for area in attack_hitbox.get_overlapping_areas():
        _on_attack_area_entered(area)
    await get_tree().create_timer(0.17, false).timeout
    attack_hitbox.monitoring = false
    await get_tree().create_timer(0.12, false).timeout
    if _alive:
        _attacking = false


func _on_attack_area_entered(area: Area2D) -> void:
    if not _attacking or _hit_this_swing:
        return
    var player := area.get_parent()
    if player is Player:
        _hit_this_swing = true
        player.take_damage(damage, _attack_direction)


func take_damage(amount: int, source_direction: Vector2) -> void:
    if not _alive:
        return
    health = maxi(0, health - amount)
    _flash_left = 0.18
    _knockback = source_direction.normalized() * 190.0
    FEEDBACK.popup(get_parent(), global_position, str(amount), Color("#fff0b5"))
    health_changed.emit(health, max_health)
    if health <= 0:
        _die()


func _die() -> void:
    _alive = false
    _warning.visible = false
    attack_hitbox.monitoring = false
    hurtbox.set_deferred("monitorable", false)
    body_shape.set_deferred("disabled", true)
    sprite.modulate = Color(0.45, 0.43, 0.45)
    defeated.emit(global_position)
    await get_tree().create_timer(0.45, false).timeout
    queue_free()



