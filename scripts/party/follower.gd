class_name Follower extends CharacterBody2D

## A recruited companion: follows the player, joins nearby fights, and never
## permanently dies.
##
## This is the shared foundation for companions. It deliberately owns only what
## every companion needs — formation following, combat activation with a leash,
## stable target selection, the faction rules, stuck recovery and the downed cycle.
## What a specific class does once it reaches its target is left to
## `_perform_attack()`, so an archer or a healer can be added later without
## touching any of the above. Nothing here assumes a melee swing except that one
## method.
##
## Faction safety is structural rather than checked at runtime: the attack hitbox
## masks only the enemy hurtbox layer, so this unit cannot damage the player, the
## Guard, the Merchant or another companion even if the code were wrong elsewhere.
## See `scripts/systems/party.gd` for the layer table.

const FRAMES := preload("res://scripts/systems/sprite_frames_factory.gd")
const FEEDBACK := preload("res://scripts/systems/combat_feedback.gd")
const PAWN_SHEET_DIR := "res://asset/Units/Blue Units/Pawn_Knife/"

enum State { FOLLOW, COMBAT_APPROACH, ATTACK, RETURN, DOWNED }

## Movement and formation.
@export var move_speed: float = 150.0
## Where the follower sits relative to the player: behind and to one side, so the
## two never occupy the same pixels.
@export var follow_offset := Vector2(-46.0, 30.0)
## Inside this radius of the slot the follower stops, which is what prevents the
## constant micro-adjusting jitter of chasing an exact point.
@export var follow_stop_distance: float = 14.0
## Beyond this it sprints, so it catches up instead of trailing forever.
@export var catch_up_distance: float = 260.0
@export var catch_up_multiplier: float = 1.5

## Combat activation.
## A hostile must be this close to the player for the follower to engage at all.
@export var assist_radius: float = 340.0
## And this close to the follower to be considered.
@export var detect_radius: float = 300.0
## The follower never travels further than this from the player.
@export var leash_distance: float = 420.0
## A rival target must be this much closer before the follower switches to it.
@export var retarget_margin: float = 0.7

## Melee.
@export var attack_range: float = 62.0
@export var attack_damage: int = 14
@export var attack_cooldown: float = 1.15
@export var attack_windup: float = 0.22
@export var attack_active: float = 0.12

## Durability and recovery.
@export var max_health: int = 60
@export var downed_seconds: float = 6.0
@export var revive_health_ratio: float = 0.5
## Regeneration only while safely out of combat, so a fight still costs something.
@export var regen_per_second: float = 3.0
@export var regen_delay: float = 4.0

## Stuck recovery. All three must hold before the follower is repositioned.
@export var stuck_check_seconds: float = 2.5
@export var stuck_progress_epsilon: float = 12.0
@export var stuck_distance: float = 220.0
## Frames between allowed fallback repositionings, so it can never look like
## teleport spam.
@export var reposition_cooldown: float = 12.0

signal downed
signal revived
signal health_changed(current: int, maximum: int)

var state: int = State.FOLLOW
var health: int = 0
var target: Node2D = null

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _attack_hitbox: Area2D = $AttackHitbox

var _player: Player
var _attack_cooldown_left := 0.0
var _attack_phase := 0.0
var _attack_origin := Vector2.ZERO
var _facing := Vector2.LEFT
var _regen_hold_left := 0.0
var _downed_left := 0.0
var _alive_enemies := 0

## Tracked slot position, advanced only by the player's own displacement. Deriving
## it from the player's facing would make the formation snap left and right every
## time the player taps a direction.
var _slot := Vector2.ZERO
var _last_player_position := Vector2.ZERO
var _has_slot := false

## Stuck detection.
var _stuck_time := 0.0
var _progress_mark := Vector2.ZERO
var _reposition_left := 0.0

var _flash_left := 0.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	health = max_health
	add_to_group("party")
	add_to_group("follower")

	_sprite = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	_attack_hitbox = get_node_or_null("AttackHitbox") as Area2D
	_build_frames()
	if _attack_hitbox != null:
		_attack_hitbox.monitoring = false
		_attack_hitbox.area_entered.connect(_on_attack_area_entered)


## Companions identify themselves to `Party.is_party_member`. That is what lets the
## enemy targeting extension treat them as valid targets for the hostile side
## without special-casing this class.
func is_party_member() -> bool:
	return true


