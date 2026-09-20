# UI asset guide

## Purpose

Which existing files to use for UI work, with their **measured** geometry and
their current use in the project. Owners of the surrounding policy:

- **How to build UI** → [UI Workflow](UI_WORKFLOW.md)
- **What it should look like** → [UI Visual Rules](../art/UI_VISUAL_RULES.md)
- **Provenance, modification, and licensing of third-party sources** →
  [Asset Usage Rules](../art/ASSET_USAGE_RULES.md)

This document does not restate those rules. It is the inventory: real paths,
measured sizes, and whether stretching is safe.

Every path below exists in the repository. Every dimension was measured from the
file, not inferred from a filename.

Geometry and compatibility notes are stable until the source asset or rendering
helper changes. Statements such as "in use," "unused," and "has no callers" are
a working-tree snapshot. Recheck those claims with a code search before deleting
or redesigning anything.

## Use this guide

Use the inventory to choose and verify an asset without repeating earlier
measurement mistakes.

1. Start with the visual role: surface, action, value bar, status icon, or
   decoration.
2. Choose the highest-priority compatible source family.
3. Inspect the exact file at native resolution.
4. Distinguish its logical rect, painted silhouette, and usable content plane.
5. Check every state and size that the component will render.
6. Capture the asset inside the real target screen before accepting it.

Do not copy a margin or optical offset from another asset merely because both
are buttons or panels. Measurements belong to the exact file, state, and
rendering helper that produced them.

## Source priority

1. `asset/UI Elements/UI Elements/` — the Tiny Swords UI kit. **First choice**
   for every panel, button, bar, and icon in the game's own style.
2. `asset/Shikashi's Fantasy Icons Pack v2/` — 245 flat 32px RPG icons. Use for
   functional item/status symbols the Tiny Swords kit lacks.
3. Other `asset/` families — `Terrain/Resources/`, `Particle FX/`, `Units/` —
   for in-world iconography such as gold piles or meat.
4. A project-owned runtime crop or composite (`TinySwordsUI`, `TinyBar`).
5. New art only when nothing above fits, and it must sit beside the pack for
   review.

Never reach for a default Godot Button, a `ColorRect` panel, or a placeholder
icon when a file below fits. In this project that is a defect, not a shortcut.

---

## Style compatibility warning

The two packs are **different art styles** and do not blend:

- **Tiny Swords** — chunky, saturated, heavy dark outlines, hand-painted pixel
  art. This is the game's identity.
- **Shikashi** — thin outlines, flatter and more muted, designed for RPG Maker MV
  at 32x32.

They work in different slots: Tiny Swords for frames, panels, buttons, bars, and
decorative icons; Shikashi for small functional item and status glyphs where a
recognisable symbol matters more than match. Do not put a Shikashi icon inside a
Tiny Swords banner as a decorative element, and do not mix the two within one
icon row.

Also note the Shikashi sheet is **crisp at 32x32 and designed for that size**.
Displaying it at a larger integer multiple is acceptable; fractional scaling
blurs it.

---

## Tiny Swords UI kit — `asset/UI Elements/UI Elements/`

### Panels

| File | Size | Opaque extent | Use |
| --- | --- | --- | --- |
| `Papers/SpecialPaper.png` | 320x320 | x9..310 y20..298 | **Modal and HUD panel surface.** 3x3, tiles at stride 128 from origin (0,0). |
| `Papers/RegularPaper.png` | 320x320 | x12..307 y20..300 | Light cream paper. Tiles at stride 128 from (12,8). |
| `Wood Table/WoodTable.png` | 448x448 | x44..403 y43..422 | Wooden table. Tiles at stride 128 from (64,64). |
| `Wood Table/WoodTable_Slots.png` | 192x192 | x12..179 y11..180 | Single slot overlay for the wood table. |
| `Banners/Banner.png` | 448x448 | x28..403 y60..430 | Scroll banner. Tiles at stride 128 from (64,64). |
| `Banners/Banner_Slots.png` | 192x192 | x5..189 y5..187 | Single slot overlay for the banner. |

**Stretch safety — read before using any of these as a panel.**

`SpecialPaper` is the **only** one of the three panel sheets that renders a clean
solid panel when nine-patched:

