class_name Player
extends CharacterBody2D

const SPRITES := preload("res://scripts/systems/sprite_frames_factory.gd")
const FEEDBACK := preload("res://scripts/systems/combat_feedback.gd")
const UI := preload("res://scripts/ui/tiny_swords_ui.gd")
const ENV := preload("res://scripts/world/tiny_swords_environment.gd")
const BLUE_WARRIOR := "res://asset/Units/Blue Units/Warrior/"

signal health_changed(current: int, maximum: int)
signal stamina_changed(current: float, maximum: float)
signal stamina_boost_changed(remaining: float)
## Emitted when stamina crosses a warning threshold downwards, so the HUD can
## shake once. `level` is 1 for the first warning and 2 for the deeper one.
signal stamina_warning(level: int)
## Emitted when an action was refused for lack of stamina, so the HUD can react.
## Never silent: the player pressed a button and must see why nothing happened.
signal stamina_denied(action: String)
## Emitted when a block ran the player out of stamina and guard broke.
signal guard_broken_exhausted
signal attack_blocked
signal died

## Cardinal directions the player has held movement in, as a bitmask of MoveDir.
## The classic tutorial teaches 上下左右, so it needs a reliable record of real
## movement rather than a guess from the final position. Reported per direction
## once, because `_physics_process` runs every frame.
signal moved(direction: int)
## Emitted when a swing actually begins, for the same reason: the tutorial counts
## an executed attack, not a button press that a cooldown or empty stamina refused.
signal attack_started
## Emitted when the shield comes up. Separate from `attack_blocked`, which needs a
## blow to actually land, because the tutorial asks only for raising it.
signal guard_started

enum MoveDir { UP = 1, DOWN = 2, LEFT = 4, RIGHT = 8 }

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

## Stamina feedback tuning. The balance values above are deliberately unchanged;
## these only shape how the player is told about them.
##
## Crossing either threshold downwards fires a one-shot HUD warning. Each
## threshold re-arms only once stamina has climbed back above it, so regenerating
## through the boundary cannot retrigger the warning every frame.
@export var warn_stamina: float = 30.0
@export var warn_stamina_deep: float = 20.0
## Stamina does not resume regenerating until this long after an action, so a
## spend reads as a cost for a moment before it refills.
@export var stamina_regen_delay: float = 0.5
## A refused attack or dash is remembered this long and fires automatically once
## stamina allows it, so a valid press is not silently dropped.
@export var stamina_input_buffer: float = 0.15
## Guard break lasts this long, locking all three stamina actions.
@export var exhausted_duration: float = 0.45
## Animation speed during the exhausted state. Only exhaustion slows animation;
## ordinary low stamina never does, so the controls never feel laggy.
@export var exhausted_anim_speed: float = 0.7
## Movement is slightly reduced while exhausted, so the state is felt as well as
## seen without removing control.
@export var exhausted_move_scale: float = 0.75
## Invulnerability granted at the moment guard breaks. Long enough to cover the
## retaliation that would otherwise land while the player cannot act.
@export var exhausted_break_grace: float = 0.45

## Feedback shake of the character itself. The HUD shrinks the stamina bar on the
## same thresholds, so warning reads as the character and the bar shuddering
## together. Amplitude is in pixels and decays over the duration.
##
## The deeper threshold is deliberately about twice the shallow one, because the
## two warnings share the same icon and the shake is what distinguishes them.
@export var char_shake_warn: float = 7.0
@export var char_shake_deep: float = 13.0
@export var char_shake_denied: float = 8.0
@export var char_shake_break: float = 16.0
@export var char_shake_seconds: float = 0.3

