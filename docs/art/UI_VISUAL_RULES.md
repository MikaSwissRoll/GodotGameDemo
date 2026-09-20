# UI visual rules

## Purpose

This document owns HUD, menus, dialogue, shops, rewards, pause screens, and
other interface presentation. UI should look native to Tiny Swords while
preserving fast comprehension during action.

## UI goals

- Communicate combat state without pulling attention away from the player.
- Use the supplied paper, wood, banner, ribbon, bar, button, cursor, avatar, and
  icon families as a coherent system.
- Keep Chinese text readable at the project's 1280 by 720 viewport.
- Express importance through position, scale, spacing, and contrast before
  adding more decoration.
- Use consistent layouts for repeated choices and transactions.

## Surface language

Use each Tiny Swords surface for a stable purpose:

- **Special or regular paper:** HUD groups, descriptions, dialogue, and compact
  information panels.
- **Wood table:** major modal surfaces, menus, rewards, shop, pause, and results.
- **Blue buttons:** safe, affirmative, primary, and navigation actions.
- **Red buttons:** destructive, dangerous, failure, or irreversible actions.
- **Bars:** health, stamina, and other continuously changing values.
- **Icons:** quick recognition for health, stamina, coins, weapons, shields,
  information, and resources.
- **Ribbons and banners:** primary screen titles and major results only.

Build stretchable assets as proper nine-slice or horizontal-slice components.
Do not stretch a complete raster uniformly when the pack provides edge, center,
and corner pieces.

## Screen hierarchy

Use this order inside a modal:

1. one title;
2. one short context or instruction block;
3. the current value needed for the decision, such as coins or reward effect;
4. clearly separated actions; and
5. secondary guidance only when it changes the decision.

A player should be able to find the primary action immediately. Keep decorative
icons near the title or value they explain; do not scatter them around the
panel.

## Typography and language

All player-facing text is Chinese unless explicitly required otherwise. Use
plain, short phrases and consistent gameplay terms. Avoid long tutorial
paragraphs inside active gameplay.

At 1280 by 720, use these practical minimums unless a tested font requires more:

- 16 pixels for secondary control hints;
- 18 pixels for HUD and compact labels;
- 20 pixels for body text and buttons; and
- 32 pixels for major modal titles.

Use warm light text on dark wood or dark blue surfaces. Use dark brown or ink
text on light paper and cream banners. Never rely on a light outline to rescue
light text placed over a light surface. Avoid scaling rendered text or UI
containers to fractional sizes.

Choose the ink from the surface's measured colour, not from an asset's name:
`SpecialPaper` reads as "paper" but renders as dark slate (`#525b66`), so it takes
the same warm light ink as the wood and button surfaces. Text drawn directly on
the game world — with no panel behind it — must carry a dark outline, because the
terrain behind it changes value as the camera moves.

The project bundles no font and uses the Godot default theme, which has no bold
face. Express emphasis through size, colour, and position; do not rely on markup.

## HUD

Keep persistent combat information near the viewport edges and leave the center
clear. Group health and stamina together. Put coins, encounter state, potions,
and run upgrades into separate compact groups according to how often the player
checks them.

Bars normally carry a text label or value, because color alone is insufficient.
The roguelite HUD is a deliberate, reviewed exception: its health and stamina
bars are unlabelled, and are told apart by **width and fill colour** — health is
the wider bar with the red gradient, stamina the narrower one with the gold
indicator line. If a third bar is ever added, the pair must be re-reviewed, since
two unlabelled bars is the most this treatment can carry. The classic adventure
HUD keeps its `生命` / `精力` values.

Icons should reinforce labels rather than replace unfamiliar information. Control
hints belong near the lower edge and should yield to dialogue, rewards, or other
short-lived messages. Keep every HUD group inside a 20-pixel inset from the
viewport edge, and give icon-plus-label pairs one consistent gap.

## Main menu and pause

The main title uses a compact left-side menu over the live classic town, with
this reading order: 边境远征, 经典模式, 远征模式, 退出游戏. Keep scenery
visible and omit gameplay HUD until the classic camera handoff completes.

