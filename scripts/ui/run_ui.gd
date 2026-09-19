extends CanvasLayer
class_name RunUI

const UPGRADES := preload("res://scripts/systems/run_upgrades.gd")
const UI := preload("res://scripts/ui/tiny_swords_ui.gd")
const INK := Color("#f7edcf")
const PANEL_COLOR := Color("#26362f", 0.96)
const EDGE := Color("#c5ab72")
# Sizes are the panel's *painted* area: the nine-patch frame extends outside it.
# MODAL_HEIGHT is the tallest layout (four actions); _show() shrinks the panel to
# the action count actually present, so two-button results leave no dead area.
# Sizes are the Control's declared rect. SpecialPaper's nine-patch fills its rect
# (the wood sheet leaves transparent corners, which let actions escape the frame),
# so 700x610 paints ~665x570 and contains the actions with real margin.
const MODAL_WIDTH := 700.0
const MODAL_HEIGHT := 610.0
const MODAL_BUTTON_WIDTH := 500.0
const MODAL_BUTTON_LEFT := 100.0
const MODAL_BUTTON_TOP := 180.0
const MODAL_BUTTON_STEP := 78.0
const MODAL_BUTTON_HEIGHT := 72.0
const MODAL_PAD := 20.0
# The title and body sit above the first button, so the panel must stay tall
# enough for them; shrinking purely to the button count overlapped the body.
const MODAL_MIN_HEIGHT := 358.0
# Button indices that cancel progress, per docs/art/UI_VISUAL_RULES.md: quitting
# or abandoning a run takes the red destructive state, matching the main menu's
# "退出游戏" button.
const DANGER_BUTTONS := {
    "shop": [2, 3],
    "pause": [1, 2],
    "win": [1],
    "dead": [1],
}

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

var health_bar: TinyBar
var stamina_bar: TinyBar
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


func set_stamina(current: float, maximum: float) -> void:
    stamina_bar.max_value = maximum
    stamina_bar.value = current

func set_boost(remaining: float) -> void:
    boost_label.visible = remaining > 0.0
    boost_label.text = "精力恢复加速：%d 秒" % ceili(remaining) if remaining > 0.0 else ""


func set_gold(amount: int) -> void:
    gold_label.text = "金币  %d" % amount


func set_stage(stage: int, remaining: int) -> void:
    if stage <= 3:
        stage_label.text = "第 %d/3 场 · 剩 %d" % [stage, remaining]
    else:
        stage_label.text = "精英 · 剩 %d" % remaining


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
    # No backing panel and no numeric labels: the art carries the meaning. The
    # bars stack directly, health above stamina, with the shorter stamina bar
    # signalling which is which.
    health_bar = _bar(root, Vector2(20, 20), "big", 288.0)
    stamina_bar = _bar(root, Vector2(20, 68), "small", 232.0)

    boost_label = _label(root, Vector2(20, 98), Vector2(310, 29), 17)
    boost_label.visible = false

    UI.add_icon(root, "res://asset/UI Elements/UI Elements/Icons/Icon_03.png", Vector2(1125, 20), Vector2(40, 40))
    gold_label = _label(root, Vector2(1171, 26), Vector2(78, 28), 21)
    gold_label.anchor_left = 1.0
    gold_label.anchor_right = 1.0
    gold_label.offset_left = -109.0
    gold_label.offset_right = -31.0

    # Battlefield info shares the gold row, to its left, right-aligned so it grows
    # away from the gold readout instead of into it.
    UI.add_icon(root, "res://asset/UI Elements/UI Elements/Icons/Icon_05.png", Vector2(864, 20), Vector2(40, 40))
    stage_label = _label(root, Vector2(912, 26), Vector2(178, 28), 20)
    stage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    stage_label.anchor_left = 1.0
    stage_label.anchor_right = 1.0
    stage_label.offset_left = -368.0
    stage_label.offset_right = -190.0

    # Potion and run-upgrade readout, on its own backing so it stays legible
    # over the arena floor.
    var pouch := _hud_panel(root, Vector2(20, -86), Vector2(430, 62))
    pouch.anchor_top = 1.0
    pouch.anchor_bottom = 1.0
    potion_label = _label(pouch, Vector2(14, 8), Vector2(402, 24), 18)
    build_label = _label(pouch, Vector2(14, 32), Vector2(402, 22), 17)

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

    modal_panel = _panel(overlay, Vector2(-MODAL_WIDTH * 0.5, -MODAL_HEIGHT * 0.5), Vector2(MODAL_WIDTH, MODAL_HEIGHT), false)
    modal_panel.anchor_left = 0.5
    modal_panel.anchor_right = 0.5
    modal_panel.anchor_top = 0.5
    modal_panel.anchor_bottom = 0.5
    UI.add_icon(modal_panel, "res://asset/UI Elements/UI Elements/Icons/Icon_06.png", Vector2(330, 30), Vector2(40, 40))
    overlay_title = _label(modal_panel, Vector2(100, 82), Vector2(500, 48), 34)
    overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    overlay_body = _label(modal_panel, Vector2(100, 134), Vector2(500, 40), 20)
    overlay_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    overlay_body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    overlay_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    overlay_body.add_theme_color_override("font_color", INK)
    # Evenly gap-separated actions, contained by the panel's visible frame.
    for index in 4:
        var button := _button(modal_panel, Vector2(MODAL_BUTTON_LEFT, MODAL_BUTTON_TOP + index * MODAL_BUTTON_STEP), Vector2(MODAL_BUTTON_WIDTH, MODAL_BUTTON_HEIGHT))
        button.pressed.connect(_on_button_pressed.bind(index))
        buttons.append(button)


