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


## Surface choice for modal panels, measured from the pack rather than assumed:
##   SpecialPaper  the only sheet whose 3x3 tiles render a clean solid panel.
##   RegularPaper  its middle tile row is transparent and the corner tiles carry
##                 baked-in padding, so it tiles as separated cards, not a surface.
##   Banner        the scroll curl repeats as visible stripes when tiled.
const REGULAR_PAPER := "res://asset/UI Elements/UI Elements/Papers/RegularPaper.png"
## Text colours for the dark SpecialPaper surface.
const INK_CREAM := Color("#f7edcf")
const INK_CREAM_BRIGHT := Color("#fff1cf")


static func paper_panel_style() -> StyleBoxTexture:
    var style := StyleBoxTexture.new()
    style.texture = _nine_patch(SPECIAL_PAPER, 128)
    style.texture_margin_left = 52.0
    style.texture_margin_top = 52.0
    style.texture_margin_right = 52.0
    style.texture_margin_bottom = 52.0
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


## Marker shown above an interactable NPC, cut from the Shikashi atlas.
##
## That sheet is a 16-column grid of 32px cells whose rows are NOT full, so a cell
## is addressed by its measured pixel rect rather than by counting columns: this
## one is row 0 col 3, the three-dot speech bubble, inner box (4,6,24,22). See
## docs/ui/UI_ASSET_GUIDE.md for the recording procedure.
const SHIKASHI_SHEET := "res://asset/Shikashi's Fantasy Icons Pack v2/#1 - Transparent Icons.png"
const SHIKASHI_BUBBLE := Rect2i(96, 0, 32, 32)

## Stamina state icons, also from the Shikashi sheet. The Tiny Swords icon set has
## no fatigue or warning concept (its twelve icons are items: logs, meat, coin,
## sword, shield, gems, cross, gear, info, notes), so these come from the fantasy
## pack, addressed by measured pixel rect as always.
##   sweat  a droplet, for the first warning step
##   zzz    sleep, for the deeper warning
##   swoon  a dazed face, for the guard-break exhausted state
const SHIKASHI_SWEAT := Rect2i(320, 0, 32, 32)
const SHIKASHI_ZZZ := Rect2i(224, 0, 32, 32)
const SHIKASHI_SWOON := Rect2i(128, 0, 32, 32)

## Local-space placement for the marker and the interaction prompt.
##
## Measured from the running scene, because the sprite metrics are misleading: a
## pawn frame is 192px but the character only occupies rows 64..134 of it, and the
## AnimatedSprite2D node ends up at scale 1.0 (not the 0.8 that the resident
## Local-space placement for the marker and the interaction prompt.
##
## Sprite metrics mislead here, so these come from the running scene: a pawn frame
## is 192px, but the character only occupies rows 64..134 of it, and the
## AnimatedSprite2D sits at position y=-36 with scale 1.0. The topmost visible
## pixel -- the hair, not the face -- is therefore local y=-68, not the -132 the
## frame size suggests and not the -61.6 a 0.8 scale would give.
##
## The marker icon is 32px drawn at 2x, so its cell is 64px tall and its tail
## hangs 11px below the cell centre. At -95 the cell bottom is -127 and the tail
## tip -73, leaving 5px of clearance above the hair at -68. That is as close as the
## bubble can sit without touching the sprite.
##
## Values further out (-146, -175, -277) were tried and read as detached from the
## NPC, which is the defect this replaced.
const INTERACT_MARKER_Y := -95.0
const INTERACT_MARKER_X := 10.0
## Sitting just under the bubble's tail.
const INTERACT_PROMPT_Y := -77.0
## A gentle bob so the marker reads as a live invitation rather than a decal.
const INTERACT_BOB := 4.0
const INTERACT_BOB_SPEED := 2.6


static func add_interact_marker(parent: Node2D, phase: float = 0.0) -> Sprite2D:
    var marker := Sprite2D.new()
    var icon := AtlasTexture.new()
    icon.atlas = load(SHIKASHI_SHEET) as Texture2D
    icon.region = SHIKASHI_BUBBLE
    marker.texture = icon
    marker.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    # 2x: the sheet is authored at 32px, which is small over a 1280x720 viewport.
    # An integer scale keeps the pixels sharp.
    marker.scale = Vector2(2.0, 2.0)
    marker.position = Vector2(INTERACT_MARKER_X, INTERACT_MARKER_Y)
    marker.z_index = 1
    marker.set_meta("bob_phase", phase)
    parent.add_child(marker)
    return marker


static func set_interact_marker_visible(marker: Sprite2D, shown: bool) -> void:
    marker.visible = shown
    # Reset to a neutral offset on appear, so it does not pop in mid-bounce.
    if shown:
        marker.position.y = INTERACT_MARKER_Y


## A small state icon, cut from the same atlas as the NPC marker. `region` is one
## of the SHIKASHI_* rects above. Returns the Sprite2D so callers can move or
## re-texture it; nearest-filtered at an integer scale so it stays crisp against
## the 32px source. Takes a Node parent so it works under either a Control or a
## Node2D host.
static func make_state_icon(parent: Node, region: Rect2i, icon_scale: float = 0.75) -> Sprite2D:
    var icon := Sprite2D.new()
    var tex := AtlasTexture.new()
    tex.atlas = load(SHIKASHI_SHEET) as Texture2D
    tex.region = region
    icon.texture = tex
    icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    icon.scale = Vector2(icon_scale, icon_scale)
    icon.visible = false
    parent.add_child(icon)
    return icon


## Advance the marker bob. Call from the owner's _process with a running time.
static func animate_interact_marker(marker: Sprite2D, time: float) -> void:
    if not marker.visible:
        return
    var phase: float = marker.get_meta("bob_phase", 0.0)
    marker.position.y = INTERACT_MARKER_Y + sin(time * INTERACT_BOB_SPEED + phase) * INTERACT_BOB


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


## Nine-patch a texture sheet whose 3x3 tiles sit at `stride` intervals with
## per-axis offsets. Several sheets in the pack need this: their tiles are 64px
## but not flush with the image edge, and the X and Y paddings differ (the light
## paper is 12 across and 20 down), so one shared offset samples empty pixels.
static func patched(path: String, stride: int, offset_x: int = 0, offset_y: int = -1) -> Texture2D:
    var oy := offset_x if offset_y < 0 else offset_y
    var key := "%s:%d:%d:%d:nine" % [path, stride, offset_x, oy]
    if _texture_cache.has(key):
        return _texture_cache[key]
    var source := (load(path) as Texture2D).get_image()
    var result := Image.create(192, 192, false, Image.FORMAT_RGBA8)
    for row in 3:
        for column in 3:
            result.blit_rect(source,
                Rect2i(offset_x + column * stride, oy + row * stride, 64, 64),
                Vector2i(column * 64, row * 64))
    var texture := ImageTexture.create_from_image(result)
    _texture_cache[key] = texture
    return texture


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
