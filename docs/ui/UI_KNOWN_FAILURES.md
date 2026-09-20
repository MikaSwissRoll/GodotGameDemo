# UI known failures

## Purpose

This document records verified visual defects and workflow traps encountered in
this project. Each entry identifies the rendered symptom, measured cause,
prevention, and the smallest useful validation.

Use it as a diagnosis index. Match the current screenshot to a symptom, then
apply only the relevant prevention and validation. Do not run every historical
check for every UI edit.

The dominant theme is that a `Control`'s declared geometry is not necessarily
what appears on screen. Godot's StyleBoxes, nine-patch sampling, transparent
padding, shadows, bevels, and extrusions can move or shrink the painted result.

## Triage a UI failure

Use this short sequence before changing layout constants:

1. Capture the exact affected state with fixed data.
2. Describe the visible defect and approximate direction or magnitude.
3. Find the matching failure below.
4. Measure the rendered pixels when code geometry and the image disagree.
5. Fix the narrowest responsible layer.
6. Recapture the same state and run only the affected functional test.

If two positional fixes fail to converge, stop nudging and remeasure the asset's
painted silhouette and usable content plane.

---

## Nine-patch does not paint at the Control's rect

**Symptoms**
- A panel's frame is much shorter than its declared size; label text sits above
  or below the visible frame
- A short panel shows a thin strip of frame with text outside it
- `size` in the debugger is correct, the picture is not

**Measured cause**
`StyleBoxTexture` with a `content_margin` set scales its corner regions by
`size - 2 * content_margin` instead of drawing at the panel's size. On
`SpecialPaper` this produced ratios of 0.40 with content margins versus 1.00
without, for the same texture and size.

Separately, at HUD sizes the sheet's fixed corner caps dominate the panel: a
declared 690x68 panel painted 41px and started ~20px below its declared top;
135x52 painted 25px; 320x176 painted 149px; 540x53 painted 26px. The painted
height followed `height - 27`.

**Prevention**
- Do not set `content_margin` on a `StyleBoxTexture`; place content with explicit
  child positions.
- For small HUD boxes, use `StyleBoxFlat` (see `TinySwordsUI.pouch_panel_style`)
  which draws exactly at the declared rect, or measure the painted size first.
- Reserve textured nine-patch panels for large surfaces only.

**Validation**
Capture, then compare the painted frame's pixel extent against the declared rect.
Do not trust `size`.

*Fixed in `75c9734`.*

---

## The art is drawn offset from the Control rect

**Symptoms**
- Text looks too high or too low inside a button even though it is centred in the
  Control's rect
- Nudging the constant appears to fix one case and breaks another

**Measured cause**
The button art does not paint at the Control's rect. In the live pause modal an
**82px row painted 94px of art**, beginning ~18px *above* the rect top and running
~29px *past* its bottom, so the visible centre sat **23px below the rect centre**.
Centring a label on the rect therefore rendered visibly high.

**Prevention**
- Never centre button content on the Control rect.
- Centre on the **painted art's** extent. `ActionRow` carries `ART_ABOVE` (18) and
  `ART_BELOW` (29) measured from a live render.
- Then bias onto the **front-facing plane**: the art includes a lower extrusion
  (its 3D edge), and the optical centre of a beveled button is not the centre of
  its full silhouette. `ActionRow.FRONT_FACE_TEXT_OFFSET_Y` (-10) applies that
  correction. A first pass centred on the whole silhouette and the text still
  read low.

**Validation**
Scan the rendered PNG: take the painted art's top and bottom and the glyph rows.
Judge the glyphs against the *front face*, not the outer silhouette.

*Diagnosed in `8093869` after four earlier attempts treated the symptom
(`2f7e023` added a 6px bias; `1ce40a4` and `b75bca0` adjusted row height). The
lesson: measure the painted geometry before touching constants, and then allow
for the bevel.*

---

## Text escapes a button's frame

**Symptoms**
- A two-line button label touches or crosses the frame at top and bottom
- The label fits the Control's `minimum_size` yet still overflows the art

**Measured cause**
The button art's frame caps occupy a fixed share of the height, and the inner
band is close to `height - 44` (measured: 24px of top padding and 20px of bottom
padding, constant across 98/110/122/133/150px rows). A button can therefore only
carry one line at any sane height: at 77px tall the band is 33px, and two 19px
lines need 54px, so the glyphs overpainted both caps.

A related trap: a `Button`'s minimum height only guarantees the *Control* fits
the text, never that the text fits inside the *art*.

**Prevention**
- Size a two-line row from the measured band, not from `minimum_size`.
- Or draw the lines as child `Label`s inside the band and keep the Button's own
  text empty — which is what `ActionRow` does.

