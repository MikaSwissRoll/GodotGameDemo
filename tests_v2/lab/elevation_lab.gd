extends Node2D

## ElevationLab — the isolated reference implementation for high ground.
##
## Two roles:
##   1. technical reference: the smallest scene that exercises LOW, HIGH, a cliff
##      boundary and a legal ramp, with nothing else in the way;
##   2. visual reference: the correct way to compose Tiny Swords high ground, per
##      docs/environment/HIGHGROUND_TILE_GRAMMAR.md.
##
## Deliberately contains no quests, no Merchant, no Guard, no village, no free-play
## spawning and no decoration. Adding any of those makes it useless as a reference.
##
## Layout, in tiles (64px). The room is 20x11.
##
##   rows 0        room boundary
##   rows 1-3      WEST terrace, cols 1-11     <- rim 1, interior 2, lip 3; face 4-5
##   rows 1-4      EAST terrace, cols 12-18    <- one row deeper, so the cliff line
##                                                steps and the silhouette is not a box
##   rows 5-6      east cliff face
##   rows 6-10     LOW ground
##
## The ramp is a staggered two-step stair in the west face: a narrow upper tread at
## cols 5-6 in face row 4, and a wider lower tread at cols 4-7 in face row 5. Each
## tread is flanked by stone, so the opening reads as steps rather than as a hole in
## a wall. The tileset has no ramp art, so this composition is the only honest way
## to draw one - see the grammar, section 4.

const ENV := preload("res://scripts/world/tiny_swords_environment.gd")
const HIGH_GROUND := preload("res://scripts/world/high_ground.gd")

const LOW_TEXTURE := preload("res://asset/Terrain/Tileset/Tilemap_color1.png")
## Both terraces share ONE palette: they are a single landform built from two rects,
## and two palettes meeting mid-terrace reads as two materials butted together. The
## grammar varies palette between regions, never within one.
const HIGH_TEXTURE := preload("res://asset/Terrain/Tileset/Tilemap_color2.png")

const ROOM_TILES := Vector2i(20, 11)
const WEST_TERRACE := Rect2i(1, 1, 11, 3)
const EAST_TERRACE := Rect2i(12, 1, 7, 4)
const RAMP_UPPER := Rect2i(5, 4, 2, 1)
const RAMP_LOWER := Rect2i(4, 5, 4, 1)
const LOW_GROUND := Rect2i(1, 6, 18, 5)

## Where the scenario suite and a human put things.
const LOW_SPAWN := Vector2(320.0, 520.0)
const HIGH_SPAWN := Vector2(150.0, 150.0)
const RAMP_MOUTH := Vector2(384.0, 440.0)
const RAMP_TOP := Vector2(384.0, 200.0)
const CLIFF_APPROACH := Vector2(150.0, 520.0)

var _art: Node2D


func _ready() -> void:
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    build()


func build() -> void:
    Elevation.begin_field()
    ENV.begin_world()

    _art = Node2D.new()
    _art.name = "LabArt"
    add_child(_art)

    ENV.add_water(_art, ROOM_TILES)
    ENV.add_ground_rect(_art, "LowGround", LOW_TEXTURE, LOW_GROUND, -20)
    # Declare BOTH terraces before constructing either. The boundary builder asks
    # whether the tile beyond an edge is also high ground, so the join between the
    # two can only be left open once both are known.
    HIGH_GROUND.declare(WEST_TERRACE, [RAMP_UPPER, RAMP_LOWER])
    HIGH_GROUND.declare(EAST_TERRACE, [])
    HIGH_GROUND.construct(_art, "WestTerrace", HIGH_TEXTURE, WEST_TERRACE, [RAMP_UPPER, RAMP_LOWER])
    HIGH_GROUND.construct(_art, "EastTerrace", HIGH_TEXTURE, EAST_TERRACE, [])
    _add_room_boundary()

    var player := get_node_or_null("Player") as Player
    if player != null:
        player.movement_bounds = Rect2(40.0, 40.0, 1200.0, 624.0)
        player.camera.limit_left = 0
        player.camera.limit_top = 0
        player.camera.limit_right = ROOM_TILES.x * 64
        player.camera.limit_bottom = ROOM_TILES.y * 64


func _add_room_boundary() -> void:
    var w := float(ROOM_TILES.x) * Elevation.TILE
    var h := float(ROOM_TILES.y) * Elevation.TILE
    ENV.add_wall(self, Vector2(w * 0.5, 16.0), Vector2(w, 32.0))
    ENV.add_wall(self, Vector2(w * 0.5, h - 16.0), Vector2(w, 32.0))
    ENV.add_wall(self, Vector2(16.0, h * 0.5), Vector2(32.0, h))
    ENV.add_wall(self, Vector2(w - 16.0, h * 0.5), Vector2(32.0, h))


## The level of a world point, for scenario assertions and debugging.
func level_at(point: Vector2) -> int:
    return Elevation.level_at(point)


func describe_level(point: Vector2) -> String:
    return Elevation.level_name(Elevation.level_at(point))
