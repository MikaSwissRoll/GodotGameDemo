# UI workflow

## Purpose

This document defines how you create, repair, and verify UI in this project. It
keeps visual review separate from interaction and gameplay checks, so a rendered
change is judged on its rendered evidence instead of on an unrelated playthrough.
The automated test suite is frozen and `tests/` is empty, so every functional
check below is done by hand in a running build.

Use the companion documents for their specific responsibilities:

| Question | Document |
| --- | --- |
| What should the UI look like? | [UI Visual Rules](../art/UI_VISUAL_RULES.md) |
| How do I create or repair it? | This document |
| Which project failures must I recognize? | [UI Known Failures](UI_KNOWN_FAILURES.md) |
| Which assets and measurements can I reuse? | [UI Asset Guide](UI_ASSET_GUIDE.md) |
| How are third-party assets handled? | [Asset Usage Rules](../art/ASSET_USAGE_RULES.md) |
| How do capture targets work? | [Visual QA](../visual_qa.md) |

UI is not complete when the scene loads or its node rectangles look correct.
The rendered pixels, relevant interactions, and affected state contracts are the
evidence.

## Default loop

Use this loop for every significant UI task:

```text
Inspect
-> Define the affected UI state and contracts
-> Plan the evidence
-> Create or repair
-> Capture the target state
-> Inspect the rendered pixels
-> Fix the cause
-> Capture and compare
-> Run the smallest affected regression
```

A screenshot of the affected state is the default visual test. Reaching that
state by playing the whole game is not required unless the route or gameplay
transition is part of the change.

## Core principles

These principles keep visual work fast enough to repeat and strict enough to
catch real defects.

- Treat rendered pixels as the source of truth. A `Control` rect, anchor, or
  minimum size does not prove where a textured frame or its visible face paints.
- Separate three questions: "Does it look right?", "Does the UI interaction
  work?", and "Does the gameplay flow still work?"
- Stage visual states directly and deterministically. Test the real transition
  separately when that transition changed.
- Capture the full viewport for context. Add a crop only when precise pixel
  measurement is useful.
- Reuse measured project components and assets before creating another styling
  path.
- Change one visual cause at a time, then recapture the same target.
- Do not use a capture of an unrelated screen as evidence for a visual change.

## Choose the verification scope first

**The automated test suite is frozen and `tests/` is empty.** No row below can
name a test to run; the evidence is captures and hand-driven checks. Read
`docs/TEST_WORKFLOW.md` for why, and do not try to restore a suite.

Before editing, classify every contract the change can affect, then collect the
union of the matching rows after the visual loop.

| Change scope | Required evidence |
| --- | --- |
| Color, spacing, font position, icon size, or decoration | Before and after captures of the affected state |
| Hover, focus, pressed, selected, or disabled styling | Captures of the affected visual states |
| Shared panel, bar, button, or `ActionRow` | Isolated component states plus captures of each materially affected screen |
| Button input, focus order, keyboard navigation, or signals | Target capture plus clicking and tabbing through the flow by hand in a running build |
| HUD value binding, affordability, inventory count, or translated text | Representative state captures with the values actually changed in-game |
| Modal visibility, pause state, shop purchase, result flow, or scene navigation | Target capture plus opening and closing the flow by hand |
| Broad gameplay progression, save behavior, or release readiness | A full hand-played pass, from the title screen through the affected progression |

There is nothing to over-run any more, and nothing will catch a regression for
you: an unobserved state is an unverified state.

## Prepare the task

Preparation defines the intended player-facing result and the proof you will
collect.

1. State the screen's purpose, primary action, and reading order.
2. Name the exact states affected, including normal, focus, disabled, empty,
   full, unaffordable, or long-text variants when relevant.
3. Identify the implementation owner:
   - `scripts/ui/town_menu.gd` owns the live town title menu.
   - `scripts/main/town_title.gd` owns its camera and mode handoff.
   - `scripts/ui/run_ui.gd` owns the roguelite HUD and modal flow.
   - `scripts/ui/game_ui.gd` owns the classic adventure HUD and modal flow.
   - `scripts/ui/tiny_swords_ui.gd` owns shared style construction.
   - `scripts/ui/tiny_bar.gd` owns health and stamina bar rendering.
   - `scripts/ui/action_row.gd` owns rich modal actions.
4. Read the matching visual rules, known failures, and asset measurements.
5. Inspect existing call sites before changing a shared component.
6. Write the planned capture targets and selective tests in
   `docs/CURRENT_TASK.md` for substantial work.