**Validation**
Look for clearance between the glyph rows and the frame edge at both ends.

*Fixed in `b75bca0` and `1ce40a4`.*

---

## Bars did not use the bar art

**Symptoms**
- A full bar looks like a flat coloured rectangle, not the supplied bar
- An empty bar shows a dark default slot instead of the pack's track

**Measured cause**
The bars were a `StyleBoxFlat` fill inside a nine-patch frame, so the shape came
from theme defaults and the sheet was only decorative. Additionally the bar's own
nine-patch conflicted with its height: `_bar()` forced 288x36 while the
background used 18px top and bottom caps (36px total) and the fill expanded -7px
per side, so the middle stretch band collapsed to zero and the fill was clipped.

**Prevention**
- Use the pack's `BigBar_Base` + `BigBar_Fill` and `SmallBar_Base` +
  `SmallBar_Fill` through `TinyBar`.
- Check that `2 * cap` is comfortably less than the bar height before choosing a
  size.

**Validation**
Inspect a full bar *and* a partly-filled bar; both must show the frame intact.

*Fixed in `c674c4c` and `4d93063`.*

---

## Bars looked like empty slots at both ends

**Symptoms**
- The fill appears to stop short of each end, leaving a dark block
- Trimming the caps to fix it destroys the rounded corner

**Measured cause**
The cap tiles are mostly recessed track — only roughly the outer 9-10 columns of
a 24px tile are the rounded wood edge — so the fill visibly ends before the
frame. This is a genuine either/or in the artwork: keeping the full rounding
keeps the dark inner groove, and removing the groove clips the rounding.

**Prevention**
- Accept one of the two, and record which. The project chose to trim the caps
  (`TinyBar` `cap_keep`: 10 for BigBar, 7 for SmallBar) so the fill reaches both
  ends, accepting a slightly clipped corner.
- Do not "fix" this by iterating constants; there is no setting that gives both.

**Validation**
Compare the end caps against the full-rounding version and confirm the chosen
trade-off still looks intentional.

*Decided in `be4ad81` (committed with that change).*

---

## HUD text was unreadable on the world

**Symptoms**
- Dark helper text nearly invisible over bright grass
- HUD labels blending into terrain of similar value

**Measured cause**
The classic controls hint used dark ink with a light shadow directly on the
grass, and it overlapped the potion panel. HUD labels generally sat on the world
with no outline after the backing panels were removed.

**Prevention**
- Text drawn directly on gameplay needs an outline
  (`font_outline_color` + `outline_size = 4`).
- Move edge hints to a viewport corner that does not collide with other HUD
  groups; the classic hint was right-aligned along the bottom edge for this
  reason.

**Validation**
Read the text over both the brightest and darkest terrain in the capture.

*Fixed in `ec4086d`.*

---

## HUD content overflowed its panel

**Symptoms**
- A stat panel's bottom row is clipped by the panel edge
- Bars are cut off at top and bottom

**Measured cause**
Panel height was guessed rather than derived. The stats panel declared 320x146
with 14px content margins, leaving 118px for 128px of content. The bar nine-patch
added its own conflict on top (above).

**Prevention**
- Compute panel height as the sum of its children's heights plus explicit
  padding, and write that sum in a comment.

**Validation**
Check the last child's bottom against the panel's painted bottom.

*Fixed in `75c9734`.*

---

## HUD violated the viewport inset

**Symptoms**
- A HUD group's icon sits almost flush with the screen edge
- Icon-to-text spacing differs between two groups built the same way

**Measured cause**
The stage panel's icon sat 6px from the screen edge, and icon-to-text spacing was
5px in the gold panel against 11px in the stage panel.

**Prevention**
- Keep essential HUD inside the 20px inset from UI_VISUAL_RULES.
- Centralise icon placement (`TinySwordsUI.add_icon`) and use one spacing value
  for every icon+label pair.

**Validation**
Measure the gap from each HUD group to the viewport edge in the capture.

*Fixed in `75c9734`.*

---

## Oversized modal with a dead area

**Symptoms**
- A large empty region below the buttons
- The panel reads as the strongest object on screen
- Content looks lost inside its container

**Measured cause**
The modal used a fixed 650x560 (later 690x660) panel regardless of action count,
so two-button results left a large unused region. Rows were also a fixed 125px
even when their labels were single-line.

**Prevention**
- Fit the panel to the action count and to each row's own height, as `_show()`
  does through `_stack_height()`.
- Size rows from content: `ActionRow.SINGLE_HEIGHT` (82) versus `FULL_HEIGHT`
  (125).

**Validation**
No region of the panel should be empty enough to read as a gap.

