extends RefCounted
class_name HighGround

## Builds high ground that obeys `docs/environment/ELEVATION_SYSTEM.md` and
## `docs/environment/HIGHGROUND_TILE_GRAMMAR.md`.
##
## TOP SURFACE FIRST, CLIFFS SECOND. Everything here is placed in that order, and
## the collision is derived from the geometry rather than hand-placed, so the drawn
## drop and the blocking edge cannot drift apart.
##
## Why this replaces `TinySwordsEnvironment.add_plateau`:
##
##  * it painted only cliff row 4, and the asset's face is rows 4 AND 5, so every
##    plateau in the game had a half-height cliff face;
##  * it walled only the bottom edge, leaving the sides and top open, so
##    `level_at` flipped at any uncovered edge - the "unintended entry" symptom;
##  * it placed that wall so a character pressing against the cliff from below ended
##    up with its centre inside the footprint, reading HIGH while standing at the
##    foot of the cliff. Here the wall occupies the LOW-side tile, so the centre
##    stays outside and the logical and physical boundaries agree.

const ENV := preload("res://scripts/world/tiny_swords_environment.gd")

## Atlas columns of the raised surface: left edge, middle, right edge.
const ATLAS_LEFT := 5
const ATLAS_MIDDLE := 6
const ATLAS_RIGHT := 7

## Atlas rows. Row 0 carries the lit rim, row 3 is the last grass row and the cliff
## lip, rows 4-5 are the two-row stone face.
const ROW_RIM := 0
const ROW_INTERIOR := 1
const ROW_LIP := 3
const ROW_FACE_TOP := 4
const ROW_FACE_BOTTOM := 5

## Height of the drawn stone face, in tiles.
const FACE_ROWS := 2


## Register a region and its ramps with the elevation field, without building it.
##
## **Every region in a scene must be declared before any of them is constructed.**
## The boundary builder asks "is the tile beyond this edge also high ground?", and
## that question is only answerable once the whole field is known. Building a region
## before its neighbour is declared walls the seam between them, splitting one
## terrace into two and stopping the player at an invisible edge.
static func declare(footprint: Rect2i, ramps: Array[Rect2i] = []) -> void:
    var region := Rect2i(
        footprint.position,
        Vector2i(maxi(footprint.size.x, 1), maxi(footprint.size.y, 1))
    )
    Elevation.register_high_region(region)
    for ramp in ramps:
        Elevation.register_ramp(ramp)


## Paint one already-declared region and derive its collision.
static func construct(
    parent: Node,
    region_name: String,
    texture: Texture2D,
    footprint: Rect2i,
    ramps: Array[Rect2i] = []
) -> TileMapLayer:
    var region := Rect2i(
        footprint.position,
        Vector2i(maxi(footprint.size.x, 1), maxi(footprint.size.y, 1))
    )
    var surface := _paint_surface(parent, region_name, texture, region)
    _paint_cliff_faces(parent, region_name, texture, region)
    _paint_boundary_faces(parent, region_name, texture, region)
    _paint_ramp_treads(parent, region_name, texture, ramps)
    _build_boundary(parent, region_name, region, ramps)
    return surface


## Declare and construct in one call. Only safe for a scene with a single region;
## with more than one, call `declare` for all of them first, then `construct`.
static func build(
    parent: Node,
    region_name: String,
    texture: Texture2D,
    footprint: Rect2i,
    ramps: Array[Rect2i] = []
) -> TileMapLayer:
    declare(footprint, ramps)
    return construct(parent, region_name, texture, footprint, ramps)


## Row 0 is the lit rim, the last row is the cliff lip, everything between is
## interior - but only where the edge is actually exposed.
##
## A rim or lip next to more high ground is a false edge: it draws a lit border and
## a ragged fringe down the middle of what is one continuous terrace, so the surface
## reads as two platforms pushed together. The neighbour test is what makes the join
## invisible.
static func _row_for(tile: Vector2i, local_y: int, height: int) -> int:
    if height <= 1:
        return ROW_LIP
    if local_y == 0 and not Elevation.is_high_tile(tile + Vector2i(0, -1)):
        return ROW_RIM
    if local_y == height - 1 and not Elevation.is_high_tile(tile + Vector2i(0, 1)):
        return ROW_LIP
    return ROW_INTERIOR


