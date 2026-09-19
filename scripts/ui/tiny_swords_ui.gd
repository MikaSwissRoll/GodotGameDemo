class_name TinySwordsUI
extends RefCounted

const SPECIAL_PAPER := "res://asset/UI Elements/UI Elements/Papers/SpecialPaper.png"
const WOOD_TABLE := "res://asset/UI Elements/UI Elements/Wood Table/WoodTable.png"
const BIG_RIBBONS := "res://asset/UI Elements/UI Elements/Ribbons/BigRibbons.png"
const BLUE_BUTTON := "res://asset/UI Elements/UI Elements/Buttons/BigBlueButton_Regular.png"
const BLUE_BUTTON_PRESSED := "res://asset/UI Elements/UI Elements/Buttons/BigBlueButton_Pressed.png"
const RED_BUTTON := "res://asset/UI Elements/UI Elements/Buttons/BigRedButton_Regular.png"
const RED_BUTTON_PRESSED := "res://asset/UI Elements/UI Elements/Buttons/BigRedButton_Pressed.png"
const BAR_BASE := "res://asset/UI Elements/UI Elements/Bars/BigBar_Base.png"

static var _texture_cache: Dictionary = {}


static func panel_style(wood: bool = false) -> StyleBoxTexture:
    var texture := _nine_patch(WOOD_TABLE if wood else SPECIAL_PAPER, 192 if wood else 128)
    var style := StyleBoxTexture.new()
    style.texture = texture
    style.texture_margin_left = 26.0
    style.texture_margin_top = 26.0
    style.texture_margin_right = 26.0
    style.texture_margin_bottom = 26.0
    # Deliberately no content_margin. Setting one made StyleBoxTexture scale the
    # nine-patch's corner regions by (size - 2*content_margin) instead of drawing
    # at the panel's size, so a 690x68 panel painted only 27px tall and its
    # labels fell outside the visible frame. Cells place their own content.
    return style


static func ribbon_style(color_index: int = 0) -> StyleBoxTexture:
    var texture := _horizontal_patch_row(BIG_RIBBONS, 192, 128, clampi(color_index, 0, 4))
    var style := StyleBoxTexture.new()
    style.texture = texture
    style.texture_margin_left = 58.0
    style.texture_margin_right = 58.0
    style.texture_margin_top = 20.0
    style.texture_margin_bottom = 20.0
    style.content_margin_left = 62.0
    style.content_margin_right = 62.0
    return style


static func pouch_panel_style() -> StyleBoxFlat:
    # Backing for the potion/upgrade readout. SpecialPaper's nine-patch does not
    # paint at the Control's rect at HUD sizes (a 68px panel painted 41px,
    # offset ~20px down), so a flat box draws exactly where it is declared.
    var style := StyleBoxFlat.new()
    style.bg_color = Color("#26362f", 0.82)
    style.border_color = Color("#c5ab72")
    style.set_border_width_all(2)
    style.set_corner_radius_all(4)
    return style


static func bar_background_style() -> StyleBoxTexture:
    var style := StyleBoxTexture.new()
    style.texture = _horizontal_patch(BAR_BASE, 128)
    # The caps stay small so the frame still fits inside the HUD bars' 26px
    # height: 12px of top and bottom cap leaves a visible middle stretch band,
    # where the previous 18px margins consumed the whole height and clipped.
    style.texture_margin_left = 26.0
    style.texture_margin_right = 26.0
    style.texture_margin_top = 12.0
    style.texture_margin_bottom = 12.0
    return style


static func bar_fill_style(color: Color) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = color
    style.border_color = color.lightened(0.22)
    style.set_border_width_all(2)
    style.set_corner_radius_all(5)
    # Keep the fill inside the frame. The previous -7px expand margins pushed
    # the fill outside the background's edges, which clipped it top and bottom.
    style.expand_margin_left = -6.0
    style.expand_margin_top = -6.0
    style.expand_margin_right = -6.0
    style.expand_margin_bottom = -6.0
    return style


static func apply_button(button: Button, danger: bool = false) -> void:
    var normal_path := RED_BUTTON if danger else BLUE_BUTTON
    var pressed_path := RED_BUTTON_PRESSED if danger else BLUE_BUTTON_PRESSED
    var normal := _button_style(normal_path)
    var pressed := _button_style(pressed_path)
    var hover := _button_style(normal_path)
    hover.modulate_color = Color(1.12, 1.12, 1.12, 1.0)
    button.add_theme_stylebox_override("normal", normal)
    button.add_theme_stylebox_override("hover", hover)
    button.add_theme_stylebox_override("focus", hover)
    button.add_theme_stylebox_override("pressed", pressed)
    button.add_theme_color_override("font_color", Color("#fff1cf"))
    button.add_theme_color_override("font_hover_color", Color.WHITE)
    button.add_theme_color_override("font_pressed_color", Color("#e7f7ff"))
    button.add_theme_color_override("font_outline_color", Color("#26394a"))
    button.add_theme_constant_override("outline_size", 4)


static func add_icon(parent: Control, texture_path: String, at: Vector2, size: Vector2) -> TextureRect:
    var icon := TextureRect.new()
    icon.texture = load(texture_path) as Texture2D
    icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    icon.position = at
    icon.size = size
    icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(icon)
    return icon


static func _button_style(path: String) -> StyleBoxTexture:
    var style := StyleBoxTexture.new()
    style.texture = _nine_patch(path, 128)
    style.texture_margin_left = 26.0
    style.texture_margin_top = 26.0
    style.texture_margin_right = 26.0
    style.texture_margin_bottom = 26.0
    style.content_margin_left = 24.0
    style.content_margin_top = 12.0
    style.content_margin_right = 24.0
    style.content_margin_bottom = 12.0
    return style


static func _nine_patch(path: String, stride: int) -> Texture2D:
    var key := "%s:%d:nine" % [path, stride]
    if _texture_cache.has(key):
        return _texture_cache[key]
    var source := (load(path) as Texture2D).get_image()
    var result := Image.create(192, 192, false, Image.FORMAT_RGBA8)
    for row in 3:
        for column in 3:
            result.blit_rect(source, Rect2i(column * stride, row * stride, 64, 64),
                Vector2i(column * 64, row * 64))
    var texture := ImageTexture.create_from_image(result)
    _texture_cache[key] = texture
    return texture


static func _horizontal_patch_row(
    path: String, column_stride: int, row_stride: int, row: int
) -> Texture2D:
    var key := "%s:%d:%d:%d:horizontal_row" % [path, column_stride, row_stride, row]
    if _texture_cache.has(key):
        return _texture_cache[key]
    var source := (load(path) as Texture2D).get_image()
    var result := Image.create(192, 64, false, Image.FORMAT_RGBA8)
    for column in 3:
        result.blit_rect(
            source,
            Rect2i(column * column_stride, row * row_stride, 64, 64),
            Vector2i(column * 64, 0)
        )
    var texture := ImageTexture.create_from_image(result)
    _texture_cache[key] = texture
    return texture


static func _horizontal_patch(path: String, stride: int) -> Texture2D:
    var key := "%s:%d:horizontal" % [path, stride]
    if _texture_cache.has(key):
        return _texture_cache[key]
    var source := (load(path) as Texture2D).get_image()
    var result := Image.create(192, 64, false, Image.FORMAT_RGBA8)
    for column in 3:
        result.blit_rect(source, Rect2i(column * stride, 0, 64, 64), Vector2i(column * 64, 0))
    var texture := ImageTexture.create_from_image(result)
    _texture_cache[key] = texture
    return texture
