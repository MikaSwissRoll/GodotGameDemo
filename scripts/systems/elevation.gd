extends RefCounted
class_name Elevation

## The single authority for gameplay elevation in this project.
##
## Read `docs/environment/ELEVATION_SYSTEM.md` first; it is the specification this
## file implements. If the two disagree, the document wins and this file is wrong.
##
## Two levels only: LOW (0) and HIGH (1). There is no continuous height.
##
## The terrain owns the truth. `level_at(point)` answers which walkable level a world
## position belongs to, and every other question - movement, melee, ranged, AI - is
## answered by asking that one function. No actor, and no scene, keeps a second copy
## of the rules.
##
## Actors expose their level with a computed property so the state is explicit and
## named, while still having exactly one source:
##
##     var elevation_level: int:
##         get: return Elevation.level_of(self)

## The two gameplay levels.
const LOW := 0
const HIGH := 1

## World size of one atlas tile. The terrain registry, the tile painter and the
## cliff builder all work in these units, so a region registered in tiles and a
## footprint painted in tiles can never drift apart.
const TILE := 64.0

## Walkable HIGH footprints, in tile coordinates.
static var _high_regions: Array[Rect2i] = []

## Declared LOW <-> HIGH connections, in tile coordinates. Each one is an opening in
## a cliff boundary; a boundary cell is only traversable where a ramp covers it.
static var _ramps: Array[Rect2i] = []


## Start a fresh field. Every world and every lab scene calls this before building,
## so a reloaded scene or a new stage never inherits the previous world's regions.
static func begin_field() -> void:
    _high_regions.clear()
    _ramps.clear()


static func register_high_region(footprint: Rect2i) -> void:
    if footprint.size.x <= 0 or footprint.size.y <= 0:
        return
    if not _high_regions.has(footprint):
        _high_regions.append(footprint)


static func register_ramp(rect: Rect2i) -> void:
    if rect.size.x <= 0 or rect.size.y <= 0:
        return
    if not _ramps.has(rect):
        _ramps.append(rect)


static func high_regions() -> Array[Rect2i]:
    return _high_regions.duplicate()


static func ramps() -> Array[Rect2i]:
    return _ramps.duplicate()


static func tile_of(point: Vector2) -> Vector2i:
    return Vector2i(floori(point.x / TILE), floori(point.y / TILE))


static func rect_of_tiles(rect: Rect2i) -> Rect2:
    return Rect2(rect.position.x * TILE, rect.position.y * TILE,
        rect.size.x * TILE, rect.size.y * TILE)


## The walkable level a world point belongs to. HIGH inside a registered high
## region, LOW everywhere else - including on a ramp, which is the approach to a
## boundary rather than part of the raised surface.
static func level_at(point: Vector2) -> int:
    var tile := tile_of(point)
    for rect in _high_regions:
        if rect.has_point(tile):
            return HIGH
    return LOW


## True when a point sits on a declared ramp. Ramps are the only legal crossings, so
## the cliff builder leaves them open and the router uses them as its links.
static func is_ramp(point: Vector2) -> bool:
    return is_ramp_tile(tile_of(point))


static func is_ramp_tile(tile: Vector2i) -> bool:
    for rect in _ramps:
        if rect.has_point(tile):
            return true
    return false


## Whether any declared ramp connects these two levels. LOW and HIGH are connected
## when at least one ramp exists; a world with no ramp is a world where high ground
## is unreachable, which is legal but must be handled by AI without freezing.
static func levels_are_connected() -> bool:
    return not _ramps.is_empty()


## True when a tile is on the boundary of a high region, i.e. the high region is on
## one side of it. Used by the builder to decide where a cliff face belongs.
static func is_high_boundary_tile(tile: Vector2i) -> bool:
    var here := _region_containing(tile)
    if here.size.x == 0:
        return false
    for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
        if _region_containing(tile + offset).size.x == 0:
            return true
    return false


static func _region_containing(tile: Vector2i) -> Rect2i:
    for rect in _high_regions:
        if rect.has_point(tile):
            return rect
    return Rect2i(0, 0, 0, 0)


# --- Actor state ------------------------------------------------------------

## The authoritative level of an actor. Never cached by the caller: two actors
## standing in the same place therefore cannot disagree.
static func level_of(actor: Node2D) -> int:
    if actor == null or not is_instance_valid(actor):
        return LOW
    return level_at(actor.global_position)


static func level_name(level: int) -> String:
    return "HIGH" if level == HIGH else "LOW"


# --- Combat rules: the only place these are decided -------------------------

## Melee connects only on the same level. Hitbox overlap and sprite overlap are
## deliberately not consulted: on opposite sides of a cliff both can overlap and the
## blow must still be refused.
static func melee_allowed(attacker: Node2D, target: Node2D) -> bool:
    if attacker == null or not is_instance_valid(attacker):
        return false
    if target == null or not is_instance_valid(target):
        return false
    return level_of(attacker) == level_of(target)


## Ranged attacks cross elevations, and never require navigation reachability.
##
## This exists so that callers stop inventing gates. It is not a range check and not
## a line-of-sight check - those belong to the weapon, which knows its own reach and
## its own projectile rules. What this function answers is only the question that
## used to be answered wrongly: elevation difference and unreachability must never
## make a ranged target invalid.
static func ranged_allowed(attacker: Node2D, target: Node2D) -> bool:
    if attacker == null or not is_instance_valid(attacker):
        return false
    if target == null or not is_instance_valid(target):
        return false
    return true


## Whether a melee actor can physically close on a target, given only the level
## model. Reachability is a navigation question, not a combat one; this is the
## minimal answer the model can give without a route: same level, or a ramp exists
## that joins the levels.
##
## It is deliberately NOT used to decide whether an attack is allowed. See
## `docs/environment/ELEVATION_SYSTEM.md` section 8.
static func could_reach_by_level(from_level: int, to_level: int) -> bool:
    if from_level == to_level:
        return true
    return levels_are_connected()