func setup(player: Player) -> void:
	_player = player
	_last_player_position = player.global_position
	_slot = player.global_position + follow_offset
	_has_slot = true
	global_position = _slot


func _build_frames() -> void:
	if _sprite == null:
		return
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	FRAMES.add_strip(frames, "idle", PAWN_SHEET_DIR + "Pawn_Idle Knife.png", 8, Vector2i(192, 192), 8.0)
	FRAMES.add_strip(frames, "run", PAWN_SHEET_DIR + "Pawn_Run Knife.png", 6, Vector2i(192, 192), 10.0)
	# The real attack sheet: four frames with the knife sweeping down and the slash
	# arc baked into frames 1-2, so no effect is layered on top of it.
	FRAMES.add_strip(frames, "attack", PAWN_SHEET_DIR + "Pawn_Attack Knife.png", 4, Vector2i(192, 192), 12.0)
	frames.set_animation_loop("attack", false)
	_sprite.sprite_frames = frames
	_sprite.play("idle")


func _physics_process(delta: float) -> void:
	_attack_cooldown_left = maxf(0.0, _attack_cooldown_left - delta)
	_reposition_left = maxf(0.0, _reposition_left - delta)
	_flash_left = maxf(0.0, _flash_left - delta)
	_apply_flash()

	if _player == null or not is_instance_valid(_player):
		velocity = Vector2.ZERO
		move_and_slide()
		return

	_alive_enemies = _count_alive_enemies()

	if state == State.DOWNED:
		_process_downed(delta)
		return

	_advance_slot()
	if _attack_phase > 0.0:
		_process_attack(delta)
		return

	_consider_combat()
	match state:
		State.FOLLOW, State.RETURN:
			_process_follow(delta)
		State.COMBAT_APPROACH:
			_process_approach(delta)
		State.ATTACK:
			_process_attack(delta)
	_regenerate(delta)
	_check_stuck(delta)
	_animate()


## The formation slot rides along with the player's own movement, so the follower
## ends up behind whatever direction the player actually travelled.
func _advance_slot() -> void:
	var player_position := _player.global_position
	var moved := player_position - _last_player_position
	_last_player_position = player_position
	if moved.length() > 0.5:
		var direction := moved.normalized()
		var side := Vector2(-direction.y, direction.x)
		_slot = player_position + direction * follow_offset.x + side * follow_offset.y
	elif not _has_slot:
		_slot = player_position + follow_offset


func _process_follow(delta: float) -> void:
	var to_slot := _slot - global_position
	var distance := to_slot.length()
	if distance <= follow_stop_distance:
		# Close enough: stop rather than oscillating around the exact point.
		velocity = Vector2.ZERO
		move_and_slide()
		return
	var speed := move_speed
	if distance > catch_up_distance:
		speed *= catch_up_multiplier
	velocity = to_slot.normalized() * speed
	_face(velocity)
	move_and_slide()


func _process_approach(delta: float) -> void:
	if not _is_target_usable(target):
		_drop_target()
		return
	var to_target := target.global_position - global_position
	if to_target.length() <= attack_range:
		velocity = Vector2.ZERO
		move_and_slide()
		_begin_attack()
		return
	velocity = to_target.normalized() * move_speed
	_face(velocity)
	move_and_slide()


## Starts a swing. Kept separate from the damage so a future ranged companion can
## override the presentation without changing when the attack happens.
func _begin_attack() -> void:
	if _attack_cooldown_left > 0.0 or not _is_target_usable(target):
		return
	# Turn to face the target first. The swing's hitbox is offset in front of the
	# companion, so attacking while still facing the last travel direction puts the
	# blow past the target's shoulder and it misses entirely.
	if target != null and is_instance_valid(target):
		_face(target.global_position - global_position)
	state = State.ATTACK
	_attack_phase = attack_windup + attack_active
	_attack_cooldown_left = attack_cooldown
	_attack_origin = global_position
	if _sprite != null:
		_sprite.play("attack")


func _process_attack(delta: float) -> void:
	_attack_phase = maxf(0.0, _attack_phase - delta)
	velocity = Vector2.ZERO
	move_and_slide()
	# The hit window opens just before the swing ends, matching the enemy's timing
	# convention so both read the same way.
	if _attack_phase <= attack_active and _attack_phase + delta > attack_active:
		_perform_attack()
	if _attack_phase == 0.0:
		state = State.FOLLOW
		if _sprite != null:
			_sprite.play("idle")


