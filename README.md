# Tiny Kingdom: Border Expedition

A small top-down pixel action RPG built with Godot 4.7.2, GDScript, the
Compatibility renderer, and the supplied Tiny Swords art. The default mode is
a short roguelite run. All in-game text is in Chinese.

![Redesigned Tiny Swords combat arena and HUD](docs/visual-arena.png)

## Game modes

Press **F5** in Godot to open the title screen. Choose **开始远征** for the
roguelite run or **经典冒险** for the original village quest. The original
scene remains at `scenes/main/game.tscn`.

A run starts from the village, moves through three combat rooms, and ends with
an elite battle. The third room has two enemy waves. Enemy mixes vary between
runs, and consecutive runs use different first-room mixes. After each regular
room, choose one of three temporary upgrades. A merchant appears after the
second room. Death and victory show a summary; **再来一局** starts a fresh run.
Gold, potions, and upgrades reset between runs. There is no permanent
progression.

## Controls

The controls are shared by both modes:

| Action | Control |
| --- | --- |
| Move or strafe | W, A, S, D |
| Attack | Space or left mouse button |
| Raise shield | Hold right mouse button |
| Dash | Shift |
| Talk or trade in classic mode | E near an NPC |
| Use health potion | 1 |
| Use stamina potion | 2 |
| Pause or resume | Esc |

The shield keeps its facing direction while raised, so you can strafe without
turning it. Its 240-degree guard arc covers the front and both flanks, leaving a
120-degree opening directly behind. Holding the shield does not spend stamina; a
successful block does.

Attacking and dashing also spend stamina. Stamina regenerates when those actions
and guarding stop. Melee enemies mark their attack area before swinging,
and archers show an aiming line before firing. Damage and blocks show floating
feedback.

## Run choices

The first upgrade pool contains six distinct effects:

| Upgrade | Effect |
| --- | --- |
| Shield counter | A successful block empowers the next hit. |
| Iron guard | Successful blocks cost four less stamina. |
| Dash cleave | Dashing through an enemy deals damage. |
| Swift step | Dashing costs less stamina and cools down faster. |
| Kill flow | A kill restores stamina. |
| Heavy blade | Attacks deal more damage but cost more stamina. |

Each defeated enemy gives one gold, and clearing a regular room gives one more.
The merchant sells health and stamina potions for three gold each. A health
potion restores 60 health. The merchant also offers one
visible run upgrade for five gold. A campfire fully restores health
before the elite battle. These values are scoped to the run mode; the classic
quest keeps its original enemy balance and gold drops.

## Project layout

The game uses focused scenes and scripts:

- `scenes/main/run_game.tscn` and `scripts/main/run_game.gd` manage runs,
  rewards, the merchant stop, and summaries.
- `scenes/world/run_arena.tscn` and `scripts/world/run_arena.gd` provide
  six hand-authored Tiny Swords arena compositions.
- `scripts/world/tiny_swords_environment.gd` builds reusable 64-pixel terrain,
  buildings, animated vegetation, resources, and collision.
- `scenes/ui/run_ui.tscn` and `scripts/ui/run_ui.gd` show the run HUD and
  choices. `scripts/ui/tiny_swords_ui.gd` supplies shared nine-slice panels,
  buttons, bars, and icons from the asset pack.
- `scripts/systems/run_upgrades.gd` defines the six temporary upgrades.
- `scenes/player/`, `scenes/enemies/`, and their scripts provide shared
  combat for both modes.
- `scenes/main/game.tscn` retains the original village adventure.

The original Tiny Swords files in `asset/` are referenced in place and are
never overwritten. See `docs/art/ART_DIRECTION.md` and
`docs/art/SCENE_DESIGN_WORKFLOW.md` before creating or revising a scene. The
supplied assets have no common audio files, so combat feedback currently uses
animation, telegraphs, color, camera shake, and floating text.

## Verification

Godot 4.7.2 launches the default scene with no reported parser, runtime, or
resource errors. Headless tests cover run flow, all six upgrade effects,
guard direction, purchases, elite victory, death, restart, and the classic
mode entry. An automated playthrough uses actual movement, attacks, and health
potions to clear the run. The original story smoke, collision, feature, and
full-route tests also pass. The menu, combat, reward, elite arena, village, and enemy camp were rendered
and visually inspected. A live MCP debug launch reports no engine errors.