## The stamina state icon rides above and to the right of the character, so the
## warning points at whoever it applies to. Offset is in the player's local space,
## clear of the sprite's head.
@export var state_icon_offset := Vector2(34.0, -74.0)
@export var state_icon_hold: float = 0.55
## 32px source drawn at 1.5x its previous 0.7, so the drop reads at a glance.
@export var state_icon_scale: float = 1.05

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
## Feedback state.
var _regen_hold_left := 0.0
var _buffer_attack_left := 0.0
var _buffer_dash_left := 0.0
var _exhausted_left := 0.0
## Threshold latches, so each warning fires once per downward crossing.
var _warn_latch := false
var _warn_deep_latch := false
## Test-only: bypasses the post-hit invulnerability window so a harness can drive
## several hits in a row. Never set during play.
var test_ignore_invulnerability := false
## Character shake state, and the world-space state icon that follows the player.
var _char_shake_left := 0.0
var _char_shake_total := 0.0
var _char_shake_amplitude := 0.0
var _char_shake_offset := Vector2.ZERO
var _state_icon: Sprite2D
var _state_icon_left := 0.0
## The camera's authored offset from the player, captured before the first frame
## overwrites `offset` for alignment. The scene places it at (0, -50) to frame the
## character above centre.
var _camera_base_offset := Vector2.ZERO
## Held for the duration of one impact shake, so the camera does not re-roll every
## frame while shaking.
var _shake_offset := Vector2.ZERO
## Directions held this session, as a MoveDir bitmask, and the previous frame's
## guard state so `guard_started` fires on the rising edge only.
var _moved_mask := 0
var _was_guarding := false


func _ready() -> void:
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    add_to_group("player")
    # The party group is who the hostile side may target. Companions join it too,
    # so enemy targeting can iterate one group instead of special-casing the player.
    add_to_group("party")
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
    # The stamina state icon is a child of the player, so it tracks them for free
    # and needs no per-frame positioning.
    _state_icon = UI.make_state_icon(self, UI.SHIKASHI_SWEAT, state_icon_scale)
    _state_icon.position = state_icon_offset
    # Capture the authored camera offset before _follow_camera() takes over
    # `offset` for pixel alignment.
    _camera_base_offset = camera.offset
    health_changed.emit(health, max_health)
    stamina_changed.emit(stamina, max_stamina)


