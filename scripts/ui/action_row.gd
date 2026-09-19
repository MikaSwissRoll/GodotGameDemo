class_name ActionRow
extends Button

## A modal action with a two-line label: a bold name and a smaller effect line.
##
## The Tiny Swords button art is a 3-slice whose frame occupies a fixed 44px —
## measured 24px of cap at the top and 20px at the bottom, regardless of the
## button's height. Its inner band is therefore `height - 44`, and since a 19px
## line box is 27px, a Button can only carry one line of text at any sane height:
## at 77px tall the inner band is 33px, so two lines (54px) spill ~10px past the
## frame at both ends. That is the "text escapes the box" defect.
##
## So the row draws its own two labels inside a taller frame and keeps the
## Button's own text empty. Sizes are fixed constants rather than themed lookups,
## which also makes the height predictable for the caller.

const FRAME_TOP := 24.0
const FRAME_BOTTOM := 20.0
## Breathing room so the smaller line does not touch the frame's rounded corners.
const INSET := 6.0

const NAME_SIZE := 21
const DESC_SIZE := 17
const NAME_HEIGHT := 30.0
const DESC_HEIGHT := 26.0
const GAP := 3.0

## Total height a row needs to show both lines inside the frame.
const FULL_HEIGHT := FRAME_TOP + NAME_HEIGHT + GAP + DESC_HEIGHT + FRAME_BOTTOM + INSET

var _name_label: Label
var _desc_label: Label


func _init() -> void:
    # The Button keeps its text empty so it never competes with the labels.
    focus_mode = Control.FOCUS_NONE
    _name_label = _make_label(NAME_SIZE)
    _desc_label = _make_label(DESC_SIZE)
    add_child(_name_label)
    add_child(_desc_label)
    _layout()


## Dark ink for a row sitting on light paper; the default light ink suits the
## dark blue button surface.
func use_light_paper() -> void:
    for label in [_name_label, _desc_label]:
        label.add_theme_color_override("font_color", Color("#3d2a1d"))
        label.add_theme_color_override("font_outline_color", Color("#f3ead6"))
        label.add_theme_constant_override("outline_size", 0)


func set_row(name_text: String, desc_text: String) -> void:
    _name_label.text = name_text
    _desc_label.text = desc_text
    _desc_label.visible = not desc_text.is_empty()
    _layout()


func _make_label(font_size: int) -> Label:
    var label := Label.new()
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    label.add_theme_font_size_override("font_size", font_size)
    # The art's dark blue interior takes warm light text, as the theme already does.
    label.add_theme_color_override("font_color", Color("#fff1cf"))
    label.add_theme_color_override("font_hover_color", Color.WHITE)
    label.add_theme_color_override("font_outline_color", Color("#26394a"))
    label.add_theme_constant_override("outline_size", 4)
    return label


func _layout() -> void:
    var width := maxf(size.x - 48.0, 1.0)
    var left := (size.x - width) * 0.5
    var lift := (size.y - FULL_HEIGHT) * 0.5
    _name_label.position = Vector2(left, FRAME_TOP + INSET * 0.5 + lift)
    _name_label.size = Vector2(width, NAME_HEIGHT)
    _desc_label.position = Vector2(left, FRAME_TOP + INSET * 0.5 + NAME_HEIGHT + GAP + lift)
    _desc_label.size = Vector2(width, DESC_HEIGHT)


func _notification(what: int) -> void:
    if what == NOTIFICATION_RESIZED:
        _layout()
