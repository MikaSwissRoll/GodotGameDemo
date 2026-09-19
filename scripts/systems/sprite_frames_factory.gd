extends RefCounted


static func add_strip(frames: SpriteFrames, animation: StringName, path: String,
        frame_count: int, frame_size: Vector2i = Vector2i(192, 192),
        fps: float = 10.0) -> void:
    var sheet: Texture2D = load(path)
    assert(sheet != null, "Missing animation sheet: " + path)
    frames.add_animation(animation)
    frames.set_animation_speed(animation, fps)
    for index in frame_count:
        var frame := AtlasTexture.new()
        frame.atlas = sheet
        frame.region = Rect2i(index * frame_size.x, 0, frame_size.x, frame_size.y)
        frames.add_frame(animation, frame)
