extends SceneTree

const VIEWPORT_SIZE := Vector2i(1280, 720)
const TITLE_SCENE := "res://scenes/main/town_title.tscn"
const TITLE_TARGETS := ["main_menu", "main_menu_focus", "main_menu_pressed", "menu_transition", "classic_entry", "town_overview"]
const RUN_SCENE := "res://scenes/main/run_game.tscn"
const CLASSIC_SCENE := "res://scenes/main/game.tscn"
const VALID_TARGETS := [
    "main_menu",
    "main_menu_focus",
    "main_menu_pressed",
    "menu_transition",
    "classic_entry",
    "town_overview",
    "village",
    "wilderness",
    "enemy_camp",
    "combat",
    "stamina_low",
    "stamina_deep",
    "stamina_denied",
    "stamina_exhausted",
    "merchant_shop",
    "dialogue_ui",
    "npc_marker_far",
    "guard_tutorial",
    "supply_tutorial",
    "free_play",
    "recruit_offer",
    "companion_follow",
    "companion_combat",
    "npc_line",
    "toast_plain",
    "pause_menu",
    "reward_overlay",
    "shop_overlay",
    "result_dead",
]

var _target := "main_menu"
var _output_path := ""


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    if not _parse_arguments():
        quit(2)
        return

    DisplayServer.window_set_size(VIEWPORT_SIZE)
    root.size = VIEWPORT_SIZE
    var scene_path := CLASSIC_SCENE if _target in CLASSIC_TARGETS else RUN_SCENE
    if _target in TITLE_TARGETS:
        scene_path = TITLE_SCENE
    var packed := load(scene_path) as PackedScene
    if packed == null:
        push_error("Visual QA could not load scene: %s" % scene_path)
        quit(3)
        return

    var game := packed.instantiate()
    root.add_child(game)
    current_scene = game
    await _wait_frames(3)
    await _configure_target(game)
    await _wait_frames(8)
    RenderingServer.force_draw(false)
    await process_frame

    var image := root.get_texture().get_image()
    if image == null or image.is_empty():
        push_error("Visual QA captured an empty viewport image")
        quit(4)
        return

    var absolute_output := ProjectSettings.globalize_path(_output_path)
    var directory_error := DirAccess.make_dir_recursive_absolute(absolute_output.get_base_dir())
    if directory_error != OK:
        push_error("Visual QA could not create output directory: %s" % error_string(directory_error))
        quit(5)
        return
    var save_error := image.save_png(absolute_output)
    if save_error != OK:
        push_error("Visual QA could not save screenshot: %s" % error_string(save_error))
        quit(6)
        return

    print("VISUAL_QA_CAPTURED target=%s path=%s size=%dx%d" % [
        _target, absolute_output, image.get_width(), image.get_height()
    ])
    paused = false
    quit(0)


func _parse_arguments() -> bool:
    var arguments := OS.get_cmdline_user_args()
    var index := 0
    while index < arguments.size():
        match arguments[index]:
            "--target":
                if index + 1 >= arguments.size():
                    push_error("--target requires a value")
                    return false
                _target = arguments[index + 1]
                index += 2
            "--output":
                if index + 1 >= arguments.size():
                    push_error("--output requires a value")
                    return false
                _output_path = arguments[index + 1]
                index += 2
            _:
                push_error("Unknown visual QA argument: %s" % arguments[index])
                return false
    if _target not in VALID_TARGETS:
        push_error("Unknown visual QA target '%s'. Valid targets: %s" % [_target, ", ".join(VALID_TARGETS)])
        return false
    if _output_path.is_empty():
        _output_path = "res://screenshots/visual_qa/%s.png" % _target
    return true


## States staged on the classic scene. Everything else runs on the roguelite
## scene, so a new roguelite target does not have to be registered in two places.
const CLASSIC_TARGETS := [
    "village", "wilderness", "enemy_camp", "dialogue_ui", "npc_marker_far",
    "guard_tutorial", "supply_tutorial", "free_play",
    "recruit_offer", "companion_follow", "companion_combat",
    "npc_line", "toast_plain"
]


func _configure_target(game: Node) -> void:
    if _target in TITLE_TARGETS:
        await _configure_title_target(game)
        return
    if _target in CLASSIC_TARGETS:
        await _configure_classic_target(game)
    else:
        await _configure_run_target(game)


