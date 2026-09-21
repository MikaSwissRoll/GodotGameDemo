extends Node2D

const ENV := preload("res://scripts/world/tiny_swords_environment.gd")
const HIGH_GROUND := preload("res://scripts/world/high_ground.gd")
const TERRAIN := [
    preload("res://asset/Terrain/Tileset/Tilemap_color1.png"),
    preload("res://asset/Terrain/Tileset/Tilemap_color2.png"),
    preload("res://asset/Terrain/Tileset/Tilemap_color3.png"),
    preload("res://asset/Terrain/Tileset/Tilemap_color4.png"),
    preload("res://asset/Terrain/Tileset/Tilemap_color5.png")
]

## A small raised knoll on every expedition stage. Three tiles at most in either
## direction, at a different place and size on each, and kept to the lower half of the
## arena where the stage builders put no buildings.
##
## NO STAIR IS DECLARED and none is wanted. With no ramp the knoll is sealed by
## construction: the wall spans its full width and all four edges carry collision. It is
## a piece of terrain to look at, not somewhere to go. Add a `make_stair` entry here if
## that ever changes - see HIGHGROUND_TILE_GRAMMAR.md section 6.1.
##
## Every rect is inside MainGround, `Rect2i(1, 1, 18, 10)`, so each knoll's wall row
## lands on ground rather than over the water at the arena's edge.
## Stage 5 - the elite fort, the run's boss arena - has NO knoll. The entry is present
## but empty rather than the array being shortened, so every stage index keeps pointing
## at its own entry and adding a stage later cannot silently shift them.
const KNOLL_RECTS := [
    Rect2i(3, 7, 2, 2),
    Rect2i(5, 6, 3, 2),
    Rect2i(2, 4, 2, 3),
    Rect2i(6, 7, 3, 3),
    Rect2i(4, 3, 3, 2),
    Rect2i(),
]

## The knoll's palette, chosen per stage to differ from BOTH the stage ground
## (`terrain_indices`) and its landmark patch (`patch_indices`). Colour is how this pack
## says "higher", so a knoll that matches the ground under it reads as a paint smudge.
const KNOLL_TERRAIN := [2, 4, 2, 0, 2, 0]

const BLUE := "res://asset/Buildings/Blue Buildings/"
const RED := "res://asset/Buildings/Red Buildings/"
const ROCK := "res://asset/Terrain/Decorations/Rocks/Rock%d.png"
const STUMP := "res://asset/Terrain/Resources/Wood/Trees/Stump %d.png"
const GOLD := "res://asset/Terrain/Resources/Gold/Gold Stones/Gold Stone %d.png"

var stage: int = 0
var _stage_root: Node2D


func _ready() -> void:
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    _add_border_collisions()
    configure(0)


func configure(next_stage: int) -> void:
    stage = next_stage
    ENV.begin_world()
    if is_instance_valid(_stage_root):
        _stage_root.queue_free()
    _stage_root = Node2D.new()
    _stage_root.name = "StageArt"
    add_child(_stage_root)
    _build_terrain()
    match stage:
        0:
            _build_village_gate()
        1:
            _build_greenwood()
        2:
            _build_old_shrine()
        3:
            _build_enemy_outpost()
        4:
            _build_trader_clearing()
        5:
            _build_elite_fort()


