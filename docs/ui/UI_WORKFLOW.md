# UI workflow

## Purpose

This document owns **how UI is built** in this project. It is the process
counterpart to the other UI documents, and deliberately does not repeat them:

| Question | Document |
| --- | --- |
| What should the UI look like? | [UI Visual Rules](../art/UI_VISUAL_RULES.md) |
| How should we build it? | this document |
| What mistakes must we not repeat? | [UI Known Failures](UI_KNOWN_FAILURES.md) |
| Which existing assets do we use? | [UI Asset Guide](UI_ASSET_GUIDE.md) |
| General asset policy and provenance | [Asset Usage Rules](../art/ASSET_USAGE_RULES.md) |

The reason this process exists at all: this project has shipped UI that compiled,
ran, responded to input, and reported no errors — while looking wrong on screen.
Every rule below comes from a defect that reached a screenshot.

## The one-sentence version

**Read the rules, pick real assets, lay out structure, then prove it with a
screenshot — because a Control's declared geometry is not what appears on screen.**

## Non-negotiable prerequisite

A UI task is not finished when the scene loads, the nodes exist, or the buttons
work. It is finished when a **rendered screenshot has been inspected** and the
quality gate below passes. No exceptions for "small" changes.

---

## The workflow

### 1. Understand the purpose

Write down, in one or two sentences, what decision or action the screen serves
and who reads it at what moment. A modal read mid-combat is not the same object
as a title screen. This drives hierarchy in step 5 and nothing later can fix it.

### 2. Inspect the existing UI architecture

Before adding nodes, read what exists:

- `scripts/ui/run_ui.gd` — roguelite HUD, main menu, and the shared modal.
- `scripts/ui/game_ui.gd` — classic adventure HUD and its own modal.
- `scripts/ui/tiny_swords_ui.gd` — `class_name TinySwordsUI`, all StyleBox and
  texture helpers. This is the only place style construction belongs.
- `scripts/ui/tiny_bar.gd` — `class_name TinyBar`, health/stamina bars.
- `scripts/ui/action_row.gd` — `class_name ActionRow`, modal action buttons.

Both UIs are built **in code**, not in `.tscn` files. `scenes/ui/run_ui.tscn` and
`game_ui.tscn` are thin `CanvasLayer` wrappers. Follow that convention.

Decide explicitly whether the change is to the roguelite UI, the classic UI, or
both. These are two separate implementations that deliberately share only
`TinySwordsUI`, `TinyBar`, and `ActionRow`.

### 3. Read the project UI rules

Read [UI_VISUAL_RULES.md](../art/UI_VISUAL_RULES.md) for surface language,
typography minimums, hierarchy, and layout safety. Read
[ART_DIRECTION.md](../art/ART_DIRECTION.md) if the change affects the overall
look. Do not start placing nodes before this.

### 4. Audit the existing assets

Open [UI_ASSET_GUIDE.md](UI_ASSET_GUIDE.md) and pick real files. Search the
filesystem rather than guessing a path. The project already contains buttons,
papers, banners, ribbons, bars, twelve icons, avatars, cursors, and a 245-icon
fantasy pack — reach for those before drawing a `ColorRect` or accepting a
default Godot control.

If an appropriate asset exists, using a placeholder instead is a defect, not a
simplification.

### 5. Define the visual hierarchy before sizing anything

State the order of attention, for example for a result modal:

1. outcome title
2. summary line
3. the primary action
4. secondary actions

Then size controls to serve that order. The single most common failure in this
project's history is sizing a container first and discovering the content does
not fit or does not dominate (see UI_KNOWN_FAILURES: oversized panel, control
geometry). Panels support content; content does not fill panels.

### 6. Build the structural layout

Factors to fix before styling:

- **Anchors.** Decide per element whether it belongs to the viewport edge, the
  viewport centre, or a parent panel. Anchored controls are positioned with
  `offset_*`, not `position` — assigning `position` on an anchored Control is
  re-derived against the anchor and can push it off-screen.
- **Insets.** Keep essential HUD inside the 20px viewport inset from
  UI_VISUAL_RULES.
- **Stacking.** Lay out stacks cumulatively from each row's own height rather
  than assuming a fixed pitch, so a row that grows does not overlap its
  neighbour.
- **Reserve** space for the modal's header and for the tallest state it can be
  in, not the state you are currently looking at.

Then render it once with placeholder text to see the bare structure before any
art is applied.

### 7. Apply project assets

Use `TinySwordsUI` helpers rather than constructing StyleBoxes inline. For
stretchable sheets, establish the real tile geometry **by measurement** before
writing margins — several sheets in this pack have irregular strides, per-axis
offsets, short final rows, or fully transparent middle tiles. See the measured
tables in UI_ASSET_GUIDE.md and the failure entries on nine-patch geometry.

### 8. Typography and Chinese readability pass

The entire player-facing UI is Chinese. Check:

- The size floors in UI_VISUAL_RULES (16px hints, 18px labels, 20px body and
  buttons, 32px modal titles).
- Contrast against the actual surface. The project's modals use the dark
  `SpecialPaper` slate, which takes warm light ink (`#f7edcf`); dark ink is only
  correct on a genuinely light surface.
