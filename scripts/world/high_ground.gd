extends RefCounted
class_name HighGround

## Builds high ground that obeys `docs/environment/ELEVATION_SYSTEM.md` and
## `docs/environment/HIGHGROUND_TILE_GRAMMAR.md`.
##
## **Read the grammar before changing anything here.** Two earlier versions of this
## builder were wrong in the same way: they invented geometry to satisfy a rule that
## had been derived from a misreading of the asset. The asset is authoritative.
##
## The geometry, in one picture (row numbers relative to the footprint):
##
##     [ footprint last row ]   grass lip, r3
##     [ wall row           ]   stone, r4 over land or r5 over water
##     [ low ground         ]
##
## A stair is 2 rows x 1 column and spans exactly the lip row and the wall row,
## because it replaces both. See the grammar, section 4.

const ENV := preload("res://scripts/world/tiny_swords_environment.gd")

## Atlas columns of the grass block set: left edge, middle, right edge.
const ATLAS_LEFT := 5
const ATLAS_MIDDLE := 6
const ATLAS_RIGHT := 7

## Atlas rows of the grass set. Only the rim and the interior are used.
##
## Row 3 is deliberately unused: it is a free-standing strip with a ragged fringe on
## its top as well as its bottom, so putting it anywhere inside a region paints a seam
## across the middle of the terrace.
const ROW_RIM := 0
const ROW_INTERIOR := 1

## The wall row. r4 and r5 are ALTERNATIVES, not two courses: r4 for a wall over
## land, r5 for a wall over water. Drawing both stacks a waterline under dry ground.
const ROW_WALL := 4
const ROW_WALL_WATER := 5

## Atlas columns of the two official stairs.
##
## Magnified at 4x the two are mirror images. Reported from the rendered result and
## not re-derived here: an earlier revision swapped these on a reading of the atlas
## that did not survive being compared against the pack's own example map. Change them
## only against a capture, never against the tile sheet alone.
## These two values have been wrong three times. Read this before touching them.
##
## `ascending_east = true` means the stair is climbed by walking EAST, so its raised
## side faces east. That is what the caller means, and it is the only thing these
## constants have to get right.
##
## The mapping from that meaning to an atlas column is NOT derivable from the tile
## sheet. The two pieces are mirror images drawn on a diagonal, they sit at c0 and c3
## with an empty spacer column between them, and the legend prints them in an order
## that does not correspond to the atlas columns. Three attempts to settle it by
## reasoning gave three different answers, each argued confidently:
##
##   1. from the legend's left-to-right panel order -> c0. Wrong.
##   2. from "which side is the grass on" in a magnified atlas crop -> c3. Wrong.
##   3. from the same reading in a magnified capture -> judgement that the value was
##      already right. Wrong again. A diagonal's orientation cannot be settled by
##      describing it in words: features belonging to the neighbouring tiles - the
##      forecourt's own left-edge fringe, the shoulder's wall - were read as the
##      stair's, and the conclusion was announced with more confidence than the
##      evidence supported.
##
## The values below are the ones the project owner confirmed against the rendered
## result. Treat them as measured data. If a stair ever looks reversed, change the
## value and render it - do not re-derive it, and do not ask the owner to justify a
## description that was already unambiguous.
const STAIR_COL_ASCENDING_EAST := 0
const STAIR_COL_ASCENDING_WEST := 3

## A stair spans two rows: the grass row and the wall row.
## A stair is two rows tall and one column wide. The official unit; do not widen it.
const STAIR_ROWS := 2

## Where a stair's two rows start, as an offset from the footprint's last row - which is
## the wall row. -1 puts the stair on the terrace's own last surface row and the wall
## row; -2 puts it on the two rows above those.
##
## This is per stair, not a global convention: different regions want their entrances at
## different heights, and a shared value silently moves every scene's stairs at once.
##
## Whichever value is used, the terrace's own last surface row has to fall inside the
## stair's rows. The level only flips when an actor steps off the stair onto that
## surface, and the wall builder opens a side boundary on ramp tiles - a stair that
## missed that row would leave the terrace walled off.
const STAIR_DEFAULT_TOP_ROW_OFFSET := -1


## One legal entrance, one column wide.
##
## `ascending_east` picks the piece: true is the stair that climbs from west to east
## (its low ground is to the west), false is its mirror.
static func make_stair(
    column: int,
    ascending_east: bool,
    top_row_offset: int = STAIR_DEFAULT_TOP_ROW_OFFSET
) -> Dictionary:
    return {
        "column": column,
        "ascending_east": ascending_east,
        "top_row_offset": top_row_offset,
    }