- `RegularPaper` — its middle tile row is transparent, and the corner tiles carry
  baked-in padding, so nine-patching produces **separated cards with a see-through
  centre**, not a surface. Its tiles also step by 128 from x=12 but its third row
  ends at y=298 rather than 319, so a single shared offset samples empty pixels.
- `Banner` — the scroll curl repeats as **visible stripes** when tiled.
- `Banner` and `WoodTable` tiles are 64px but step by 128 from an origin of (64,64),
  not from the image edge. `_nine_patch()` samples from (0,0) and is wrong for
  them; `TinySwordsUI.patched()` takes per-axis offsets and is correct.

Banner and wood table are therefore **decorative banners and table surfaces**, not
general panel backgrounds. Note the main-menu title bar is currently a
`StyleBoxFlat`, not the `Banner` sheet.

### Buttons

| File | Sheet | Tile geometry | Native frame |
| --- | --- | --- | --- |
| `Buttons/BigBlueButton_Regular.png` | 320x320 | 3x3, stride 128 from (0,0) | caps 24px top / 20px bottom |
| `Buttons/BigBlueButton_Pressed.png` | 320x320 | as above | pressed state |
| `Buttons/BigRedButton_Regular.png` | 320x320 | as above | destructive |
| `Buttons/BigRedButton_Pressed.png` | 320x320 | as above | destructive pressed |
| `Buttons/SmallBlueRoundButton_Regular.png` | 128x128 | 3x3, stride 64 from (0,0) | small round |
| `Buttons/SmallBlueRoundButton_Pressed.png` | 128x128 | as above | |
| `Buttons/SmallBlueSquareButton_Regular.png` | 128x128 | as above | small square |
| `Buttons/SmallBlueSquareButton_Pressed.png` | 128x128 | as above | |
| `Buttons/SmallRedRoundButton_Regular.png` | 128x128 | as above | |
| `Buttons/SmallRedRoundButton_Pressed.png` | 128x128 | as above | |
| `Buttons/SmallRedSquareButton_Regular.png` | 128x128 | as above | |
| `Buttons/SmallRedSquareButton_Pressed.png` | 128x128 | as above | |
| `Buttons/TinyRoundBlueButton.png` | 64x64 | single tile | icon-size button |
| `Buttons/TinyRoundRedButton.png` | 64x64 | single tile | |
| `Buttons/TinySquareBlueButton.png` | 64x64 | single tile | |
| `Buttons/TinySquareRedButton.png` | 64x64 | single tile | |

**Semantics:** blue is safe/affirmative/navigation; red is destructive,
irreversible, or a spend. See
[UI_VISUAL_RULES](../art/UI_VISUAL_RULES.md) "Surface language".

**Size constraints for the Big buttons — measured.** The frame's caps take a
constant 44px of height (24 top, 20 bottom) and the painted inner band is close to
`height - 44`. A Button's own single text block is fine at any reasonable height,
but **two lines of text cannot fit inside the frame at any sane button height**.
For a two-line row use `ActionRow`, which draws its own labels.

For reference, `ActionRow` uses `SINGLE_HEIGHT = 82` and `FULL_HEIGHT = 125`. It
centres its labels on the art's measured visible extent (`ART_ABOVE = 18`,
`ART_BELOW = 29`, both read from a live render) and then applies
`FRONT_FACE_TEXT_OFFSET_Y = -10` to bias onto the front-facing plane, because the
art includes a lower extrusion and the optical centre of the beveled button is not
the centre of its full silhouette.

These constants model two different bounds. `ART_ABOVE` and `ART_BELOW` describe
the complete painted silhouette, while `FRONT_FACE_TEXT_OFFSET_Y` excludes the
lower depth extrusion from the perceived content center. The recent pause and
reward fix only converged after both bounds were measured. Recheck the
front-facing plane for pressed art or a different button family instead of
reusing this offset blindly.

### Bars

| File | Size | Opaque extent | Use |
| --- | --- | --- | --- |
| `Bars/BigBar_Base.png` | 320x64 | x40..279 y9..59 | Health bar frame. 3-slice: caps x40..63 and x256..279, middle x128..191, frame y9..52. Recess y25..43. |
| `Bars/BigBar_Fill.png` | 64x64 | x0..63 y20..43 | Health fill: a vertical gradient, so horizontal stretch/tile is lossless. |
| `Bars/SmallBar_Base.png` | 320x64 | x49..270 y22..40 | Stamina bar frame. Caps x49..63 and x256..270, middle x128..191, frame y22..40. Recess y30..38. |
| `Bars/SmallBar_Fill.png` | 64x64 | x0..63 y30..32 | Stamina fill: a **solid 3px line**, not a block. The track is the empty part and this line is the value. |