- The project has **no bundled font**; the Godot default theme is used. There is
  no bold variant, so emphasis must come from size, colour, or position.
- HUD text sitting directly on the world needs an outline, because the ground
  behind it changes.
- Longest expected label per component, per UI_VISUAL_RULES layout safety.

### 9. Pixel-scale and texture pass

- `texture_filter = TEXTURE_FILTER_NEAREST` on every pixel-art texture.
- Do not scale pixel art to fractional sizes; pick one integer-ish scale per
  family and keep it consistent.
- Preserve aspect ratio for icons and sprites; only stretchable sheets may
  stretch.
- Do not stretch a complete raster when the pack supplies edge, center, and
  corner pieces.

### 10. Runtime screenshot

Capture the real rendered result with the project harness:

```powershell
.\tools\capture_visual_qa.ps1 -Target <target> -Output res://screenshots/visual_qa/<name>.png
```

Targets and their captured states are listed in
[Visual QA](../visual_qa.md). Add a new target when a state you changed has none
— a UI state with no capture target cannot be visually QA'd, and this project has
already shipped one such defect.

The harness reports a non-zero exit even on success because it re-raises Godot's
stderr; judge success by the PNG being written and by its contents.

### 11. Visual critique

Open the PNG and describe what is actually there, not what the code says should
be there. Cover at least the checklist in step 13. State concrete observations
with positions, sizes, and contrast — "buttons span roughly 45% of the panel
width and leave a wide margin" is useful; "looks fine" is not.

### 12. Fix

Fix the cause, not the symptom. Adjusting a constant until the picture happens to
look right is how this project accumulated five separate attempts at one
alignment bug. When the rendered result disagrees with your model of the layout,
**measure the rendered pixels** before changing anything (see the measurement
recipe below).

### 13. Screenshot again, and compare

Re-capture with a distinct filename and compare against the previous capture.
Repeat 11–13 until the critique is clean. Do not batch multiple visual changes
into one capture — you will not know which one helped.

### 14. Regression test

Run the harnesses that cover the affected UI. The full set is currently eight
suites:

```powershell
foreach ($t in @("smoke_game","playthrough","ballistics","roguelite_smoke",
                 "roguelite_playthrough","collision_smoke","new_features_smoke",
                 "upgrade_effects_smoke")) {
  & $godot --path . --script "res://tests/$t.gd"
}
```

`new_features_smoke` asserts HUD translation, and `smoke_game` /
`roguelite_smoke` assert the menu, pause, shop, and result flows. If a UI change
renames or removes a member those tests touch, update the test in the same
change.

`roguelite_playthrough` is flaky (random wave variants) — a single failure there
is not necessarily caused by a UI change; re-run before investigating.

---

## Measuring the rendered result

When the screen disagrees with the code, do not adjust constants by feel. Instead:

1. Render the control **in isolation** on a contrasting flat background, with no
   text, so only the frame/art is visible.
2. Repeat at **several sizes**. A single size cannot separate a constant from a
   ratio; this project mis-derived the button frame three times by measuring one
   height.
3. Scan the PNG for the known fill colour to find the painted band, and for the
   label ink colour to find the glyph rows.
4. Only then write the constant, and note the measurement in a comment.

Worked examples of this paying off, and of skipping it going wrong, are in
[UI_KNOWN_FAILURES.md](UI_KNOWN_FAILURES.md).

---

## UI quality gate

A significant UI screen is complete only when every line passes. Record any
deliberate exception in the task notes.

- [ ] Visual hierarchy is clear — the intended first thing to read is the first
      thing the eye goes to
- [ ] Primary action is obvious
- [ ] Chinese text is fully readable against its actual surface
- [ ] No missing glyphs (no tofu boxes)
- [ ] No accidental overlaps between HUD groups, text, and panels
- [ ] No clipped text at either end of a label or button
- [ ] Buttons are not unnaturally stretched
- [ ] Decorative panels do not dominate their content
- [ ] Existing project assets were reused where appropriate
- [ ] Pixel-art assets are not blurred (nearest filtering, no fractional scale)
- [ ] Asset aspect ratios are preserved
- [ ] UI is consistent with the game's art direction
- [ ] Gameplay HUD does not appear on inappropriate menu screens
- [ ] A runtime screenshot has been captured and visually reviewed
- [ ] Relevant existing UI still works (regression suite run)

---

## When to redesign instead of adjust

If the critique shows the hierarchy itself is wrong — the panel dominates, the
primary action is not legible, content does not fit the container's proportions —
**restructure the layout** rather than nudging positions. This project's own
history shows a layout that received five positional fixes for one alignment
symptom before the actual cause (the art does not paint at the Control's rect)
was measured. Positional fixes on a wrong composition do not converge.

## Related documents

- [Visual QA](../visual_qa.md) — capture targets and how to add one.
- [UI Known Failures](UI_KNOWN_FAILURES.md) — the specific defects not to repeat.
- [UI Asset Guide](UI_ASSET_GUIDE.md) — measured inventory of usable assets.
- [UI Visual Rules](../art/UI_VISUAL_RULES.md) — the target look.
- [Asset Usage Rules](../art/ASSET_USAGE_RULES.md) — provenance and modification
  policy for third-party sources.
