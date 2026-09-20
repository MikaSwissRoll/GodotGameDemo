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
## Companion recruitment. The hire itself is decided by the game, not the UI, so the
## UI only reports which row the player chose.
signal recruit_accepted
signal recruit_declined
## Acknowledging a companion line that carried no decision.
signal dismiss_requested

const INK := Color("#f7edcf")
const PANEL_COLOR := Color("#26362f", 0.94)
const EDGE := Color("#c5ab72")
## Overlay action stack: the band rows are laid out in, and the gap between them.
const MODAL_CONTENT_TOP := 180.0
const MODAL_CONTENT_HEIGHT := 330.0
const ROW_GAP := 16.0
const QUEST_TEXT_RIGHT := -178.0
const QUEST_TEXT_MAX_WIDTH := 520.0
const QUEST_ICON_SIZE := 40.0
const QUEST_ICON_GAP := 8.0

var health_bar: TinyBar
var health_label: Label
var stamina_bar: TinyBar
var stamina_label: Label
var gold_icon: TextureRect
var gold_label: Label
var quest_icon: TextureRect
var quest_label: Label
var potion_label: Label
var boost_label: Label
var toast_label: Label
var hud_root: Control
var overlay: ColorRect
var overlay_panel: Panel
var overlay_title: Label
var overlay_body: Label
var primary_button: ActionRow
var secondary_button: ActionRow
var tertiary_button: ActionRow
var _mode := ""


## Which overlay is up, or "" when the HUD is showing. Exposed read-only so a
## harness can assert that a particular modal did or did not appear.
func current_mode() -> String:
    return _mode
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


## Low-stamina warning. Level 1 is the shallow threshold, level 2 the deeper one.
## The bar shakes here; the character and its state icon are driven by the player,
## so the warning reads as the character and the bar shuddering together.
func _on_stamina_warning(level: int) -> void:
    stamina_bar.shake(6.0 if level >= 2 else 3.0, 0.22 if level >= 2 else 0.16)


## A refused action must never be silent.
func _on_stamina_denied(_action: String) -> void:
    stamina_bar.shake(5.0, 0.18)


## Guard broke from running out of stamina.
func _on_guard_broken_exhausted() -> void:
    stamina_bar.shake(8.0, 0.3)


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
    _layout_quest_group()


## Hide the whole tracker, shield included. Free play has no objective, and leaving
## a finished quest pinned at 5/5 would read as unfinished business.
func set_quest_visible(shown: bool) -> void:
    quest_label.visible = shown
    quest_icon.visible = shown


## Reward feedback for a completed quest step, shown over the character so it reads
## as the player receiving it rather than as a status line.
func show_reward_feedback(text: String) -> void:
    show_toast(text, 2.4)


func _layout_quest_group() -> void:
    # Pin the group before the gold icon, but keep the shield beside the text.
    # The label expands left as objectives grow instead of entering the gold HUD.
    var text_width := minf(
        ceilf(quest_label.get_minimum_size().x),
        QUEST_TEXT_MAX_WIDTH)
    quest_label.offset_right = QUEST_TEXT_RIGHT
    quest_label.offset_left = QUEST_TEXT_RIGHT - text_width
    quest_icon.offset_right = quest_label.offset_left - QUEST_ICON_GAP
    quest_icon.offset_left = quest_icon.offset_right - QUEST_ICON_SIZE


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


## `line` lets the Merchant speak according to progression. Empty falls back to the
## plain shop wording, so existing callers keep working.
func show_shop(gold: int, health_price: int, stamina_price: int, line: String = "") -> void:
    _shop_gold = gold
    _health_price = health_price
    _stamina_price = stamina_price
    var body := "购买药水，按 1 或 2 使用。\n当前金币：%d" % gold
    if not line.is_empty():
        body = "%s\n当前金币：%d" % [line, gold]
    _show_overlay("村庄商人", body, "", "", "shop", "离开商店")
    _refresh_shop_buttons()


## The hire offer. Uses the same overlay and action rows as every other decision,
## so the companion does not introduce a second dialogue framework.
func show_recruit_offer(body: String, hire_label: String, can_hire: bool) -> void:
    _show_overlay("雇佣兵", body, hire_label, "暂时不用", "recruit")
    # A refused offer still reads as a real choice, so the hire row keeps its
    # normal state and simply does nothing when it is unaffordable; the body
    # explains why, which is clearer than a dead button.


## A recruit line with no decision, used for the refusal and for talking to him
## after he has already joined.
func show_recruit_notice(title: String, body: String) -> void:
    _show_overlay(title, body, "知道了", "", "recruit_notice")