## The class-specific part. A melee companion sweeps its hitbox; a future archer
## would spawn a projectile here instead and nothing above would change.
func _perform_attack() -> void:
	if _attack_hitbox == null:
		return
	_attack_hitbox.position = _facing * 44.0 + Vector2(0.0, -20.0)
	_attack_hitbox.monitoring = true
	await get_tree().physics_frame
	if not is_inside_tree() or _attack_hitbox == null:
		return
	for area in _attack_hitbox.get_overlapping_areas():
		_on_attack_area_entered(area)
	_attack_hitbox.monitoring = false


func _on_attack_area_entered(area: Area2D) -> void:
	var enemy := area.get_parent()
	if enemy == null or not enemy.has_method("take_damage"):
		return
	# Belt and braces: the mask already excludes anything friendly, but a mis-set
	# mask in a future scene must not turn into friendly fire.
	if not Party.is_hostile(enemy):
		return
	enemy.take_damage(attack_damage, _facing)




## Combat only starts for threats near the player, and only continues while the
## target stays inside the leash. This is what stops the companion from wandering
## off across the map after one enemy.
func _consider_combat() -> void:
	if _attack_phase > 0.0 or state == State.DOWNED:
		return
	var distance_home := global_position.distance_to(_player.global_position)
	if distance_home > leash_distance:
		_drop_target()
		state = State.RETURN
		return
	if _is_target_usable(target):
		# Stickiness: keep the current target while it remains reasonable, so the
		# companion does not oscillate between two enemies.
		var to_target := global_position.distance_to(target.global_position)
		var rival := _pick_target()
		if rival != null and rival != target:
			var rival_distance := global_position.distance_to(rival.global_position)
			if rival_distance < to_target * retarget_margin:
				target = rival
		state = State.COMBAT_APPROACH
		return
	_drop_target()
	var found := _pick_target()
	if found != null:
		target = found
		state = State.COMBAT_APPROACH
	else:
		state = State.FOLLOW


## Nearest living hostile that is close enough to the follower and, more
## importantly, close enough to the player to count as assisting rather than
## wandering off.
func _pick_target() -> Node2D:
	var best: Node2D = null
	var best_distance := detect_radius
	for node in get_tree().get_nodes_in_group("bandits"):
		if not Party.is_hostile(node):
			continue
		var enemy := node as Enemy
		if enemy.health <= 0:
			continue
		if enemy.global_position.distance_to(_player.global_position) > assist_radius:
			continue
		var distance := global_position.distance_to(enemy.global_position)
		if distance < best_distance:
			best_distance = distance
			best = enemy
	return best


func _is_target_usable(candidate: Node2D) -> bool:
	if candidate == null or not is_instance_valid(candidate):
		return false
	if not candidate.has_method("take_damage"):
		return false
	if (candidate as Enemy).health <= 0:
		return false
	return global_position.distance_to(candidate.global_position) <= leash_distance


func _drop_target() -> void:
	target = null


func _regenerate(delta: float) -> void:
	if state == State.DOWNED or health >= max_health:
		return
	if _alive_enemies > 0:
		_regen_hold_left = regen_delay
		return
	_regen_hold_left = maxf(0.0, _regen_hold_left - delta)
	if _regen_hold_left > 0.0:
		return
	health = mini(max_health, health + int(ceilf(regen_per_second * delta)))
	health_changed_signal()


## Two conditions only: far from the player AND no real progress. Either alone is
## normal, together means something is blocking the path.
func _check_stuck(delta: float) -> void:
	if state == State.DOWNED:
		return
	var far := global_position.distance_to(_player.global_position) > stuck_distance
	if not far:
		_stuck_time = 0.0
		_progress_mark = global_position
		return
	if global_position.distance_to(_progress_mark) > stuck_progress_epsilon:
		_stuck_time = 0.0
		_progress_mark = global_position
		return
	_stuck_time += delta
	if _stuck_time < stuck_check_seconds:
		return
	_stuck_time = 0.0
	_recover_from_stuck()


