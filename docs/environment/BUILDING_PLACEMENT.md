# Building Placement

How to put a building on the map, and how to talk about where it is.

Read with `HIGHGROUND_TILE_GRAMMAR.md` §6.1 when the building goes on high ground.
For the coordinate conventions themselves see `AGENTS.md`, "Coordinate protocol".

## 1. The call

```gdscript
ENV.add_building(parent, texture_path, foot, scale, collision_size, shadow_scale)
```

| Argument | Meaning |
| --- | --- |
| `foot` | **the anchor.** Where the building stands. Not its centre on screen. |
| `scale` | `1.0` unless the art needs shrinking |
| `collision_size` | the blocking box at the base; `Vector2.ZERO` for none |
| `shadow_scale` | ground shadow, `Vector2(1.7, 0.66)` for the castle, `(1.0, 0.55)` default |

## 2. What `foot` actually controls

```
sprite:     x from foot.x - w/2  to  foot.x + w/2
            y from foot.y - h*scale  to  foot.y          <- grows UPWARD
collision:  centred at  foot - Vector2(0, collision.y * 0.5)
```

Two consequences that decide most placement questions:

**The sprite and the anchor are in different tiles.** A building is drawn upward from
its foot, so its bulk covers the rows *above* the tile the anchor sits in. A monastery
with its foot at row 7 is "the house at row 6" to anyone looking at the screen. When
someone names a building by where they can see it, convert: the foot is at the
**bottom** of what they are pointing at.

**The collision box sits above the foot, not on it.** A `250x56` box on a foot at
`y = 480` covers `y 424..480` - rows 6 and 7, not row 7 alone.

## 3. Placing at a tile

To stand a building on tile `(C, R)`, put the foot at the tile's centre:

```gdscript
foot = Vector2(C * 64 + 32, R * 64 + 32)
```

Then check three constraints.

| Constraint | How |
| --- | --- |
| **It fits** | `w <= region width in px` and `h * scale <= region height in px` |
| **Nothing else overlaps** | compare `x` and `y` extents against the other buildings |
| **Paint order is right** | the list is sorted by `foot.y`, back to front, so roofs overlap correctly |

> **Watch the unsorted buildings.** The castle and the monastery are added *before* the
> sorted loop, so they draw behind every house. Placing a rare building next to the
> generic houses lets the houses paint over it. Either separate the coordinates, or add
> it to the sorted list.

## 4. Measuring before placing

Do not estimate a sprite's size. Read it:

```powershell
Add-Type -AssemblyName System.Drawing
$img = [System.Drawing.Image]::FromFile($path)
"$($img.Width) x $($img.Height) px = $([math]::Round($img.Width/64,2)) x $([math]::Round($img.Height/64,2)) tiles"
```

The castle is `320 x 256` = 5 x 4 tiles. The forecourt is 11 x 6, so it fits with room
to spare - a fact worth having before choosing the coordinate, not after.

## 5. Answering "where is X?"

Answer with four things, always:

1. **what it is**;
2. its **foot in world pixels**;
3. **the tile the foot sits in** - `floor(x / 64)`, `floor(y / 64)`;
4. **which tiles its sprite covers**.

Item 4 is what stops the next round of guessing. Without it, "the house at col 26 row 6"
has no answer, because no house has a foot there - the thing covering that tile is the
monastery, whose foot is at col 26 **row 7**.

**When the named tile holds nothing, answer with arithmetic.** Report what is on the
tile and whose footprint covers it, act on the closest match, and say which one it was.
Guessing is not available: the coordinates either match or they do not.

## 6. Worked examples

| Building | Foot | Foot tile | Sprite covers |
| --- | --- | --- | --- |
| Castle | `(1248, 352)` | col 19 row 5 | 5 x 4 tiles above the foot |
| Monastery | `(1848, 510)` | col 28 row 7 | spans cols 26-29, rows 4-7 |
| House1 | `(1690, 790)` | col 26 row 12 | cols 26-27, rows 9-12 |

A move is quoted as a tile delta and converted: **+/-N columns or rows = +/-N * 64 px**.
The monastery's move from `x 1720` to `x 1848` is "+2 columns", which is how it was
asked for and how it should be recorded.

## 7. Removing one

When asked to delete a building, leave the exact call in a comment above where it was:

```gdscript
    # To restore:
    #     ENV.add_building(self, BLUE + "Castle.png", Vector2(1248, 352), 1.0,
    #         Vector2(250, 56), Vector2(1.7, 0.66))
```

Git has the history, but the person reading the file does not want to go looking for it.
This is what made the castle's removal and restoration a one-line operation.