## Same idea for columns: left and right edge art only faces exposed ground.
static func _column_for(tile: Vector2i, local_x: int, width: int) -> int:
    if width <= 1:
        return ATLAS_MIDDLE
    if local_x == 0 and not Elevation.is_high_tile(tile + Vector2i(-1, 0)):
        return ATLAS_LEFT
    if local_x == width - 1 and not Elevation.is_high_tile(tile + Vector2i(1, 0)):
        return ATLAS_RIGHT
    return ATLAS_MIDDLE


static func _paint_surface(
    parent: Node,
    region_name: String,
    texture: Texture2D,
    region: Rect2i
) -> TileMapLayer:
    var layer := ENV._new_tile_layer(parent, region_name, texture, -18)
    for local_y in range(region.size.y):
        for local_x in range(region.size.x):
            var tile := region.position + Vector2i(local_x, local_y)
            layer.set_cell(tile, 0,
                Vector2i(_column_for(tile, local_x, region.size.x),
                    _row_for(tile, local_y, region.size.y)))
    return layer


## The stone face is TWO rows, and it is skipped wherever a ramp opens the edge.
static func _paint_cliff_faces(
    parent: Node,
    region_name: String,
    texture: Texture2D,
    region: Rect2i
) -> void:
    var layer := ENV._new_tile_layer(parent, region_name + "Cliff", texture, -17)
    for local_x in range(region.size.x):
        var tile_x := region.position.x + local_x
        for face_row in range(FACE_ROWS):
            var tile_y := region.position.y + region.size.y + face_row
            if Elevation.is_ramp_tile(Vector2i(tile_x, tile_y)):
                continue
            layer.set_cell(
                Vector2i(tile_x, tile_y),
                0,
                Vector2i(_column_for(Vector2i(tile_x, tile_y), local_x, region.size.x),
                    ROW_FACE_TOP + face_row)
            )


## A ramp is a composed stair: the lip row repeated down the opening, so every tread
## reads as a walkable surface rather than a wall. The tileset contains no ramp art,
## so this is the only honest way to draw one - see the grammar, section 4.
static func _paint_ramp_treads(
    parent: Node,
    region_name: String,
    texture: Texture2D,
    ramps: Array[Rect2i]
) -> void:
    if ramps.is_empty():
        return
    var layer := ENV._new_tile_layer(parent, region_name + "Ramp", texture, -16)
    for ramp in ramps:
        for local_y in range(ramp.size.y):
            for local_x in range(ramp.size.x):
                var tread := ramp.position + Vector2i(local_x, local_y)
                layer.set_cell(tread, 0,
                    Vector2i(_column_for(tread, local_x, ramp.size.x), ROW_LIP))


## The north, east and west edges, drawn as a retaining wall.
##
## The tileset's stone face is a HORIZONTAL course, so the south edge is the only one
## it can render as a cliff. The other three still need collision - a cliff is a
## boundary on every side - and collision with nothing drawn under it is an invisible
## wall, which is the one thing the grammar forbids outright: it looks walkable and is
## not.
##
## The fix is not to remove the collision, which would make the plateau reachable from
## every side and undo the whole model. It is to draw what is already there: the same
## stone, laid along the low-side band the collision already occupies, which reads as
## a retaining wall holding the terrace up. It uses the base course rather than the
## top course, because the top course carries a grass overhang that only makes sense
## on a downward-facing drop.
static func _paint_boundary_faces(
    parent: Node,
    region_name: String,
    texture: Texture2D,
    region: Rect2i
) -> void:
    var first_col := region.position.x
    var last_col := region.position.x + region.size.x
    var first_row := region.position.y
    var last_row := region.position.y + region.size.y

    var tiles: Array[Vector2i] = []
    var columns: Array[int] = []

    # North band.
    for col in range(first_col, last_col):
        var tile := Vector2i(col, first_row - 1)
        if _edge_is_solid(tile):
            tiles.append(tile)
            columns.append(col - first_col)
    # West and east bands.
    for row in range(first_row, last_row):
        for band_col in [first_col - 1, last_col]:
            var tile := Vector2i(band_col, row)
            if _edge_is_solid(tile):
                tiles.append(tile)
                columns.append(-1)

    if tiles.is_empty():
        return
    var layer := ENV._new_tile_layer(parent, region_name + "Retaining", texture, -17)
    for index in tiles.size():
        var tile := tiles[index]
        var column := ATLAS_MIDDLE
        if columns[index] >= 0:
            column = _column_for(tile, columns[index], region.size.x)
        layer.set_cell(tile, 0, Vector2i(column, ROW_FACE_BOTTOM))