func _build_terrain() -> void:
    ENV.add_water(_stage_root, Vector2i(20, 12))
    var terrain_indices: Array[int] = [0, 0, 1, 2, 0, 3]
    var terrain_index: int = terrain_indices[stage]
    ENV.add_ground_rect(
        _stage_root,
        "MainGround",
        TERRAIN[terrain_index],
        Rect2i(1, 1, 18, 10)
    )
    var patch_indices: Array[int] = [1, 1, 0, 3, 1, 4]
    var patch_index: int = patch_indices[stage]
    var patches: Array[Rect2i] = [
        Rect2i(7, 1, 6, 3),
        Rect2i(2, 1, 6, 3),
        Rect2i(12, 1, 5, 3),
        Rect2i(12, 1, 6, 3),
        Rect2i(7, 1, 6, 3),
        Rect2i(6, 1, 8, 3)
    ]
    var patch: Rect2i = patches[stage]
    # Expedition stages are flat. The landmark patch keeps its own terrain colour so
    # the arena still reads as a place rather than a featureless field, but it is
    # painted as ordinary ground: no cliff row, no drop shadow, no collision wall,
    # and no entry in the elevation registry. Classic Mode keeps its plateaus.
    ENV.add_ground_rect(_stage_root, "LandmarkGround", TERRAIN[patch_index], patch, -18)
    # The knoll is built last of the terrain so its surface draws over MainGround and
    # the landmark patch. `build` declares and constructs in one call, which is safe
    # here because a stage has exactly one high region - with more than one, every
    # region must be declared before any is constructed.
    #
    # A zero-size entry means this stage has no knoll at all.
    var knoll: Rect2i = KNOLL_RECTS[stage]
    if knoll.size.x > 0 and knoll.size.y > 0:
        HIGH_GROUND.build(_stage_root, "Knoll", TERRAIN[KNOLL_TERRAIN[stage]], knoll)
    if stage != 0:
        for data in [
            [1, Vector2(40, 114), 0], [2, Vector2(1230, 128), 5],
            [3, Vector2(46, 615), 9], [4, Vector2(1228, 604), 13]
        ]:
            ENV.add_water_foam(_stage_root, data[1], data[2] + stage)
            ENV.add_water_rock(_stage_root, data[0], data[1], data[2] + stage)


func _build_village_gate() -> void:
    ENV.add_building(_stage_root, BLUE + "Castle.png", Vector2(640, 285), 0.82,
        Vector2(205, 52), Vector2(1.55, 0.62))
    ENV.add_building(_stage_root, BLUE + "House1.png", Vector2(1010, 276), 0.72,
        Vector2(70, 36))
    ENV.add_building(_stage_root, BLUE + "House2.png", Vector2(1110, 306), 0.68,
        Vector2(70, 34))
    ENV.add_sheep(_stage_root, Vector2(950, 360), 1)
    ENV.add_sheep(_stage_root, Vector2(1080, 390), 4)
    _tree_cluster(Vector2(140, 250), [1, 2, 4], 0)
    _tree_cluster(Vector2(1130, 565), [3, 1], 3)
    _scatter_bushes([Vector2(255, 145), Vector2(330, 160), Vector2(1000, 565)], 0)
    _scatter_rocks([Vector2(190, 570), Vector2(1040, 520)], 0)


func _build_greenwood() -> void:
    ENV.add_building(_stage_root, BLUE + "Tower.png", Vector2(1085, 260), 0.72,
        Vector2(66, 38))
    _tree_cluster(Vector2(145, 245), [1, 2, 3, 4], 1)
    _tree_cluster(Vector2(1070, 560), [2, 4, 1], 5)
    _tree_cluster(Vector2(350, 595), [3, 2], 2)
    _scatter_bushes([
        Vector2(270, 150), Vector2(415, 135), Vector2(920, 150),
        Vector2(985, 565), Vector2(170, 560)
    ], 1)
    _scatter_rocks([Vector2(520, 150), Vector2(1135, 455), Vector2(735, 600)], 1)


func _build_old_shrine() -> void:
    ENV.add_building(_stage_root, BLUE + "Monastery.png", Vector2(1015, 300), 0.62,
        Vector2(82, 42), Vector2(0.8, 0.52))
    ENV.add_building(_stage_root, BLUE + "House3.png", Vector2(1130, 270), 0.58,
        Vector2(62, 30))
    _tree_cluster(Vector2(150, 250), [3, 4, 2], 0)
    _tree_cluster(Vector2(1085, 575), [1, 3], 4)
    _scatter_bushes([
        Vector2(305, 150), Vector2(390, 160), Vector2(880, 580),
        Vector2(1030, 535), Vector2(175, 550)
    ], 2)
    _scatter_rocks([Vector2(505, 145), Vector2(1160, 430), Vector2(305, 575)], 2)
    ENV.add_sheep(_stage_root, Vector2(960, 390), 2)


