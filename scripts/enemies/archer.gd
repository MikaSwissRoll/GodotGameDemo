extends CharacterBody2D
class_name ArcherEnemy

const SPRITES := preload("res://scripts/systems/sprite_frames_factory.gd")
const FEEDBACK := preload("res://scripts/systems/combat_feedback.gd")
const PARTY := preload("res://scripts/systems/party.gd")
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
## How often the archer re-evaluates who to shoot. Not per frame, so it cannot
## flicker between the player and a companion mid-draw.
@export var retarget_interval: float = 1.6
## A companion must be this much closer than the player before the archer switches
## to it, which keeps existing player targeting stable.
@export var companion_preference: float = 0.6

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hurtbox: Area2D = $Hurtbox
@onready var body_shape: CollisionShape2D = $CollisionShape2D

var target: Node2D
var health: int
var _warning: Line2D
var _alive := true
var _shoot_left := 0.0
var _shooting := false
var _flash_left := 0.0
var _knockback := Vector2.ZERO
var _retarget_left := 0.0


func _ready() -> void:
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    health = max_health
    # Class-level group membership. Declared in the scene file it only tagged the
    # placed story enemies, so anything spawned at runtime had no group and was
    # invisible to companions, target queries and the alive count.
    add_to_group("bandits")
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
    _retarget(delta)
    if not is_instance_valid(target):
        velocity = _knockback
        move_and_slide()
        return
    var to_player := target.global_position - global_position
    var distance := to_player.length()
    var direction := to_player.normalized()
    if distance < detection_range:
        sprite.flip_h = direction.x < 0.0
    # A cliff face is not a path. Arrows still fly over terrain, but the archer
    # itself no longer climbs a cliff to reposition, and it does not fire when the
    # only thing between it and the target is a cliff face it is standing against.
    var same_level := not _elevation_blocks(target.global_position)
    if _shooting:
        velocity = _knockback
    elif not same_level:
        velocity = _knockback
        if sprite.animation != "idle" and not _shooting:
            sprite.play("idle")
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


## Keeps a valid target, and only looks for a new one occasionally.
##
## Previously the archer grabbed the player once in `_ready` and never looked again,
## so it could not react to a recruited companion at all — the arrow mask was fixed
## to allow companion hits, but the archer never aimed at one. Detection range is
## much longer than a melee enemy's, so the player stays the natural default; a
## companion only takes over when it is clearly the nearer threat.
func _retarget(delta: float) -> void:
    _retarget_left = maxf(0.0, _retarget_left - delta)
    if _is_target_valid(target) and _retarget_left > 0.0:
        return
    _retarget_left = retarget_interval
    if _is_target_valid(target):
        var rival := _nearest_party_actor()
        if rival != null and rival != target:
            var rival_distance := global_position.distance_to(rival.global_position)
            var current_distance := global_position.distance_to(target.global_position)
            # The player is preferred, so a companion must be markedly closer.
            var bias := 1.0 if target is Player else companion_preference
            if rival_distance < current_distance * bias:
                target = rival
        return
    target = _nearest_party_actor()


func _is_target_valid(candidate: Node2D) -> bool:
    if candidate == null or not is_instance_valid(candidate):
        return false
    if candidate is Player:
        return not (candidate as Player).is_dead()
    if candidate.has_method("is_party_member") and candidate.is_party_member():
        # A downed companion is out of the fight and not worth an arrow.
        return (candidate.get("state") as int) != 4 and (candidate.get("health") as int) > 0
    return false


## Nearest living member of the player's party. Friendly NPCs are deliberately
## excluded: they are not party members and must stay safe.
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
    return best


## True when the straight line to the target would cross between elevation levels.
## Arrows are not told about elevation and still fly over cliffs, but the archer
## itself must not climb one to reposition.
func _elevation_blocks(target_point: Vector2) -> bool:
    return ENV.elevation_at(global_position) != ENV.elevation_at(target_point)


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
    # Arrows are not told about elevation: they fly over terrain and hit whatever
    # they reach, from a plateau or from below it. The player's melee attack is
    # what cannot cross between elevation levels.
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