func set_shop_message(message: String) -> void:
    if _mode == "shop":
        overlay_body.text = "%s\n当前金币：%d" % [message, _shop_gold]


func _refresh_shop_buttons() -> void:
    primary_button.set_row("生命药水  ·  %d 金币" % _health_price, "")
    secondary_button.set_row("精力药水  ·  %d 金币" % _stamina_price, "")


func _build_hud(root: Control) -> void:
    # Classic keeps the 生命 / 精力 numeric labels (the roguelite HUD drops them),
    # but adopts the same bar art: BigBar for health, SmallBar for stamina.
    health_label = _label(root, Vector2(20, 20), Vector2(280, 26), 19)
    health_bar = _bar(root, Vector2(20, 48), "big", 288.0)
    stamina_label = _label(root, Vector2(20, 104), Vector2(280, 26), 19)
    stamina_bar = _bar(root, Vector2(20, 132), "small", 232.0)

    gold_icon = UI.add_icon(root,
        "res://asset/UI Elements/UI Elements/Icons/Icon_03.png",
        Vector2(1125, 20), Vector2(40, 40))
    gold_icon.anchor_left = 1.0
    gold_icon.anchor_right = 1.0
    gold_icon.offset_left = -155.0
    gold_icon.offset_right = -115.0
    gold_label = _label(root, Vector2(1171, 26), Vector2(78, 28), 21)
    gold_label.anchor_left = 1.0
    gold_label.anchor_right = 1.0
    gold_label.offset_left = -109.0
    gold_label.offset_right = -31.0

    # The group's right edge is fixed before the gold icon. `set_quest()` sizes
    # the label from its current text and moves the shield with its left edge.
    quest_icon = UI.add_icon(root,
        "res://asset/UI Elements/UI Elements/Icons/Icon_06.png",
        Vector2(584, 20), Vector2(40, 40))
    quest_icon.anchor_left = 1.0
    quest_icon.anchor_right = 1.0
    quest_label = _label(root, Vector2(632, 26), Vector2(470, 28), 18)
    quest_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    quest_label.anchor_left = 1.0
    quest_label.anchor_right = 1.0

    # Potion readout on its own backing so it stays legible over the ground.
    var pouch := _pouch_panel(root, Vector2(20, -66), Vector2(400, 48))
    pouch.anchor_top = 1.0
    pouch.anchor_bottom = 1.0
    potion_label = _label(pouch, Vector2(14, 10), Vector2(372, 28), 18)

    # Above the pouch, clear of it.
    boost_label = _label(root, Vector2(20, -96), Vector2(400, 26), 17)
    boost_label.anchor_top = 1.0
    boost_label.anchor_bottom = 1.0
    boost_label.offset_top = -96.0
    boost_label.offset_bottom = -70.0
    boost_label.visible = false

    # Right-aligned along the bottom edge, as in the roguelite HUD, so it never
    # collides with the potion pouch on the left.
    var controls := _label(root, Vector2(-540, -25), Vector2(500, 25), 16)
    controls.anchor_left = 1.0
    controls.anchor_right = 1.0
    controls.anchor_top = 1.0
    controls.anchor_bottom = 1.0
    controls.anchor_left = 1.0
    controls.anchor_right = 1.0
    controls.anchor_top = 1.0
    controls.anchor_bottom = 1.0
    controls.text = "WASD 移动 · 左键挥砍 · 右键举盾 · Shift 冲刺 · E 交谈 · 1／2 药水 · Esc 暂停"
    toast_label = _label(root, Vector2(-400, -170), Vector2(800, 90), 22)
    toast_label.anchor_left = 0.5
    toast_label.anchor_right = 0.5
    toast_label.anchor_top = 1.0
    toast_label.anchor_bottom = 1.0
    toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    toast_label.visible = false


func _bar(parent: Control, at: Vector2, design: String, width: float) -> TinyBar:
    var bar := TinyBar.new()
    bar.design = design
    bar.position = at
    bar.size = Vector2(width, bar.native_height())
    parent.add_child(bar)
    return bar


func _pouch_panel(parent: Control, at: Vector2, dimensions: Vector2) -> Panel:
    var panel := Panel.new()
    panel.position = at
    panel.size = dimensions
    panel.add_theme_stylebox_override("panel", UI.pouch_panel_style())
    parent.add_child(panel)
    return panel


