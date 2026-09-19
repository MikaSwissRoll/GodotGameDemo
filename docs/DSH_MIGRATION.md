# DeepSeek Harness Migration

Migration of this project's AI development workflow from the previous Codex
environment to DeepSeek Harness (DSH Desktop `2.0.9`, harness `0.1.5-rc.1`).

No gameplay, scene, or asset content was changed. The migration touched only
agent-environment files plus three stale naming references in documentation.

## Project Instructions

`AGENTS.md` is loaded correctly, with no duplication into DSH configuration.

DSH loads workspace instructions through `@deepseek-ai/dsh-agent-instructions`
(65,536-byte budget). It discovers the project root via the `.git` marker and
loads the `AGENTS.md` / `CLAUDE.md` chain from the project root down to the
session working directory. This session's runtime context carries an
`Instructions from: AGENTS.md` block containing the file's real content, so the
chain is provably active rather than merely present on disk.

Live refresh was also observed: after editing `AGENTS.md` mid-session, DSH
pushed an `Updated instructions from: AGENTS.md` block into the running session
without a restart.

`docs/art/` remains the persistent visual design system and all five documents
are present and readable: `ART_DIRECTION.md`, `ENVIRONMENT_DESIGN.md`,
`SCENE_DESIGN_WORKFLOW.md`, `UI_VISUAL_RULES.md`, `ASSET_USAGE_RULES.md`.
None of them were copied or re-declared in DSH configuration.

Only stale agent naming was corrected (Codex → the agent) in `AGENTS.md` and
`docs/visual_qa.md`. The autonomous development workflow itself was left
untouched.

## Skills

`godot-gdscript-patterns` now lives at:

```text
.agents/skills/godot-gdscript-patterns/
├── SKILL.md
└── references/
    ├── advanced-patterns.md
    └── details.md
```

The previous Codex environment kept this skill at
`C:\Users\22141\.codex\skills\godot-gdscript-patterns`, which is a Codex-only
location that DSH never scans. DSH's filesystem skill provider scans
`<projectRoot>/.agents/skills` at rank 200, so the skill was copied there
verbatim (SHA-256 verified identical for all three files). Only this one skill
was migrated; the upstream collection was not installed.

Verified end to end:

- DSH discovered it without a restart — it appeared in the session skill
  catalog immediately, and the host log records the skill-registry refresh at
  that moment with no warning for this skill.
- Frontmatter is valid: `name: godot-gdscript-patterns` with a non-empty
  description.
- Loading works: the `skill` tool returned the body with its base directory
  resolved to the project path.
- Referenced resources stay reachable: `references/details.md` (492 lines) was
  read successfully through its relative path.

## Godot MCP

The existing MCP server was reused, not reinstalled. The previous Codex
environment ran `@coding-solo/godot-mcp` `0.1.1` from a project-local install
at `.codex\godot-mcp`, driven by `.codex\config.toml` `[mcp_servers.godot]`.
Its `command`, `args`, `env`, and `cwd` were taken from that file verbatim.

DSH is configured through its official MCP client,
`@deepseek-ai/dsh-mcp-client`, added to the active profile patch layer at
`~/.dsh/profiles/desktop/cordis.patch.yml`:

```yaml
- id: mcp-godot
  name: '@deepseek-ai/dsh-mcp-client'
  config:
    serverName: godot
    transport: stdio
    command: "C:\\Program Files\\nodejs\\node.exe"
    args: ["D:\\Major Project\\GodotGameDemo\\.codex\\godot-mcp\\node_modules\\@coding-solo\\godot-mcp\\build\\index.js"]
    cwd: "D:\\Major Project\\GodotGameDemo"
    env:
      GODOT_PATH: "C:\\Users\\22141\\Desktop\\Godot_v4.7.2-stable_win64.exe"
    toolCallTimeoutMs: 180000
```

Tools surface to the model as `mcp__godot__<tool>`. The server exposes 15 tools:
`launch_editor`, `run_project`, `get_debug_output`, `stop_project`,
`get_godot_version`, `list_projects`, `get_project_info`, `create_scene`,
`add_node`, `load_sprite`, `export_mesh_library`, `save_scene`, `get_uid`,
`update_project_uids`. Together these cover identifying the project, launching
it, reading debug/runtime output, and stopping it.

Verified:

- Every referenced path exists: the Node runtime, the server entry point, the
  server package directory, and the Godot executable. No path was guessed.
- The server was exercised by hand over the same interface DSH uses. Each tool
  resolves to a direct Godot CLI invocation, and those invocations were run
  successfully: `--version` → `4.7.2.stable.official.ed1daf0bf`,
  `--path <project>` (project opens), and the debug-output path, which is how
  parser/runtime errors are reported.
- No secrets or API keys appear in this configuration or in this document.

Not yet verified: the MCP tools do not appear in the *current* agent session,
because the DSH host process started at 16:00 and this configuration was
written at 16:26. The profile patch layer is applied at boot, so the entry is
not live in an already-running session; there is no error, just no mount yet.
A DSH Desktop restart is required, after which `mcp__godot__get_godot_version`
and `mcp__godot__get_project_info` should be called once to confirm the bridge
from the agent side.

## Godot Runtime

The existing project runs unchanged. Verified:

- Godot `4.7.2.stable.official.ed1daf0bf` starts.
- `project.godot` loads; `run/main_scene` is `res://scenes/main/run_game.tscn`.
- The main startup scene instantiates and runs with zero script, parser, or
  resource errors.
- The Main Menu still works and gameplay still launches.
- All seven existing test harnesses pass with exit code 0, and a scan of every
  log for script/parse/resource errors returned zero matches:

| Harness | Result |
| --- | --- |
| `smoke_game.gd` | menu, movement, dash, pause, combat, archer, quest, gold, completion, death, restart, title |
| `playthrough.gd` | walked the route, fought five raiders, picked up gold, returned to Guard |
| `roguelite_smoke.gd` | guard strafe, rooms, rewards, shop, elite, win, reset, variation, death, classic entry |
| `roguelite_playthrough.gd` | attacks cleared all rooms and the elite |
| `collision_smoke.gd` | river, bridge, village castle |
| `new_features_smoke.gd` | guard, directional block, stamina costs, merchant purchases, potions, Chinese HUD |
| `upgrade_effects_smoke.gd` | counter, guard efficiency, heavy attack, kill refund, swift dash, dash cleave |

Two harmless environment errors appear in Godot stderr on every run: failure to
rotate `user://logs/*.log` and failure to read the root certificate store.
These are artifacts of the DSH workspace-write sandbox, which permits writes
under the project but not under `%APPDATA%\Godot`. The newest real log file
predates this session. Neither error affects rendering, gameplay, or exit
codes, and neither was introduced by the migration.

Git confirms the game is untouched: only `AGENTS.md` and `docs/visual_qa.md`
are modified, and `git diff` shows nothing but the three naming substitutions.

## Visual QA

The existing capture harness was reused without modification. No replacement
screenshot system was built.

`tools/capture_visual_qa.ps1` captured a 1280x720 PNG of the real Compatibility
renderer output for the `main_menu` target via
`tools/visual_qa_capture.gd`, which instantiates the actual project scene,
enters the target state, waits for rendered frames, and saves the viewport
texture. All eight documented targets remain available.

The current DSH model can genuinely inspect screenshot content — not merely
produce a PNG. This required one fix: `~/.dsh/settings.yaml` overrode the
DeepSeek model catalog without declaring `inputModalities`, so DSH initially
refused with `model "deepseek-flash" does not declare image input`. Because the
built-in catalog already declares `deepseek-flash` as `["text","image"]`,
`inputModalities: [text, image]` was added to that override, keeping the user's
existing `deepseek-flash` / `deepseek-v4-pro` selection intact. Settings
hot-reloaded, and image inspection then worked in the same session.

Concrete observations from inspecting the captured Main Menu at 1280x720, read
against `docs/art/UI_VISUAL_RULES.md`:

- **UI hierarchy** — the modal reads top-down as banner title "边境远征",
  subtitle "踏出村庄·选择战技·击败精英", then three actions. The single title
  and single short subtitle follow the documented structure.
- **Button proportions** — the three buttons are visibly narrower than the
  panel's effective paper area, roughly 170 px against a ~340 px panel. The
  rule asks buttons to share a width and sit inside the paper area; they do
  share a width and are contained, but they leave a wide empty margin on both
  sides, so the modal reads sparse.
- **Spacing and balance** — button order is correct (start, classic, quit, with
  quit red for a destructive action). The vertical rhythm is even, but the
  lower third of the panel is empty below the red button, leaving the content
  top-weighted.
- **Text readability** — title and subtitle are dark ink on the cream banner,
  matching the documented fix against light text on light surfaces. Button
  labels are legible at this size. No clipping or fractional scaling is
  visible.
- **Tiny Swords consistency** — wood frame with blue and red buttons, paper
  interior, cream banner, and shield emblem all match the documented surface
  language. The shield slightly overlaps the panel's top-left corner ornament.
- **Background/UI balance** — the castle with stone walls anchors the upper
  center and gives the scene a clear landmark silhouette. Ground is otherwise
  mostly flat grass, and the lower-right quadrant is nearly empty apart from
  two trees and a rock, which is flatter than the "layered landscape" pillar.
  The world stays fully visible behind the modal rather than behind a veil.

These are observations only. No visual change was made, because this migration
explicitly excludes new work.

## Remaining Gaps

1. **Godot MCP tools are not live in this session.** The configuration is
   written and validated, but the profile patch layer is applied at DSH boot,
   so the tools appear only after restarting DSH Desktop. After the restart,
   call `mcp__godot__get_godot_version` and `mcp__godot__get_project_info`
   once to confirm the bridge from the agent side. Every task the MCP server
   performs was meanwhile verified directly through the same Godot CLI
   invocations.
2. **Image input depended on a settings override.** Visual QA works now, but it
   is enabled by an explicit `inputModalities` declaration in
   `~/.dsh/settings.yaml`. Removing or rewriting that override without
   re-declaring image support would silently disable screenshot inspection
   again, because DSH's catalog schema defaults `inputModalities` to
   `["text"]`.
3. **Godot log rotation is sandbox-blocked.** Under the default
   workspace-write policy, Godot cannot write `user://logs`. Not a migration
   defect and not player-visible, but it means Godot's own rotating log files
   under `%APPDATA%\Godot` are unavailable for post-mortem debugging from
   inside this sandbox; stdout/stderr capture remains the reliable channel.
4. **`skills/.system` parity is intentionally absent.** Codex shipped bundled
   system skills (`imagegen`, `openai-docs`, `plugin-creator`, `review-agent`,
   `skill-creator`, `skill-installer`). These are Codex-platform features with
   no DSH equivalent and no bearing on this project, so they were not carried
   over.

Existing Codex configuration was deliberately left in place and is still
functional: `.codex\config.toml`, `.codex\godot-mcp` (the MCP server install
DSH now points at), and `~/.codex/skills/godot-gdscript-patterns` (the
migration source). Nothing was deleted, so the previous environment remains
usable as a fallback.