## The two tile rows a stair occupies, given the footprint's last row.
static func stair_rect(stair: Dictionary, last_row: int) -> Rect2i:
    var offset := int(stair.get("top_row_offset", STAIR_DEFAULT_TOP_ROW_OFFSET))
    return Rect2i(int(stair["column"]), last_row + offset, 1, STAIR_ROWS)


## Register a region and its stairs with the elevation field, without building it.
##
## **Every region in a scene must be declared before any of them is constructed.**
## The boundary builder asks "is the tile beyond this edge also high ground?", and
## that question is only answerable once the whole field is known. Building a region
## before its neighbour is declared walls the seam between them, splitting one
## terrace into two and stopping the player at an invisible edge.
static func declare(footprint: Rect2i, stairs: Array = []) -> void:
    var region := _normalize(footprint)
    Elevation.register_high_region(region)
    for stair in stairs:
        Elevation.register_ramp(stair_rect(stair, region.position.y + region.size.y))


## Paint one already-declared region and derive its collision.
##
## `edge_art` draws the grass set's rim and left/right edge pieces on the north, east
## and west sides. Leave it OFF when the region is surrounded by more ground: the
## ground should run seamlessly into its surroundings and the palette step should be
## what says "this is higher". Turn it ON when those sides meet a different material,
## such as water, where a fringe is the correct edge treatment.
static func construct(
    parent: Node,
    region_name: String,
    texture: Texture2D,
    footprint: Rect2i,
    stairs: Array = [],
    wall_over_water: bool = false,
    edge_art: bool = true
) -> TileMapLayer:
    var region := _normalize(footprint)
    var surface := _paint_surface(parent, region_name, texture, region, edge_art)
    _paint_wall(parent, region_name, texture, region, wall_over_water)
    _paint_stairs(parent, region_name, texture, region, stairs)
    _build_boundary(parent, region, stairs)
    return surface


## Declare and construct in one call. Only safe for a scene with a single region;
## with more than one, call `declare` for all of them first, then `construct`.
static func build(
    parent: Node,
    region_name: String,
    texture: Texture2D,
    footprint: Rect2i,
    stairs: Array = [],
    wall_over_water: bool = false,
    edge_art: bool = true
) -> TileMapLayer:
    declare(footprint, stairs)
    return construct(parent, region_name, texture, footprint, stairs, wall_over_water, edge_art)


static func _normalize(footprint: Rect2i) -> Rect2i:
    return Rect2i(footprint.position,
        Vector2i(maxi(footprint.size.x, 1), maxi(footprint.size.y, 1)))


## The surface is the grass set's SQUARE, repeated: r0 for the top row and r1 for
## everything else.
##
## r3 is deliberately NOT used. It is a free-standing strip with a ragged fringe on
## its TOP as well as its bottom, so using it as the last row paints a seam and a
## change of tone straight across the middle of the terrace - which reads as a band of
## high ground rather than a raised area. The junction with the wall is already
## handled by the wall's own tile, whose top edge carries the grass overhang.
##
## The rim (r0) is only drawn on a top row that faces exposed ground; mid-region it
## would invent an edge.
static func _row_for(tile: Vector2i, local_y: int, edge_art: bool) -> int:
    if edge_art and local_y == 0 and not Elevation.is_high_tile(tile + Vector2i(0, -1)):
        return ROW_RIM
    return ROW_INTERIOR


## Left and right edge art, so the high ground has a visible seam against the ordinary
## ground beside it. Without it the two greens simply meet and the terrace reads as a
## stripe of a different colour rather than as a place.
static func _column_for(tile: Vector2i, local_x: int, width: int, edge_art: bool) -> int:
    if not edge_art or width <= 1:
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
    region: Rect2i,
    edge_art: bool
) -> TileMapLayer:
    var layer := ENV._new_tile_layer(parent, region_name, texture, -18)
    for local_y in range(region.size.y):
        for local_x in range(region.size.x):
            var tile := region.position + Vector2i(local_x, local_y)
            layer.set_cell(tile, 0,
                Vector2i(_column_for(tile, local_x, region.size.x, edge_art),
                    _row_for(tile, local_y, edge_art)))
    return layer