func _configure_title_target(title: Node) -> void:
    if _target == "main_menu_focus":
        title.menu.buttons[1].grab_focus()
    elif _target == "main_menu_pressed":
        var click := InputEventMouseButton.new()
        click.position = title.menu.buttons[0].get_global_rect().get_center()
        click.button_index = MOUSE_BUTTON_LEFT
        click.pressed = true
        root.push_input(click, true)
    elif _target in ["classic_entry", "menu_transition"]:
        title.start_classic()
        title.transition.pause()
        title.transition.custom_step(title.transition_seconds * (0.5 if _target == "menu_transition" else 1.1))
        await _wait_frames(2)
    elif _target == "town_overview":
        title.menu.hide()
    _freeze_art(title.game.get_node("World"))
    title.game.player.sprite.pause()
    title.game.player.sprite.process_mode = Node.PROCESS_MODE_DISABLED
    paused = true


func _freeze_art(node: Node) -> void:
    if node is AnimatedSprite2D:
        node.pause()
        node.frame = mini(2, node.sprite_frames.get_frame_count(node.animation) - 1)
    if node.is_in_group("town_resident"):
        node.position = node.route[0]
    for child in node.get_children():
        _freeze_art(child)
    node.process_mode = Node.PROCESS_MODE_DISABLED


func _configure_run_target(game: Node) -> void:
    var ui := game.get_node("RunUI")
    match _target:
        "main_menu":
            paused = true
        "combat":
            ui.start_requested.emit()
            await _wait_frames(10)
            paused = true
        "stamina_low":
            # Both warning steps in one frame: drive the player to just past each
            # threshold and let the HUD show its icon, so the two severities can be
            # compared side by side with the bar they belong to.
            ui.start_requested.emit()
            await _wait_frames(6)
            # Crossing the line fires the character shake, the bar shake and the
            # state icon together; wait for the shake to settle so the capture shows
            # the settled state rather than a mid-shudder frame.
            game.player._change_stamina(-72.0)   # 100 -> 28, past the shallow line
            await _wait_frames(24)
            paused = true
        "stamina_deep":
            ui.start_requested.emit()
            await _wait_frames(6)
            game.player._change_stamina(-82.0)   # 100 -> 18, past the deep line
            await _wait_frames(24)
            paused = true
        "stamina_denied":
            # A refused action: stamina below both costs, then the denial signal the
            # player emits when a press cannot be afforded.
            ui.start_requested.emit()
            await _wait_frames(6)
            game.player._change_stamina(-95.0)   # 100 -> 5, affords nothing
            await _wait_frames(2)
            game.player.stamina_denied.emit("attack")
            await _wait_frames(24)
            paused = true
        "stamina_exhausted":
            # Guard break: a block that empties the bar. Drives the real path so the
            # exhausted state and its animation slowdown are what gets captured.
            ui.start_requested.emit()
            await _wait_frames(6)
            var p = game.player
            p.test_ignore_invulnerability = true
            p._change_stamina(-95.0)
            p._guard_broken = false
            p.guarding = true
            p.facing = Vector2.RIGHT
            p.take_damage(12, Vector2.LEFT)
            await _wait_frames(24)
            paused = true
        "merchant_shop":
            game.gold = 12
            ui.set_gold(12)
            game.call("_enter_shop")
        "pause_menu":
            ui.start_requested.emit()
            await _wait_frames(5)
            game.phase = "pause"
            ui.show_pause()
            paused = true
        "reward_overlay":
            ui.start_requested.emit()
            await _wait_frames(5)
            var rewards: Array[String] = ["swift_step", "dash_cleave", "shield_counter"]
            ui.show_rewards(rewards)
            paused = true
        "shop_overlay":
            # The real four-button shop modal, which is the tallest the shared
            # overlay gets and the layout that drives the adaptive panel height.
            ui.start_requested.emit()
            await _wait_frames(6)
            game.gold = 12
            ui.set_gold(12)
            game.call("_enter_shop")
            ui.call("show_shop", 12, game.shop_upgrade_id,
                game.health_potion_price, game.stamina_potion_price, game.upgrade_price)
            paused = true
        "result_dead":
            # Drive a real death so the result overlay is reached the way the
            # game reaches it, which also proves the HUD is hidden behind it.
            # Clear the spawn invulnerability, otherwise take_damage no-ops.
            ui.start_requested.emit()
            await _wait_frames(6)
            var hero := game.get_node("Player")
            hero._invulnerability_left = 0.0
            hero.take_damage(hero.max_health, Vector2.RIGHT)
            await _wait_frames(6)
            paused = true


