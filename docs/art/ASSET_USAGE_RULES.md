# Asset usage rules

## Purpose

This document owns how Tiny Swords assets are inspected, selected, imported,
scaled, animated, reused, and protected. It does not decide scene composition or
UI hierarchy; use [Environment Design](ENVIRONMENT_DESIGN.md) and
[UI Visual Rules](UI_VISUAL_RULES.md) for those decisions.

## Source and ownership

The project asset root is:

```text
asset/
```

It contains the Tiny Swords PNG sources and included Aseprite files. Treat these
as third-party originals:

- never overwrite, rename, recolor, crop, or reorganize source files in place;
- never remove source variants because the current scene does not use them;
- create derived textures, resources, atlases, or scripts outside `asset/`;
- preserve the source pack's license and do not redistribute or repackage it;
  and
- record the source path when creating a project-owned derivative.

The official license permits use and modification in projects, but the local
rule remains stricter: original files stay unchanged so updates and provenance
remain clear.

## Inspect before referencing

Before adding an asset:

1. search the actual project files rather than guessing a path;
2. inspect the image at native resolution;
3. record its width and height;
4. determine whether it is a single sprite, animation strip, atlas, or
   stretchable component sheet;
5. confirm frame size, frame count, and direction layout;
6. check all color and shape variants in the same family; and
7. verify the rendered result in Godot after import.

Do not infer animation frames from a filename alone. The pack includes families
with different strip sizes and stretchable UI sheets whose pieces are separated
by regular strides.

## Selection order

Use assets in this order:

1. an exact existing Tiny Swords asset;
2. another variant from the same family;
3. a composition of existing pieces;
4. a project-owned runtime crop, atlas, animation, or nine-slice resource; and
5. new compatible art only when the pack has no suitable solution.

A placeholder must be documented and visually reviewed beside native assets. Do
not draw generic rectangles, circles, or gradients over the final scene when a
matching terrain, panel, button, bar, icon, effect, or prop already exists.

## Family map

Use the actual project families consistently:

- `asset/Terrain/Tileset/`: five terrain colors, water background, water foam,
  shadows, flat ground, elevation, cliffs, and stairs.
- `asset/Buildings/`: castle, houses, monastery, barracks, archery building,
  and tower in blue, red, purple, yellow, and black.
- `asset/Terrain/Resources/`: trees, stumps, sheep, gold, meat, wood, and tools.
- `asset/Terrain/Decorations/`: bushes, ground rocks, animated water rocks,
  clouds, and the rubber duck.
- `asset/Units/`: warrior, lancer, archer, monk, and pawn families in faction
  colors.
- `asset/Particle FX/`: dust, fire, explosion, and water-related effects.
- `asset/UI Elements/`: paper, wood table, banners, ribbons, swords, bars,
  buttons, cursors, avatars, and icons.

Check the folder whenever the pack is updated; this list describes the current
project copy rather than a promise that it will never change.

## Pixel rendering and scale

Use nearest-neighbor filtering and avoid mipmaps for pixel-art gameplay and UI
textures. Keep terrain at its native 64-pixel cell size. Align terrain,
collisions, and major placement anchors to integer coordinates.

Prefer native 1x display scale. When the camera composition requires resizing:

- choose one shared scale for the asset family or scene role;
- keep the scale stable across adjacent objects of the same type;
- avoid arbitrary per-object fractional scales;
- inspect the result during camera movement for shimmer and uneven pixels; and
- do not resample and save a smaller copy into the source asset folder.

Use flips only when they preserve lighting, handedness, weapon direction, and
readability. Do not rotate pixel assets to angles the pack does not support.

## Animation

The official pack uses a 10 fps or 100 ms baseline. Preserve that timing for
character actions unless gameplay demands a deliberate change. Environmental
loops may run more slowly when a calmer motion reads better, but the choice
should be consistent within the family.

Offset the starting frames of repeated water foam, bushes, trees, animals, and
fire so a scene does not pulse in sync. Do not stretch one frame or skip frames
without inspecting the loop. Keep combat hit timing tied to gameplay logic,
not merely to visual frame count.

## Faction variants

Use blue units and buildings for the current friendly village and red for the
current hostile force. Do not mix color variants decoratively inside one faction.
Purple, yellow, and black require a documented faction or encounter purpose
before use. Neutral terrain and resources may appear across factions, while
placement and activity communicate ownership.

## Terrain assets

Treat terrain tiles as a connected grammar rather than independent decorative
sprites. Use the 64-pixel grid and official adjacency, cliff, shadow, stair, and
foam roles defined in [Environment Design](ENVIRONMENT_DESIGN.md). Do not use
terrain center tiles as free-floating patches without correct edges.

## Buildings and props

Use the foundation foot as the placement anchor. A building sprite may overlap
characters visually above its foundation, while collision remains on the lower
base. Keep shadow, scale, and faction treatment consistent across a building
group.

Use props to communicate activity or shape composition. Repeated rocks, trees,
resources, or sheep should use family variants and phase offsets before duplicate
copies become obvious.

## UI assets

Reconstruct stretchable UI from its supplied edge, center, and corner pieces.
Use project-owned `StyleBoxTexture`, atlas, or generated runtime textures; keep
the source component sheets untouched. Verify corners, content margins, text
contrast, and button states at the final control size.

## Derived resource rules

Project-owned helpers may crop frames or assemble textures at runtime. A derived
resource should:

- reference the original `res://asset/...` path;
- state its frame or slice geometry in code or resource metadata;
- live under `scripts/`, `scenes/`, or another project-owned directory;
- avoid embedding unnecessary copies of the original sheet; and
- remain reusable only when more than one scene actually needs it.

## Asset review checklist

Before accepting a new reference, confirm:

- the path and filename exist exactly as written;
- the source file remains unchanged;
- the correct family and faction variant were chosen;
- filtering, scale, and integer placement preserve pixel clarity;
- animation frames and timing are correct;
- derived crop or slice geometry matches the source sheet;
- an existing asset was not overlooked in favor of a placeholder; and
- the rendered scene or UI was captured and visually inspected.

## Source references

- [Tiny Swords by Pixel Frog](https://pixelfrog-assets.itch.io/tiny-swords)
- [Official Tiny Swords Tilemap Guide](https://pixelfrog-assets.itch.io/tiny-swords/devlog/1138989/tilemap-guide)