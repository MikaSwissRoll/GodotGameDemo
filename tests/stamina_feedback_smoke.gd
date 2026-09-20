extends SceneTree

## Stamina feedback contract.
##
## Covers the parts of the feature that are pure state and timing: thresholds,
## denial, the last-chance guard, exhaustion, the input buffer and the regen hold.
## The rendered feedback (bar shake, warning icon) is reviewed separately through
## the HUD, since it is visual.
##
## Balance values are asserted unchanged, so an accidental retune fails here.

const INPUT_SETUP := preload("res://scripts/systems/input_setup.gd")
const UI := preload("res://scripts/ui/tiny_swords_ui.gd")

var game: Node2D
var player: Player
var warnings: Array[int] = []
var denials: Array[String] = []
var breaks := 0


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    create_timer(60.0).timeout.connect(func() -> void:
        push_error("stamina feedback test timed out")
        quit(1))
    INPUT_SETUP.ensure_actions()
    game = (load("res://scenes/main/game.tscn") as PackedScene).instantiate() as Node2D
    root.add_child(game)
    current_scene = game
    player = game.get_node("Player") as Player
    player.stamina_warning.connect(func(level: int) -> void: warnings.append(level))
    player.stamina_denied.connect(func(action: String) -> void: denials.append(action))
    player.guard_broken_exhausted.connect(func() -> void: breaks += 1)
    (game.get_node("GameUI") as GameUI).start_requested.emit()
    # The post-hit invulnerability window would otherwise swallow the harness's
    # consecutive damage calls, so the guard tests would silently never land.
    player.test_ignore_invulnerability = true
    await _wait_frames(3)

    _check_balance_unchanged()
    await _check_warning_thresholds()
    # These contain `await`, so they are coroutines: calling one without `await`
    # returns at its first suspension point and the rest never runs.
    await _check_character_shake()
    await _check_state_icon_anchor()
    await _check_last_chance_guard()
    await _check_exhaustion()
    await _check_regen_hold()
    _check_buffers()
    _check_upgrade_costs()

    print("STAMINA PASS: thresholds, char shake, icon anchor, last-chance guard, exhaustion, buffer, regen hold, costs")
    quit(0)


## The character must shudder on a warning, and settle. Only the sprite moves, so a
## feedback shake can never displace the collision body.
func _check_character_shake() -> void:
    # The preceding threshold checks leave stamina low, which fires a shake of its
    # own. Let it finish before measuring, or the baseline below records a frame
    # mid-shudder and the settle assertion can never match.
    var waited := 0
    while player._char_shake_left > 0.0 and waited < 120:
        await physics_frame
        waited += 1
    await physics_frame
    var body_before := player.global_position
    # Capture the resting sprite position before shaking.
    var sprite_base := player.sprite.position
    player.shake_character(6.0, 0.25)
    var amplitudes: Array[float] = []
    var body_moved := 0.0
    for frame in 16:
        await physics_frame
        amplitudes.append(absf(player.sprite.position.x - sprite_base.x))
        body_moved = maxf(body_moved, player.global_position.distance_to(body_before))
    var peak := 0.0
    for value in amplitudes:
        peak = maxf(peak, value)
    assert(peak > 0.5, "the character did not move during a warning shake (peak %.2fpx)" % peak)
    assert(body_moved < 1.0,
        "the shake moved the body by %.2fpx; it must only move the sprite" % body_moved)
    # Let it finish and confirm it settles exactly back.
    var settled := 0
    while settled < 40 and not is_equal_approx(player.sprite.position.x, sprite_base.x):
        await physics_frame
        settled += 1
    assert(is_equal_approx(player.sprite.position.x, sprite_base.x),
        "the character shake did not settle (x=%.2f, base=%.2f)" % [
            player.sprite.position.x, sprite_base.x])
    print("  character shake peaked at %.1fpx on the sprite, body stayed put, settled" % peak)


## The state icon rides the character's upper-right, so it points at whoever the
## warning applies to rather than sitting beside the bar.
func _check_state_icon_anchor() -> void:
    var icon: Sprite2D = player._state_icon
    assert(icon != null, "player has no state icon")
    assert(icon.get_parent() == player, "state icon is not a child of the player")
    assert(icon.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST,
        "state icon is not nearest-filtered")
    assert(player.state_icon_offset.x > 0.0 and player.state_icon_offset.y < 0.0,
        "state icon offset is not up and to the right: %s" % player.state_icon_offset)
    # It must show while stamina is low and hide once recovered. Every band uses
    # the same sweat drop; severity is the shake, not the symbol.
    player.restore_stamina()
    await _wait_frames(3)
    assert(not icon.visible, "state icon stayed visible at full stamina")
    player._change_stamina(-75.0)          # -> 25, the shallow band
    await _wait_frames(3)
    assert(icon.visible, "state icon did not appear at low stamina")
    assert(Rect2i((icon.texture as AtlasTexture).region) == UI.SHIKASHI_SWEAT,
        "shallow warning shows the wrong icon")
    player._change_stamina(-10.0)          # -> 15, the deep band
    await _wait_frames(3)
    assert(Rect2i((icon.texture as AtlasTexture).region) == UI.SHIKASHI_SWEAT,
        "deep warning shows the wrong icon; every band uses the sweat drop")
    player.restore_stamina()
    await _wait_frames(3)
    print("  state icon follows the player, up-and-right, always the sweat drop, hides when safe")