Both UI roots are built in code, while their `.tscn` files are thin
`CanvasLayer` wrappers. Extend that convention unless a deliberate architecture
change has been approved.

## Create a new UI

Use this procedure when you add a screen, overlay, HUD group, or reusable
component.

1. **Define the hierarchy.** List the order in which the player must notice the
   title, state, primary action, secondary action, and supporting text.
2. **Choose real assets.** Use [UI Asset Guide](UI_ASSET_GUIDE.md) to select a
   panel, button, bar, and icon that match the role. Confirm the exact path and
   native geometry. For an icon that lives inside an atlas sheet, record its cell
   with the guide's scanning procedure rather than by counting columns by eye,
   and render the cell to confirm it before use.
3. **Build the structure.** Establish anchors, viewport ownership, cumulative
   stack layout, content padding, and the tallest supported state before adding
   decoration.
4. **Size from content and painted geometry.** Derive container height from
   child content and explicit padding. Do not infer usable space from the
   `Control` size alone.
5. **Apply shared styles.** Use `TinySwordsUI`, `TinyBar`, and `ActionRow` instead
   of building inline variants.
6. **Add behavior.** Wire signals, focus order, escape behavior, and disabled
   states without coupling presentation to unrelated gameplay systems.
7. **Check Chinese text.** Use the longest realistic labels, correct wrapping,
   readable line spacing, complete glyphs, and contrast against the rendered
   surface.
8. **Preserve pixel art.** Use nearest filtering, integer scales where
   practical, correct aspect ratio, and only stretch assets whose measured
   construction supports it.
9. **Add a deterministic capture target.** Stage the exact UI state with fixed
   data and freeze or stabilize animation before capture.
10. **Run the visual loop.** Capture, inspect, fix, and compare before running
    the selective tests from the scope table.

Do not postpone the capture target until the end. A new state that cannot be
captured cannot be visually verified during development.

## Repair an existing UI

Use this procedure when a screenshot shows clipping, alignment, hierarchy,
contrast, scaling, or state presentation problems.

1. **Reproduce the exact state.** Capture a baseline with a stable target and a
   distinct `_before` filename.
2. **Describe the visible defect.** Name the object, state, direction, and
   approximate magnitude. "The label reads 10 pixels low on the blue face" is
   actionable; "alignment feels off" is not.
3. **Match known failures.** Check
   [UI Known Failures](UI_KNOWN_FAILURES.md) before inventing a fix.
4. **Identify the responsible layer.** Decide whether the cause is asset
   geometry, shared component layout, screen composition, text metrics, state
   binding, or capture staging.
5. **Measure before nudging.** If code geometry and the screenshot disagree,
   measure the rendered silhouette and usable content plane at several sizes.
6. **Fix the narrowest shared cause.** Change a shared component only when every
   caller needs the same correction. Keep screen-specific composition in its
   screen owner.
7. **Capture the same state again.** Use an `_after` filename and compare against
   the baseline at the same resolution and state.
8. **Test affected contracts.** Run only the interaction or integration checks
   selected before editing.

If two positional adjustments fail to converge, stop changing offsets and
remeasure the asset. Repeated nudges usually mean the wrong geometry is being
centered.

## Design capture targets

A capture target is a deterministic visual fixture, not a substitute for every
gameplay test. It must create the state quickly enough to support repeated
iteration.

A reliable target must:

- instantiate the real screen or game scene;
- use fixed representative data;
- enter the requested state through a public method or a small staging hook;
- wait for layout and rendering to settle;
- freeze movement or animation when it would make comparison noisy;
- capture the full 1280 by 720 viewport; and
- write to `screenshots/visual_qa/`.

For a visual-only task, stage the state directly. For a transition change, keep
the direct target for visual proof and add a small test that performs the real
transition. Do not make visual QA depend on killing enemies, earning currency,
or finishing unrelated rooms.

Capture only the variants the change can affect. Common variants include:

- normal, focused, pressed, and disabled buttons;
- empty, partial, and full bars;
- affordable and unaffordable shop actions;
- short and longest realistic Chinese text;
- HUD shown, HUD hidden, and modal-over-HUD states; and
- single-line and two-line `ActionRow` content.

The full viewport is mandatory because a local crop cannot reveal collisions
with the HUD, world, screen edge, or another overlay. Use a crop in addition to
the viewport when measuring a component's pixels.

Run the current harness with:

```powershell
.\tools\capture_visual_qa.ps1 -Target <target> `
  -Output res://screenshots/visual_qa/<target>_before.png
