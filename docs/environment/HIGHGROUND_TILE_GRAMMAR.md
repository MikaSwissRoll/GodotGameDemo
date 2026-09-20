# Tiny Swords High-Ground Tile Grammar

How to build high ground in this project using the **actual** Tiny Swords terrain
assets. Read with [`ELEVATION_SYSTEM.md`](ELEVATION_SYSTEM.md), which defines the
gameplay model this grammar must express.

Every fact below was measured from the files in `asset/Terrain/Tileset/`, not
recalled. Do not add a tile reference to code without re-checking it here first.

---

## 1. The atlas, measured

All five palettes — `Tilemap_color1.png` … `Tilemap_color5.png` — are **576 × 384**,
a **9 column × 6 row** grid of **64 px** cells. Their silhouettes are byte-identical
per cell; only the palette differs. So one grammar covers all five, and a colour
swap is always safe.

Per-cell opaque coverage, which is the authoritative "does this cell have art" map:

```
        c0   c1   c2   c3   c4   c5   c6   c7   c8
r0      92   94   92   88    .   92   97   94   89
r1      97  100  100   97    .  100  100  100  100
r2      97  100   98   95    .  100  100  100  100
r3      91   94   92   88    .   93   97   94   91
r4      48    .    .   50    .   89   95   90   84
r5      89    .    .   92    .   85   93   85   78
```

Two consequences that are easy to get wrong:

- **Column 4 is empty.** It is a spacer. Nothing may be placed there.
- The atlas is split into a **LOW set (columns 0–3)** and a **HIGH set
  (columns 5–8)**, separated by that spacer. The two sets are the same shapes with
  different edge treatment.

## 2. Cell semantics

### LOW set — ordinary ground

| Cells | Role |
| --- | --- |
| `c0–c2 × r0` | Top edge of a ground block (ragged grass fringe above) |
| `c0–c2 × r1` | Interior |
| `c0–c2 × r2` | Bottom edge of a ground block |
| `c3 × r0–r2` | One-tile-wide vertical ground strip |
| `c0–c2 × r3` | Free-standing horizontal ground strip (fringed top and bottom) |
| `c3 × r3` | Single free-standing ground tile (fringed on all four sides) |
| `c0 × r4–r5` | Shoreline corner, land to the **left**, water lower-right |
| `c3 × r4–r5` | Shoreline corner, land to the **right**, water lower-left |

`c0/r4` and `c3/r4` are only ~50 % opaque because they are diagonal; `r5` below
completes them. They are a matched **pair** and are always placed together.

### HIGH set — raised ground

| Cells | Role |
| --- | --- |
| `c5–c7 × r0` | Top edge of the high surface — carries a **light teal lit rim** |
| `c5–c7 × r1–r2` | High surface interior |
| `c5–c7 × r3` | **Last grass row before the drop.** Clean straight lower edge with a pale highlight — this is the cliff lip |
| `c8 × r0–r3` | One-tile-wide high-ground strip |
| `c5–c8 × r4` | **Upper cliff face** — grey stone, with grass overhanging its top edge |
| `c5–c8 × r5` | **Lower cliff face** — grey stone, the base course |

The only visual difference between the LOW block and the HIGH block is the **lit
teal rim** on the high surface and the **clean lip** instead of a ragged fringe at
its bottom edge. That rim is the cue the player reads as "this is a step up".

## 3. The cliff face is TWO rows tall

Rows `r4` and `r5` together form the stone face, and **both must be placed**. The
asset provides no single-row face.

> **Defect in the current builder.** `TinySwordsEnvironment.add_plateau` places the
> cliff with `atlas_y = 4` only. Every plateau in the game therefore has a **half-height
> cliff face**: a 64 px painted drop for a 128 px of art. This is one of the reasons the
> high ground reads as a flat box. Correct terrain places `r4` **and** `r5`.

## 4. There is no ramp tile — ramps must be composed

This is the single most important fact in this document.

**The tileset contains no grass ramp, stair or slope tile.** The only
elevation-adjacent art is the 2-row stone cliff face (§3) and the diagonal
shoreline corners (`c0`/`c3` × `r4–r5`), which are **land meeting water**, not a
route between levels.

The project nonetheless uses cells `(0,4) (0,5) (3,4) (3,5)` — the shoreline
corners — as the castle terrace's "side ramps" in `world.gd`. That is a
repurposing, and it is why the legal way up a plateau does not read as a way up:
the player is shown a beach, not a staircase.

Because there is no ramp art, **a legal access point must be composed from what
exists**. Two step heights are available:

| Step | Composition | Reads as |
| --- | --- | --- |
| **1-tile step** | high-surface last row `r3` above stone `r4` | a low ledge with grass on top |
| **2-tile step** | high-surface last row `r3` above stone `r4`+`r5` | a full-height drop |

A stair is a sequence of these at descending heights — typically
`r3+r4+r5` → `r3+r4` → ground, each offset one tile outward, giving a two-step
descent. Each step repeats the **lip row `r3` directly above its own stone rows**,
so every tread reads as a walkable surface rather than a wall.