func _physics_process(delta: float) -> void:
    _attack_cooldown_left = maxf(0.0, _attack_cooldown_left - delta)
    _dash_cooldown_left = maxf(0.0, _dash_cooldown_left - delta)
    _dash_left = maxf(0.0, _dash_left - delta)
    _invulnerability_left = maxf(0.0, _invulnerability_left - delta)
    _flash_left = maxf(0.0, _flash_left - delta)
    _shake_left = maxf(0.0, _shake_left - delta)
    _regen_hold_left = maxf(0.0, _regen_hold_left - delta)
    _buffer_attack_left = maxf(0.0, _buffer_attack_left - delta)
    _buffer_dash_left = maxf(0.0, _buffer_dash_left - delta)
    _exhausted_left = maxf(0.0, _exhausted_left - delta)
    _tick_char_shake(delta)
    _tick_state_icon(delta)
    _knockback = _knockback.move_toward(Vector2.ZERO, 900.0 * delta)
    if _dead:
        sprite.modulate = Color(0.55, 0.55, 0.6)
    else:
        sprite.modulate = Color(1.0, 0.55, 0.55) if _flash_left > 0.0 else Color.WHITE
    _follow_camera()
    _apply_anim_speed()

    if stamina_boost_left > 0.0:
        stamina_boost_left = maxf(0.0, stamina_boost_left - delta)
        if stamina_boost_left == 0.0:
            stamina_boost_multiplier = 1.0
        stamina_boost_changed.emit(stamina_boost_left)

    if _dead or not controls_enabled:
        velocity = Vector2.ZERO
        guarding = false
        # Keep the edge flag in step with the state, or a guard that was up when
        # the player died would swallow the next `guard_started`.
        _was_guarding = false
        dash_hitbox.monitoring = false
        return

    var exhausted := is_exhausted()
    var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
    if not Input.is_action_pressed("guard"):
        _guard_broken = false
    # Any stamina above zero is enough to raise the shield. The cost is settled
    # when a hit actually lands, which is what makes the last block work.
    guarding = (Input.is_action_pressed("guard") and not _guard_broken
        and not _attacking and _dash_left <= 0.0 and not exhausted and stamina > 0.0)
    if guarding and not _was_guarding:
        guard_started.emit()
    _was_guarding = guarding
    _report_movement(direction)

    # Keep the shield aimed where it was raised while allowing strafing.
    if direction != Vector2.ZERO and _dash_left <= 0.0 and not guarding:
        facing = direction.normalized()
        sprite.flip_h = facing.x < -0.1

    var dash_cost := get_dash_cost()
    var attack_cost := get_attack_cost()
    var can_act := not _attacking and _dash_left <= 0.0 and not guarding and not exhausted

    # A press that is refused for stamina is remembered briefly, so the action
    # fires on its own as soon as stamina allows instead of the press being lost.
    # Holding the key keeps the buffer alive instead of only arming on the initial
    # press: a player who holds attack through the wait must still get the swing,
    # since frame-perfect re-pressing is not something to demand of them.
    var holding_dash := Input.is_action_pressed("dash")
    var holding_attack := Input.is_action_pressed("attack")
    if can_act and _dash_cooldown_left <= 0.0 and (Input.is_action_just_pressed("dash") or holding_dash):
        _buffer_dash_left = stamina_input_buffer
    if can_act and _attack_cooldown_left <= 0.0 and (Input.is_action_just_pressed("attack") or holding_attack):
        _buffer_attack_left = stamina_input_buffer

    var want_dash := _buffer_dash_left > 0.0 and holding_dash
    var want_attack := _buffer_attack_left > 0.0 and holding_attack

    if can_act and _dash_cooldown_left <= 0.0 and want_dash and stamina >= dash_cost:
        _buffer_dash_left = 0.0
        _change_stamina(-dash_cost)
        _hold_regen()
        _dash_left = dash_duration
        _dash_cooldown_left = dash_cooldown - (0.25 if upgrades.has("swift_step") else 0.0)
        _invulnerability_left = dash_duration + 0.08
        if direction != Vector2.ZERO:
            facing = direction.normalized()
        _shake_left = 0.08
        _dash_hits.clear()
        dash_hitbox.monitoring = upgrades.has("dash_cleave")

    if can_act and _attack_cooldown_left <= 0.0 and want_attack and stamina >= attack_cost:
        _buffer_attack_left = 0.0
        _change_stamina(-attack_cost)
        _hold_regen()
        _start_attack()

    # Refuse loudly: a press that cannot be afforded tells the HUD, so the next
    # attempt is not a surprise. Fired on the initial press only, so holding the
    # key does not spam the warning every frame.
    if can_act and _dash_cooldown_left <= 0.0 and Input.is_action_just_pressed("dash") \
            and stamina < dash_cost:
        stamina_denied.emit("dash")
        shake_character(char_shake_denied)
        show_state_icon(2, 0.35)
    if can_act and _attack_cooldown_left <= 0.0 and Input.is_action_just_pressed("attack") \
            and stamina < attack_cost:
        stamina_denied.emit("attack")
        shake_character(char_shake_denied)
        show_state_icon(2, 0.35)

    if _regen_hold_left <= 0.0 and not guarding and not _attacking and _dash_left <= 0.0:
        _change_stamina(stamina_regen_rate * stamina_boost_multiplier * delta)

    if _dash_left > 0.0:
        velocity = facing * dash_speed
    elif guarding:
        velocity = direction * move_speed * 0.6 + _knockback
    elif exhausted:
        velocity = direction * move_speed * exhausted_move_scale + _knockback
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


## True while guard is broken from running out of stamina. All three stamina
## actions are locked for the duration.
func is_exhausted() -> bool:
    return _exhausted_left > 0.0


## Report each cardinal direction once, for the tutorial. Held diagonals report
## both of their components, and a direction is never re-reported, so a quest that
## counts four directions cannot be farmed by wiggling.
func _report_movement(direction: Vector2) -> void:
    if direction == Vector2.ZERO:
        return
    if direction.y < -0.1:
        _report_direction(MoveDir.UP)
    if direction.y > 0.1:
        _report_direction(MoveDir.DOWN)
    if direction.x < -0.1:
        _report_direction(MoveDir.LEFT)
    if direction.x > 0.1:
        _report_direction(MoveDir.RIGHT)


func _report_direction(flag: int) -> void:
    if _moved_mask & flag:
        return
    _moved_mask |= flag
    moved.emit(flag)


## Which cardinal directions have been held this session. Bitmask of MoveDir.
func moved_mask() -> int:
    return _moved_mask


