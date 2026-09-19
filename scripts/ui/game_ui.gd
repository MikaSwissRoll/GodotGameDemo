extends CanvasLayer
class_name GameUI

const UI := preload("res://scripts/ui/tiny_swords_ui.gd")

signal start_requested
signal resume_requested
signal restart_requested
signal title_requested
signal quit_requested
signal buy_health_requested
signal buy_stamina_requested
signal shop_closed

const INK := Color("#f7edcf")
const PANEL_COLOR := Color("#26362f", 0.94)
const EDGE := Color("#c5ab72")

var health_bar: ProgressBar
var health_label: Label
var stamina_bar: ProgressBar
var stamina_label: Label
var gold_label: Label
var quest_label: Label
var potion_label: Label
var boost_label: Label
var toast_label: Label
var hud_root: Control
var overlay: ColorRect
var overlay_panel: Panel
var overlay_title: Label
var overlay_body: Label
var primary_button: Button
var secondary_button: Button
var tertiary_button: Button
var _mode := ""
var _toast_time := 0.0
var _shop_gold := 0
var _health_price := 0
var _stamina_price := 0


func _ready() -> void:
    var root := Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(root)
    hud_root = Control.new()
    hud_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_child(hud_root)
    _build_hud(hud_root)
    _build_overlay(root)
    show_main_menu()


func _process(delta: float) -> void:
    if _toast_time > 0.0:
        _toast_time -= delta
        if _toast_time <= 0.0:
            toast_label.visible = false


func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("pause"):
        if _mode == "pause":
            resume_requested.emit()
            get_viewport().set_input_as_handled()
        elif _mode == "shop":
            shop_closed.emit()
            get_viewport().set_input_as_handled()


func set_health(current: int, maximum: int) -> void:
    health_bar.max_value = maximum
    health_bar.value = current
    health_label.text = "生命  %d / %d" % [current, maximum]


func set_stamina(current: float, maximum: float) -> void:
    stamina_bar.max_value = maximum
    stamina_bar.value = current
    stamina_label.text = "精力  %d / %d" % [ceili(current), ceili(maximum)]


func set_gold(amount: int) -> void:
    gold_label.text = "金币  %d" % amount
    _shop_gold = amount
    if _mode == "shop":
        _refresh_shop_buttons()


func set_inventory(health_count: int, stamina_count: int) -> void:
    potion_label.text = "药水  [1] 生命 ×%d    [2] 精力 ×%d" % [health_count, stamina_count]


func set_stamina_boost(remaining: float) -> void:
    boost_label.text = "精力恢复加速：%d 秒" % ceili(remaining) if remaining > 0.0 else ""
    boost_label.visible = remaining > 0.0


func set_quest(text: String) -> void:
    quest_label.text = text


func show_toast(message: String, seconds: float = 2.8) -> void:
    toast_label.text = message
    toast_label.visible = true
    _toast_time = seconds


func hide_overlay() -> void:
    _mode = ""
    overlay.visible = false
    hud_root.visible = true


func show_main_menu() -> void:
    _show_overlay("小小王国", "边境任务\n\n穿过边境，守护村庄。", "开始游戏", "退出游戏", "menu")


func show_pause() -> void:
    _show_overlay("游戏暂停", "稍作休息，再继续冒险。", "继续游戏", "重新开始", "pause", "返回主菜单")


func show_game_over() -> void:
    _show_overlay("冒险失败", "村庄仍在等待你的帮助。", "重新开始", "返回主菜单", "game_over")


func show_complete() -> void:
    _show_overlay("试玩完成", "盗匪已被击败，村庄恢复了平静。", "继续探索", "返回主菜单", "complete")


func show_shop(gold: int, health_price: int, stamina_price: int) -> void:
    _shop_gold = gold
    _health_price = health_price
    _stamina_price = stamina_price
    _show_overlay("村庄商人", "购买药水，按 1 或 2 使用。\n当前金币：%d" % gold,
        "", "", "shop", "离开商店")
    _refresh_shop_buttons()


func set_shop_message(message: String) -> void:
    if _mode == "shop":
        overlay_body.text = "%s\n当前金币：%d" % [message, _shop_gold]


func _refresh_shop_buttons() -> void:
    primary_button.text = "生命药水  ·  %d 金币" % _health_price
    secondary_button.text = "精力药水  ·  %d 金币" % _stamina_price