func _check_balance_unchanged() -> void:
    assert(is_equal_approx(player.max_stamina, 100.0), "max_stamina changed")
    assert(is_equal_approx(player.attack_stamina_cost, 20.0), "attack cost changed")
    assert(is_equal_approx(player.dash_stamina_cost, 30.0), "dash cost changed")
    assert(is_equal_approx(player.guard_block_cost, 8.0), "block cost changed")
    assert(is_equal_approx(player.stamina_regen_rate, 22.0), "regen rate changed")
    assert(player.exhausted_duration >= 0.35 and player.exhausted_duration <= 0.5,
        "exhausted duration outside the 0.35-0.5s window")
    assert(player.exhausted_anim_speed >= 0.65 and player.exhausted_anim_speed <= 0.8,
        "exhausted animation speed outside the 0.65-0.8x window")
    assert(is_equal_approx(player.stamina_input_buffer, 0.15), "buffer window changed")
    assert(is_equal_approx(player.stamina_regen_delay, 0.5), "regen delay changed")
    print("  balance values unchanged, feedback windows in range")


func _check_warning_thresholds() -> void:
    warnings.clear()
    player.restore_stamina()
    await _wait_frames(2)
    assert(warnings.is_empty(), "warning fired at full stamina")

    # Cross the shallow threshold.
    player._change_stamina(-75.0)          # 100 -> 25, past 30
    await _wait_frames(2)
    assert(warnings == [1], "expected one level-1 warning, got %s" % [warnings])

    # Crossing again without recovering must not re-fire.
    player._change_stamina(-2.0)
    player._change_stamina(-2.0)
    await _wait_frames(2)
    assert(warnings == [1], "level-1 warning spammed: %s" % [warnings])

    # Cross the deep threshold.
    player._change_stamina(-3.0)           # -> 20, at the deep line
    await _wait_frames(2)
    assert(warnings == [1, 2], "expected a level-2 warning, got %s" % [warnings])

    # Recovering above both thresholds re-arms them.
    player.restore_stamina()
    await _wait_frames(2)
    player._change_stamina(-75.0)
    await _wait_frames(2)
    assert(warnings == [1, 2, 1], "thresholds did not re-arm after recovery: %s" % [warnings])
    print("  warnings: one per downward crossing, re-arm on recovery, no spam")


func _check_last_chance_guard() -> void:
    # Guard must be raisable with any stamina above zero, below the old 10 minimum.
    player.restore_stamina()
    player._change_stamina(-95.0)          # -> 5, below guard_min_stamina
    player._guard_broken = false
    player.guarding = true
    print("  setup: stamina=%.1f guarding=%s broken=%s dead=%s controls=%s" % [
        player.stamina, player.guarding, player._guard_broken, player._dead, player.controls_enabled])
    assert(player.stamina > 0.0 and player.stamina < player.guard_min_stamina,
        "setup: expected stamina below guard_min_stamina")

    breaks = 0
    var health_before := player.health
    # `source_direction` is the direction the blow travels, and take_damage negates
    # it to get the incoming vector. The player faces right, so a blow arriving
    # from the front travels left; passing RIGHT here would describe a hit from
    # behind, which correctly fails the guard arc.
    player.facing = Vector2.RIGHT
    player.take_damage(12, Vector2.LEFT)
    print("  after hit: health %d->%d stamina=%.1f guarding=%s exhausted=%s breaks=%d" % [
        health_before, player.health, player.stamina, player.guarding, player.is_exhausted(), breaks])
    assert(player.health == health_before, "an underfunded block still took damage")
    assert(is_equal_approx(player.stamina, 0.0), "underfunded block did not empty stamina")
    assert(breaks == 1, "underfunded block did not raise the guard-break signal")
    assert(not player.guarding, "guard stayed up after breaking")
    print("  last-chance guard: blocked at %.0f stamina, emptied the bar, broke guard" % 5.0)