func _build_enemy_outpost() -> void:
    ENV.add_building(_stage_root, RED + "Barracks.png", Vector2(1030, 290), 0.72,
        Vector2(105, 44), Vector2(0.92, 0.54))
    ENV.add_building(_stage_root, RED + "Tower.png", Vector2(1145, 280), 0.6,
        Vector2(58, 34))
    ENV.add_fire(_stage_root, Vector2(930, 365), 2, 2)
    _tree_cluster(Vector2(150, 260), [4, 3, 4], 2)
    _scatter_bushes([Vector2(275, 150), Vector2(380, 585), Vector2(1110, 555)], 3)
    for index in 3:
        ENV.add_static_prop(_stage_root, STUMP % (index + 1), Vector2(215 + index * 72, 555), 0.42)
    for index in 3:
        ENV.add_static_prop(_stage_root, GOLD % (index + 2), Vector2(1010 + index * 58, 500), 0.44)
    _scatter_rocks([Vector2(470, 145), Vector2(1160, 455), Vector2(700, 600)], 3)


func _build_trader_clearing() -> void:
    ENV.add_building(_stage_root, BLUE + "Archery.png", Vector2(965, 285), 0.64,
        Vector2(84, 38), Vector2(0.88, 0.5))
    ENV.add_building(_stage_root, BLUE + "House2.png", Vector2(1100, 292), 0.62,
        Vector2(64, 32))
    ENV.add_fire(_stage_root, Vector2(530, 430), 1, 3)
    ENV.add_sheep(_stage_root, Vector2(1030, 400), 0)
    _tree_cluster(Vector2(145, 245), [1, 2, 4], 2)
    _tree_cluster(Vector2(1120, 565), [3, 1], 5)
    _scatter_bushes([Vector2(295, 150), Vector2(390, 575), Vector2(925, 550)], 4)
    _scatter_rocks([Vector2(250, 560), Vector2(1160, 440)], 4)


func _build_elite_fort() -> void:
    ENV.add_building(_stage_root, RED + "Castle.png", Vector2(640, 290), 0.82,
        Vector2(210, 54), Vector2(1.55, 0.62))
    ENV.add_building(_stage_root, RED + "Tower.png", Vector2(245, 280), 0.58,
        Vector2(58, 34))
    ENV.add_building(_stage_root, RED + "Tower.png", Vector2(1045, 280), 0.58,
        Vector2(58, 34))
    ENV.add_fire(_stage_root, Vector2(420, 350), 3, 0)
    ENV.add_fire(_stage_root, Vector2(860, 350), 3, 5)
    _tree_cluster(Vector2(150, 560), [4, 3], 1)
    _tree_cluster(Vector2(1130, 565), [4, 3], 4)
    _scatter_bushes([Vector2(180, 170), Vector2(1100, 170), Vector2(325, 585), Vector2(955, 585)], 5)
    _scatter_rocks([Vector2(260, 505), Vector2(1020, 505), Vector2(640, 590)], 5)


func _tree_cluster(origin: Vector2, variants: Array, phase: int) -> void:
    var offsets := [Vector2.ZERO, Vector2(74, 24), Vector2(35, 88), Vector2(118, 82)]
    for index in variants.size():
        ENV.add_tree(_stage_root, variants[index], origin + offsets[index],
            0.58 + (index % 2) * 0.06, false, phase + index * 2)


func _scatter_bushes(points: Array, phase: int) -> void:
    for index in points.size():
        ENV.add_bush(_stage_root, index % 4 + 1, points[index], 0.52, phase + index)


func _scatter_rocks(points: Array, phase: int) -> void:
    for index in points.size():
        ENV.add_static_prop(_stage_root, ROCK % (index % 4 + 1), points[index],
            0.75 + ((phase + index) % 2) * 0.12)


func _add_border_collisions() -> void:
    ENV.add_wall(self, Vector2(640, 58), Vector2(1152, 28))
    ENV.add_wall(self, Vector2(640, 662), Vector2(1152, 28))
    ENV.add_wall(self, Vector2(58, 360), Vector2(28, 604))
    ENV.add_wall(self, Vector2(1222, 360), Vector2(28, 604))
