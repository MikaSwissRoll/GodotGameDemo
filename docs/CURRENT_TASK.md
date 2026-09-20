# Current task: an open market square

## Goal

Remove the separate campfire grass tile block. Build a lived-in market with
varied native props and residents, using the supplied reference for clustered
activity and keeping the bridge route and grazing districts.

## Existing systems affected

Starting-town scenery and ambient actor placement.

## Important assumptions

Use actual Tiny Swords resources and wood UI pieces as small display counters.
Market goods and extra residents are scenery, not new purchases or pickups.
Keep player, guard, merchant, and main walking lanes clear.

## Implementation phases

1. Remove the campfire grass layer and inspect available resources.
2. Compose food, tool, lumber, and trading clusters around the campfire.
3. Capture title and classic entry, inspect, and refine.

## Test plan

Inspect fresh full-viewport captures and run the existing title smoke test.
Original building and bridge collision remains unchanged.

## Out of scope

New trade mechanics, item systems, new art generation, and source-asset edits.

## Outcome

Removed CampfireGreen. Added three native wood counters, grouped tools, food,
mineral goods, wood stacks, and three ambient market residents. Goods are
non-interactive scenery. Reviewed the title and classic-entry captures; moved
the northern counter clear of the bridge route in a second visual pass.
The title smoke test and Git whitespace check pass.
