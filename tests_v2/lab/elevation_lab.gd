extends Node2D

## ElevationLab — the isolated reference implementation for high ground.
##
## Two roles:
##   1. technical reference: the smallest scene that exercises LOW, HIGH, a cliff
##      boundary and the official stairs, with nothing else in the way;
##   2. visual reference: the correct way to compose Tiny Swords high ground, per
##      docs/environment/HIGHGROUND_TILE_GRAMMAR.md.
##
## Deliberately contains no quests, no Merchant, no Guard, no village, no free-play
## spawning and no decoration. Adding any of those makes it useless as a reference.
##
## Layout, in tiles (64px). The room is 20x11.
##
##   rows 0        room boundary
##   rows 1-3      HIGH terrace, cols 4-15   <- rim row 1, interior row 2, lip row 3
##   row  4        the wall row              <- ONE row of stone, opened at the stairs
##   rows 5-10     LOW ground
##
## The terrace is flanked by WATER on its north, east and west sides. That is not
## decoration: only the viewer-facing edge of a raised region shows a face, so those
## three edges are collision with nothing drawn under them, and the pack's own maps
## always put water or a map edge there. Putting same-height grass beside them would
## make the boundary read ambiguously.
##
## The stairs are the pack's official pieces: one column wide, two rows tall,
## spanning the lip row and the wall row, at the two ends of the south wall.

const ENV := preload("res://scripts/world/tiny_swords_environment.gd")
const HIGH_GROUND := preload("res://scripts/world/high_ground.gd")

## Low ground uses one palette's grass set; high ground uses another. The colour step
## is the elevation cue - see the grammar, section 5. color1 and color2 are too close
## to read as a step; color3 is clearly distinct.
const LOW_TEXTURE := preload("res://asset/Terrain/Tileset/Tilemap_color1.png")
const HIGH_TEXTURE := preload("res://asset/Terrain/Tileset/Tilemap_color3.png")

const ROOM_TILES := Vector2i(20, 11)
const TERRACE := Rect2i(4, 1, 12, 3)
const STAIR_WEST_COLUMN := 4
const STAIR_EAST_COLUMN := 15
const LOW_GROUND := Rect2i(1, 5, 18, 6)

## Where the scenario suite and a human put things.
const LOW_SPAWN := Vector2(640.0, 600.0)
const HIGH_SPAWN := Vector2(640.0, 150.0)
const STAIR_WEST_MOUTH := Vector2(288.0, 400.0)
const STAIR_WEST_TOP := Vector2(288.0, 150.0)
const CLIFF_APPROACH := Vector2(640.0, 450.0)

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
    # One region, so `build` is safe here. A scene with two or more must declare all
    # of them before constructing any - see HighGround.declare.
    # `edge_art` is ON because this terrace is flanked by WATER on its north, east and
    # west sides, where a fringe is the correct edge treatment. A terrace surrounded by
    # more grass would leave it off so the ground runs on seamlessly.
    HIGH_GROUND.build(_art, "Terrace", HIGH_TEXTURE, TERRACE, [
        HIGH_GROUND.make_stair(STAIR_WEST_COLUMN, true),
        HIGH_GROUND.make_stair(STAIR_EAST_COLUMN, false),
    ], false, true)
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
