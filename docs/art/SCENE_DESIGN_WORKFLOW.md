# Scene design workflow

## Purpose

This document owns the repeatable process for designing and validating playable
scenes. It does not redefine the visual language, environment grammar, UI
system, or asset rules. Read the relevant owner documents before starting:

- [Art Direction](ART_DIRECTION.md)
- [Environment Design](ENVIRONMENT_DESIGN.md)
- [UI Visual Rules](UI_VISUAL_RULES.md)
- [Asset Usage Rules](ASSET_USAGE_RULES.md)
- [Visual QA Workflow](../visual_qa.md)

## 1. Write a scene brief

Before placing assets, record:

- gameplay purpose;
- location and faction;
- primary landmark;
- player entry, exit, and intended route;
- combat or interaction footprint;
- required NPCs, enemies, rewards, and transitions;
- dominant and supporting terrain colors; and
- the visual QA capture target or camera position.

If the scene has no clear purpose or landmark, resolve that before decoration.

## 2. Audit relevant assets

Inspect the actual files under `asset/` and list the terrain, buildings,
vegetation, props, effects, and UI pieces that fit the brief. Confirm exact
filenames, image dimensions, frame layout, and available faction variants.
Follow [Asset Usage Rules](ASSET_USAGE_RULES.md); do not begin with placeholders
when a suitable Tiny Swords family already exists.

## 3. Block out gameplay

Place player starts, exits, NPCs, enemies, encounter boundaries, and collision
limits using simple shapes or terrain cells. Test movement and combat scale
before visual detailing.

The blockout must answer:

- Can the player see the next meaningful destination?
- Is there enough room to move, dash, guard, and read enemy attacks?
- Are doors, merchants, and dialogue positions reachable?
- Can the camera frame the intended landmark without hiding play space?

## 4. Build the terrain silhouette

Create the water background, lowest land, elevation footprint, cliffs, stairs,
roads, and bridges using the layer rules in
[Environment Design](ENVIRONMENT_DESIGN.md). Review the silhouette without
buildings. The route, water boundary, and height changes should already read.

## 5. Establish composition

Frame the target camera view and mark its focal, play, and frame zones. Place
the primary landmark first, then the main route and one or two supporting forms.
Check visual weight at the actual 1280 by 720 viewport before adding small props.

## 6. Place architecture and large nature

Add buildings, large trees, cliffs, and rock masses. Align building foundations
and entrances, then add only the collision needed at ground contact. Test
character overlap and route clearance after every major placement group.

## 7. Add narrative clusters

Use vegetation, resources, animals, fire, stumps, tools, and small rocks to
explain what happens in the location. Add details as clusters around meaningful
activity and boundaries. Stop when additional decoration no longer improves
place recognition, route framing, or story.

## 8. Apply interaction and UI presentation

Add interaction prompts, dialogue, shop, HUD, and modal states using
[UI Visual Rules](UI_VISUAL_RULES.md). Test the densest gameplay state with the
HUD visible. UI must not cover the landmark, active enemies, interaction text,
or the next route.

## 9. Run functional checks

Run Godot and resolve parser, runtime, resource, signal, collision, and camera
errors. Exercise the relevant old gameplay as well as the new scene. A clean
runtime is required before visual approval, but it is not visual approval.

## 10. Capture and inspect

Use the local workflow in [Visual QA](../visual_qa.md):

```text
Run Godot
→ Capture target
→ Inspect the rendered image
→ Identify concrete problems
→ Modify
→ Capture the same target again
→ Compare
```

Capture at least:

- the first player view;
- the densest combat or interaction state;
- any menu, shop, dialogue, reward, or pause overlay changed by the task; and
- a transition view when the scene connects two distinct areas.

Review hierarchy, route clarity, terrain seams, water edges, elevation shadows,
building grounding, repeated patterns, character overlap, text contrast, and
UI clipping. Use `_before` and `_after` filenames for focused iterations.

## 11. Acceptance gate

A scene is complete only when:

- its gameplay purpose and route work;
- its landmark and faction read at a glance;
- terrain, water, and elevation follow the environment rules;
- combat and interaction space remain clear;
- assets follow the project selection and scaling rules;
- relevant UI remains readable;
- the rendered result has been inspected and improved where needed;
- parser, runtime, and resource errors are resolved; and
- unrelated existing behavior still works.

## Scene brief template

```markdown
### Scene

- Purpose:
- Faction/location:
- Landmark:
- Entry and exit:
- Gameplay footprint:
- Required actors and interactions:
- Terrain palette:
- Asset families:
- Visual QA targets:
- Out of scope:
```