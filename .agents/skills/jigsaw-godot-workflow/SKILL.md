---
name: jigsaw-godot-workflow
description: Inspect, edit, debug, and visually validate the JIGCAT Godot project through the live Godot editor and the godot-ai MCP. Use for changes involving .tscn scenes, Control layout, scene-tree nodes, signals, themes, animations, project settings, runtime interaction, visual regressions, or GDScript behavior that must be verified in Godot.
---

# JIGCAT Godot Workflow

Use godot-ai as the editor bridge; do not duplicate its capabilities with file-only guesses.

1. Read the repository `AGENTS.md` and follow its Godot AI loop, code-organization rules, and validation criteria.
2. Resolve the current repository root and inspect `git status --short`. Preserve existing user changes.
3. Confirm that the connected Godot session points to this checkout. Inspect the affected scene tree, node properties, and logs before editing.
4. Use godot-ai for scene nodes, resources, signals, themes, animations, project settings, runtime state, and screenshots. Use `apply_patch` when hand-authored GDScript or text produces a clearer diff.
5. Save deliberately, re-inspect the affected state, check diagnostics and Git diff, then validate exactly as required by `AGENTS.md`.

Treat godot-ai tool names as version-dependent: discover the current equivalent capability when a remembered name is absent. If the bridge is unavailable, keep the CLI validation path working and report the limitation; do not install a second Godot MCP as an ad hoc fallback.

Read `docs/AI_DEVELOPMENT.md` only when setup, connection, deterministic debug commands, or MCP troubleshooting is needed.