func _configure_classic_target(game: Node) -> void:
    var ui := game.get_node("GameUI")
    var player := game.get_node("Player")
    var camera := player.get_node("Camera2D") as Camera2D
    camera.position_smoothing_enabled = false
    ui.start_requested.emit()
    # Staging starts play directly rather than through the title screen, so the
    # NPC interaction affordances have to be armed the way begin_from_title()
    # arms them; otherwise they correctly stay hidden and cannot be reviewed.
    for npc_name in ["VillageGuard", "Merchant"]:
        game.get_node(npc_name).set_interaction_active(true)
    match _target:
        "village":
            player.global_position = Vector2(1020, 920)
            # Exercise the longest current quest HUD state instead of the short
            # pre-quest prompt that cannot reveal quest/gold collisions.
            var quest := game.get_node("QuestManager") as QuestManager
            quest.accept_quest()
        "guard_tutorial":
            # The Guard training quest mid-progress: the longest objective line the
            # tutorial produces, so quest-label collisions show up here.
            player.global_position = Vector2(1120, 920)
            var progress := game.get_node("ClassicProgression") as ClassicProgression
            progress.guard_briefed = true
            progress.record_direction(ClassicProgression.MoveDir.UP)
            progress.record_direction(ClassicProgression.MoveDir.LEFT)
            progress.record_direction(ClassicProgression.MoveDir.RIGHT)
            progress.record_attack()
        "supply_tutorial":
            # The Merchant supply quest mid-progress.
            player.global_position = Vector2(1000, 900)
            var supply := game.get_node("ClassicProgression") as ClassicProgression
            supply.start_merchant_tutorial()
            supply.merchant_briefed = true
            supply.record_purchase("health")
            supply.record_potion_used("stamina")
        "free_play":
            # Post-main-quest: the tracker must be gone and the outer camp restocked.
            player.global_position = Vector2(2650, 850)
            var done := game.get_node("ClassicProgression") as ClassicProgression
            done.start_free_play()
        "recruit_offer":
            # The hire dialogue, with enough gold that the offer is the real one.
            var prog := game.get_node("ClassicProgression") as ClassicProgression
            prog.start_free_play()
            game.gold = 40
            ui.set_gold(40)
            player.global_position = Vector2(1240, 1080)
            await _wait_frames(4)
            game._on_pawn_knife_interacted()
        "companion_follow":
            # A hired companion on station behind the player, out of combat.
            var prog2 := game.get_node("ClassicProgression") as ClassicProgression
            prog2.start_free_play()
            game.gold = 40
            game._on_recruit_accepted()
            player.global_position = Vector2(1020, 980)
            # Let the companion walk to its slot before the frame is frozen.
            await _wait_frames(90)
        "companion_combat":
            # Player and companion engaging an outer group together.
            var prog3 := game.get_node("ClassicProgression") as ClassicProgression
            prog3.start_free_play()
            game.gold = 40
            game._on_recruit_accepted()
            player.global_position = Vector2(2700, 850)
            var foe := game.get_node("MeleeEnemy1") as Node2D
            foe.global_position = Vector2(2790, 860)
            await _wait_frames(120)
        "wilderness":
            player.global_position = Vector2(2050, 800)
        "enemy_camp":
            player.global_position = Vector2(4000, 800)
        "dialogue_ui":
            # Inside the guard's radius, so the bubble hands over to "E 交谈".
            player.global_position = Vector2(1320, 920)
            ui.show_toast("守卫：盗匪袭击了村庄！请击败 5 名盗匪，并收集 5 枚金币。", 30.0)
        "npc_marker_far":
            # Outside every NPC radius, so the guiding bubbles are on screen and
            # no key prompt is. Framed near the guard so both are comparable.
            player.global_position = Vector2(1080, 920)
        "npc_line":
            # An NPC speaking, on its backing panel. The longest Guard line, so the
            # panel has to be measured rather than assumed to fit.
            player.global_position = Vector2(1240, 620)
            ui.show_npc_line("守卫：训练结束了。敌人已经在村外集结，击败 5 名敌兵，把他们抢走的金币带回来。", 30.0)
        "toast_plain":
            # A status line, which must stay unbacked so it does not read as speech.
            player.global_position = Vector2(1240, 620)
            ui.show_toast("格挡成功！", 30.0)
    camera.reset_smoothing()
    # The two toast targets own their line, so the blanket hide must not clear it.
    if _target not in ["dialogue_ui", "npc_marker_far", "npc_line", "toast_plain"]:
        ui.toast_label.visible = false
        ui.toast_backing.visible = false
    await _wait_frames(4)
    paused = true


func _wait_frames(count: int) -> void:
    for _frame in count:
        await process_frame