*Fixed in `835207e`.*

---

## Uneven spacing between modal actions

**Symptoms**
- One action looks crowded against its neighbour while others are well separated
- Rows appear inconsistently stacked even though the pitch is constant

**Measured cause**
Rows sat on a 78px pitch with a 72px height, but a two-line label's minimum height
pushed its actual height to 77px, absorbing its gap. Godot expands a Button to its
minimum rather than shrinking it, so the declared height was silently ignored.

**Prevention**
- Never declare a row height below what its content needs; derive it.
- Lay stacks out cumulatively from actual row heights instead of a fixed pitch.
- Use one gap value, and make it large enough that a taller row still reads as
  separated.

**Validation**
Compare the gap above and below each row in the capture.

*Fixed in `be4ad81`, then made structural in `835207e`.*

---

## Wrong semantic colour on an action

**Symptoms**
- A "continue" action rendered in the destructive red state
- Users hesitate on the safe path

**Measured cause**
`DANGER_BUTTONS["shop"]` listed index 3, which was `继续远征`. Continuing a run
abandons nothing, so the destructive state was wrong.

**Prevention**
- Assign the red state only to actions that quit, abandon, or irreversibly reset.
  Check the action list against
  [UI_VISUAL_RULES](../art/UI_VISUAL_RULES.md) "Main menu and pause" before
  writing the index list.
- Prefer naming the rule by action, not by index, when the list is stable enough.

**Validation**
Walk the action list and confirm each colour against its consequence.

*Fixed in `be4ad81`.*

---

## Dark ink on a dark surface

**Symptoms**
- Subtitle barely legible against its card
- Text contrast acceptable in isolation, poor over the game world

**Measured cause**
The main-menu subtitle used dark ink (`#4b3527`) while the card surface,
`SpecialPaper`, is dark slate `#525b66`. The colour was chosen from the
assumption that "paper" is light; in this pack `SpecialPaper` is not, and the
light sheets (`RegularPaper`, `Banner`) cannot tile into a solid panel.

**Prevention**
- Choose ink from the measured surface colour, not from the asset's name.
- In this project: warm light ink (`#f7edcf`) on `SpecialPaper`.

**Validation**
Sample the rendered surface pixel and compare against the text colour.

*Fixed in `ff88036`.*

---

## Buttons rendered with literal BBCode tags

**Symptoms**
- A label shows `[b]生命药水[/b]` on screen

**Measured cause**
`Button` in this Godot build has no `bbcode_enabled` property, and the project
bundles no font, so the default theme has no bold face. Setting markup on a
Button both fails and cannot bold anything.

**Prevention**
- Do not use BBCode on `Button`. Use `RichTextLabel` for markup, or separate
  `Label` children for mixed sizes (as `ActionRow` does).
- Emphasis must come from size, colour, or position.

**Validation**
Read the rendered text; look for stray tags.

*Corrected during `b75bca0`.*

---

## Nineteen lines of Chinese destroyed by a shell encoding round-trip

**Symptoms**
- Source text becomes mojibake (`精力恢复加速` → `绮惧姏鎭㈠鍔犻€燂`)

**Measured cause**
Reading a UTF-8 file with PowerShell's `Get-Content -Raw` and writing it back
with `Set-Content` re-encoded the bytes through the ANSI code page.

**Prevention**
- Never edit project source with shell text round-trips, and never use
  `-replace` for source edits. Use the repository's file editing tools.
- If it happens, restore from git rather than hand-repairing: the working tree
  held no uncommitted work in this case, so `git checkout` recovered it.

**Validation**
Grep the edited file for replacement characters before committing.

*Recovered from git; no lasting damage.*

---

## Using a `Button` where a richer row is needed

**Symptoms**
- Two lines of different sizes cannot be expressed
- Emphasis is impossible without bundling a font

**Measured cause**
A `Button` renders one text block at one size. The pack's button art also cannot
hold two lines inside its frame (above).

**Prevention**
- For a name + effect row, use `ActionRow`: its own `Label` children over the
  Button's background.
- Reach for `RichTextLabel` when genuine inline markup is required.

**Validation**
Confirm both lines carry the intended relative size and sit inside the frame.

*Introduced as `action_row.gd` in `b75bca0`.*

---

## Visual verification depended on a full playthrough

**Symptoms**

- A small color, spacing, or text-position edit takes as long to verify as a
  gameplay feature.
- Visual iteration is blocked by combat, currency, random waves, or another
  unrelated route to the screen.
- An unrelated flaky playthrough obscures whether the UI change is correct.

**Measured cause**

