extends CanvasLayer
class_name RunUI

const UPGRADES := preload("res://scripts/systems/run_upgrades.gd")
const UI := preload("res://scripts/ui/tiny_swords_ui.gd")
const INK := Color("#f7edcf")
const PANEL_COLOR := Color("#26362f", 0.96)
const EDGE := Color("#c5ab72")

signal start_requested
signal classic_requested
signal quit_requested
signal reward_selected(index: int)
signal buy_health_requested
signal buy_stamina_requested
signal buy_upgrade_requested
signal shop_continue_requested
signal resume_requested
signal restart_requested
signal title_requested

var health_bar: ProgressBar
var stamina_bar: ProgressBar
var health_label: Label
var stamina_label: Label
var boost_label: Label
var gold_label: Label
var stage_label: Label
var potion_label: Label
var build_label: Label
var toast_label: Label
var hud_root: Control
var overlay: ColorRect
var menu_root: Control
var modal_panel: Panel
var menu_buttons: Array[Button] = []
var overlay_title: Label
var overlay_body: Label
var buttons: Array[Button] = []
var mode := ""
var reward_options: Array[String] = []
var _toast_time := 0.0
var _shop_upgrade := ""
var _health_price := 3
var _stamina_price := 3
var _upgrade_price := 5


func _ready() -> void:
    var root := Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(root)
    hud_root = Control.new()
    hud_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_child(hud_root)
    _build_hud(hud_root)
    _build_overlay(root)
    show_menu()


func _process(delta: float) -> void:
    if _toast_time > 0.0:
        _toast_time -= delta
        if _toast_time <= 0.0:
            toast_label.visible = false


func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("pause") and mode == "pause":
        resume_requested.emit()
        get_viewport().set_input_as_handled()


func set_health(current: int, maximum: int) -> void:
    health_bar.max_value = maximum
    health_bar.value = current
    health_label.text = "生命  %d / %d" % [current, maximum]


func set_stamina(current: float, maximum: float) -> void:
    stamina_bar.max_value = maximum
    stamina_bar.value = current
    stamina_label.text = "精力  %d / %d" % [ceili(current), ceili(maximum)]


func set_boost(remaining: float) -> void:
    boost_label.visible = remaining > 0.0
    boost_label.text = "精力恢复加速：%d 秒" % ceili(remaining) if remaining > 0.0 else ""


func set_gold(amount: int) -> void:
    gold_label.text = "金币  %d" % amount


func set_stage(stage: int, remaining: int) -> void:
    if stage <= 3:
        stage_label.text = "第 %d / 3 场  ·  剩余敌人 %d" % [stage, remaining]
    else:
        stage_label.text = "精英战  ·  剩余敌人 %d" % remaining


func set_inventory(health_count: int, stamina_count: int) -> void:
    potion_label.text = "[1] 生命药水 ×%d    [2] 精力药水 ×%d" % [health_count, stamina_count]


func set_build(owned: Dictionary) -> void:
    var names: Array[String] = []
    for id in owned.keys():
        names.append(UPGRADES.name_of(id))
    build_label.text = "本局战技：" + ("无" if names.is_empty() else " · ".join(names))


func show_toast(message: String, seconds: float = 2.0) -> void:
    toast_label.text = message
    toast_label.visible = true
    _toast_time = seconds


func show_menu() -> void:
    mode = "menu"
    hud_root.visible = false
    toast_label.visible = false
    _toast_time = 0.0
    menu_root.visible = true
    modal_panel.visible = false
    overlay.color = Color("#10282a", 0.16)
    overlay.visible = true
    menu_buttons[0].grab_focus()


func show_rewards(options: Array[String]) -> void:
    reward_options = options
    var labels: Array[String] = []
    for id in options:
        labels.append("%s\n%s" % [UPGRADES.name_of(id), UPGRADES.description_of(id)])
    _show("选择本局战技", "战斗获胜，额外获得 1 金币。选一个本局战技。",
        labels, "reward")


func show_shop(gold: int, upgrade_id: String, health_price: int, stamina_price: int, upgrade_price: int) -> void:
    _shop_upgrade = upgrade_id
    _health_price = health_price
    _stamina_price = stamina_price
    _upgrade_price = upgrade_price
    _show("行商营地", "把金币留给保命药水，还是换取新的战技？\n当前金币：%d" % gold,
        ["生命药水  ·  %d 金币" % health_price,
        "精力药水  ·  %d 金币" % stamina_price,
        _upgrade_button_text(),
        "继续远征"], "shop")


func refresh_shop(gold: int, message: String = "") -> void:
    if mode != "shop":
        return
    overlay_body.text = "%s\n当前金币：%d" % [
        message if not message.is_empty() else "把金币留给保命药水，还是换取新的战技？", gold
    ]
    buttons[2].text = _upgrade_button_text()


