extends Node2D
## Decorative resident: a bounded route with idle stops, no gameplay input.

const FRAMES := preload("res://scripts/systems/sprite_frames_factory.gd")
@export var role := "居民"
@export var idle_sheet: String
@export var walk_sheet: String
@export var frame_size := Vector2i(192, 192)
@export var route := PackedVector2Array()
@export var walk_speed := 34.0
@export var rest_seconds := 2.0
@export var phase := 0.0
var sprite: AnimatedSprite2D
var _destination := 1
var _rest_left := 0.0

func _ready() -> void:
    add_to_group("town_resident")
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    var frames := SpriteFrames.new()
    frames.remove_animation("default")
    for entry in [["idle", idle_sheet], ["walk", walk_sheet]]:
        var sheet := load(entry[1]) as Texture2D
        FRAMES.add_strip(frames, entry[0], entry[1],
            int(float(sheet.get_width()) / frame_size.x), frame_size, 7.0)
    sprite = AnimatedSprite2D.new()
    sprite.sprite_frames = frames
    sprite.scale = Vector2(0.8, 0.8)
    sprite.position = Vector2(0, -30)
    add_child(sprite)
    sprite.play("idle")
    if not route.is_empty():
        position = route[0]
    _rest_left = phase

func _process(delta: float) -> void:
    if route.size() < 2:
        return
    if _rest_left > 0.0:
        _rest_left -= delta
        sprite.play("idle")
        return
    var target := route[_destination]
    var direction := target - position
    if absf(direction.x) > 1.0:
        sprite.flip_h = direction.x < 0.0
    position = position.move_toward(target, walk_speed * delta)
    sprite.play("walk")
    if position.distance_to(target) < 0.5:
        _destination = (_destination + 1) % route.size()
        _rest_left = rest_seconds
        sprite.play("idle")
