class_name TinyBar
extends Control

## A health or stamina bar built from the Tiny Swords bar sheet, replacing a flat
## ProgressBar fill.
##
## The two designs in `Bars/` work differently, and each is used as its artist
## intended rather than forced into one model:
##
##   BigBar (health)    frame y 9..52 with a 19px recess at y 25..43, filled by
##                      the BigBar_Fill gradient. The recess is the track and the
##                      gradient is the value.
##   SmallBar (stamina) frame y 22..40 with a 9px dark track at y 30..38, marked
##                      by SmallBar_Fill, a solid 3px line at y 30..32. The track
##                      is the empty part and the line is the value.
##
## Both sheets are horizontal 3-slices with irregular tile spacing rather than
## nine-patches: caps at x 40..63 / 49..63 and 256..279 / 256..270, middles at
## x 128..191. NinePatchRect does not stretch them correctly at any patch margin
## or axis mode (verified by sweeping margins 6/12/24/40 in both STRETCH and
## TILE), because the caps are not flush with their 64px tiles. So each bar is
## composed at its exact width instead: caps blitted whole, middle tile repeated.
## That keeps every edge at native pixel size and costs one draw call.
##
## Both fills ship red. Stamina needs to read as gold, and multiplying red by
## gold only yields orange, so `tint` is applied as a hue shift plus a tint rather
## than a plain modulate.

## Shifts the fill's hue. Red (hue 0) at -0.92 lands on gold.
const HUE_SHADER := """
shader_type canvas_item;
uniform float hue_shift = 0.0;
uniform vec4 tint : source_color = vec4(1.0);
vec3 shift_hue(vec3 c, float h) {
    vec3 k = vec3(0.57735);
    float angle = h * 6.2831853;
    float cos_a = cos(angle);
    return c * cos_a + cross(k, c) * sin(angle) + k * dot(k, c) * (1.0 - cos_a);
}
void fragment() {
    vec4 tex = texture(TEXTURE, UV);
    if (tex.a < 0.02) {
        discard;
    }
    tex.rgb = shift_hue(tex.rgb, hue_shift) * tint.rgb;
    COLOR = tex;
}
"""

## Per-design sheet geometry, in source pixels.
const DESIGNS := {
    "big": {
        "base": "res://asset/UI Elements/UI Elements/Bars/BigBar_Base.png",
        "fill": "res://asset/UI Elements/UI Elements/Bars/BigBar_Fill.png",
        "left": Rect2i(40, 9, 24, 44),
        "middle": Rect2i(128, 9, 64, 44),
        "right": Rect2i(256, 9, 24, 44),
        # Each cap tile is 24px wide, but only the ~10 columns at its *outer* end
        # are the rounded wood edge; the rest is recessed track. Keeping just the
        # edge lets the fill run all the way to the corners instead of stopping at
        # a dark groove. The outer end is the left of the left cap and the right
        # of the right cap, so the two ends trim from opposite sides.
        "cap_keep": 10,
        "height": 44,
        "track_top": 16,
        "fill_band": Rect2i(0, 24, 64, 19),
        "hue_shift": 0.0,
        "tint": Color.WHITE,
    },
    "small": {
        "base": "res://asset/UI Elements/UI Elements/Bars/SmallBar_Base.png",
        "fill": "res://asset/UI Elements/UI Elements/Bars/SmallBar_Fill.png",
        "left": Rect2i(49, 22, 15, 19),
        "middle": Rect2i(128, 22, 64, 19),
        "right": Rect2i(256, 22, 15, 19),
        "cap_keep": 7,
        "height": 19,
        "track_top": 9,
        "fill_band": Rect2i(0, 30, 64, 3),
        "hue_shift": -0.92,
        "tint": Color.WHITE,
    },
}

var design: String = "big":
    set(new_design):
        design = new_design if DESIGNS.has(new_design) else "big"
        _load_sheet()
        _apply_fill_style()

