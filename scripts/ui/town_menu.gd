extends CanvasLayer
## Side menu over the live classic town. Gameplay input is owned by the title.
const UI := preload("res://scripts/ui/tiny_swords_ui.gd")
signal classic_requested
signal expedition_requested
signal quit_requested
var root: Control
var panel: Panel
var title_label: Label
var buttons: Array[ActionRow] = []
var locked := false

func _ready() -> void:
    layer = 20
    process_mode = Node.PROCESS_MODE_ALWAYS
    root = Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(root)
    panel = Panel.new()
    panel.size = Vector2(350, 452)
    panel.add_theme_stylebox_override("panel", UI.panel_style())
    root.add_child(panel)
    UI.add_icon(panel, "res://asset/UI Elements/UI Elements/Icons/Icon_06.png",
        Vector2(148, 26), Vector2(54, 54))
    title_label = Label.new()
    title_label.text = "边境远征"
    title_label.position = Vector2(30, 90)
    title_label.size = Vector2(290, 60)
    title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title_label.add_theme_font_size_override("font_size", 42)
    title_label.add_theme_color_override("font_color", UI.INK_CREAM)
    title_label.add_theme_color_override("font_outline_color", Color("#26394a"))
    title_label.add_theme_constant_override("outline_size", 4)
    title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    panel.add_child(title_label)
    var labels := ["经典模式", "远征模式", "退出游戏"]
    for i in labels.size():
        var button := ActionRow.new()
        button.name = "Action%d" % i
        button.position = Vector2(34, 174 + i * 84)
        button.size = Vector2(282, ActionRow.SINGLE_HEIGHT)
        button.set_row(labels[i], "")
        UI.apply_button(button, i == 2)
        # A transparent focus ring must not repaint normal art over pressed art.
        var focus := StyleBoxFlat.new()
        focus.draw_center = false
        focus.border_color = Color("#f5d781")
        focus.set_border_width_all(2)
        focus.set_corner_radius_all(5)
        focus.expand_margin_left = -19
        focus.expand_margin_right = -19
        focus.expand_margin_top = -18
        focus.expand_margin_bottom = -18
        button.add_theme_stylebox_override("focus", focus)
        # The shared helper has no disabled art; retain the source face while
        # briefly locking this title during the camera handoff.
        var disabled := button.get_theme_stylebox("normal").duplicate() as StyleBoxTexture
        disabled.modulate_color = Color(0.72, 0.72, 0.72)
        button.add_theme_stylebox_override("disabled", disabled)
        panel.add_child(button)
        buttons.append(button)
        button.pressed.connect(_activate.bind(i))
    for i in buttons.size():
        buttons[i].focus_neighbor_top = buttons[i].get_path_to(buttons[posmod(i - 1, 3)])
        buttons[i].focus_neighbor_bottom = buttons[i].get_path_to(buttons[(i + 1) % 3])
    get_viewport().size_changed.connect(_layout)
    _layout()
    buttons[0].grab_focus()

func _layout() -> void:
    panel.position = Vector2(32, roundf((get_viewport().get_visible_rect().size.y - panel.size.y) * 0.5))

func set_locked(value: bool) -> void:
    locked = value
    for button in buttons:
        button.disabled = value
        if value:
            button.release_focus()

func _activate(index: int) -> void:
    if locked:
        return
    match index:
        0: classic_requested.emit()
        1: expedition_requested.emit()
        2: quit_requested.emit()
