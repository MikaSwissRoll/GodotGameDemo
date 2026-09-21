extends Node2D

const ENV := preload("res://scripts/world/tiny_swords_environment.gd")
const HIGH_GROUND := preload("res://scripts/world/high_ground.gd")
const TOWN := preload("res://scripts/world/starting_town.gd")

## The castle high ground is a stepped union rather than one isolated rectangle.
## Its north edge reaches the map boundary, two shallow shoulders frame the castle,
## and the original forecourt projects south to carry the visible wall and stairs.
## This keeps the gameplay footprint explicit while matching the Tiny Swords
## reference language: the castle belongs to a larger landform instead of sitting on
## a flat coloured stage.
const CASTLE_NORTH_TERRACE := Rect2i(13, 0, 13, 2)
const CASTLE_WEST_SHOULDER := Rect2i(13, 2, 2, 4)
const CASTLE_EAST_SHOULDER := Rect2i(24, 2, 2, 4)
const CASTLE_TERRACE := Rect2i(14, 2, 11, 6)
## The stairs occupy the low-ground side notches immediately outside the forecourt.
## The west stair climbs east into the terrace; the east stair climbs west. Keeping
## them outside the footprint leaves the south wall continuous, as in the reference.
##
## They sit one column further out than the forecourt's edge, and they had to move when
## the forecourt widened: at 14 and 24 they would now be part of the terrace itself
## rather than a notch beside it.
const CASTLE_STAIR_WEST_COLUMN := 13
const CASTLE_STAIR_EAST_COLUMN := 25
const MAP_CELLS := Vector2i(75, 24)
const MAP_SIZE := Vector2(4800.0, 1536.0)
const RIVER_LEFT := 2304.0
const RIVER_RIGHT := 2560.0
const BLUE := "res://asset/Buildings/Blue Buildings/"
const RED := "res://asset/Buildings/Red Buildings/"
const ROCK := "res://asset/Terrain/Decorations/Rocks/Rock%d.png"
const STUMP := "res://asset/Terrain/Resources/Wood/Trees/Stump %d.png"
const GOLD := "res://asset/Terrain/Resources/Gold/Gold Stones/Gold Stone %d.png"
const GRASS_1 := preload("res://asset/Terrain/Tileset/Tilemap_color1.png")
const GRASS_2 := preload("res://asset/Terrain/Tileset/Tilemap_color2.png")
const GRASS_3 := preload("res://asset/Terrain/Tileset/Tilemap_color3.png")
const GRASS_4 := preload("res://asset/Terrain/Tileset/Tilemap_color4.png")

var _art: Node2D


func _ready() -> void:
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    ENV.begin_world()
    _art = Node2D.new()
    _art.name = "EnvironmentArt"
    add_child(_art)
    _build_terrain()
    _build_village()
    _build_borderlands()
    _build_enemy_camp()
    _place_water_details()
    _place_water_walls()
    queue_redraw()


func _draw() -> void:
    var bridge := Rect2(RIVER_LEFT - 24.0, 704.0, RIVER_RIGHT - RIVER_LEFT + 48.0, 192.0)
    draw_rect(bridge, Color("#71503b"))
    draw_rect(bridge.grow(-8.0), Color("#b7794e"))
    for plank_y in range(718, 890, 24):
        draw_line(Vector2(RIVER_LEFT - 12, plank_y), Vector2(RIVER_RIGHT + 12, plank_y),
            Color("#e0a064"), 4.0)
        draw_line(Vector2(RIVER_LEFT - 12, plank_y + 5), Vector2(RIVER_RIGHT + 12, plank_y + 5),
            Color("#674538"), 2.0)
    draw_rect(Rect2(RIVER_LEFT - 30, 696, RIVER_RIGHT - RIVER_LEFT + 60, 12), Color("#4f3b35"))
    draw_rect(Rect2(RIVER_LEFT - 30, 896, RIVER_RIGHT - RIVER_LEFT + 60, 12), Color("#4f3b35"))
    for x in range(int(RIVER_LEFT - 4), int(RIVER_RIGHT + 8), 32):
        draw_circle(Vector2(x, 700), 5.0, Color("#d7bc83"))
        draw_circle(Vector2(x, 902), 5.0, Color("#d7bc83"))