func _build_overlay(root: Control) -> void:
    overlay = ColorRect.new()
    overlay.color = Color("#0b1718", 0.77)
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_child(overlay)

    # SpecialPaper rather than the wood sheet: the wood nine-patch leaves
    # transparent corners, which let actions escape the frame.
    overlay_panel = _panel(overlay, Vector2(-350, -305), Vector2(700, 610), false)
    overlay_panel.anchor_left = 0.5
    overlay_panel.anchor_right = 0.5
    overlay_panel.anchor_top = 0.5
    overlay_panel.anchor_bottom = 0.5

    var emblem := TextureRect.new()
    emblem.texture = load("res://asset/UI Elements/UI Elements/Icons/Icon_06.png") as Texture2D
    emblem.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    emblem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    emblem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    emblem.position = Vector2(330, 30)
    emblem.size = Vector2(40, 40)
    overlay_panel.add_child(emblem)

    overlay_title = _label(overlay_panel, Vector2(100, 82), Vector2(500, 48), 34)
    overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    overlay_body = _label(overlay_panel, Vector2(100, 134), Vector2(500, 78), 20)
    overlay_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    overlay_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

    # Action rows draw their own two-line labels; the Button art's frame is a
    # fixed 44px, so its own text cannot carry two lines inside the frame.
    primary_button = _action_row(overlay_panel, Vector2(70, 200))
    secondary_button = _action_row(overlay_panel, Vector2(70, 320))
    tertiary_button = _action_row(overlay_panel, Vector2(70, 440))
    tertiary_button.visible = false
    primary_button.pressed.connect(_on_primary_pressed)
    secondary_button.pressed.connect(_on_secondary_pressed)
    tertiary_button.pressed.connect(_on_tertiary_pressed)


## Actions that abandon or restart the run take the red destructive state, the
## same rule the roguelite overlays and the main menu's "退出游戏" follow.
const DANGER_BY_MODE := {
    "menu": [1],
    "pause": [1, 2],
    "game_over": [1],
    "complete": [1],
}


func _action_row(parent: Control, at: Vector2) -> ActionRow:
    var row := ActionRow.new()
    row.position = at
    # Overlay labels are single-line, so the row takes its single-line height.
    row.size = Vector2(560, ActionRow.SINGLE_HEIGHT)
    UI.apply_button(row)
    parent.add_child(row)
    return row


## Overlay labels are single-line, so the row shows the name alone.
func _set_row_text(row: ActionRow, text: String) -> void:
    row.set_row(text, "")


func _show_overlay(title: String, body: String, primary: String, secondary: String, mode: String, tertiary: String = "") -> void:
    _mode = mode
    hud_root.visible = mode != "menu"
    overlay_title.text = title
    overlay_body.text = body
    _set_row_text(primary_button, primary)
    _set_row_text(secondary_button, secondary)
    _set_row_text(tertiary_button, tertiary)
    tertiary_button.visible = not tertiary.is_empty()
    # Lay the visible rows out cumulatively and centre the stack on the panel, so
    # two-button modals leave no dead area and the taller row height the art needs
    # is respected rather than assumed.
    var rows: Array[ActionRow] = [primary_button, secondary_button, tertiary_button]
    var visible_rows: Array[ActionRow] = []
    for row in rows:
        if row.visible:
            visible_rows.append(row)
    var total := 0.0
    for row in visible_rows:
        total += row.size.y
    total += ROW_GAP * maxf(visible_rows.size() - 1, 0)
    var top := (MODAL_CONTENT_HEIGHT - total) * 0.5 + MODAL_CONTENT_TOP
    for row in visible_rows:
        row.position.y = top
        top += row.size.y + ROW_GAP
    var danger: Array = DANGER_BY_MODE.get(mode, [])
    UI.apply_button(primary_button, 0 in danger)
    UI.apply_button(secondary_button, 1 in danger)
    UI.apply_button(tertiary_button, 2 in danger)
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
        "recruit": recruit_accepted.emit()
        "recruit_notice": dismiss_requested.emit()


func _on_secondary_pressed() -> void:
    match _mode:
        "menu": quit_requested.emit()
        "pause": restart_requested.emit()
        "shop": buy_stamina_requested.emit()
        "recruit": recruit_declined.emit()
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
    # The HUD no longer sits on a backing panel, so an outline keeps the text
    # legible over bright grass and dark terrain alike.
    label.add_theme_color_override("font_outline_color", Color("#26362f"))
    label.add_theme_constant_override("outline_size", 4)
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    parent.add_child(label)
    return label


func _button(parent: Control, at: Vector2, dimensions: Vector2) -> Button:
    var button := Button.new()
    button.position = at
    button.size = dimensions
    button.add_theme_font_size_override("font_size", 20)
    UI.apply_button(button)
    parent.add_child(button)
    return button
