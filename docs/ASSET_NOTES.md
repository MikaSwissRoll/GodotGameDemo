# Tiny Swords asset notes

The supplied Tiny Swords art is in `asset/`. The game references these files
directly and never modifies the third-party originals.

## Current use

- **Characters:** Blue Warrior strips provide the player. Blue Pawn supplies
  village NPCs. Red Warrior and Red Archer strips provide enemy types.
- **Terrain:** All five `Tilemap_color` sheets are available through the shared
  64-pixel terrain builder. Water uses the supplied background tile. Land uses
  proper edge and corner cells instead of colored rectangle placeholders.
- **Environment:** Tree1 through Tree4, Bushe1 through Bushe4, all four ground
  rocks, animated water rocks, stumps, gold stones, sheep, the rubber duck, and
  three fire strips appear across the current scenes.
- **Buildings:** The village uses the blue castle, houses, monastery, barracks,
  archery building, and tower. Hostile areas use the matching red building set.
- **UI:** Special paper, wood table, blue button, bar frame, coin, sword, and
  shield assets form the shared HUD and modal visual system.
- **Items:** The gold resource and red arrow sheets remain in use for drops and
  projectiles.
- **Effects:** Fire is animated in camps. Combat still uses tint, knockback,
  telegraphs, camera shake, and floating text. Dust and explosion strips remain
  available for later animation polish.
- **Audio:** No WAV, OGG, MP3, or FLAC files were found in the supplied pack.

## Runtime helpers

`scripts/world/tiny_swords_environment.gd` creates `TileMapLayer` terrain,
animated strip sprites, buildings, shadows, props, and foundation collision.
`scripts/ui/tiny_swords_ui.gd` reconstructs the supplied component sheets into
project-owned runtime nine-slice textures. Source images under `asset/` remain
unchanged.

Follow `art/ASSET_USAGE_RULES.md` and the matching documents under `docs/art/` when adding assets, scenes, or UI.
