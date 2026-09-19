class_name TinyBar
extends Control

## A health or stamina bar built from the Tiny Swords bar sheet, replacing a flat
## ProgressBar fill.
##
## `Bars/BigBar_Base.png` (320x64) is a horizontal 3-slice with irregular tile
## spacing rather than a nine-patch: left cap x 40..63, middle tile x 128..191,
## right cap x 256..279. NinePatchRect does not stretch this layout correctly at
## any patch margin or axis mode (verified by sweeping margins 6/12/24/40 in both
## STRETCH and TILE) because the caps are not flush with their 64px tiles.
##
## So the bar is composed at the exact requested width instead: caps blitted
## whole, middle tile repeated. The 44px-tall frame carries a recessed band at
## y 25..43, and the gradient from `BigBar_Fill.png` is drawn into that recess.
## Compositing a single texture per ratio keeps the fill inside the frame and
## costs one draw call, and it keeps every edge at native pixel size.

const BASE := "res://asset/UI Elements/UI Elements/Bars/BigBar_Base.png"
const FILL := "res://asset/UI Elements/UI Elements/Bars/BigBar_Fill.png"

const FRAME_HEIGHT := 44
const CAP_LEFT := Rect2i(40, 9, 24, FRAME_HEIGHT)
const MIDDLE := Rect2i(128, 9, 64, FRAME_HEIGHT)
const CAP_RIGHT := Rect2i(256, 9, 24, FRAME_HEIGHT)
## Recessed band inside the frame: y 25..43 in the sheet, 16px below the frame top.
const RECESS_TOP := 16
const RECESS_HEIGHT := 19
## BigBar_Fill's visible band, a vertical gradient (so stretching it is free).
const FILL_BAND := Rect2i(0, 24, 64, RECESS_HEIGHT)

## Setter parameters are deliberately not named after the property: inside a
## setter the parameter shadows it, so `value = clampf(value, ...)` would assign
## to the parameter and silently discard the write.
var max_value: float = 100.0:
    set(new_max):
        max_value = maxf(new_max, 0.0001)
        _mark_dirty()

var value: float = 100.0:
    set(new_value):
        value = clampf(new_value, 0.0, max_value)
        _mark_dirty()

## Tints the shared red fill, so health stays red and stamina reads as gold.
var tint: Color = Color.WHITE:
    set(new_tint):
        tint = new_tint
        _mark_dirty()

var _display: TextureRect
var _source: Image
var _built_width := -1
var _built_ratio := -1.0
var _built_tint := Color(-1, -1, -1, -1)


func _init() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    _source = (load(BASE) as Texture2D).get_image()
    _display = TextureRect.new()
    _display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    _display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    _display.stretch_mode = TextureRect.STRETCH_SCALE
    _display.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(_display)
    _compose()


func ratio() -> float:
    return clampf(value / max_value, 0.0, 1.0)


func _notification(what: int) -> void:
    if what == NOTIFICATION_RESIZED:
        _compose()


func _mark_dirty() -> void:
    _built_width = -1
    _compose()


func _compose() -> void:
    if _display == null or _source == null:
        return
    var width := int(round(size.x))
    var current := ratio()
    if width <= CAP_LEFT.size.x + CAP_RIGHT.size.x or (
        width == _built_width and is_equal_approx(current, _built_ratio) and tint == _built_tint
    ):
        return
    _built_width = width
    _built_ratio = current
    _built_tint = tint

    var result := Image.create(width, FRAME_HEIGHT, false, Image.FORMAT_RGBA8)
    var left := CAP_LEFT.size.x
    var right := width - CAP_RIGHT.size.x
    result.blit_rect(_source, CAP_LEFT, Vector2i(0, 0))
    var x := left
    while x < right:
        var span := mini(MIDDLE.size.x, right - x)
        result.blit_rect(_source, Rect2i(MIDDLE.position, Vector2i(span, FRAME_HEIGHT)), Vector2i(x, 0))
        x += span
    result.blit_rect(_source, CAP_RIGHT, Vector2i(right, 0))

    var span := float(right - left)
    var filled := int(round(span * current))
    if filled > 0:
        var band := _fill_band(filled)
        result.blend_rect(band, Rect2i(0, 0, filled, RECESS_HEIGHT), Vector2i(left, RECESS_TOP))

    _display.texture = ImageTexture.create_from_image(result)


## The gradient, scaled to the requested width and tinted.
func _fill_band(filled: int) -> Image:
    var band := (load(FILL) as Texture2D).get_image().get_region(FILL_BAND)
    band.resize(filled, RECESS_HEIGHT, Image.INTERPOLATE_NEAREST)
    band.convert(Image.FORMAT_RGBA8)
    for y in RECESS_HEIGHT:
        for x in filled:
            var c := band.get_pixel(x, y)
            band.set_pixel(x, y, Color(c.r * tint.r, c.g * tint.g, c.b * tint.b, c.a))
    return band