**Never nine-patch these.** They are 3-slices with irregular tile spacing — the
caps are not flush with their 64px tiles — and `NinePatchRect` does not stretch
them correctly at any patch margin or axis mode (margins 6/12/24/40 were swept in
both STRETCH and TILE). Use `TinyBar`, which composes the bar at its exact width:
caps blitted whole, middle tile repeated.

Both fills ship red. Stamina must read gold, and multiplying red by gold only
yields orange, so `TinyBar` applies a small hue-shift shader rather than a
modulate.

### Icons — `Icons/`, all 64x64

Identified by rendering the sheet, not by filename. Only three are currently used.

| File | Depicts | Used for | In use |
| --- | --- | --- | --- |
| `Icon_01.png` | Wooden club / log | — | no |
| `Icon_02.png` | Stack of logs | — | no |
| `Icon_03.png` | **Gold coin with $** | Currency readout | **yes** |
| `Icon_04.png` | Raw meat | — (available for health/food) | no |
| `Icon_05.png` | **Sword over a shield** | Combat / stage readout | **yes** |
| `Icon_06.png` | **Shield, blue quartered** | Quest objective, modal emblem | **yes** |
| `Icon_07.png` | Green gem | — | no |
| `Icon_08.png` | Orange gem | — | no |
| `Icon_09.png` | **Red X** | — (available for cancel/close) | no |
| `Icon_10.png` | Gear / cog | — (available for settings) | no |
| `Icon_11.png` | Ring with an **i** | — (available for info/tooltip) | no |
| `Icon_12.png` | Musical notes | — | no |

These are chunky pixel art with heavy outlines and match the kit exactly. Prefer
them over the Shikashi pack for anything decorative or HUD-level. `Icon_04`
(meat) is the natural companion to a health readout and `Icon_09` / `Icon_10` /
`Icon_11` are obvious unused affordances.

### Ribbons and decorations

| File | Size | Geometry | In use |
| --- | --- | --- | --- |
| `Ribbons/BigRibbons.png` | 448x640 | 3 columns x30..127, 192..255, 320..416; **5 rows** y20..122, 148..250, 276..378, 404..506, 532..634 (128px steps from x64/y64) | helper exists (`ribbon_style`), **not called** |
| `Ribbons/SmallRibbons.png` | 320x640 | 3 columns x2..63, 128..191, 256..317 (128px steps from x2); **10 rows** y4..63, 68..121, 132..191, … 580..633 (64px steps from y4) | no |
| `Swords/Swords.png` | 448x640 | 3 columns x23..127, 192..255, 320..411 (128px steps from x64); a **single full-height column group**, y0..639, so not a tile grid | no |

`BigRibbons` has **five** rows, not ten, and `SmallRibbons` has ten. `Swords` is
not a 3x3 sheet at all — it spans the full 640px height, so it is a decoration
strip, not a nine-patch source.

`BigRibbons` is a multi-row colour sheet, not a 3x3 nine-patch. Treating it as
`_nine_patch` samples the wrong region — this is why the main-menu title bar is a
`StyleBoxFlat` rather than a ribbon.

### Avatars and cursors

| File | Size | In use |
| --- | --- | --- |
| `Human Avatars/Avatars_01.png` … `Avatars_25.png` | 256x256 each | no |
| `Cursors/Cursor_01.png` … `Cursor_03.png` | 64x64 | no |
| `Cursors/Cursor_04.png` | 128x128 | no |

Useful for a future dialogue speaker portrait, a character-select screen, or a
custom cursor. Nothing uses them today.

---

## Shikashi's Fantasy Icons Pack v2 — `asset/Shikashi's Fantasy Icons Pack v2/`

| File | Size | Contents |
| --- | --- | --- |
| `#1 - Transparent Icons.png` | 512x867 | 245 icons on transparent background |
| `#2 - Transparent Icons & Drop Shadow.png` | 512x867 | same icons with a drop shadow |
| `Background 1a/1b/2.png`, `BG 3a/3b/3c/4a/4b/5/6/7/8/9/10/11.png` | 512x867 | icon frames/backgrounds, one sheet each |

