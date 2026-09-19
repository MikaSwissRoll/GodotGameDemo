class_name TinySwordsEnvironment
extends RefCounted

const TILE_SIZE := Vector2i(64, 64)
const WATER := preload("res://asset/Terrain/Tileset/Water Background color.png")
const SHADOW := preload("res://asset/Terrain/Tileset/Shadow.png")
const WATER_FOAM := preload("res://asset/Terrain/Tileset/Water Foam.png")


static func add_water(parent: Node, cells: Vector2i, layer_name: String = "Water") -> TileMapLayer:
    var layer := _new_tile_layer(parent, layer_name, WATER, -30)
    for y in range(cells.y):
        for x in range(cells.x):
            layer.set_cell(Vector2i(x, y), 0, Vector2i.ZERO)
    return layer


static func add_ground_rect(
    parent: Node,
    layer_name: String,
    texture: Texture2D,
    rect: Rect2i,
    z_index: int = -20,
    edges := Vector4i(1, 1, 1, 1)
) -> TileMapLayer:
    var layer := _new_tile_layer(parent, layer_name, texture, z_index)
    for local_y in range(rect.size.y):
        for local_x in range(rect.size.x):
            var atlas_x := 1
            var atlas_y := 1
            if edges.x == 1 and local_x == 0:
                atlas_x = 0
            elif edges.z == 1 and local_x == rect.size.x - 1:
                atlas_x = 2
            if edges.y == 1 and local_y == 0:
                atlas_y = 0
            elif edges.w == 1 and local_y == rect.size.y - 1:
                atlas_y = 2
            layer.set_cell(rect.position + Vector2i(local_x, local_y), 0, Vector2i(atlas_x, atlas_y))
    return layer


static func add_plateau(
    parent: Node,
    layer_name: String,
    texture: Texture2D,
    rect: Rect2i,
    collision: bool = true
) -> TileMapLayer:
    var surface := _new_tile_layer(parent, layer_name, texture, -18)
    for local_y in range(rect.size.y):
        for local_x in range(rect.size.x):
            var atlas_x := 6
            if local_x == 0:
                atlas_x = 5
            elif local_x == rect.size.x - 1:
                atlas_x = 7
            var atlas_y := 1
            if local_y == 0:
                atlas_y = 0
            elif local_y == rect.size.y - 1:
                atlas_y = 3
            surface.set_cell(rect.position + Vector2i(local_x, local_y), 0,
                Vector2i(atlas_x, atlas_y))

    var cliff := _new_tile_layer(parent, layer_name + "Cliff", texture, -17)
    var cliff_y := rect.position.y + rect.size.y
    for local_x in range(rect.size.x):
        var atlas_x := 6
        if local_x == 0:
            atlas_x = 5
        elif local_x == rect.size.x - 1:
            atlas_x = 7
        cliff.set_cell(Vector2i(rect.position.x + local_x, cliff_y), 0,
            Vector2i(atlas_x, 4))
        var shadow := Sprite2D.new()
        shadow.texture = SHADOW
        shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
        shadow.position = Vector2((rect.position.x + local_x) * 64 + 32, cliff_y * 64 + 40)
        shadow.z_index = -19
        parent.add_child(shadow)
    if collision:
        add_wall(parent,
            Vector2((rect.position.x + rect.size.x * 0.5) * 64.0, cliff_y * 64.0 + 32.0),
            Vector2(rect.size.x * 64.0, 58.0))
    return surface


static func add_water_foam(parent: Node, at: Vector2, phase: int = 0) -> AnimatedSprite2D:
    var frames := SpriteFrames.new()
    frames.remove_animation("default")
    frames.add_animation("foam")
    frames.set_animation_speed("foam", 8.0)
    frames.set_animation_loop("foam", true)
    for index in 16:
        var frame := AtlasTexture.new()
        frame.atlas = WATER_FOAM
        frame.region = Rect2(index * 192, 0, 192, 192)
        frames.add_frame("foam", frame)
    var sprite := AnimatedSprite2D.new()
    sprite.sprite_frames = frames
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    sprite.position = at
    sprite.z_index = -16
    parent.add_child(sprite)
    sprite.play("foam")
    sprite.frame = posmod(phase, 16)
    return sprite


static func add_building(
    parent: Node,
    texture_path: String,
    foot: Vector2,
    scale_factor: float = 1.0,
    collision_size := Vector2.ZERO,
    shadow_scale := Vector2(1.0, 0.55)
) -> Sprite2D:
    var texture := load(texture_path) as Texture2D
    var shadow := Sprite2D.new()
    shadow.name = "BuildingShadow"
    shadow.texture = SHADOW
    shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    shadow.position = foot - Vector2(0.0, 22.0)
    shadow.scale = shadow_scale * scale_factor
    shadow.z_index = -4
    parent.add_child(shadow)

    var sprite := Sprite2D.new()
    sprite.name = texture_path.get_file().get_basename()
    sprite.texture = texture
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    sprite.scale = Vector2.ONE * scale_factor
    sprite.position = foot - Vector2(0.0, texture.get_height() * scale_factor * 0.5)
    sprite.z_index = -1
    parent.add_child(sprite)
    if collision_size != Vector2.ZERO:
        add_wall(parent, foot - Vector2(0.0, collision_size.y * 0.5), collision_size)
    return sprite