func _build_hud(root: Control) -> void:
    var health_panel := _panel(root, Vector2(20, 20), Vector2(330, 145))
    health_label = _label(health_panel, Vector2(17, 7), Vector2(295, 26), 19)
    health_bar = _progress_bar(health_panel, Vector2(17, 35), Color("#bf514b"))
    stamina_label = _label(health_panel, Vector2(17, 72), Vector2(295, 26), 19)
    stamina_bar = _progress_bar(health_panel, Vector2(17, 100), Color("#d5ae50"))

    var gold_panel := _panel(root, Vector2(-170, 20), Vector2(150, 55))
    gold_panel.anchor_left = 1.0
    gold_panel.anchor_right = 1.0
    UI.add_icon(gold_panel, "res://asset/UI Elements/UI Elements/Icons/Icon_03.png", Vector2(7, 6), Vector2(42, 42))
    gold_label = _label(gold_panel, Vector2(48, 13), Vector2(92, 28), 20)

    var quest_panel := _panel(root, Vector2(-715, 91), Vector2(695, 58))
    quest_panel.anchor_left = 1.0
    quest_panel.anchor_right = 1.0
    UI.add_icon(quest_panel, "res://asset/UI Elements/UI Elements/Icons/Icon_06.png", Vector2(7, 7), Vector2(42, 42))
    quest_label = _label(quest_panel, Vector2(53, 13), Vector2(625, 32), 18)

    potion_label = _label(root, Vector2(26, -96), Vector2(660, 30), 18)
    potion_label.anchor_top = 1.0
    potion_label.anchor_bottom = 1.0
    boost_label = _label(root, Vector2(26, -124), Vector2(500, 26), 17)
    boost_label.anchor_top = 1.0
    boost_label.anchor_bottom = 1.0
    boost_label.visible = false

    var controls := _label(root, Vector2(26, -55), Vector2(1210, 44), 16)
    controls.anchor_top = 1.0
    controls.anchor_bottom = 1.0
    controls.text = "WASD 移动  ·  空格／左键挥砍  ·  右键举盾  ·  Shift 冲刺  ·  E 交谈  ·  1／2 使用药水  ·  Esc 暂停"
    controls.add_theme_color_override("font_color", Color("#26362f"))
    controls.add_theme_color_override("font_shadow_color", Color("#eee2b5"))
    controls.add_theme_constant_override("shadow_offset_x", 1)
    controls.add_theme_constant_override("shadow_offset_y", 1)

    toast_label = _label(root, Vector2(-400, -170), Vector2(800, 90), 22)
    toast_label.anchor_left = 0.5
    toast_label.anchor_right = 0.5
    toast_label.anchor_top = 1.0
    toast_label.anchor_bottom = 1.0
    toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    toast_label.visible = false
    toast_label.add_theme_color_override("font_shadow_color", Color.BLACK)
    toast_label.add_theme_constant_override("shadow_offset_x", 2)
    toast_label.add_theme_constant_override("shadow_offset_y", 2)


func _progress_bar(parent: Control, at: Vector2, fill: Color) -> ProgressBar:
    var bar := ProgressBar.new()
    bar.position = at
    bar.size = Vector2(295, 22)
    bar.show_percentage = false
    var bar_back := UI.bar_background_style()
    var bar_fill := UI.bar_fill_style(fill)
    bar.add_theme_stylebox_override("background", bar_back)
    bar.add_theme_stylebox_override("fill", bar_fill)
    parent.add_child(bar)
    return bar


func _build_overlay(root: Control) -> void:
    overlay = ColorRect.new()
    overlay.color = Color("#0b1718", 0.72)
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_child(overlay)

    overlay_panel = _panel(overlay, Vector2(-275, -235), Vector2(550, 470), true)
    overlay_panel.anchor_left = 0.5
    overlay_panel.anchor_right = 0.5
    overlay_panel.anchor_top = 0.5
    overlay_panel.anchor_bottom = 0.5
    var emblem := TextureRect.new()
    emblem.texture = load("res://asset/UI Elements/UI Elements/Icons/Icon_06.png") as Texture2D
    emblem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    emblem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    emblem.position = Vector2(243, 22)
    emblem.size = Vector2(64, 64)
    overlay_panel.add_child(emblem)

    overlay_title = _label(overlay_panel, Vector2(32, 100), Vector2(486, 53), 35)
    overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    overlay_body = _label(overlay_panel, Vector2(40, 175), Vector2(470, 105), 21)
    overlay_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    overlay_body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

    primary_button = _button(overlay_panel, Vector2(150, 314), Vector2(250, 54))
    secondary_button = _button(overlay_panel, Vector2(150, 382), Vector2(250, 48))
    tertiary_button = _button(overlay_panel, Vector2(150, 406), Vector2(250, 48))
    tertiary_button.visible = false
    primary_button.pressed.connect(_on_primary_pressed)
    secondary_button.pressed.connect(_on_secondary_pressed)
    tertiary_button.pressed.connect(_on_tertiary_pressed)


func _show_overlay(title: String, body: String, primary: String, secondary: String, mode: String, tertiary: String = "") -> void:
    _mode = mode
    hud_root.visible = mode != "menu"
    overlay_title.text = title
    overlay_body.text = body
    primary_button.text = primary
    secondary_button.text = secondary
    tertiary_button.text = tertiary
    tertiary_button.visible = not tertiary.is_empty()
    primary_button.position.y = 276.0 if tertiary_button.visible else 314.0
    secondary_button.position.y = 341.0 if tertiary_button.visible else 382.0
    toast_label.visible = false
    _toast_time = 0.0
    overlay.visible = true
    primary_button.grab_focus()


func _on_primary_pressed() -> void:
    match _mode:
        "menu": start_requested.emit()
        "pause", "complete": resume_requested.emit()
        "game_over": restart_requested.emit()
        "shop": buy_health_requested.emit()


func _on_secondary_pressed() -> void:
    match _mode:
        "menu": quit_requested.emit()
        "pause": restart_requested.emit()
        "shop": buy_stamina_requested.emit()
        _: title_requested.emit()


func _on_tertiary_pressed() -> void:
    if _mode == "shop":
        shop_closed.emit()
    else:
        title_requested.emit()


func _panel(parent: Control, at: Vector2, dimensions: Vector2, wood: bool = false) -> Panel:
    var panel := Panel.new()
    panel.position = at
    panel.size = dimensions
    panel.add_theme_stylebox_override("panel", UI.panel_style(wood))
    parent.add_child(panel)
    return panel


func _label(parent: Control, at: Vector2, dimensions: Vector2, font_size: int) -> Label:
    var label := Label.new()
    label.position = at
    label.size = dimensions
    label.add_theme_color_override("font_color", INK)
    label.add_theme_font_size_override("font_size", font_size)
    parent.add_child(label)
    return label


func _button(parent: Control, at: Vector2, dimensions: Vector2) -> Button:
    var button := Button.new()
    button.position = at
    button.size = dimensions
    button.add_theme_font_size_override("font_size", 22)
    UI.apply_button(button)
    parent.add_child(button)
    return button