**Layout — read this before using any cell coordinate.**

The sheet is **512 × 867**, on a **32 × 32 cell grid: 16 columns × 27 rows**, with
the last row incomplete. Two traps make naive coordinates wrong:

1. **Rows are not full.** The grid is 16 wide, but occupied cells per row vary
   sharply. Measured by scanning the sheet:

   | Row | Occupied columns | Count |
   | --- | --- | --- |
   | 0 | 0–10 | 11 |
   | 1 | 0–4 | 5 |
   | 2 | 0–6 | 7 |
   | 3 | 0–15 | 16 |
   | 4 | 0–8 | 9 |
   | 5 | 0–15 | 16 |
   | 6 | 0–11 | 12 |
   | 7 | 0–15 | 16 |
   | 8 | 0–9 | 10 |
   | 9–11 | 0–15 | 16 |

   So "the 6th icon in row 0" is **col 5 (sparkles)**, not the speech bubble —
   row 0 holds only 11 icons, and the speech bubble is **col 3**.

2. **The pack's manifest lists icons by category, not by atlas position.** The
   order in `Shikashi's Fantasy Icons Pack.txt` (status effects → body → buffs →
   special moves → …) is *not* the visual order of the atlas. Do not derive a
   cell coordinate from the manifest's category list.

There is no per-icon file. Extract with `AtlasTexture` at a 32px region.

**Using a cell in Godot**

```gdscript
var tex := AtlasTexture.new()
tex.atlas = load("res://asset/Shikashi's Fantasy Icons Pack v2/#1 - Transparent Icons.png")
tex.region = Rect2i(col * 32, row * 32, 32, 32)
```

Set `texture_filter = TEXTURE_FILTER_NEAREST` on the node. The sheet's `.import`
settings already match the Tiny Swords icons (no mipmaps, lossless), so no import
change is needed. The `#` and space in the filename are fine in a `res://` path.

**How to record a new cell — do not count columns by eye**

Counting by eye is how this project already got a coordinate wrong once: a cell
was recorded as `px(160,0)` for the speech bubble when `px(160,0)` is sparkles,
and the error only surfaced because the cell was rendered and looked at. Use this
procedure:

1. **Scan the sheet**, do not count. Determine which cells are occupied per row
   (a short Godot script reading the image's alpha is enough). This immediately
   exposes a short row. `tools/dump_icon_atlas.gd` does this and flags any row
   that is not full:

   ```powershell
   $godot --path . --script res://tools/dump_icon_atlas.gd
   ```

   Set its `DETAIL_ROWS` to the rows you are choosing from to also print each
   cell's pixel rect and inner opaque box.
2. **Convert to a pixel rect** as `Rect2i(col * 32, row * 32, 32, 32)`.
3. **Also record the inner bounding box** — the opaque extent within the cell,
   which is smaller than 32x32 and is what you want for tight placement (a head
   marker should use the icon's real bounds, not the cell's padding).
4. **Render the cell and look at it** before writing the coordinate anywhere.
   This is the step that catches a wrong coordinate; nothing else does.
5. Record it in the table below with the pixel rect, not a row/column phrase.

When describing a cell in a message, give the **pixel rect** — `px(96,0,32,32)`.
Row/column phrases such as "row 5, icon 2" are ambiguous: row and column may be
counted from 0 or 1, "icon 2" may mean the 2nd occupied cell or column 2, and
`#1` / `#2` are two different files.

**Confirmed cells**

Measured from `#1 - Transparent Icons.png` and verified by rendering.

| Icon | Cell | Pixel rect | Inner box | Suits |
| --- | --- | --- | --- | --- |
| Speech bubble, three dots | row 0, col 3 | `px(96,0,32,32)` | `(4,6,24,22)` | interactable / trade marker |
| Sparkles | row 0, col 5 | `px(160,0,32,32)` | `(4,3,23,24)` | *not* a bubble — kept as a counter-example |
| Filled bubble | row 4, col 0 | `px(0,128,32,32)` | `(3,5,26,20)` | content waiting to be read |
| Double bubble | row 4, col 1 | `px(32,128,32,32)` | `(3,3,26,25)` | plain dialogue |
| Campfire | row 4, col 2 | `px(64,128,32,32)` | `(5,3,22,26)` | rest point |

**Contents**, per the pack's own manifest: 11 status effects, 5 body icons, 7
buffs and debuffs, 16 special moves, 9 non-combat actions, 28 weapons, 26
clothing and armour, 16 healing items, 64 general items, 31 food, 15 fishing
items, 11 resources, 6 orbs, 39 new icons. Use this only to know *what exists*,
never to infer a position.

**Not currently used anywhere in the project.** Nothing references this pack.

**Scaling:** authored for 32x32. Display at 32 (1x), 64 (2x), or 96 (3x) with
`TEXTURE_FILTER_NEAREST`. Avoid arbitrary sizes.

**Style caveat:** the icons are white or lightly coloured line art. Over the
Tiny Swords bright grass a white bubble has weak contrast; expect to need an
outline or a translucent backing plate. Judge this in a rendered capture over the
real terrain, not against a flat swatch.

---

## Other families worth borrowing from

Existing project art that can serve as UI iconography when a symbol is wanted
rather than a UI glyph. Verify the exact filename in the folder before use.

| Path | Contents |
| --- | --- |
| `asset/Terrain/Resources/` | trees, stumps, sheep, **gold**, **meat**, wood, tools |
| `asset/Particle FX/` | dust, fire, explosion, water effects |
| `asset/Units/` | warrior, lancer, archer, monk, pawn in five faction colours |
| `asset/Buildings/` | castle, houses, barracks, tower in five faction colours |

`Terrain/Resources/` gold and meat match the world art and are a natural fit for a
reward or loot readout where a UI-styled icon would look pasted on.

---

## Current gaps and unused opportunities

Honest state of asset usage, so future work does not re-derive it:

- **`RegularPaper` and `Banner` cannot serve as general panel surfaces** for the
  measured reasons above. Their sheets remain unused beyond documentation.
- **Nine of twelve icons are unused.** `Icon_04` (meat), `Icon_09` (red X),
  `Icon_10` (gear), `Icon_11` (info) are obvious affordances for a health
  readout, a close button, settings, and a tooltip.
- **No potion or status icons are used yet.** The shop currently shows potions as
  text-only buttons; the Shikashi healing-item icons or a Tiny Swords composition
  would strengthen it.
- **The twelve Shikashi background sheets are unused.** They are alternate icon
  frames and could style a status-effect row.
- **`SmallRibbons`, `Swords`, all avatars, and all cursors are unused.**
- **Dead style helpers.** `TinySwordsUI.bar_background_style()`,
  `bar_fill_style()`, and `ribbon_style()` currently have no callers — the bars
  and the title bar were replaced by `TinyBar` and a `StyleBoxFlat`. They are
  leftovers, not available tools; remove or repurpose them rather than assuming
  they are the intended path.

## Keep usage notes current

The geometry tables are measurement records. The "in use" and "current gaps"
sections are maintenance hints and require verification against the current
working tree.

Before changing one of those statements:

1. Search exact asset paths and helper names with `rg`.
2. Check runtime-created resources, because many UI assets are referenced in
   GDScript rather than `.tscn` files.
3. Update every affected row and the current-gaps list in the same change.
4. Record a new measurement when a rendering helper changes how the asset is
   sliced, stretched, tinted, or offset.

Do not remove a helper solely because this guide calls it unused.

## Add a new asset reference

Add evidence that another developer can reproduce.

1. Confirm the exact path on disk.
2. Open the file at native resolution and record width, height, alpha bounds, and
   any transparent padding.
3. Classify it as a single sprite, three-slice, nine-patch, or multi-row sheet.
4. Measure tile origin, stride, cap sizes, and safe stretch axes when applicable.
5. Record the logical rect, complete painted silhouette, and usable content
   plane separately.
6. Repeat rendered measurements at three representative sizes when the asset
   stretches.
7. Check regular, pressed, focused, and disabled art when those states use
   different files or offsets.
8. Add or update the relevant table and current-use note.
9. Verify the result in a full-viewport target capture.

See [Asset Usage Rules](../art/ASSET_USAGE_RULES.md) for provenance and the
no-modification policy on `asset/`.