The former workflow treated three independent questions as one test: whether the
state can be reached through gameplay, whether the UI behaves correctly, and
whether the rendered state looks correct. It ran the full regression set after
every significant UI edit even when only rendered pixels changed.

**Prevention**

- Stage the affected visual state directly with a deterministic capture target.
- Operate the affected interaction by hand when its contract changed.
- Reserve a hand-played full pass for progression changes, milestones, and release
  validation.
- Do not treat an unrelated failure as a visual quality gate.

*The suite this lesson came from has since been frozen and deleted; see
`../TEST_WORKFLOW.md`. The lesson still holds for hand verification.*

**Validation**

The target repeatedly produces the same state, the screenshot is inspected, and
the smallest test covering any changed behavior passes.

*The selective policy replaced the former all-suite UI regression step.*

---

## Screenshot existed while the capture command reported failure

**Symptoms**

- The requested PNG is present and visually valid, but the wrapper exits with an
  error.
- Re-running the same target produces the same image and the same unrelated
  stderr report.
- A stale PNG can be mistaken for evidence from the latest run.

**Measured cause**

The Windows wrapper redirects Godot stderr and surfaces any stderr text as a
PowerShell error under `ErrorActionPreference = Stop`. Warnings can therefore
terminate the wrapper even when Godot wrote the PNG.

**Prevention**

- Treat a fresh PNG and process status as separate signals.
- Check the output timestamp and stderr before accepting the capture.
- Keep warnings visible, but do not let a benign warning impersonate a render
  failure.
- Never accept an existing file without proving the current run rewrote it.

**Validation**

Remove or rename the previous output, run the target, confirm a fresh PNG was
written, inspect it, and classify any stderr. Record an unresolved wrapper error
instead of calling the run clean.

*This is a capture-harness limitation, not a reason to run the whole game.*

---

## A UI state with no capture target

**Symptoms**
- A screen cannot be visually QA'd because the harness has no target for it
- The defect only surfaces when a user reports it

**Measured cause**
The result overlay had no capture target, so "does the HUD hide behind the result
modal?" was never checked, and it did not hide. The merchant `shop_overlay`,
`reward_overlay`, and `result_dead` states were likewise uncovered. The reward
modal in particular went through several rounds of button-sizing fixes with no
way to capture it.

**Prevention**

- When you add or change a UI state, add a target to
  `tools/visual_qa_capture.gd` and the `ValidateSet` in
  `tools/capture_visual_qa.ps1` in the same change.
- Make the visual target deterministic: use fixed data, enter the state directly,
  wait for layout, and freeze noisy motion.
- If the transition into the state changed, exercise that transition by hand in a
  running build. Do not make repeated visual capture depend on completing
  unrelated gameplay.

**Validation**

Every state you touched must be reachable by name in the capture harness and
produce a stable full-viewport image. When its transition changed, the transition
must also have been opened and observed by hand.

*`shop_overlay` and `result_dead` added in `75c9734`; `reward_overlay` added
later, closing the last gap.*

---

## HUD stayed visible behind the result modal

**Symptoms**
- Health, gold, and stage readouts still painted under a full-screen result
- The modal competes with live-looking gameplay information

**Measured cause**
`_show()` set `hud_root.visible = next_mode != "menu"`, so `win` and `dead` kept
the combat HUD visible beneath the overlay.

**Prevention**
- Decide HUD visibility per modal state explicitly. `pause` keeps the frozen HUD
  as pause context; run-ending and shop modals subordinate it.
- Add a capture target for the state so it is actually checked.

**Validation**
Inspect the result capture; the combat HUD must be absent.

*Fixed in `75c9734`.*

---

## Measuring the wrong thing

Not a UI defect, but the meta-failure that produced five of the entries above.

**Symptoms**
- A layout bug "fixed" repeatedly without converging
- Each fix appears to work for one case and breaks another

**Measured cause**
Three specific measurement mistakes were made in this project:

1. Measuring at a **single size**, which cannot separate a constant from a ratio.
   The button frame was mis-derived three times this way.
2. Measuring with **text present**, so glyph pixels were misread as frame edges.
3. Trusting **declared geometry** (`size`, `min_size`, computed label rects)
   instead of the rendered pixels.

**Prevention**
- Measure the art **empty and in isolation** on a contrasting background.
- Measure at **several sizes**.
- Measure the **rendered PNG**, scanning for known fill and ink colours.
- When a fix does not converge after two attempts, stop adjusting constants and
  re-derive the geometry from a measurement.

**Validation**
The derived constant reproduces the observed pixel positions at every size
tested.

*The approach that finally worked is written up in
[UI_WORKFLOW.md](UI_WORKFLOW.md#measuring-the-rendered-result).*