func _build_terrain() -> void:
    ENV.add_water(_art, MAP_CELLS)
    ENV.add_ground_rect(_art, "VillageContinent", GRASS_1,
        Rect2i(0, 0, 36, MAP_CELLS.y), -20, Vector4i(0, 0, 1, 0))
    ENV.add_ground_rect(_art, "EnemyContinent", GRASS_3,
        Rect2i(40, 0, 35, MAP_CELLS.y), -20, Vector4i(1, 0, 0, 0))
    # CastleTerrace, migrated to the elevation model.
    #
    # The original terrain was closer to correct than an earlier revision of this
    # migration gave it credit for: it drew one wall row (right) and placed the two
    # official stair pieces at the two ends of the south wall (right). What was
    # actually broken was that only part of the bottom edge had collision at all, so
    # the sides and top of the terrace were free entry, and that its hand-placed wall
    # was 40px tall at y=510 while the wall row is y 512..576.
    #
    # Now the surface, the one wall row, the collision on all four edges and the two
    # stairs all come from one builder, so the drawn drop and the blocking edge cannot
    # drift apart.
    # Two side entrances, in the low-ground notches immediately outside the ends of
    # the forecourt's south wall: column 14 climbs west to east, column 24 climbs east
    # to west, so each one's raised side faces the terrace.
    #
    # They are declared against the FORECOURT, so each occupies the two rows beside
    # its last surface row and its wall row. That is what opens the side boundary at
    # exactly one column while the south wall itself stays continuous.
    var stairs := [
        HIGH_GROUND.make_stair(CASTLE_STAIR_WEST_COLUMN, true),
        HIGH_GROUND.make_stair(CASTLE_STAIR_EAST_COLUMN, false),
    ]
    # GRASS_3 is a clearly different palette from the village's GRASS_1: raising the
    # ground has to be obvious at a glance, and colour is how the pack says it.
    #
    # Declare the complete union first. Constructing a piece before its neighbours
    # are known would wall the internal seams and split one terrace into four.
    HIGH_GROUND.declare(CASTLE_NORTH_TERRACE)
    HIGH_GROUND.declare(CASTLE_WEST_SHOULDER)
    HIGH_GROUND.declare(CASTLE_EAST_SHOULDER)
    HIGH_GROUND.declare(CASTLE_TERRACE, stairs)
    HIGH_GROUND.construct(_art, "CastleNorthTerrace", GRASS_3,
        CASTLE_NORTH_TERRACE, [], false, true)
    HIGH_GROUND.construct(_art, "CastleWestShoulder", GRASS_3,
        CASTLE_WEST_SHOULDER, [], false, true)
    HIGH_GROUND.construct(_art, "CastleEastShoulder", GRASS_3,
        CASTLE_EAST_SHOULDER, [], false, true)
    HIGH_GROUND.construct(_art, "CastleTerrace", GRASS_3,
        CASTLE_TERRACE, stairs, false, true)
    # Continuous lowland lets roads and grouped scenery describe the village.
    #
    # CampRise is NOT migrated yet: it still uses the old builder through the
    # temporary bridge in `add_plateau`, which registers it with `Elevation` so it
    # stays a real level for actors. It has no ramp, so it is unreachable by design
    # until it gets one - see docs/environment/ELEVATION_AUDIT.md section 11.
    ENV.add_plateau(_art, "CampRise", GRASS_4, Rect2i(53, 1, 19, 9))
    ENV.add_ground_rect(_art, "CampRoad", GRASS_4, Rect2i(40, 10, 31, 4), -18)


func _build_village() -> void:
    var town := TOWN.new()
    _art.add_child(town)


func set_title_active(active: bool) -> void:
    _art.process_mode = Node.PROCESS_MODE_ALWAYS if active else Node.PROCESS_MODE_INHERIT


func _build_borderlands() -> void:
    _tree_cluster(Vector2(2150, 1220), [3, 4], 1)
    _tree_cluster(Vector2(2690, 300), [3, 4, 2], 3)
    _tree_cluster(Vector2(2720, 1320), [1, 4, 3], 6)
    _bush_cluster([Vector2(2060, 620), Vector2(2170, 1070), Vector2(2740, 620),
        Vector2(2820, 1100)], 3)
    _rock_cluster([Vector2(2190, 590), Vector2(2700, 560), Vector2(2820, 1210)], 2)


