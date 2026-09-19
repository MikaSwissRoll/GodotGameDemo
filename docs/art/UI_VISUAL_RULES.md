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

## HUD

Keep persistent combat information near the viewport edges and leave the center
clear. Group health and stamina together. Put coins, encounter state, potions,
and run upgrades into separate compact groups according to how often the player
checks them.

Bars must include a text label or value; color alone is insufficient. Icons
should reinforce labels rather than replace unfamiliar information. Control
hints belong near the lower edge and should yield to dialogue, rewards, or other
short-lived messages.

## Main menu and pause

Use one centered modal with a strong title and no more than one short subtitle.
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