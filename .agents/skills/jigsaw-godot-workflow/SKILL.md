---
name: jigsaw-godot-workflow
description: Inspect, edit, debug, and visually validate the JIGCAT Godot project through the live Godot editor and the godot-ai MCP. Use for changes involving .tscn scenes, Control layout, scene-tree nodes, signals, themes, animations, project settings, runtime interaction, visual regressions, or GDScript behavior that must be verified in Godot.
---

# JIGCAT Godot Workflow

Use the live editor as the source of truth for scene structure and rendered behavior. Keep file edits reviewable and finish with focused evidence.

## 1. Establish the current state

1. Read the applicable `AGENTS.md` instructions.
2. Resolve the repository root from the active checkout with `git rev-parse --show-toplevel`; do not embed a machine-specific absolute path. Confirm that `project.godot` exists at that root.
3. Run `git status --short` and preserve staged, unstaged, and untracked user changes.
4. Use the godot-ai capability that reports editor and project state. Confirm that the connected project root matches the resolved checkout before mutating anything. Activate the correct session when multiple editors are connected.
5. For scene work, inspect the scene hierarchy and node properties before deciding what to change. Never guess a NodePath or property value from filenames alone.
6. Read recent editor errors when the editor is not ready or the scene contains warnings.

Tool names can change between godot-ai releases. Treat names such as `editor_state`, `session_activate`, `scene_get_hierarchy`, `node_get_properties`, and `logs_read` as current examples, not a permanent API contract. If a named tool is absent, inspect the connected server's current tool catalog and select the equivalent capability before concluding that MCP is unavailable.

If godot-ai is unavailable, use the installed Godot version compatible with the project's `config/features` in `project.godot`, start this checkout in a normal editor window, and retry. A new Codex session may be required after MCP configuration changes.

## 2. Choose the editing surface

- Use godot-ai scene and node tools for node hierarchy, ownership, anchors, offsets, properties, groups, and scene instancing.
- Use `signal_manage`, `theme_manage`, `ui_manage`, `animation_create` or `animation_manage`, `input_map_manage`, and resource tools for their owned Godot concepts.
- Prefer `batch_execute` for a related multi-operation editor change so it can roll back on failure.
- Save deliberately with `scene_save` after inspecting the result.
- Use `apply_patch` for GDScript and other hand-authored text when that produces a clearer Git diff than an MCP text operation.
- Do not edit `.godot/`, imported artifacts, or generated UID files manually.
- Follow the current code-organization rules in the applicable `AGENTS.md`. Do not duplicate its list of coordinator files here because that list can evolve with the project.

## 3. Inspect before and after mutation

After changing a scene:

1. Re-read the affected subtree and key properties.
2. Inspect the Git diff, including generated scene-file changes.
3. Read editor logs and resolve new parse errors, invalid resources, broken NodePaths, and signal failures.
4. Capture an editor or running-game screenshot when visual placement or rendering matters.

Do not treat a syntactically valid `.tscn` file as visual proof.

## 4. Run focused validation

Run Godot visual validation in a normal non-headless window. Never add `--headless` for UI, layout, transition, motion, or game-flow validation.

Discover validation scripts from the current checkout every time; documentation is not a test registry:

```powershell
$repoRoot = (git rev-parse --show-toplevel).Trim()
$testFiles = rg --files (Join-Path $repoRoot 'scripts/tests') -g '*.gd' |
    ForEach-Object { [IO.Path]::GetRelativePath($repoRoot, $_) }
```

Choose the narrowest current script that covers the change. Search candidate filenames and contents using feature terms from the change, then open the candidate and confirm that it exercises the affected screen or system and emits explicit pass/fail output. Do not infer coverage from an old filename, and do not silently fall back to a nonexistent path. If no current script covers the behavior, report the validation gap and add focused coverage when it is in scope.

Immediately before running the selected script, verify that it exists and derive its `res://` path from the repository-relative path:

```powershell
$repoRoot = (git rev-parse --show-toplevel).Trim()
$selectedTest = '<repository-relative path returned by discovery>'
$selectedFile = Join-Path $repoRoot $selectedTest
if (-not (Test-Path -LiteralPath $selectedFile)) { throw "Validation script no longer exists: $selectedTest" }
$resPath = 'res://' + ($selectedTest -replace '\\', '/')
Godot_console.exe --path $repoRoot --script $resPath
```

The console executable still opens the normal display window and preserves structured test output in the calling shell. Use `Godot.exe --editor --path $repoRoot` for interactive editor launch. Require both a zero exit code and the script's explicit `"ok": true` result. Then read relevant editor/game logs and inspect produced screenshots when the test covers visual behavior.

Use `project_run`, `game_manage`, and `editor_screenshot` for interactive runtime details that an existing script cannot expose. Keep the editor visible and stop the run when inspection is complete.

## 5. Handle MCP fallback carefully

When the live editor cannot be reached after one reconnect attempt:

- Continue with direct `.tscn` or `.tres` editing only when the task remains safe and the existing structure is fully understood.
- Increase validation: run the focused test, inspect logs, and render or capture the affected screen.
- State clearly in the handoff that live scene-tree inspection was unavailable.

Do not install or enable a second Godot MCP alongside godot-ai as an ad hoc fallback.

## 6. Report completion

Summarize:

- Scenes, nodes, scripts, and resources changed.
- Whether changes were made through the live editor or file patches.
- Focused validation commands and their pass/fail results.
- Screenshots or logs inspected.
- Any remaining validation that requires manual interaction or another platform.