Pause and gameplay overlays use one centered modal with a strong title and no
more than one short subtitle.
Buttons should share a width, remain inside the panel's effective paper area,
and follow the same vertical rhythm. Order actions by likelihood and risk.
Place quitting, abandoning a run, and destructive restart actions last or use a
red state when confirmation is required.

The paused gameplay view should remain visible behind a dark translucent veil.
The overlay must make the paused state obvious without hiding all spatial
context.

## Dialogue and interaction

Keep dialogue close enough to the speaker or lower screen region that the player
understands its source, while preserving the character and immediate route.
Show the speaker name or portrait when conversations become multi-line or
involve several characters.

Short one-line feedback may use a toast. Quests, choices, and multi-step
conversations require a dedicated panel. Do not use rapidly disappearing toast
text for information the player must compare or remember.

## Shop and reward choices

Show the player's relevant currency on the same modal as the purchase. Every
shop action must display item name, price, and a short effect. Disabled or sold
items need a visible state beyond color alone.

Reward choices should use parallel structure and comparable text length. Put the
playstyle-changing effect first; supporting numeric details come second. Keep
all choices within one view without scrolling for the current small feature
set.

## Interaction states

Buttons require distinct normal, hover or focus, pressed, and disabled states.
Keyboard focus must remain visible. Text and icon placement should not jump
between states. Keep hit areas larger than the visible label and preserve clear
spacing between adjacent actions.

## Stamina feedback

A player must never discover that stamina is empty only because an action stopped
responding. Every stamina cost is announced twice: by the bar while it falls, and
by immediate feedback when an action is refused.

- Warning steps at **30** and **20**. Each fires a one-shot shake of the character
  **and** the stamina bar together, the deeper step harder, so the shudder reads
  as belonging to the player rather than to the HUD alone. Each threshold re-arms
  only once stamina climbs back above it, so regenerating across the line cannot
  retrigger the warning.
- A **refused action** shakes the character and the bar briefly and pops the icon.
  Refusal is never silent, and never uses text or sound.
- A **guard break** gets the strongest, shortest shake and the exhausted icon.
- Feedback is debounced so repeated events cannot keep the icon up or turn the
  shake into a permanent wobble. The bar and the character must be still whenever
  nothing is wrong.
- The state icon comes from the Shikashi atlas (`SHIKASHI_SWEAT`, `SHIKASHI_ZZZ`,
  `SHIKASHI_SWOON`) and rides **above and to the right of the character**, not
  beside the bar, so it points at whoever the warning applies to. It shows at rest
  while stamina is low, and pops briefly on an event. The bar and its fill artwork
  are never recoloured or modified for feedback.
- The character shake moves the **sprite only**, never the body, so feedback can
  never displace collision or the player's real position, and it settles back
  exactly rather than leaving a fraction of a pixel behind.
- **Low stamina must not slow normal actions.** Attack, dash, and guard keep their
  timing so the controls never feel laggy; only the exhausted state slows
  animation, and only briefly.

## Layout safety

- Keep essential HUD inside a 20-pixel viewport inset.
- Do not cover the player's default spawn or the main encounter center.
- Test the longest Chinese label expected in each component.
- Prevent text from touching ornamental borders or nine-slice corners.
- Avoid more than one full-screen modal at a time.
- Hide or subordinate HUD groups when a modal makes them irrelevant.

## Visual QA targets

For any changed UI state, capture and inspect the matching target defined in
[Visual QA](../visual_qa.md). Check actual rendered text, focus, panel borders,
button containment, icon alignment, contrast, clipping, and the amount of world
still visible behind the interface. Numerical anchors and clean logs do not
replace this inspection.

## Related documents

This document defines the target look. It deliberately does not cover process,
past defects, or the asset inventory:

- [UI Workflow](../ui/UI_WORKFLOW.md) — how to build UI, and the completion gate.
- [UI Known Failures](../ui/UI_KNOWN_FAILURES.md) — defects this project has
  already shipped and fixed.
- [UI Asset Guide](../ui/UI_ASSET_GUIDE.md) — measured inventory of usable assets.
- [Asset Usage Rules](ASSET_USAGE_RULES.md) — provenance and modification policy.