## Recovery in order of intrusiveness. Only the last step moves the companion, and
## it is rate limited and refused while the player is under attack, so a fallback
## never yanks the companion out of a fight.
func _recover_from_stuck() -> void:
	# 1. Recompute where the slot is and try again: cheap, and usually enough.
	_slot = _player.global_position + follow_offset
	_progress_mark = global_position
	state = State.FOLLOW
	_drop_target()
	# 2. If that has already been tried recently, and nobody is fighting, step the
	#    companion to the player's side instead of leaving it stranded.
	if _reposition_left > 0.0 or _alive_enemies > 0:
		return
	_reposition_left = reposition_cooldown
	global_position = _safe_point_near_player()
	velocity = Vector2.ZERO


## A point beside the player that is not inside world geometry, so the fallback
## does not drop the companion into a wall.
func _safe_point_near_player() -> Vector2:
	var space := get_world_2d().direct_space_state
	for attempt in 8:
		var angle := TAU * float(attempt) / 8.0
		var candidate := _player.global_position + Vector2(cos(angle), sin(angle)) * 56.0
		var query := PhysicsPointQueryParameters2D.new()
		query.position = candidate
		query.collision_mask = Party.LAYER_WORLD
		query.collide_with_areas = false
		if space.intersect_point(query, 1).is_empty():
			return candidate
	return _player.global_position + follow_offset


func _process_downed(delta: float) -> void:
	velocity = Vector2.ZERO
	move_and_slide()
	_downed_left = maxf(0.0, _downed_left - delta)
	if _downed_left > 0.0:
		return
	# Revive beside the player rather than where he fell, which may be deep in
	# whatever downed him.
	health = maxi(1, int(round(float(max_health) * revive_health_ratio)))
	global_position = _safe_point_near_player()
	_last_player_position = _player.global_position
	_slot = global_position
	state = State.FOLLOW
	_attack_cooldown_left = 1.0
	if _sprite != null:
		# Stand back up: undo the downed pose as well as the grey.
		_sprite.rotation_degrees = 0.0
		_sprite.speed_scale = 1.0
		_sprite.modulate = _base_modulate()
		_sprite.play("idle")
	health_changed_signal()
	revived.emit()


## Companions take damage but never die: a mistake by the AI must not cost the
## player a 25-gold investment permanently.
func take_damage(amount: int, source_direction: Vector2) -> void:
	if state == State.DOWNED or amount <= 0:
		return
	health = maxi(0, health - amount)
	_flash_left = 0.16
	velocity += source_direction.normalized() * 120.0
	FEEDBACK.popup(get_parent(), global_position, "-%d" % amount, Color("#ff8b80"))
	health_changed_signal()
	if health <= 0:
		_enter_downed()


func _enter_downed() -> void:
	state = State.DOWNED
	_downed_left = downed_seconds
	_drop_target()
	if _sprite != null:
		# There is no hurt or death art anywhere in the pack, so the downed pose is
		# the standing frame turned a quarter turn. Lying on his side, greyed and
		# darkened, reads as "down" at a glance without new art, and the game keeps
		# running: a companion never ends the session.
		_sprite.play("idle")
		_sprite.speed_scale = 0.0
		_sprite.rotation_degrees = 90.0
		_sprite.modulate = Color(0.45, 0.44, 0.48)
	downed.emit()


func _apply_flash() -> void:
	if _sprite == null or state == State.DOWNED:
		return
	_sprite.modulate = Color(1.0, 0.55, 0.55) if _flash_left > 0.0 else _base_modulate()


func _base_modulate() -> Color:
	return Color.WHITE


func _face(direction: Vector2) -> void:
	if direction == Vector2.ZERO:
		return
	_facing = direction.normalized()
	if _sprite != null:
		_sprite.flip_h = _facing.x < -0.1


func _animate() -> void:
	if _sprite == null or _attack_phase > 0.0:
		return
	var moving := velocity.length() > 1.0
	var wanted := "run" if moving else "idle"
	if _sprite.animation != wanted:
		_sprite.speed_scale = 1.0
		_sprite.play(wanted)
	if wanted == "run":
		_face(velocity)


func _count_alive_enemies() -> int:
	var total := 0
	for node in get_tree().get_nodes_in_group("bandits"):
		if Party.is_hostile(node) and (node as Enemy).health > 0:
			total += 1
	return total


func health_changed_signal() -> void:
	health_changed.emit(health, max_health)