func mark_shop_upgrade_sold() -> void:
    _shop_upgrade = ""
    buttons[2].text = "本次战技已售出"


func show_pause() -> void:
    _show("暂停", "整顿装备，准备下一场战斗。",
        ["继续游戏", "重新开始本局", "返回主菜单"], "pause")


func show_end(won: bool, summary: String) -> void:
    _show("远征胜利" if won else "远征失败", summary,
        ["再来一局", "返回主菜单"], "win" if won else "dead")


func hide_overlay() -> void:
    mode = ""
    overlay.visible = false
    menu_root.visible = false
    modal_panel.visible = false
    hud_root.visible = true


func _upgrade_button_text() -> String:
    if _shop_upgrade.is_empty():
        return "本次战技已售出"
    return "战技：%s  ·  %d 金币\n%s" % [
        UPGRADES.name_of(_shop_upgrade), _upgrade_price,
        UPGRADES.description_of(_shop_upgrade)
    ]


func _build_hud(root: Control) -> void:
    var stats := _panel(root, Vector2(20, 20), Vector2(320, 146))
    health_label = _label(stats, Vector2(16, 6), Vector2(290, 28), 19)
    health_bar = _bar(stats, Vector2(16, 38), Color("#bf514b"))
    stamina_label = _label(stats, Vector2(16, 73), Vector2(290, 28), 19)
    stamina_bar = _bar(stats, Vector2(16, 105), Color("#d5ae50"))
    boost_label = _label(root, Vector2(26, 169), Vector2(310, 29), 17)
    boost_label.visible = false

    var gold_panel := _panel(root, Vector2(-165, 20), Vector2(145, 52))
    gold_panel.anchor_left = 1.0
    gold_panel.anchor_right = 1.0
    UI.add_icon(gold_panel, "res://asset/UI Elements/UI Elements/Icons/Icon_03.png", Vector2(7, 5), Vector2(42, 42))
    gold_label = _label(gold_panel, Vector2(47, 10), Vector2(90, 30), 21)

    var stage_panel := _panel(root, Vector2(-570, 82), Vector2(550, 53))
    stage_panel.anchor_left = 1.0
    stage_panel.anchor_right = 1.0
    UI.add_icon(stage_panel, "res://asset/UI Elements/UI Elements/Icons/Icon_05.png", Vector2(7, 5), Vector2(42, 42))
    stage_label = _label(stage_panel, Vector2(53, 10), Vector2(480, 32), 20)

    var bottom := _panel(root, Vector2(20, -114), Vector2(690, 90))
    bottom.anchor_top = 1.0
    bottom.anchor_bottom = 1.0
    potion_label = _label(bottom, Vector2(14, 8), Vector2(660, 31), 18)
    build_label = _label(bottom, Vector2(14, 46), Vector2(660, 30), 17)

    var controls := _label(root, Vector2(-520, -45), Vector2(500, 31), 16)
    controls.anchor_left = 1.0
    controls.anchor_right = 1.0
    controls.anchor_top = 1.0
    controls.anchor_bottom = 1.0
    controls.text = "WASD 移动 · 左键挥砍 · 右键举盾 · Shift 冲刺 · Esc 暂停"

    toast_label = _label(root, Vector2(-350, -166), Vector2(700, 70), 23)
    toast_label.anchor_left = 0.5
    toast_label.anchor_right = 0.5
    toast_label.anchor_top = 1.0
    toast_label.anchor_bottom = 1.0
    toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    toast_label.visible = false


func _build_overlay(root: Control) -> void:
    overlay = ColorRect.new()
    overlay.color = Color("#0b1718", 0.77)
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_child(overlay)
    _build_main_menu(overlay)

    modal_panel = _panel(overlay, Vector2(-325, -280), Vector2(650, 560), true)
    modal_panel.anchor_left = 0.5
    modal_panel.anchor_right = 0.5
    modal_panel.anchor_top = 0.5
    modal_panel.anchor_bottom = 0.5
    UI.add_icon(modal_panel, "res://asset/UI Elements/UI Elements/Icons/Icon_06.png", Vector2(297, 18), Vector2(56, 56))
    overlay_title = _label(modal_panel, Vector2(75, 78), Vector2(500, 50), 34)
    overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    overlay_body = _label(modal_panel, Vector2(70, 135), Vector2(510, 64), 20)
    overlay_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    overlay_body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    overlay_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    overlay_body.add_theme_color_override("font_color", Color("#4b3527"))
    for index in 4:
        var button := _button(modal_panel, Vector2(110, 215 + index * 78), Vector2(430, 64))
        button.pressed.connect(_on_button_pressed.bind(index))
        buttons.append(button)