## Overrides the design's `cap_keep`; 0 uses the design value.
var cap_keep_override: int = 0:
    set(value):
        cap_keep_override = value
        _mark_dirty()


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

var _display: TextureRect
var _fill_layer: TextureRect
var _shader: ShaderMaterial
var _source: Image
var _band: Image
var _built_width := -1
var _built_ratio := -1.0


func _init() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE

    _display = TextureRect.new()
    _display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    _display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    _display.stretch_mode = TextureRect.STRETCH_SCALE
    _display.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(_display)

    # The value artwork is its own layer so the hue shift never touches the frame.
    _fill_layer = TextureRect.new()
    _fill_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    _fill_layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    # Tile, not scale: the band is a 64px source and the bar is 288px wide.
    _fill_layer.stretch_mode = TextureRect.STRETCH_TILE
    _fill_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _shader = ShaderMaterial.new()
    _shader.shader = Shader.new()
    _shader.shader.code = HUE_SHADER
    _fill_layer.material = _shader
    add_child(_fill_layer)

    _load_sheet()
    _apply_fill_style()
    _compose()


func ratio() -> float:
    return clampf(value / max_value, 0.0, 1.0)


## Native frame height for the active design, so callers can size correctly.
func native_height() -> float:
    return float(_geometry()["height"])


func _geometry() -> Dictionary:
    return DESIGNS[design if DESIGNS.has(design) else "big"]


func _load_sheet() -> void:
    var geo := _geometry()
    _source = (load(geo["base"]) as Texture2D).get_image()
    _band = (load(geo["fill"]) as Texture2D).get_image().get_region(geo["fill_band"])


func _apply_fill_style() -> void:
    if _shader == null:
        return
    var geo := _geometry()
    _shader.set_shader_parameter("hue_shift", geo["hue_shift"])
    _shader.set_shader_parameter("tint", geo["tint"])
    _mark_dirty()


func _notification(what: int) -> void:
    if what == NOTIFICATION_RESIZED:
        _compose()


func _mark_dirty() -> void:
    _built_width = -1
    _compose()


func _compose() -> void:
    if _display == null or _source == null or _band == null:
        return
    var geo := _geometry()
    var height: int = geo["height"]
    var keep: int = cap_keep_override if cap_keep_override > 0 else int(geo["cap_keep"])
    # Keep the outer end of each cap: left of the left cap, right of the right cap.
    var left_rect := _outer_edge(geo["left"], keep, false)
    var right_rect := _outer_edge(geo["right"], keep, true)
    var middle: Rect2i = geo["middle"]
    var width := int(round(size.x))
    if width <= left_rect.size.x + right_rect.size.x or width == _built_width:
        return
    _built_width = width

    var result := Image.create(width, height, false, Image.FORMAT_RGBA8)
    var left := left_rect.size.x
    var right := width - right_rect.size.x
    result.blit_rect(_source, left_rect, Vector2i(0, 0))
    var x := left
    while x < right:
        var span := mini(middle.size.x, right - x)
        result.blit_rect(_source, Rect2i(middle.position, Vector2i(span, height)), Vector2i(x, 0))
        x += span
    result.blit_rect(_source, right_rect, Vector2i(right, 0))
    _display.texture = ImageTexture.create_from_image(result)

    # The fill uses the sheet's own colours; only its length changes here.
    _fill_layer.texture = ImageTexture.create_from_image(_band)
    _fill_layer.position = Vector2(left, float(geo["track_top"]))
    _fill_layer.size = Vector2(
        maxf(float(right - left) * ratio(), 0.0),
        float(geo["fill_band"].size.y)
    )


## Keep only the columns at a cap's outer end, where its rounded wood edge is.
func _outer_edge(cap: Rect2i, keep: int, is_right: bool) -> Rect2i:
    var width := maxi(3, mini(keep, cap.size.x))
    var x := cap.position.x + cap.size.x - width if is_right else cap.position.x
    return Rect2i(x, cap.position.y, width, cap.size.y)
