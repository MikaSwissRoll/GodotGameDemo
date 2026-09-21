# Tiny Swords High-Ground Tile Grammar

How to build high ground in this project using the **actual** Tiny Swords terrain
assets. Read with [`ELEVATION_SYSTEM.md`](ELEVATION_SYSTEM.md), which defines the
gameplay model this grammar must express.

Every fact below was measured from the files in `asset/Terrain/Tileset/` and checked
against the pack's own tile legend. Do not add a tile reference to code without
re-checking it here first.

> **Two earlier revisions of this document were wrong**, and both errors were acted
> on before they were caught. It claimed the cliff face was two rows and that the
> pack had no ramp tile; in fact rows 4 and 5 are two *variants* of a one-row wall,
> and the "shoreline corners" it dismissed are the pack's **stairs**. Read §2 and §4
> before trusting any tile coordinate in prose elsewhere.

## 1. The atlas, measured

All five palettes — `Tilemap_color1.png` … `Tilemap_color5.png` — are **576 × 384**,
a **9 column × 6 row** grid of **64 px** cells. Their silhouettes are byte-identical
per cell; only the palette differs. So one grammar covers all five, and a colour swap
is always safe.

Per-cell opaque coverage, the authoritative "does this cell have art" map:

```
        c0   c1   c2   c3   c4   c5   c6   c7   c8
r0      92   94   92   88    .   92   97   94   89
r1      97  100  100   97    .  100  100  100  100
r2      97  100   98   95    .  100  100  100  100
r3      91   94   92   88    .   93   97   94   91
r4      48    .    .   50    .   89   95   90   84
r5      89    .    .   92    .   85   93   85   78
```

**Column 4 is empty.** It is a spacer and nothing may be placed there.

## 1a. Tile numbers — the shared vocabulary

So a tile can be named unambiguously in conversation, every cell has a number:

```
number = row * 9 + column + 1        (row 0-5 top to bottom, column 0-8 left to right)
```

`#1` is the top-left cell, `#9` the top-right, `#10` starts row 1, `#54` is the
bottom-right. Say "**#46**" and it means exactly one cell, in every palette.

| Row | Numbers | What the row holds |
| --- | --- | --- |
| r0 | **#1 – #9** | top edge of the ground sets |
| r1 | **#10 – #18** | set interiors |
| r2 | **#19 – #27** | bottom edge of the square sets |
| r3 | **#28 – #36** | the free-standing strip pieces |
| r4 | **#37 – #45** | the two stairs' upper halves, and the wall over land |
| r5 | **#46 – #54** | the two stairs' lower halves, and the wall over water |

The cells that actually matter, by number:

| # | Cell | What it is |
| --- | --- | --- |
| **#2 / #11 / #20** | c1 r0/r1/r2 | waterside square: top, interior, bottom |
| **#4** | c3 r0 | top of the waterside strip |
| **#7 / #16 / #25 / #34** | c6 r0/r1/r2/r3 | grass square: top, upper interior, lower interior, bottom |
| **#13** | c4 r1 | *empty spacer* |
| **#28** | c0 r3 | the free-standing strip — **fringes on BOTH edges, never use it inside a region** |
| **#37 / #46** | c0 r4 / c0 r5 | **stair: climbs west → east** (upper half / lower half) |
| **#40 / #49** | c3 r4 / c3 r5 | **stair: climbs east → west** (upper half / lower half) |
| **#42 / #43 / #44** | c5/c6/c7 r4 | **south wall over land** (left/middle/right) |
| **#45** | c8 r4 | south wall over land, strip end |
| **#46 / #47 / #48** | c5/c6/c7 r5 | **south wall over water** (left/middle/right) |
| **#49** | c8 r5 | south wall over water, strip end |

**Name tiles by number when talking; keep `c{col} r{row}` in code.** The number is for
conversation, the coordinate is for addressing.

> Where a number has to appear in code, write both: `#42 (c5 r4)`. A bare number is
> unreadable in source, and a bare coordinate is what produced three rounds of "which
> stair piece do you mean".

## 2. What each cell is

The pack's legend names four kinds of piece. The columns are **not** "low" and
"high" — they are two ground *materials*, and elevation is expressed by colour (§5).