```

A clean capture writes a fresh PNG and completes without an unexplained process
failure. If the PNG exists but the wrapper reports an error, inspect and
classify stderr before calling the run verified. Do not treat a stale PNG as
evidence.

## Inspect the rendered result

Review the image as a player would see it, then inspect local geometry. Record
specific observations before editing again.

Check the following concerns when they apply:

- reading order and visual hierarchy;
- prominence of the primary action;
- Chinese glyph coverage, wrapping, clipping, and line spacing;
- text contrast against the actual rendered surface;
- optical centering on the usable face of beveled or extruded art;
- consistent gaps, padding, and viewport insets;
- overlap between HUD groups, panels, and world objects;
- correct normal, focus, pressed, selected, and disabled states;
- icon meaning, scale, aspect ratio, and pixel sharpness;
- bar appearance at empty, partial, and full values;
- HUD visibility behind pause, shop, reward, win, and death overlays; and
- consistency with the project's Tiny Swords visual language.

"Looks fine" is not a review result. State what was inspected and why the image
passes or what concrete problem remains.

## Measure rendered geometry

When a textured control disagrees with its declared rectangle, distinguish
three different bounds:

1. **Control rect:** the logical input and layout rectangle.
2. **Painted silhouette:** every visible pixel, including outlines, shadows, and
   lower extrusion.
3. **Usable content plane:** the visible face where text and icons must appear.

The recent expedition button fix demonstrated why this distinction matters.
Centering on the `Control` rect was wrong, and centering on the full painted
silhouette still read low because the lower extrusion is depth decoration.
`ActionRow` first models the measured silhouette with `ART_ABOVE` and
`ART_BELOW`, then uses `FRONT_FACE_TEXT_OFFSET_Y` to center its labels on the
front-facing plane.

Use this measurement procedure:

1. Render the component without text on a contrasting flat background.
2. Render it at three or more representative sizes.
3. Include every affected state, especially regular and pressed art.
4. Measure the painted top, bottom, left, and right extents.
5. Mark the usable face after excluding shadow, bevel, and extrusion.
6. Add text and measure the glyph bounds against that face.
7. Derive constants from all samples, then document what each constant models.
8. Recheck the component in a real full-screen capture.

Do not reuse an optical offset on another asset merely because the controls have
the same logical size.

## Verify by hand

Visual inspection and functional checks answer different questions, and with the
suite frozen only the first is automated. A rendered capture proves how something
looks; it does not prove that pressing it does anything.

For every UI behaviour the change touches, open it in a running build and operate
it: click the button, tab through the focus order, buy the item, open and close the
modal, walk through the scene transition. Then say in the task notes what you
opened and what happened. There is no suite to delegate this to, and no pass/fail
line to quote instead of looking.

`docs/visual_qa.md` documents the capture harness, which still works and is now
the main automated evidence available.

## UI quality gate

A UI task is complete when every applicable line below has evidence. Mark
non-applicable items in the task notes rather than running unrelated checks.

- [ ] The affected state has a deterministic capture target.
- [ ] A fresh full-viewport screenshot was inspected.
- [ ] Before and after captures use the same target, resolution, and state.
- [ ] The reading order and primary action are clear.
- [ ] Chinese text is readable, complete, and unclipped.
- [ ] Text and icons sit on the intended painted content plane.
- [ ] No accidental overlap, overflow, or screen-edge collision is visible.
- [ ] Pixel art remains sharp and keeps its intended proportions.
- [ ] Relevant interaction states were inspected.
- [ ] Shared-component callers affected by the change were checked.
- [ ] The affected interaction was operated by hand and the result recorded.
- [ ] No persistent parser, runtime, resource, or signal error remains.
- [ ] Deliberate visual trade-offs and known limitations are recorded.

Do not require a full-game playthrough for a visual-only task.

## Decide when to redesign

Redesign the layout when the hierarchy or proportions are wrong. Continue with
a local repair when the composition is sound and one measured component is
wrong.

Typical redesign signals include a panel that dominates its content, actions
that cannot fit the asset's usable face, an unclear primary action, or repeated
offset fixes that break another state. Positional tweaks do not repair a wrong
composition.

## Related documents

Use these documents while following this workflow:

- [Visual QA](../visual_qa.md) describes the capture harness and target list.
- [UI Known Failures](UI_KNOWN_FAILURES.md) maps visible symptoms to verified
  causes.
- [UI Asset Guide](UI_ASSET_GUIDE.md) records measured asset geometry.
- [UI Visual Rules](../art/UI_VISUAL_RULES.md) defines the target visual
  language.
- [Asset Usage Rules](../art/ASSET_USAGE_RULES.md) defines provenance and
  third-party asset policy.
