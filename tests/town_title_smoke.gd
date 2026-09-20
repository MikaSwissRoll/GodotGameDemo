extends SceneTree
const TITLE := "res://scenes/main/town_title.tscn"
var failures := 0

func _init() -> void:
    call_deferred("_run")

func check(value: bool, message: String) -> void:
    if not value:
        failures += 1
        push_error(message)

func frames(count: int = 3) -> void:
    for i in count:
        await process_frame

func _run() -> void:
    create_timer(20.0).timeout.connect(func(): push_error("Town test timed out"); quit(1))
    root.size = Vector2i(1280, 720)
    var title = load(TITLE).instantiate()
    root.add_child(title)
    current_scene = title
    await frames()
    if "--quit-check" in OS.get_cmdline_user_args():
        var quit_click := InputEventMouseButton.new()
        quit_click.position = title.menu.buttons[2].get_global_rect().get_center()
        quit_click.button_index = MOUSE_BUTTON_LEFT
        quit_click.pressed = true
        root.push_input(quit_click, true)
        await frames(1)
        quit_click = quit_click.duplicate()
        quit_click.pressed = false
        print("QUIT BUTTON DISPATCHED")
        root.push_input(quit_click, true)
        await create_timer(1.0).timeout
        push_error("Quit button did not terminate the game")
        quit(1)
        return
    var down := InputEventKey.new()
    down.keycode = KEY_DOWN
    down.pressed = true
    root.push_input(down, true)
    await frames(1)
    check(root.gui_get_focus_owner() == title.menu.buttons[1], "Keyboard focus did not advance")
    down = down.duplicate()
    down.pressed = false
    root.push_input(down, true)
    title.menu.buttons[0].grab_focus()
    var game = title.game
    var hero = game.player
    var start: Vector2 = hero.position
    var npc = get_nodes_in_group("town_resident")[4]
    var npc_start: Vector2 = npc.position
    var enemy = game.get_node("MeleeEnemy1")
    var enemy_start: Vector2 = enemy.position
    check(paused and title.phase == "menu", "Title must suspend gameplay")
    check(not hero.controls_enabled and not game.ui.visible, "Title leaked controls or HUD")
    check(title.menu.title_label.text == "边境远征", "Wrong title")
    for i in 3:
        check(title.menu.buttons[i]._name_label.text == ["经典模式", "远征模式", "退出游戏"][i], "Wrong menu order")
    Input.action_press("move_right")
    Input.action_press("attack")
    Input.action_press("interact")
    await create_timer(0.7).timeout
    Input.action_release("move_right")
    Input.action_release("attack")
    Input.action_release("interact")
    check(hero.position == start and not hero._attacking, "Menu input reached player")
    check(enemy.position == enemy_start, "Enemy AI moved during title")
    check(npc.position.distance_to(npc_start) > 2.0, "Ambient NPC did not move while title paused")
    check(game.quest.state == QuestManager.QuestState.AVAILABLE, "Title interaction altered quest")
    title.transition_seconds = 0.3
    # Exercise Godot GUI dispatch, not only the signal connection.
    var click := InputEventMouseButton.new()
    click.position = title.menu.buttons[0].get_global_rect().get_center()
    click.button_index = MOUSE_BUTTON_LEFT
    click.pressed = true
    root.push_input(click, true)
    await frames(1)
    click = click.duplicate()
    click.pressed = false
    root.push_input(click, true)
    await frames(1)
    check(title.phase == "transition" and paused, "Classic did not enter protected camera transition")
    if title.phase != "transition":
        print("CLICK DIAGNOSTIC: ", click.position, " hover=", root.gui_get_hovered_control())
        quit(1)
        return
    title.start_expedition()
    check(title.phase == "transition", "Second click interrupted the transition")
    await create_timer(0.16).timeout
    check(title.camera.zoom.x > title.overview_zoom.x and title.camera.zoom.x < 1.0, "Camera did not animate zoom")
    await create_timer(0.3).timeout
    check(title.phase == "classic" and not paused, "Classic did not start")
    check(hero == title.game.player and hero.position == start, "Classic replaced or moved the player")
    check(root.get_camera_2d() == hero.camera and not title.camera.enabled, "Camera handoff failed")
    check(hero.camera.get_screen_center_position().distance_to(title.camera.position) < 2.0, "Camera handoff jumped")
    check(game.ui.visible and not game.ui.overlay.visible and not title.menu.visible, "Classic UI state incorrect")
    Input.action_press("move_right")
    await create_timer(0.12).timeout
    Input.action_release("move_right")
    check(hero.position.x > start.x + 8, "Classic player could not move after handoff")
    var pause := InputEventAction.new()
    pause.action = "pause"
    pause.pressed = true
    game._unhandled_input(pause)
    check(paused and game.ui._mode == "pause", "Classic pause failed")
    npc_start = npc.position
    await create_timer(0.12).timeout
    check(npc.position == npc_start, "Ambient NPC ignored gameplay pause")
    game.ui.resume_requested.emit()
    check(not paused, "Resume failed")
    game.guard.interacted.emit()
    check(game.quest.state == QuestManager.QuestState.ACTIVE, "Guard no longer starts quest")
    game.merchant.interacted.emit()
    check(paused and game.ui._mode == "shop", "Existing merchant did not open")
    game.ui.shop_closed.emit()
    game.ui.restart_requested.emit()
    await frames(6)
    check(current_scene.scene_file_path == "res://scenes/main/game.tscn", "Restart loaded title host")
    check(not paused and not current_scene.ui.overlay.visible, "Restart did not begin classic play directly")
    current_scene.ui.title_requested.emit()
    await frames(6)
    check(current_scene.scene_file_path == TITLE and paused, "Classic title return failed")
    current_scene.menu.buttons[1].pressed.emit()
    await frames(8)
    check(current_scene.scene_file_path == "res://scenes/main/run_game.tscn", "Expedition route failed")
    check(current_scene.phase == "combat" and not paused, "Expedition showed another menu")
    current_scene.ui.title_requested.emit()
    await frames(8)
    check(current_scene.scene_file_path == TITLE and paused, "Expedition title return failed")
    print("TOWN TITLE SMOKE: %d failures" % failures)
    quit(0 if failures == 0 else 1)