| Region | Cells | Piece | Use |
| --- | --- | --- | --- |
| top-left | `c0–c2 × r0–r2` | 临水地块 · square | ground beside water |
| top-left | `c3 × r0–r2` | 临水地块 · rectangle | one-tile-wide strip beside water |
| top-left | `c0–c3 × r3` | 临水地块 · bottom strip | free-standing horizontal edge |
| bottom-left | **`c0 × r4–r5`** | **楼梯 · 由西向东的向上楼梯** | legal LOW→HIGH, climbing westward→eastward |
| bottom-left | **`c3 × r4–r5`** | **楼梯 · 由东向西的向上楼梯** | legal LOW→HIGH, climbing eastward→westward |
| top-right | `c5–c7 × r0–r2` | 草地块 · square | grass ground |
| top-right | `c8 × r0–r2` | 草地块 · rectangle | one-tile-wide grass strip |
| top-right | `c5–c8 × r3` | 草地块 · bottom strip | **the lip row**: clean lower edge with a pale highlight, sits directly on the wall |
| bottom-right | **`c5–c8 × r4`** | **墙体 · 南面高地的墙体** | the south wall over land |
| bottom-right | **`c5–c8 × r5`** | **墙体 · 南面高地的临水墙体** | the south wall over water |

`r4` and `r5` are **alternatives, not two courses**. Pick one row: `r4` when the
ground at the foot of the wall is land, `r5` when it is water. Drawing both stacks a
waterline under dry ground.

## 3. Projection: only the south edge has a face

The pack is drawn in a fixed top-down view with the camera to the **south**. A raised
region therefore shows a vertical face on **one edge only** — the edge facing the
viewer:

| Edge | What is drawn |
| --- | --- |
| **South** (viewer-facing) | the wall row, `r4` or `r5` |
| North (far) | nothing, and the surface runs on **seamlessly**: interior art, no rim |
| East / West | nothing, and the surface runs on **seamlessly**: interior art, no side fringe |

Collision exists on all four edges — a cliff is a boundary on every side (invariant 5
of `ELEVATION_SYSTEM.md`) — but only the south edge is *painted with a face*.

The three unpainted edges use **interior** art, not edge art. An edge piece draws a
ragged fringe and an outline, which turns the high ground into a patch laid on top of
the terrain with a visible seam. Left as interior, the ground runs continuously into
its surroundings and the **palette step** is what says "this is higher" (see §5).

`HighGround` exposes this as `edge_art`. Leave it **off** when the region is
surrounded by more ground. Turn it **on** when those sides meet a different material
such as water, where a fringe is the correct treatment.

**This is not an invisible wall, and it is not a defect.** It is the projection. An
earlier revision of this document treated unpainted collision as a lie and built a
stone retaining wall on all four sides; the result looked like a moat and contradicted
every other object in the game. A later one drew the grass set's edge art there, which
produced the seamless-ground defect instead. Do not repeat either.

What it *does* mean is that a high region whose north, east or west edge faces
same-height open ground will read ambiguously. The official maps avoid this by putting
**water or a map edge** against those sides. Do the same: choose a footprint whose
non-south edges meet something the player already reads as impassable.

## 4. The stair

A stair is **2 rows tall and 1 column wide**. A side entrance spans the two rows
beside the end of the south wall:

```
[ beside the last surface row ]   <- upper stair row, crossing the side boundary
[ beside the wall row         ]   <- lower stair row on low ground
```

The raised side faces the high surface. The other side stays connected to the
low-ground notch. The south wall remains one continuous row.

Direction is fixed by the piece, and the two are **mirror images**:

| Piece | Measured appearance (4x) | Raised side | Climbs |
| --- | --- | --- | --- |
| `c3 × r4–r5` | stone left, **grass right** | east | west → east |
| `c0 × r4–r5` | **grass left**, stone right | west | east → west |

> Identify them by that measurement, **not** by the legend's panel order. The legend
> prints the two trapezoids side by side and the atlas places them two columns apart,
> and reading the order across from one to the other puts them backwards. Placing the
> wrong one still climbs, but its grass faces away from the terrace, so the slope reads
> as descending the wrong way.

At a **wall's end** the raised side must face the terrace: place the west stair one
column outside the footprint and use `c3` (raised side east). Place the east stair
one column outside the footprint and use `c0` (raised side west).

### A side stair leaves the south wall intact

Paint the south wall across its **full span**. Draw each stair in the low-ground
notch beside the wall, on the layer above the terrain.

The stair's upper row opens the west or east collision boundary. It does not cut an
opening in the south wall. This creates the U-shaped outline used by the castle
terrace: short upper wall sections, low-ground side approaches, and one continuous
front wall.

**What is drawn and what blocks are separate questions.** Open collision only on the
side boundary cell covered by the stair. Keep the remaining side boundary and the
complete south wall solid.

The wall's collision is exactly ONE row, matching the one row drawn. A taller collider
stops the player a tile short of the stone they can see, with a visible gap between
them.

Place stairs immediately **outside the ends** of the south wall. A one-column stair
is the official unit; do not widen it, and do not compose a substitute. An earlier
revision placed both stairs over the wall itself. That left the side notches empty
and made the intended U-shaped high-ground outline unreadable.