## ONE row of wall along the south edge, at the row below the footprint.
##
## The wall is painted across the FULL span, including under a stair. The stair is a
## separate piece drawn on a layer above (see `_paint_stairs`), so it occludes the
## wall the way the pack's own art does. An earlier version cut a tile out of the wall
## at each stair instead, which left the grass with nothing behind it - the stair read
## as a patch glued to the wall's end and the wall read as bitten.
##
## What is drawn and what blocks are separate questions: the collision for this row is
## opened at the stair columns, the stone is not.
static func _paint_wall(
    parent: Node,
    region_name: String,
    texture: Texture2D,
    region: Rect2i,
    wall_over_water: bool
) -> void:
    var wall_row := region.position.y + region.size.y
    var atlas_row := ROW_WALL_WATER if wall_over_water else ROW_WALL
    var layer := ENV._new_tile_layer(parent, region_name + "Wall", texture, -17)
    var exposed_columns: Array[int] = []
    for column in range(region.position.x, region.position.x + region.size.x):
        # A composite terrace is built from several declared rectangles. Where the
        # rectangle below is also HIGH, this is an internal seam rather than a drop.
        # Painting a wall here would cut a false stone band through the terrace.
        if not Elevation.is_high_tile(Vector2i(column, wall_row)):
            exposed_columns.append(column)
    _paint_wall_runs(layer, exposed_columns, wall_row, atlas_row)


## Paint every consecutive exposed run with its own terminating end pieces.
##
## Treating the entire source rectangle as one run produces the wrong corners on a
## stepped footprint: a wall that stops beside a forward terrace needs an end cap at
## that join, even though the source rectangle itself continues behind the terrace.
static func _paint_wall_runs(
    layer: TileMapLayer,
    columns: Array[int],
    wall_row: int,
    atlas_row: int
) -> void:
    if columns.is_empty():
        return
    var run_start := 0
    for index in range(1, columns.size() + 1):
        var run_ended := index >= columns.size() or columns[index] != columns[index - 1] + 1
        if not run_ended:
            continue
        var run_length := index - run_start
        for run_index in range(run_length):
            var atlas_column := ATLAS_MIDDLE
            if run_length > 1 and run_index == 0:
                atlas_column = ATLAS_LEFT
            elif run_length > 1 and run_index == run_length - 1:
                atlas_column = ATLAS_RIGHT
            layer.set_cell(Vector2i(columns[run_start + run_index], wall_row), 0,
                Vector2i(atlas_column, atlas_row))
        run_start = index


## The official stair pieces, drawn over the lip row and the wall row on their own
## layer, so a stair OCCLUDES the wall rather than replacing it. That is what makes it
## read as a slope in front of the wall instead of a hole in it.
static func _paint_stairs(
    parent: Node,
    region_name: String,
    texture: Texture2D,
    region: Rect2i,
    stairs: Array
) -> void:
    if stairs.is_empty():
        return
    var last_row := region.position.y + region.size.y
    var layer := ENV._new_tile_layer(parent, region_name + "Stairs", texture, -15)
    for stair in stairs:
        var column := int(stair["column"])
        var atlas_column := STAIR_COL_ASCENDING_EAST if bool(stair["ascending_east"]) \
            else STAIR_COL_ASCENDING_WEST
        # Atlas r4 is the piece's upper row and r5 its lower, so the upper half lands
        # on the lip row and the lower half on the wall row.
        var top_row := last_row + int(stair.get("top_row_offset", STAIR_DEFAULT_TOP_ROW_OFFSET))
        layer.set_cell(Vector2i(column, top_row), 0,
            Vector2i(atlas_column, ROW_WALL))
        layer.set_cell(Vector2i(column, top_row + 1), 0,
            Vector2i(atlas_column, ROW_WALL_WATER))


## Movement collision for every edge, split around the stair openings.
##
## The south wall is ONE row, matching the one row that is drawn: a taller collider
## would stop the player a tile short of the stone they can see, with a visible gap
## between them.
##
## The north, east and west edges also get collision and deliberately get no art.
## Only the viewer-facing edge of a raised region shows a face - that is the
## projection, not an invisible wall. See the grammar, section 3.
static func _build_boundary(parent: Node, region: Rect2i, stairs: Array) -> void:
    var tile := Elevation.TILE
    var first_col := region.position.x
    var last_col := region.position.x + region.size.x
    var first_row := region.position.y
    var last_row := region.position.y + region.size.y

    # South: the drawn wall row.
    _wall_span_x(parent, first_col, last_col, float(last_row) * tile + tile * 0.5, tile, last_row)
    # North.
    _wall_span_x(parent, first_col, last_col, float(first_row) * tile - tile * 0.5, tile, first_row - 1)
    # East and west.
    _wall_span_y(parent, first_row, last_row, float(first_col) * tile - tile * 0.5, tile, first_col - 1)
    _wall_span_y(parent, first_row, last_row, float(last_col) * tile + tile * 0.5, tile, last_col)

    if stairs.is_empty():
        return


## A LOW-side tile is solid unless a stair opens it or it is itself high ground.
static func _edge_is_solid(tile: Vector2i) -> bool:
    if Elevation.is_ramp_tile(tile):
        return false
    return not Elevation.is_high_tile(tile)


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
## stair open.
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
