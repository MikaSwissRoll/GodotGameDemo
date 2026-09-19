# Art direction

## Purpose

This document owns the project's overall visual identity. It defines what the
game should feel like at a glance and how visual decisions are prioritized. Use
[Environment Design](ENVIRONMENT_DESIGN.md),
[UI Visual Rules](UI_VISUAL_RULES.md), and
[Asset Usage Rules](ASSET_USAGE_RULES.md) for implementation-level rules.

The supplied Tiny Swords reference image is a direction reference for density,
terrain depth, building groups, vegetation rhythm, water treatment, route
clarity, composition, and color unity. It is not a map to copy tile for tile.

## Visual promise

The game should look like a compact, hand-authored fantasy kingdom built from
Tiny Swords, with the clarity required by a responsive top-down action RPG.
Each viewport should read as a small illustrated diorama: one memorable place,
one understandable route, and enough breathing room to fight.

A player should be able to identify within a moment:

1. where they can move;
2. what location or faction they have entered;
3. which objects matter to play; and
4. where the eye should rest.

## Visual pillars

### Miniature kingdom

Buildings, cliffs, trees, units, props, and UI belong to the same colorful,
chunky fantasy world. Scenes should feel intentionally arranged and lived in,
not like isolated sprites distributed over a flat field.

### Layered landscape

Water, foam, terrain edges, shadows, elevation, structures, vegetation, and
small accents create foreground and background depth. Flat open grass is used
for play space, not as the dominant visual treatment of an entire screen.

### Readable action

Gameplay information wins over decoration. Enemy silhouettes, attack tells,
interaction zones, exits, and navigable ground must remain legible during
movement and combat. Detail should frame action rather than compete with it.

### Strong places

Every important screen needs a recognizable landmark or silhouette: a castle
gate, shrine, bridge, camp stronghold, tower group, or other clear anchor.
Supporting details should reinforce that place's purpose.

### Controlled abundance

Tiny Swords offers many coherent asset families. Use that variety in clustered,
intentional compositions. Density should rise near landmarks, boundaries, and
narrative activity, then fall around combat and interaction space.

### Faction clarity

Blue communicates village safety, allies, and support. Red communicates hostile
occupation and danger. Terrain, fire, resource clutter, and structure layout
should reinforce the faction before the player reads text. Purple, yellow, and
black remain reserved for future factions with a defined gameplay purpose.

## Visual hierarchy

Prioritize each screen in this order:

1. player, enemies, attack tells, and interactable characters;
2. playable route, exits, and collision boundaries;
3. primary landmark and faction identity;
4. supporting architecture and terrain depth;
5. vegetation, resources, animals, effects, and small accents;
6. ambient detail that does not affect play.

If a lower-priority layer obscures a higher-priority layer, simplify, move, or
remove it.

## Color and value direction

Use the pack's native palette as the source of truth. Choose one dominant grass
color and one supporting terrain color per location. Use water and darker edge
values to frame the playable land. Keep important units and tells distinct from
the ground by silhouette and value, not by unrelated glow effects.

Avoid broad color overlays that flatten the pack's palette. Use screen-wide
tints only for short, meaningful states such as damage, danger, or transition.
UI colors should echo the same wood, paper, blue, red, cream, and dark-ink
families used by the assets.

## Camera and presentation

The target composition is the project's 1280 by 720 gameplay viewport. Build
and review scenes at that framing. Preserve hard pixel edges with nearest
filtering and stable pixel placement. Camera movement may be smooth, but it
must not make terrain seams, building edges, or text appear soft or unstable.

## Decision test

Before approving a visual choice, ask:

- Does it look native to Tiny Swords?
- Does it make this location easier to recognize?
- Does it preserve movement, combat, and interaction readability?
- Does it use an existing coherent asset family before inventing a substitute?
- Does the rendered 1280 by 720 result support the intended hierarchy?

A visually busy scene that fails these questions is not finished.

## Sources

- [Tiny Swords by Pixel Frog](https://pixelfrog-assets.itch.io/tiny-swords)
- [Official Tiny Swords Tilemap Guide](https://pixelfrog-assets.itch.io/tiny-swords/devlog/1138989/tilemap-guide)