## Movement collision for every edge, split around the ramp openings.
##
## Two rules make this agree with the drawing:
##
##  * **One wall per drawn face row.** The south edge is not one tall block but one
##    wall per stone row, each opened by the ramp cells in *its own* row. That is
##    what lets a staggered stair open the lower row while the upper row stays
##    solid, so the step actually steps.
##  * **An edge facing high ground is not an edge.** A terrace built from two
##    adjacent rects has no wall along the seam, so its top stays walkable across
##    the join, and only the outline that faces LOW ground is walled.
##
## Every wall occupies the LOW-side tile adjacent to the footprint and never the
## footprint itself, so a character stopped by it still samples a LOW tile.
static func _build_boundary(parent: Node, region_name: String, region: Rect2i, ramps: Array[Rect2i]) -> void:
    var tile := Elevation.TILE
    var first_col := region.position.x
    var last_col := region.position.x + region.size.x
    var first_row := region.position.y
    var last_row := region.position.y + region.size.y

    # South: the visible drop, one wall per drawn stone row.
    for face_row in range(FACE_ROWS):
        var row := last_row + face_row
        _wall_span_x(parent, first_col, last_col, float(row) * tile + tile * 0.5, tile, row)

    # North, east and west. These bands are painted as a retaining wall by
    # `_paint_boundary_faces`, so the collision here has something visible under it
    # rather than being an invisible wall.
    var north_row := first_row - 1
    _wall_span_x(parent, first_col, last_col, float(first_row) * tile - tile * 0.5, tile, north_row)
    _wall_span_y(parent, first_row, last_row, float(first_col) * tile - tile * 0.5, tile, first_col - 1)
    _wall_span_y(parent, first_row, last_row, float(last_col) * tile + tile * 0.5, tile, last_col)


## A LOW-side tile is solid unless a ramp opens it or it is itself high ground.
static func _edge_is_solid(tile: Vector2i) -> bool:
    if Elevation.is_ramp_tile(tile):
        return false
    return not Elevation.is_high_tile(tile)


## Returns the number of walls emitted.
static func _wall_span_x(
    parent: Node,
    first_col: int,
    last_col: int,
    centre_y: float,
    height: float,
    band_row: int
) -> int:
    var solid: Array[int] = []
    for col in range(first_col, last_col):
        if _edge_is_solid(Vector2i(col, band_row)):
            solid.append(col)
    return _emit_runs(parent, solid, centre_y, height, true)


## Returns the number of walls emitted.
static func _wall_span_y(
    parent: Node,
    first_row: int,
    last_row: int,
    centre_x: float,
    width: float,
    band_col: int
) -> int:
    var solid: Array[int] = []
    for row in range(first_row, last_row):
        if _edge_is_solid(Vector2i(band_col, row)):
            solid.append(row)
    return _emit_runs(parent, solid, centre_x, width, false)


## Emit one wall per consecutive run of solid indices, and report how many.
##
## The trailing run is flushed explicitly: a wall whose last index is solid has no
## following open index to trigger the flush, and dropping it left one side of every
## ramp open.
static func _emit_runs(
    parent: Node,
    indices: Array[int],
    centre_cross: float,
    size_cross: float,
    horizontal: bool
) -> int:
    if indices.is_empty():
        return 0
    var tile := Elevation.TILE
    var emitted := 0
    var run_start := indices[0]
    var previous := indices[0]
    for position in range(1, indices.size() + 1):
        var current := 1048576 if position >= indices.size() else indices[position]
        if current == previous + 1:
            previous = current
            continue
        var span := float(previous - run_start + 1) * tile
        var centre := float(run_start) * tile + span * 0.5
        if horizontal:
            ENV.add_wall(parent, Vector2(centre, centre_cross), Vector2(span, size_cross))
        else:
            ENV.add_wall(parent, Vector2(centre_cross, centre), Vector2(size_cross, span))
        emitted += 1
        run_start = current
        previous = current
    return emitted
