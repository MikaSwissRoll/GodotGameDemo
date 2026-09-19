extends CharacterBody2D
class_name ArcherEnemy

const SPRITES := preload("res://scripts/systems/sprite_frames_factory.gd")
const FEEDBACK := preload("res://scripts/systems/combat_feedback.gd")
const ENV := preload("res://scripts/world/tiny_swords_environment.gd")
const ARROW_SCENE := preload("res://scenes/enemies/arrow.tscn")
const RED_ARCHER := "res://asset/Units/Red Units/Archer/"

signal defeated(at: Vector2)

@export var max_health: int = 55
@export var move_speed: float = 105.0
@export var detection_range: float = 630.0
@export var preferred_range: float = 320.0
@export var shoot_cooldown: float = 1.9
@export var projectile_damage: int = 10

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hurtbox: Area2D = $Hurtbox
@onready var body_shape: CollisionShape2D = $CollisionShape2D

var target: Player
var health: int
var _warning: Line2D
var _alive := true
var _shoot_left := 0.0
var _shooting := false
var _flash_left := 0.0
var _knockback := Vector2.ZERO


func _ready() -> void:
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    health = max_health
    target = get_tree().get_first_node_in_group("player") as Player
    var frames := SpriteFrames.new()
    frames.remove_animation("default")
    SPRITES.add_strip(frames, "idle", RED_ARCHER + "Archer_Idle.png", 6, Vector2i(192, 192), 8.0)
    SPRITES.add_strip(frames, "run", RED_ARCHER + "Archer_Run.png", 4, Vector2i(192, 192), 8.0)
    SPRITES.add_strip(frames, "shoot", RED_ARCHER + "Archer_Shoot.png", 8, Vector2i(192, 192), 12.0)
    frames.set_animation_loop("shoot", false)
    sprite.sprite_frames = frames
    sprite.play("idle")
    _warning = Line2D.new()
    _warning.width = 5.0
    _warning.default_color = Color(1.0, 0.18, 0.12, 0.72)
    _warning.z_index = 1
    _warning.visible = false
    add_child(_warning)


func _physics_process(delta: float) -> void:
    if not _alive:
        return
    _shoot_left = maxf(0.0, _shoot_left - delta)
    _flash_left = maxf(0.0, _flash_left - delta)
    _knockback = _knockback.move_toward(Vector2.ZERO, 700.0 * delta)
    sprite.modulate = Color(1.0, 0.45, 0.45) if _flash_left > 0.0 else Color.WHITE
    if not is_instance_valid(target) or target.is_dead():
        velocity = _knockback
        move_and_slide()
        return
    var to_player := target.global_position - global_position
    var distance := to_player.length()
    var direction := to_player.normalized()
    if distance < detection_range:
        sprite.flip_h = direction.x < 0.0
    if _shooting:
        velocity = _knockback
    elif distance < detection_range and distance < preferred_range * 0.65:
        velocity = -direction * move_speed + _knockback
        if sprite.animation != "run":
            sprite.play("run")
    elif distance < detection_range and distance > preferred_range * 1.15:
        velocity = direction * move_speed + _knockback
        if sprite.animation != "run":
            sprite.play("run")
    else:
        velocity = _knockback
        if sprite.animation != "idle" and not _shooting:
            sprite.play("idle")
    if distance < detection_range and _shoot_left <= 0.0 and not _shooting:
        _shoot(direction)
    move_and_slide()


func _shoot(direction: Vector2) -> void:
    _shooting = true
    _shoot_left = shoot_cooldown
    sprite.play("shoot")
    _warning.clear_points()
    _warning.add_point(Vector2(0, -27))
    _warning.add_point(Vector2(0, -27) + direction * 380.0)
    _warning.visible = true
    await get_tree().create_timer(0.42, false).timeout
    if not _alive or not is_inside_tree():
        return
    _warning.visible = false
    var arrow := ARROW_SCENE.instantiate() as EnemyArrow
    arrow.direction = direction
    arrow.damage = projectile_damage
    # Ballistics depends on the shooter's elevation: from a plateau the shot may
    # drop onto the low ground, while a shot from below cannot reach a plateau.
    arrow.origin_plateau = ENV.plateau_at(global_position)
    arrow.from_high_ground = ENV.elevation_at(global_position)
    get_parent().add_child(arrow)
    arrow.global_position = global_position + Vector2(0.0, -27.0) + direction * 45.0
    await get_tree().create_timer(0.34, false).timeout
    if _alive:
        _shooting = false


func take_damage(amount: int, source_direction: Vector2) -> void:
    if not _alive:
        return
    health = maxi(0, health - amount)
    _flash_left = 0.18
    _knockback = source_direction.normalized() * 180.0
    FEEDBACK.popup(get_parent(), global_position, str(amount), Color("#fff0b5"))
    if health <= 0:
        _die()


func _die() -> void:
    _alive = false
    _warning.visible = false
    hurtbox.set_deferred("monitorable", false)
    body_shape.set_deferred("disabled", true)
    sprite.modulate = Color(0.45, 0.43, 0.45)
    defeated.emit(global_position)
    await get_tree().create_timer(0.45, false).timeout
    queue_free()