func exhausted_left() -> float:
    return _exhausted_left


## Shudder the character. Applied to the sprite only, never to the body, so a
## feedback shake can never move the collision or the player's actual position.
func shake_character(amplitude: float, seconds: float = -1.0) -> void:
    var duration := char_shake_seconds if seconds < 0.0 else seconds
    _char_shake_amplitude = maxf(amplitude, _char_shake_amplitude if _char_shake_left > 0.0 else 0.0)
    _char_shake_total = maxf(duration, 0.0001)
    _char_shake_left = _char_shake_total


func _tick_char_shake(delta: float) -> void:
    var wanted := Vector2.ZERO
    if _char_shake_left > 0.0:
        _char_shake_left = maxf(0.0, _char_shake_left - delta)
        if _char_shake_left > 0.0:
            # Horizontal only, so the character reads as shuddering rather than
            # bobbing, and it settles instead of stopping abruptly.
            var decay := _char_shake_left / _char_shake_total
            wanted.x = sin((1.0 - decay) * TAU * 3.0) * _char_shake_amplitude * decay
        else:
            # The last frame must land exactly on zero: the sine envelope can leave
            # a fraction of a pixel behind, which would offset the sprite for good.
            _char_shake_amplitude = 0.0
    if wanted != _char_shake_offset:
        sprite.position -= _char_shake_offset
        _char_shake_offset = wanted
        sprite.position += _char_shake_offset


## Show the stamina state icon above the character. Held briefly, and re-armed by
## later events, so a burst cannot leave it stuck on screen.
func show_state_icon(level: int, seconds: float = -1.0) -> void:
    _state_icon.texture = _state_icon_texture(level)
    _state_icon.visible = true
    _state_icon_left = state_icon_hold if seconds < 0.0 else seconds


## The state icon is the sweat drop for every band. The severity is carried by the
## size of the character shake instead, so the player reads one familiar symbol and
## a strength, not a symbol they have to decode.
func _state_icon_texture(_level: int) -> AtlasTexture:
    var tex := AtlasTexture.new()
    tex.atlas = load(UI.SHIKASHI_SHEET) as Texture2D
    tex.region = UI.SHIKASHI_SWEAT
    return tex


func _tick_state_icon(delta: float) -> void:
    if _state_icon_left > 0.0:
        _state_icon_left = maxf(0.0, _state_icon_left - delta)
        if _state_icon_left == 0.0:
            _refresh_state_icon()
        return
    # No active pop: mirror the bar so an already-low player sees the warning
    # without having to cross the threshold again.
    _refresh_state_icon()


## Point the icon at the current band, or hide it when stamina is comfortable.
func _refresh_state_icon() -> void:
    var level := 0
    if stamina <= warn_stamina_deep:
        level = 2
    elif stamina <= warn_stamina:
        level = 1
    if level == 0:
        _state_icon.visible = false
    else:
        _state_icon.visible = true
        _state_icon.texture = _state_icon_texture(level)


## Suppress regeneration briefly after a spend, so the cost is felt before the bar
## starts climbing again.
func _hold_regen() -> void:
    _regen_hold_left = stamina_regen_delay


## Keep the camera locked to the player and aligned to the pixel grid.
##
## The scene ships `position_smoothing_enabled = true`, which makes the camera lag
## behind the body and move in uneven steps -- measured at 0 to 4.4 px per frame
## while the player moves a constant 3.67 px. In world space the walk is perfectly
## even, so that unevenness only exists on screen, where it reads as a stutter, and
## for pixel art it also drags the world across half pixels and makes the tiles
## shimmer.
##
## With the camera trailing by a whole pixel the sprite keeps its sub-pixel
## position, so motion stays smooth, while the world stays aligned to the grid.
func _follow_camera() -> void:
    camera.position_smoothing_enabled = false
    var base := _camera_base_offset
    if _shake_left > 0.0:
        # Impact shake. The jitter is computed once when the shake starts and held
        # for its duration; recomputing it per frame would add camera judder on top
        # of the shake.
        if _shake_offset == Vector2.ZERO:
            _shake_offset = Vector2(float(randi_range(-2, 2)), float(randi_range(-2, 2)))
        base += _shake_offset
    elif _shake_offset != Vector2.ZERO:
        _shake_offset = Vector2.ZERO
    # Snap the camera centre to a whole pixel, so the world never resamples while
    # the sprite keeps its sub-pixel position and motion stays smooth.
    camera.offset = Vector2(
        base.x - fposmod(global_position.x + base.x, 1.0),
        base.y - fposmod(global_position.y + base.y, 1.0)
    )