static func add_tree(
    parent: Node,
    variant: int,
    foot: Vector2,
    scale_factor: float = 0.68,
    add_collision: bool = false,
    phase: int = 0
) -> AnimatedSprite2D:
    var height := 256 if variant <= 2 else 192
    var sprite := add_animated_strip(
        parent,
        "res://asset/Terrain/Resources/Wood/Trees/Tree%d.png" % variant,
        Vector2i(192, height),
        8,
        foot - Vector2(0.0, height * scale_factor * 0.5),
        scale_factor,
        4.0,
        phase
    )
    sprite.z_index = -1
    if add_collision:
        add_wall(parent, foot - Vector2(0.0, 10.0), Vector2(42.0, 30.0) * scale_factor / 0.68)
    return sprite


static func add_bush(
    parent: Node,
    variant: int,
    at: Vector2,
    scale_factor: float = 0.62,
    phase: int = 0
) -> AnimatedSprite2D:
    var sprite := add_animated_strip(
        parent,
        "res://asset/Terrain/Decorations/Bushes/Bushe%d.png" % variant,
        Vector2i(128, 128),
        8,
        at,
        scale_factor,
        4.5,
        phase
    )
    sprite.z_index = -2
    return sprite


static func add_water_rock(parent: Node, variant: int, at: Vector2, phase: int = 0) -> AnimatedSprite2D:
    var sprite := add_animated_strip(
        parent,
        "res://asset/Terrain/Decorations/Rocks in the Water/Water Rocks_0%d.png" % variant,
        Vector2i(64, 64),
        16,
        at,
        1.0,
        7.0,
        phase
    )
    sprite.z_index = -15
    return sprite


static func add_sheep(parent: Node, at: Vector2, phase: int = 0) -> AnimatedSprite2D:
    var sprite := add_animated_strip(
        parent,
        "res://asset/Terrain/Resources/Meat/Sheep/Sheep_Idle.png",
        Vector2i(128, 128),
        6,
        at - Vector2(0.0, 40.0),
        0.7,
        4.0,
        phase
    )
    sprite.z_index = -1
    return sprite


static func add_fire(parent: Node, at: Vector2, variant: int = 1, phase: int = 0) -> AnimatedSprite2D:
    var frame_count := 8 + (variant - 1) * 2
    var sprite := add_animated_strip(
        parent,
        "res://asset/Particle FX/Fire_0%d.png" % variant,
        Vector2i(64, 64),
        frame_count,
        at,
        1.25,
        10.0,
        phase
    )
    sprite.z_index = -1
    return sprite


static func add_static_prop(
    parent: Node,
    texture_path: String,
    at: Vector2,
    scale_factor: float = 1.0,
    z_index: int = -2
) -> Sprite2D:
    var sprite := Sprite2D.new()
    sprite.name = texture_path.get_file().get_basename()
    sprite.texture = load(texture_path) as Texture2D
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    sprite.position = at
    sprite.scale = Vector2.ONE * scale_factor
    sprite.z_index = z_index
    parent.add_child(sprite)
    return sprite


static func add_animated_strip(
    parent: Node,
    texture_path: String,
    frame_size: Vector2i,
    frame_count: int,
    at: Vector2,
    scale_factor: float,
    fps: float,
    phase: int = 0
) -> AnimatedSprite2D:
    var texture := load(texture_path) as Texture2D
    var frames := SpriteFrames.new()
    frames.remove_animation("default")
    frames.add_animation("loop")
    frames.set_animation_speed("loop", fps)
    frames.set_animation_loop("loop", true)
    for index in frame_count:
        var frame := AtlasTexture.new()
        frame.atlas = texture
        frame.region = Rect2(index * frame_size.x, 0, frame_size.x, frame_size.y)
        frames.add_frame("loop", frame)
    var sprite := AnimatedSprite2D.new()
    sprite.sprite_frames = frames
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    sprite.position = at
    sprite.scale = Vector2.ONE * scale_factor
    parent.add_child(sprite)
    sprite.play("loop")
    sprite.frame = posmod(phase, frame_count)
    return sprite


static func add_wall(parent: Node, center: Vector2, size: Vector2) -> StaticBody2D:
    var wall := StaticBody2D.new()
    wall.position = center
    wall.collision_layer = 2
    wall.collision_mask = 0
    var shape := RectangleShape2D.new()
    shape.size = size
    var collision := CollisionShape2D.new()
    collision.shape = shape
    wall.add_child(collision)
    parent.add_child(wall)
    return wall


static func _new_tile_layer(
    parent: Node,
    layer_name: String,
    texture: Texture2D,
    z_index: int
) -> TileMapLayer:
    var tile_set := TileSet.new()
    tile_set.tile_size = TILE_SIZE
    var source := TileSetAtlasSource.new()
    source.texture = texture
    source.texture_region_size = TILE_SIZE
    var columns := floori(float(texture.get_width()) / float(TILE_SIZE.x))
    var rows := floori(float(texture.get_height()) / float(TILE_SIZE.y))
    for y in range(rows):
        for x in range(columns):
            source.create_tile(Vector2i(x, y))
    tile_set.add_source(source, 0)
    var layer := TileMapLayer.new()
    layer.name = layer_name
    layer.tile_set = tile_set
    layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    layer.z_index = z_index
    parent.add_child(layer)
    return layer
