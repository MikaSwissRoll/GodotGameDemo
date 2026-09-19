# Environment design

## Purpose

This document owns terrain, water, elevation, architecture, vegetation, roads,
and environment composition. It translates the visual identity in
[Art Direction](ART_DIRECTION.md) into repeatable spatial rules. The order used
to build and validate a scene belongs in
[Scene Design Workflow](SCENE_DESIGN_WORKFLOW.md).

## Terrain grid and layer stack

Tiny Swords terrain uses a 64 by 64 pixel grid. Keep terrain cells aligned to
that grid and build the world in the official layer order:

1. background water color;
2. animated water foam where terrain meets water;
3. lowest flat ground;
4. shadow for the next elevation;
5. elevated ground, including the correct cliff face;
6. repeated shadow and elevated-ground pairs for additional levels;
7. stairs where playable elevations connect;
8. buildings and large natural landmarks;
9. vegetation, resources, animals, effects, and small decoration.

The official shadow is larger than a single cell and overlaps neighboring
edges. Place it under the same walkable area as the raised ground, shifted one
complete 64-pixel cell downward to create height. Water foam follows the same
overlap principle and should use varied starting animation frames.

## Landforms and water

Land silhouettes should have readable inlets, corners, projections, and level
changes. Avoid featureless rectangles unless the shape is deliberately hidden
by the camera or architecture.

Every visible water boundary needs:

- the water background;
- correct ground edge and corner tiles;
- foam on exposed contact edges;
- occasional animated water rocks or a rare memorable accent; and
- enough clear water to read as a body of water rather than a narrow border.

Use the correct elevated cliff variant for the surface below it: one connects
to walkable lower terrain and another meets water. Stairs must visually join
both the upper walkable surface and the lower destination.

## Composition zones

Design each gameplay view with three overlapping zones:

- **Focal zone:** one landmark or compact building group that defines the place.
- **Play zone:** open, navigable ground for combat, movement, or interaction.
- **Frame zone:** water, cliffs, trees, rocks, and structures that shape the
  camera edge and prevent the scene from feeling empty.

Use asymmetry. Start with one large form, support it with two or three medium
forms, and finish with several small accents. Avoid equal spacing, mirrored
clusters, and decoration distributed at a constant density.

As working clearances at 1280 by 720:

- keep about 160 pixels clear around combat spawn points;
- keep about 96 pixels clear around interactive NPCs and doors; and
- keep main roads, bridges, and combat approaches at least 128 pixels wide.

These values may grow when attack ranges or groups of enemies need more room.

## Roads and navigation

Routes should be readable from terrain shape, gates, bridges, building
entrances, and the direction of vegetation clusters. Use paths to connect
purposeful destinations rather than painting decorative lines through empty
space.

A main route should have a clear beginning, continuation, and destination.
Secondary paths may lead to merchants, rewards, or optional encounters. Do not
use dense props to create a maze unless the gameplay specifically requires one.

When the asset pack has no suitable road or bridge, a project-owned custom
solution may be used. It must follow the 64-pixel rhythm, native palette, pixel
edge weight, and surrounding terrain geometry.

## Architecture

Place buildings by the visible foundation foot and doorway, not by the texture
center. Keep doors facing reachable ground and leave a small forecourt in front.
Collision should cover the lower foundation only so roofs and upper walls can
overlap characters naturally.

### Village

Use blue buildings around small courtyards and a legible route. Combine one
primary landmark, such as the castle or monastery, with houses and one or two
functional buildings. Sheep, wood activity, bushes, and orderly spacing convey
safety and daily life.

### Wilderness

Use landform silhouette, elevation, water, trees, bushes, and rocks as the main
forms. Architecture should be sparse and purposeful: a tower, shrine, bridge,
or abandoned house should orient the player rather than fill space.

### Enemy camp

Use red buildings, tighter defensive groupings, towers, barracks, archery
structures, fires, stumps, rocks, and gathered resources. Keep the combat center
open while making the perimeter feel occupied and dangerous.

### Combat room

Frame the arena with terrain height, water, structures, and vegetation. Keep
attack lanes and enemy silhouettes unobstructed. Put most small decoration
outside the active center and avoid props that resemble pickups or projectiles.

## Vegetation and prop rhythm

Use all available tree, bush, ground-rock, and water-rock variants before
repeating a single frame excessively. Prefer clusters of three to seven items
with varied silhouettes, small position offsets, and restrained scale changes.
Do not arrange trees or rocks on an obvious regular grid.

Build a cluster from:

- one dominant tree, building, or rock mass;
- two or three supporting forms;
- smaller bushes, stones, stumps, or resources near the base; and
- optional activity, such as sheep, fire, or one memorable accent.

Use empty space deliberately between clusters. Reserve rare accents such as the
rubber duck for locations where they aid memory or character.

## Depth and overlap

Characters should pass in front of foundations and behind upper foliage or roof
silhouettes when appropriate. Large structures need a visual ground contact,
usually a native shadow and a foundation collision. Avoid floating buildings,
trees with exposed empty bases, or props whose shadow direction conflicts with
the scene.

## Environment rejection checks

Revise the scene when any of these are true:

- most of the viewport is uninterrupted flat grass;
- terrain borders are plain geometry instead of supplied edge tiles;
- water touches land without edge treatment or foam;
- buildings form a straight asset gallery rather than a place;
- vegetation is evenly spaced or repeated with no variation;
- the route is unclear without UI arrows;
- decorative objects obstruct attacks, exits, or interactions; or
- safe and hostile locations are indistinguishable at a glance.