## Break guard and lock the stamina actions for a short exhausted window. Called
## when a block runs the player out of stamina.
##
## Grants brief invulnerability, because the block that breaks guard was the blow
## the player had already committed to stopping: without it, running out of
## stamina means taking that hit plus the next one while unable to act, which
## punishes the correct play twice.
func _enter_exhausted() -> void:
    _exhausted_left = exhausted_duration
    _guard_broken = true
    guarding = false
    _invulnerability_left = maxf(_invulnerability_left, exhausted_break_grace)
    _shake_left = 0.12
    guard_broken_exhausted.emit()
    # The HUD shakes the stamina bar on the same signal, so the character and the
    # bar shudder together.
    shake_character(char_shake_break)
    show_state_icon(3, 0.6)


## Only the exhausted state slows animation. Low stamina on its own never does, so
## a warning never turns into laggy controls.
func _apply_anim_speed() -> void:
    var wanted := exhausted_anim_speed if is_exhausted() else 1.0
    if not is_equal_approx(sprite.speed_scale, wanted):
        sprite.speed_scale = wanted


## Fire the one-shot HUD warnings on downward threshold crossings. Each latch
## clears only once stamina is back above its threshold, so regenerating over the
## line cannot retrigger the warning every frame.
func _check_stamina_warnings() -> void:
    if stamina <= warn_stamina_deep:
        if not _warn_deep_latch:
            _warn_deep_latch = true
            _warn_latch = true
            stamina_warning.emit(2)
            shake_character(char_shake_deep)
            show_state_icon(2)
    elif stamina <= warn_stamina:
        if not _warn_latch:
            _warn_latch = true
            stamina_warning.emit(1)
            shake_character(char_shake_warn)
            show_state_icon(1)
    else:
        _warn_latch = false
        _warn_deep_latch = false


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
        if amount < 0.0:
            _check_stamina_warnings()
        elif stamina > warn_stamina:
            # Re-arm both warnings once safely clear, so the next descent warns
            # again. Done on the upward move rather than only inside
            # `_check_stamina_warnings`, which spending can never reach.
            _warn_latch = false
            _warn_deep_latch = false
        # Refresh on any change so the icon cannot linger after recovery.
        _refresh_state_icon()


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
    # Announced here rather than where the input is read, so the tutorial counts a
    # swing that actually happened and not a press that stamina or a cooldown refused.
    attack_started.emit()
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
    # The player's melee cannot cross between elevation levels. A swing made from
    # the low ground does not reach a target on a plateau, and one made from a
    # plateau does not reach down to the low ground: terrain is a real boundary for
    # the player in both directions, while enemy arrows fly over it.
    if ENV.elevation_at(global_position) != ENV.elevation_at((enemy as Node2D).global_position):
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
    if _dead or (_invulnerability_left > 0.0 and not test_ignore_invulnerability):
        return
    var incoming := -source_direction.normalized()
    var block_cost := guard_block_cost - (4.0 if upgrades.has("iron_guard") else 0.0)
    var half_arc_radians := deg_to_rad(guard_arc_degrees * 0.5)
    var arc_threshold := cos(half_arc_radians)
    var inside_guard_arc := incoming == Vector2.ZERO or facing.dot(incoming) >= arc_threshold
    # Last-chance guard: raising the shield only needs stamina above zero, so a hit
    # that lands while the player is nearly spent is still blocked. Paying for it
    # can then empty the bar, which breaks guard.
    if guarding and stamina > 0.0 and inside_guard_arc:
        var affordable := stamina >= block_cost
        if affordable:
            _change_stamina(-block_cost)
            _hold_regen()
        else:
            # Block it anyway, but spend everything and break.
            _change_stamina(-stamina)
            _hold_regen()
        if not affordable or stamina < guard_min_stamina:
            _enter_exhausted()
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



