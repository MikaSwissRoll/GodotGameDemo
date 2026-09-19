extends RefCounted

static func ensure_actions() -> void:
    _key("move_left", KEY_A)
    _key("move_right", KEY_D)
    _key("move_up", KEY_W)
    _key("move_down", KEY_S)
    _key("attack", KEY_SPACE)
    _mouse("attack", MOUSE_BUTTON_LEFT)
    _mouse("guard", MOUSE_BUTTON_RIGHT)
    _key("dash", KEY_SHIFT)
    _key("interact", KEY_E)
    _key("use_health_potion", KEY_1)
    _key("use_stamina_potion", KEY_2)
    _key("pause", KEY_ESCAPE)


static func _key(action: StringName, code: Key) -> void:
    if not InputMap.has_action(action):
        InputMap.add_action(action)
    var event := InputEventKey.new()
    event.physical_keycode = code
    if not InputMap.action_has_event(action, event):
        InputMap.action_add_event(action, event)


static func _mouse(action: StringName, button: MouseButton) -> void:
    if not InputMap.has_action(action):
        InputMap.add_action(action)
    var event := InputEventMouseButton.new()
    event.button_index = button
    if not InputMap.action_has_event(action, event):
        InputMap.action_add_event(action, event)