Do not invent a ramp by drawing arbitrary tiles, and do not present a shoreline
corner as a route. If a scene genuinely needs a ramp the art cannot express, that
is a decision to raise with the user — not something to fake with cliff tiles.

## 5. Construction order

Build in this order. Every one of the failures in §7 came from starting at step 5.

```
1.  Gameplay purpose        what is this high ground FOR?
2.  High-ground footprint   the walkable rect, in tiles
3.  Legal access point      where the ramp is, and its direction
4.  Top-surface shape       rim row r0, interior r1-r2, lip row r3
5.  Visible drop edges      which boundary cells actually drop
6.  Cliff faces             stone r4 + r5 under every lip row r3
7.  Gameplay collision      movement blockers along cliffs, opening at the ramp
8.  Navigation              LOW and HIGH connected only through the ramp
9.  Decoration              only after 1-8 are correct
10. Runtime screenshot QA   judged against §10
```

**TOP SURFACE FIRST. CLIFFS SECOND.**

Cliff tiles express a visible elevation boundary. They are **not** generic
wall-fill. A cliff tile placed where no drop is visible is a lie about the terrain.

## 6. Composition recipes

### Minimum viable plateau

- Purpose: a defensible overlook, an archer perch, or a route waypoint.
- Footprint: 4 × 3 tiles or larger. Smaller cannot show rim, interior and lip.
- Access: one composed stair (§4) on one edge, two tiles wide.
- Top surface: `r0` across the top row, `r1`/`r2` interior, `r3` across the bottom row.
- Drop: `r4`+`r5` under every `r3`, except across the ramp opening.
- Collision: one movement blocker per boundary **segment**, never one block over the
  whole footprint.
- Shape: a plateau must not be a bare rectangle. Break the outline — a notch, an
  angled corner, an L — so its silhouette says what it is for.

### Rules that keep it from looking mechanical

- A cliff run should not exceed roughly five tiles without a break — a corner, a
  stepped section, or the ramp. Long straight stone strips read as a wall texture,
  not a landform.
- The **rim row `r0` may only appear at the true top of a region**. Repeating it
  mid-plateau creates a false edge.
- The **lip row `r3` may only appear immediately above stone**. A lip with grass
  below it is a visible lie about where the drop is.
- Vary palette between adjacent regions, never within one region.
- A shoreline corner (`c0`/`c3` × `r4–r5`) may only be used where land actually
  meets water.

## 7. Failure modes this grammar exists to prevent

All seven observed in the current project.

| Failure | Cause |
| --- | --- |
| Giant rectangular grass platform | Footprint drawn as a plain rect with no silhouette design |
| Huge solid cliff front | Whole footprint treated as one wall instead of a boundary |
| Long mechanically repeated cliff strip | Cliff tiles used as fill along an unbroken straight run |
| High ground that looks like a thick box | Only `r4` placed, so the face is half height and the top reads as a slab edge |
| Terrain built cliff-first | Work started at step 5 with no gameplay purpose or footprint decided |
| Platform with no functional relationship to gameplay | Drawn for looks; nothing can reach it, nothing uses it |
| Ramp that does not read as a ramp | A **shoreline corner** used as an access route (§4) |

## 9. Edges the tileset cannot draw as a cliff

The stone face is a **horizontal** course. There is no vertical cliff art anywhere
in the pack, so a high region can render a cliff on its **south** edge only.

The other three edges still have to be blocked — a cliff is a boundary on every side
(invariant 5) — and blocking an edge with nothing drawn under it produces an
invisible wall, which is exactly what the last line of §8 forbids: it looks walkable
and is not.

`HighGround` resolves this by drawing a **retaining wall**: the same stone, laid
along the low-side band that the collision already occupies, using the base course
(`ROW_FACE_BOTTOM`) rather than the top course. The top course carries a grass
overhang that only makes sense on a downward-facing drop; the base course is plain
masonry and reads correctly as a wall running along an edge.

The result is a terrace that looks held up rather than one whose ground simply
stops. This is the grammar's preferred remedy — bound the edge with something
visible, using the terrain's own material rather than scattered decoration.

What is **not** acceptable:

- shipping the invisible wall and calling it done;
- removing the collision, which makes the plateau reachable from every side and
  undoes the entire model;
- improvising a vertical cliff from rotated stone tiles. A rotated horizontal course
  reads as a mistake far more often than as a face. If you try it, verify it in a
  capture before believing it.

## 10. Visual QA checklist

Run the scene, capture the full viewport, and judge the rendered pixels. There is no
automated assertion for this.

**Macro** — does HIGH read as one coherent region? Can a viewer tell LOW, HIGH and
the legal entrance apart at a glance?

**Meso** — does the plateau look like terrain rather than a large rectangular box?
Are cliff faces used only where a drop is actually visible? Are there long
mechanical cliff strips? Does the ramp belong to the terrain it serves?

**Micro** — are top and cliff cells aligned? Are the rim row and the lip row each
used only in their legal position? Is tile repetition distracting?

**Gameplay readability** — can a player see where they cannot cross, and see how to
get up?

> Anywhere that **looks traversable but is blocked** is a failure.
> Anywhere that **looks blocked but is traversable** is also a failure.

A platform that satisfies every gameplay invariant and still fails this checklist is
not finished.