func _build_main_menu(parent: Control) -> void:
    menu_root = Control.new()
    menu_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    parent.add_child(menu_root)

    var card := _panel(menu_root, Vector2(84, 154), Vector2(408, 416))
    var ribbon := Panel.new()
    ribbon.position = Vector2(108, 108)
    ribbon.size = Vector2(370, 88)
    ribbon.add_theme_stylebox_override("panel", UI.ribbon_style(0))
    menu_root.add_child(ribbon)

    UI.add_icon(menu_root, "res://asset/UI Elements/UI Elements/Icons/Icon_06.png",
        Vector2(102, 114), Vector2(76, 76))
    var title := _label(menu_root, Vector2(174, 126), Vector2(270, 52), 38)
    title.text = "边境远征"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    title.add_theme_color_override("font_color", Color("#fff2cf"))
    title.add_theme_color_override("font_outline_color", Color("#26394a"))
    title.add_theme_constant_override("outline_size", 5)

    var subtitle := _label(menu_root, Vector2(124, 220), Vector2(328, 62), 20)
    subtitle.text = "踏出村庄 · 选择战技 · 击败精英"
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    subtitle.add_theme_color_override("font_color", Color("#fff1cf"))
    subtitle.add_theme_color_override("font_outline_color", Color("#26362f"))
    subtitle.add_theme_constant_override("outline_size", 3)

    var divider := ColorRect.new()
    divider.color = Color("#d3a64d")
    divider.position = Vector2(166, 287)
    divider.size = Vector2(244, 2)
    divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
    menu_root.add_child(divider)

    var specs := [
        [Vector2(128, 310), Vector2(320, 66), "开始远征", false],
        [Vector2(151, 392), Vector2(274, 54), "经典冒险", false],
        [Vector2(168, 462), Vector2(240, 50), "退出游戏", true],
    ]
    for index in specs.size():
        var spec: Array = specs[index]
        var button := _button(menu_root, spec[0], spec[1], spec[3])
        button.text = spec[2]
        button.add_theme_font_size_override("font_size", 22 if index == 0 else 19)
        button.pressed.connect(_on_button_pressed.bind(index))
        menu_buttons.append(button)


func _show(title: String, body: String, labels: Array[String], next_mode: String) -> void:
    mode = next_mode
    hud_root.visible = next_mode != "menu"
    menu_root.visible = false
    modal_panel.visible = true
    overlay.color = Color("#0b1718", 0.77)
    toast_label.visible = false
    _toast_time = 0.0
    overlay_title.text = title
    overlay_body.text = body
    for index in 4:
        buttons[index].visible = index < labels.size()
        if index < labels.size():
            buttons[index].text = labels[index]
    overlay.visible = true
    buttons[0].grab_focus()


func _on_button_pressed(index: int) -> void:
    match mode:
        "menu":
            match index:
                0: start_requested.emit()
                1: classic_requested.emit()
                2: quit_requested.emit()
        "reward":
            reward_selected.emit(index)
        "shop":
            match index:
                0: buy_health_requested.emit()
                1: buy_stamina_requested.emit()
                2: buy_upgrade_requested.emit()
                3: shop_continue_requested.emit()
        "pause":
            match index:
                0: resume_requested.emit()
                1: restart_requested.emit()
                2: title_requested.emit()
        "win", "dead":
            if index == 0:
                restart_requested.emit()
            else:
                title_requested.emit()


func _panel(parent: Control, at: Vector2, size: Vector2, wood: bool = false) -> Panel:
    var panel := Panel.new()
    panel.position = at
    panel.size = size
    panel.add_theme_stylebox_override("panel", UI.panel_style(wood))
    parent.add_child(panel)
    return panel


func _label(parent: Control, at: Vector2, size: Vector2, font_size: int) -> Label:
    var label := Label.new()
    label.position = at
    label.size = size
    label.add_theme_color_override("font_color", INK)
    label.add_theme_font_size_override("font_size", font_size)
    parent.add_child(label)
    return label


func _bar(parent: Control, at: Vector2, fill: Color) -> ProgressBar:
    var bar := ProgressBar.new()
    bar.position = at
    bar.size = Vector2(288, 22)
    bar.show_percentage = false
    var background := UI.bar_background_style()
    var foreground := UI.bar_fill_style(fill)
    bar.add_theme_stylebox_override("background", background)
    bar.add_theme_stylebox_override("fill", foreground)
    parent.add_child(bar)
    return bar


func _button(parent: Control, at: Vector2, size: Vector2, danger: bool = false) -> Button:
    var button := Button.new()
    button.position = at
    button.size = size
    button.add_theme_font_size_override("font_size", 19)
    UI.apply_button(button, danger)
    parent.add_child(button)
    return button