func _build_main_menu(parent: Control) -> void:
    menu_root = Control.new()
    menu_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    parent.add_child(menu_root)

    # The card is the menu: it holds the banner, subtitle, divider, and all three
    # buttons, so nothing overlaps its border or leaves a dead area. The declared
    # 400x428 is the painted area; the nine-patch frame adds ~85px per side.
    # SpecialPaper's tiles align with the nine-patch sampling, unlike the wood
    # sheet, whose tiles sit at offsets that would sample empty space.
    var card := _panel(menu_root, Vector2(440, 146), Vector2(400, 428))
    _banner(menu_root, Vector2(455, 126), Vector2(370, 56))

    UI.add_icon(menu_root, "res://asset/UI Elements/UI Elements/Icons/Icon_06.png",
        Vector2(470, 136), Vector2(36, 36))
    var title := _label(menu_root, Vector2(514, 136), Vector2(296, 36), 33)
    title.text = "边境远征"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    title.add_theme_color_override("font_color", Color("#f7edcf"))
    title.add_theme_constant_override("outline_size", 0)

    # SpecialPaper renders as dark slate (#525b66), so the card takes warm light
    # ink rather than the dark ink used on genuinely light surfaces.
    var subtitle := _label(menu_root, Vector2(480, 208), Vector2(320, 28), 20)
    subtitle.text = "踏出村庄 · 选择战技 · 击败精英"
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    subtitle.add_theme_color_override("font_color", INK)
    subtitle.add_theme_constant_override("outline_size", 0)

    var divider := ColorRect.new()
    divider.color = Color("#d3a64d")
    divider.position = Vector2(520, 248)
    divider.size = Vector2(240, 2)
    divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
    menu_root.add_child(divider)

    var specs := [
        [Vector2(495, 274), Vector2(290, 64), "开始远征", false, 22],
        [Vector2(495, 350), Vector2(290, 64), "经典冒险", false, 20],
        [Vector2(495, 426), Vector2(290, 64), "退出游戏", true, 20],
    ]
    for index in specs.size():
        var spec: Array = specs[index]
        var button := _button(menu_root, spec[0], spec[1], spec[3])
        button.text = spec[2]
        button.add_theme_font_size_override("font_size", spec[4])
        button.pressed.connect(_on_button_pressed.bind(index))
        menu_buttons.append(button)


func _banner(parent: Control, at: Vector2, size: Vector2) -> Panel:
    var banner := Panel.new()
    banner.position = at
    banner.size = size
    var style := StyleBoxFlat.new()
    style.bg_color = Color("#2b3b52")
    style.border_color = Color("#c5ab72")
    style.set_border_width_all(2)
    style.set_corner_radius_all(4)
    banner.add_theme_stylebox_override("panel", style)
    parent.add_child(banner)
    return banner


func _show(title: String, body: String, labels: Array[String], next_mode: String) -> void:
    mode = next_mode
    # A run-ending or shop modal makes the combat HUD irrelevant, so subordinate
    # it. Keep it for "pause", where the frozen HUD is the visible pause context
    # the art rules ask for.
    hud_root.visible = next_mode == "pause"
    menu_root.visible = false
    modal_panel.visible = true
    overlay.color = Color("#0b1718", 0.77)
    toast_label.visible = false
    _toast_time = 0.0
    overlay_title.text = title
    overlay_body.text = body
    var danger: Array = DANGER_BUTTONS.get(next_mode, [])
    for index in 4:
        buttons[index].visible = index < labels.size()
        if index < labels.size():
            buttons[index].text = labels[index]
            # Re-apply per state: the same Button instance is reused across
            # overlay modes, so the destructive style must be set and cleared.
            UI.apply_button(buttons[index], index in danger)
    # Fit the panel to the action count. A fixed height left a large dead area
    # under two-button results such as "远征失败".
    # Center-anchored, so offsets are relative to the viewport centre; assigning
    # `position` here would be re-derived against the anchor and push the panel
    # off-screen, so set the offsets that `position` is computed from.
    var needed := maxf(
        MODAL_BUTTON_TOP + MODAL_BUTTON_STEP * (labels.size() - 1) + MODAL_BUTTON_HEIGHT,
        MODAL_MIN_HEIGHT
    ) + MODAL_PAD
    modal_panel.offset_left = -MODAL_WIDTH * 0.5
    modal_panel.offset_right = MODAL_WIDTH * 0.5
    modal_panel.offset_top = -needed * 0.5
    modal_panel.offset_bottom = needed * 0.5
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


func _hud_panel(parent: Control, at: Vector2, size: Vector2) -> Panel:
    var panel := Panel.new()
    panel.position = at
    panel.size = size
    panel.add_theme_stylebox_override("panel", UI.pouch_panel_style())
    parent.add_child(panel)
    return panel


func _label(parent: Control, at: Vector2, size: Vector2, font_size: int) -> Label:
    var label := Label.new()
    label.position = at
    label.size = size
    label.add_theme_color_override("font_color", INK)
    label.add_theme_font_size_override("font_size", font_size)
    # The HUD has no backing panel, so an outline keeps the text legible over
    # both bright grass and dark terrain.
    label.add_theme_color_override("font_outline_color", Color("#26362f"))
    label.add_theme_constant_override("outline_size", 4)
    # Center the line box inside its slot. Top-aligned text sat against the
    # panel's frame, so glyphs read as escaping the box they belong to.
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    parent.add_child(label)
    return label


func _bar(parent: Control, at: Vector2, design: String, width: float) -> TinyBar:
    var bar := TinyBar.new()
    # Setting `design` also applies that design's default fill tint; an explicit
    # assignment here would be redundant and is avoided so the sheet owns its look.
    bar.design = design
    bar.position = at
    # Each design is used at its native frame height so the caps stay crisp;
    # only the width varies, and only the middle tile repeats.
    bar.size = Vector2(width, bar.native_height())
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



