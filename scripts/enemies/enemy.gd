class_name Enemy
extends CharacterBody2D

const SPRITES := preload("res://scripts/systems/sprite_frames_factory.gd")
const FEEDBACK := preload("res://scripts/systems/combat_feedback.gd")
const PARTY := preload("res://scripts/systems/party.gd")
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
## How often an enemy re-evaluates who to attack. Not per frame, so it cannot
## flicker between the player and a companion mid-swing.
@export var retarget_interval: float = 1.6
## A rival must be this much closer before an enemy switches away from its current
## target, which keeps existing player targeting stable.
@export var companion_preference: float = 0.6

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hurtbox: Area2D = $Hurtbox
@onready var attack_hitbox: Area2D = $AttackHitbox
@onready var body_shape: CollisionShape2D = $CollisionShape2D

var target: Node2D
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
var _retarget_left := 0.0


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
    _retarget(delta)
    if not is_instance_valid(target):
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


## Keep a valid target, and only look for a new one occasionally.
##
## Before companions existed this could simply hold the player forever. Now that a
## recruited companion is also a legitimate target, the enemy needs to notice when
## its current target is gone and to sometimes prefer whoever is closer. Both are
## done on a timer rather than per frame, so an enemy does not flicker between the
## player and a companion and lose its wind-up.
func _retarget(delta: float) -> void:
    _retarget_left = maxf(0.0, _retarget_left - delta)
    if _is_target_valid(target) and _retarget_left > 0.0:
        return
    _retarget_left = retarget_interval
    if _is_target_valid(target):
        # Still valid, but re-evaluate: a companion may have closed in.
        var rival := _nearest_party_actor()
        if rival != null and rival != target:
            var rival_distance := global_position.distance_to(rival.global_position)
            var current_distance := global_position.distance_to(target.global_position)
            if rival_distance < current_distance * companion_preference:
                target = rival
        return
    target = _nearest_party_actor()


func _is_target_valid(candidate: Node2D) -> bool:
    if candidate == null or not is_instance_valid(candidate):
        return false
    if candidate is Player:
        return not (candidate as Player).is_dead()
    # A downed companion stops being worth attacking, which is what makes the
    # downed state read as out of the fight rather than a free hit.
    if candidate.has_method("is_party_member"):
        return candidate.state != 4 and (candidate.get("health") as int) > 0
    return false


## Nearest living member of the player's party. Deliberately does not include the
## Guard or the Merchant: they are friendly, not party members, and must stay safe.
func _nearest_party_actor() -> Node2D:
    var best: Node2D = null
    var best_distance := INF
    for node in get_tree().get_nodes_in_group("party"):
        if not _is_target_valid(node):
            continue
        var distance := global_position.distance_to((node as Node2D).global_position)
        if distance < best_distance:
            best_distance = distance
            best = node
    # Fall back to the player if nothing has registered in the party group yet,
    # so an enemy is never left without a target in an existing scene.
    if best == null:
        var player := get_tree().get_first_node_in_group("player") as Player
        if player != null and not player.is_dead():
            best = player
    return best


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
    var victim := area.get_parent()
    if not PARTY.is_party_member(victim):
        return
    _hit_this_swing = true
    victim.take_damage(damage, _attack_direction)


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