func _build_enemy_camp() -> void:
    ENV.add_building(_art, RED + "Tower.png", Vector2(3110, 630), 0.72,
        Vector2(68, 38))
    ENV.add_building(_art, RED + "Barracks.png", Vector2(3450, 650), 0.78,
        Vector2(116, 46), Vector2(1.0, 0.58))
    ENV.add_building(_art, RED + "Castle.png", Vector2(3980, 620), 0.96,
        Vector2(230, 60), Vector2(1.75, 0.68))
    ENV.add_building(_art, RED + "Archery.png", Vector2(4450, 650), 0.76,
        Vector2(100, 42))
    ENV.add_building(_art, RED + "Tower.png", Vector2(4670, 630), 0.7,
        Vector2(68, 38))
    ENV.add_building(_art, RED + "House1.png", Vector2(3320, 1320), 0.74,
        Vector2(72, 36))
    ENV.add_building(_art, RED + "House3.png", Vector2(3620, 1320), 0.74,
        Vector2(72, 36))
    ENV.add_building(_art, RED + "Barracks.png", Vector2(4280, 1325), 0.72,
        Vector2(106, 44))

    ENV.add_fire(_art, Vector2(3650, 700), 2, 0)
    ENV.add_fire(_art, Vector2(4220, 700), 3, 4)
    _tree_cluster(Vector2(2880, 330), [4, 3, 2], 1)
    _tree_cluster(Vector2(4540, 300), [4, 3, 1], 4)
    _tree_cluster(Vector2(2960, 1330), [3, 4, 2], 6)
    _tree_cluster(Vector2(4560, 1330), [4, 1, 3], 2)
    _bush_cluster([Vector2(3240, 310), Vector2(3720, 300), Vector2(4320, 315),
        Vector2(3070, 1170), Vector2(3910, 1260), Vector2(4660, 1160)], 5)
    _rock_cluster([Vector2(3040, 1090), Vector2(3420, 1160), Vector2(4050, 1120),
        Vector2(4620, 1050)], 4)
    for index in 4:
        ENV.add_static_prop(_art, STUMP % (index % 4 + 1),
            Vector2(3150 + index * 120, 610 + (index % 2) * 35), 0.42)
    for index in 5:
        ENV.add_static_prop(_art, GOLD % (index % 6 + 1),
            Vector2(4010 + index * 78, 1180 + (index % 2) * 42), 0.46)


func _place_water_details() -> void:
    for data in [
        [1, Vector2(2380, 170), 0], [2, Vector2(2490, 340), 4],
        [3, Vector2(2390, 560), 8], [4, Vector2(2480, 1060), 12],
        [2, Vector2(2385, 1280), 2], [1, Vector2(2480, 1430), 7]
    ]:
        ENV.add_water_foam(_art, data[1], data[2])
        ENV.add_water_rock(_art, data[0], data[1], data[2])
    ENV.add_static_prop(_art,
        "res://asset/Terrain/Decorations/Rubber Duck/Rubber duck.png",
        Vector2(2440, 1160), 1.0, -14)


func _tree_cluster(origin: Vector2, variants: Array, phase: int) -> void:
    var offsets := [Vector2.ZERO, Vector2(84, 22), Vector2(36, 96), Vector2(130, 105)]
    for index in variants.size():
        ENV.add_tree(_art, variants[index], origin + offsets[index],
            0.62 + (index % 2) * 0.07, false, phase + index * 2)


func _bush_cluster(points: Array, phase: int) -> void:
    for index in points.size():
        ENV.add_bush(_art, index % 4 + 1, points[index], 0.58, phase + index)


func _rock_cluster(points: Array, phase: int) -> void:
    for index in points.size():
        ENV.add_static_prop(_art, ROCK % (index % 4 + 1), points[index],
            0.82 + ((phase + index) % 2) * 0.12)


func _place_water_walls() -> void:
    ENV.add_wall(self, Vector2(2432, 344), Vector2(256, 688))
    ENV.add_wall(self, Vector2(2432, 1220), Vector2(256, 632))