The asset set contains no separate wooden stair image. The castle terrace keeps the
official grass slope underneath and adds pixel-aligned wooden treads as presentation
only. The overlay does not define elevation, collision, or ramp reachability.

## 5. Colour is elevation

The pack distinguishes low ground from high ground **by using a different palette**,
not by different geometry:

- low ground: the 草地块 set from one palette, e.g. `Tilemap_color1.png`;
- high ground: the 草地块 set from **another** palette, e.g. `Tilemap_color2.png`;
- **the stair comes from the high ground's palette**, because it is part of the high
  terrain.

So a stair joining `color1` low ground to `color2` high ground is drawn from
`color2`. Keep the two palettes clearly distinct: if the step up is not obvious at a
glance, the fix is the palette, not extra geometry.

Within one landform, use one palette. Two palettes meeting mid-terrace reads as two
materials butted together, not as one region.

## 6. Construction order

```
1.  Gameplay purpose        what is this high ground FOR?
2.  High-ground footprint   the walkable rect, in tiles
3.  Legal access point      which columns the stairs occupy, and their direction
4.  Top-surface shape       rim row r0, interior r1–r2, lip row r3
5.  Wall                    stone r4 (or r5 over water) across the south edge
6.  Stairs                  official pieces over the lip row and the wall row
7.  Gameplay collision      1 row of wall at the south, opened at the stair columns,
                            plus collision on the other three edges with no art
8.  Navigation              LOW and HIGH connected only through the stairs
9.  Decoration              only after 1–8 are correct
10. Runtime screenshot QA   judged against §9
```

**TOP SURFACE FIRST. WALL SECOND.** A wall tile where no drop is visible is a lie
about the terrain.

## 7. Composition notes

- Minimum footprint: 3 rows tall, so rim, interior and lip all fit. Under 3 rows the
  region cannot show the rim/lip distinction at all.
- The **rim row `r0` may only appear at the true top** of a region; repeating it
  mid-region invents an edge.
- The **lip row `r3` may only appear immediately above the wall**. A lip with grass
  below it is a visible lie about where the drop is.
- The 临水地块 set is for ground that actually meets water. Using it for the interior
  of a landmass makes the whole area read as a beach.
- Break a long silhouette deliberately — vary the footprint, or let the stairs do it —
  rather than flagging it later. A straight wall is not itself wrong; an unbroken one
  of 18 tiles is.

## 8. Failure modes this grammar exists to prevent

| Failure | Cause |
| --- | --- |
| High ground that looks like a flat slab | Two wall rows drawn instead of one, or the wrong palette contrast |
| A waterline under dry ground | `r5` used where the foot of the wall is land |
| Ground that reads as a beach inland | 临水地块 used away from water |
| A plateau that looks like a moat | Collision walls drawn on all four edges |
| A ramp that does not read as a ramp | A stair piece used, but placed a row too low, so it never meets the grass row |
| A ramp that looks like a hole in a wall | A composed substitute instead of the official stair piece |
| Long mechanical cliff strip | Wall tiles used as fill along an unbroken run |
| Platform with no gameplay purpose | Drawn for looks; nothing can reach it, nothing uses it |

## 9. Visual QA checklist

Run the scene, capture the full viewport, and judge the rendered pixels. There is no
automated assertion for this.

**Macro** — does HIGH read as one coherent region? Can a viewer tell LOW, HIGH and the
legal entrance apart at a glance?

**Meso** — does the plateau look like terrain rather than a large rectangular box? Is
the wall exactly one row? Are the stairs at the ends of the wall, meeting the grass
row? Is the palette step between low and high obvious?

**Micro** — are top and wall cells aligned? Are the rim row and the lip row each used
only in their legal position? Is `r4`/`r5` chosen to match what is under the wall?

**Gameplay readability** — can a player see where they cannot cross, and see how to
get up?

> Anywhere that **looks traversable but is blocked** is a failure.
> Anywhere that **looks blocked but is traversable** is also a failure.

Within the scope of the *visible surface* — a raised region's north and side edges are
not visible faces and are excluded by §3.

## 10. Official references

The pack ships a tile legend and an example map. They are **third-party art and are
not redistributed with this repository** — `asset/` is gitignored. Supply them
locally at:

| Path | What it shows |
| --- | --- |
| `asset/Reference/official_tile_legend_zh.png` | the legend: which cells are ground, stairs and wall |
| `asset/Reference/official_showcase_map.png` | an assembled example map: how the pieces combine |
| `asset/Reference/official_castle_terrace.png` | a raised castle terrace in context |
| `asset/Reference/official_stair_and_wall.png` | a stair meeting the wall and the grass row |

**Read all three of the atlas, the legend and the example map before changing
terrain.** The atlas says which pieces exist, the legend says what each one is, and
the example map says how they are meant to combine. Any one of them alone produced a
wrong answer in this project's history — twice.