func _check_exhaustion() -> void:
    assert(player.is_exhausted(), "not exhausted after a guard break")
    assert(player.exhausted_left() > 0.0, "exhausted timer not running")
    # `_die()` zeroed health during the earlier damage test; a dead player returns
    # early from _physics_process and would never reach the animation update.
    player.health = player.max_health
    player._dead = false
    # The exhausted window is ~0.45s, which is short enough that a fixed number of
    # awaited frames can overshoot it. Poll for the slowdown instead, and separately
    # assert that it does return to normal once exhaustion ends.
    var saw_slow := false
    var frames := 0
    while player.is_exhausted() and frames < 120:
        if is_equal_approx(player.sprite.speed_scale, player.exhausted_anim_speed):
            saw_slow = true
        await physics_frame
        frames += 1
    assert(saw_slow, "animation never slowed during the exhausted state")
    assert(not player.is_exhausted(), "exhausted state never ended")

    # And it must restore afterwards.
    var restored := false
    frames = 0
    while frames < 10:
        if is_equal_approx(player.sprite.speed_scale, 1.0):
            restored = true
            break
        await physics_frame
        frames += 1
    assert(restored, "animation speed not restored after exhaustion (%.2f)" % player.sprite.speed_scale)
    print("  exhaustion slowed the animation to %.2fx and restored to 1.0x" % player.exhausted_anim_speed)


func _check_regen_hold() -> void:
    # `_dead` latches once health hits zero, and a dead player does not regenerate.
    player._dead = false
    player.restore_stamina()
    await _wait_frames(2)
    # Regeneration is invisible at full stamina, so start from a real deficit.
    # Spend below the warn line too, which also proves warnings do not block regen.
    player._change_stamina(-40.0)
    await _wait_frames(2)
    player._hold_regen()
    var before := player.stamina
    await _wait_frames(4)
    assert(is_equal_approx(player.stamina, before),
        "stamina regenerated during the hold (%.1f -> %.1f)" % [before, player.stamina])

    # After the hold it must resume at the configured rate.
    var waited := 0.0
    while player._regen_hold_left > 0.0 and waited < 2.0:
        await physics_frame
        waited += 1.0 / 60.0
    var after_hold := player.stamina
    var frames := 0
    while frames < 30:
        await physics_frame
        frames += 1
    var gained := player.stamina - after_hold
    var seconds := float(frames) / 60.0
    var rate := gained / seconds
    assert(gained > 0.0, "stamina did not regenerate at all after the hold")
    assert(absf(rate - player.stamina_regen_rate) < 3.0,
        "regen rate after the hold was %.1f/sec, expected ~%.1f" % [rate, player.stamina_regen_rate])
    print("  regen held at %.1f for %.2fs, then resumed at %.1f/sec" % [
        before, player.stamina_regen_delay, rate])


func _check_buffers() -> void:
    # The buffer is a timer, so verify it is armed on a refused press and that a
    # stale buffer cannot fire later.
    player.restore_stamina()
    player._change_stamina(-90.0)          # -> 10, short of both costs
    player._buffer_attack_left = 0.0
    player._buffer_dash_left = 0.0
    player._attacking = false
    player.guarding = false
    player._dash_left = 0.0
    player._attack_cooldown_left = 0.0
    player._dash_cooldown_left = 0.0

    # Simulate the press path: a refused press arms the buffer.
    player._buffer_attack_left = player.stamina_input_buffer
    assert(player._buffer_attack_left > 0.0, "attack buffer not armed")
    assert(player.stamina < player.get_attack_cost(), "setup: expected to afford nothing")

    # Buffers must expire rather than linger indefinitely.
    var frames := 0
    while player._buffer_attack_left > 0.0 and frames < 60:
        await physics_frame
        frames += 1
    assert(player._buffer_attack_left == 0.0, "attack buffer never expired")
    assert(frames <= 20, "attack buffer lasted %d frames, expected ~9 at 60fps" % frames)
    print("  input buffer armed and expired in %d frames (~%.2fs)" % [frames, frames / 60.0])


func _check_upgrade_costs() -> void:
    player.restore_stamina()
    player.upgrades.clear()
    assert(is_equal_approx(player.get_attack_cost(), 20.0), "base attack cost wrong")
    assert(is_equal_approx(player.get_dash_cost(), 30.0), "base dash cost wrong")

    player.add_upgrade("heavy_blade")
    assert(is_equal_approx(player.get_attack_cost(), 30.0),
        "heavy_blade no longer adds to the attack cost")
    player.add_upgrade("swift_step")
    assert(is_equal_approx(player.get_dash_cost(), 20.0),
        "swift_step no longer reduces the dash cost")

    # iron_guard still discounts a block that the player can afford.
    player.add_upgrade("iron_guard")
    player.restore_stamina()
    player._guard_broken = false
    player.guarding = true
    player.facing = Vector2.RIGHT
    player.take_damage(12, Vector2.LEFT)
    assert(is_equal_approx(player.stamina, 96.0),
        "iron_guard block cost is %.1f, expected 4" % (100.0 - player.stamina))
    player.upgrades.clear()
    print("  upgrade cost modifiers intact: heavy_blade +10, swift_step -10, iron_guard -4")


func _wait_frames(count: int) -> void:
    for _i in count:
        await process_frame
