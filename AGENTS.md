# Repository Instructions

> **The test suites are paused while the UI is being reworked.** The screens are
> changing shape faster than the assertions can follow, so the suites fail for
> reasons that are not defects. `RUN_TESTS` in `.github/workflows/quality.yml` is
> `"false"`: the `gdunit` and `runtime-validation` jobs still run and report, so
> the required checks on `main` are satisfied, but they execute nothing. The
> `quality` job still lints. Until this note is removed, verify visual work by
> running the app and inspecting it rather than by the criteria below, and say
> plainly in any handoff that the suites did not run.

When the game UI, layout, or visual flow needs validation, prefer running a Godot validation script in a normal non-headless window. This exercises the real display server, runs the relevant screens automatically, prints explicit pass/fail results, and exits without requiring manual window control. Do not add `--headless` when the purpose is visual validation.

Discover validation scripts from the current checkout before choosing one:

```powershell
$repoRoot = (git rev-parse --show-toplevel).Trim()
$testFiles = rg --files (Join-Path $repoRoot 'scripts/tests') -g '*.gd' |
    ForEach-Object { [IO.Path]::GetRelativePath($repoRoot, $_) }
```

Search the discovered filenames and contents using terms from the affected feature, inspect the candidate, and choose the narrowest current script that exercises the behavior. Do not treat filenames written in documentation as an authoritative test registry. Verify the selected file still exists immediately before deriving its `res://` path and running it.

```powershell
$selectedTest = '<repository-relative path returned by discovery>'
$selectedFile = Join-Path $repoRoot $selectedTest
if (-not (Test-Path -LiteralPath $selectedFile)) { throw "Validation script no longer exists: $selectedTest" }
$resPath = 'res://' + ($selectedTest -replace '\\', '/')
Godot_console.exe --path $repoRoot --script $resPath
```

Treat a zero exit code together with the script's `"ok": true` results as the validation criterion. If no discovered script covers the behavior, report the gap and add focused coverage when it is in scope.

Do not treat a screenshot by itself as a pass. A visual change passes only when the process exits zero, the final JSON has `"ok": true`, the relevant state and layout assertions pass, and logs contain no script/runtime errors. AI development tooling must not create new tests or alter visual baselines automatically.

Only launch the project interactively when the validation scripts cannot expose the visual detail that needs inspection:

```text
# macOS
/Applications/Godot.app/Contents/MacOS/Godot --path "$PWD"

# Windows, if Godot is on PATH
Godot.exe --path <resolved-repository-root>
```

For interactive inspection, wait briefly for the scene to render, then inspect the displayed game window. To reach a specific state without replaying a manual input sequence, drive `Game.debug_execute()` from a validation script instead. For a quick smoke run, start the window, wait about 2 seconds, then terminate the process. On macOS desktop runs, the warning `Orientation not supported by this display server` is expected and does not block launch.

## Git and pull request integration

- `main` is the always-runnable integration baseline. It must never contain an incomplete feature, an unreachable intermediate architecture, or code that has not passed its required validation.
- Start each substantial feature by creating one integration branch from `main`, named `feat/<scope>` (for example, `feat/refactor-runtime-ui`).
- All implementation branches and their pull requests must target the active feature integration branch, never `main`. A vertical slice is merged only after it is connected to the real runtime path, replaces its old path, and passes its focused validation.
- Open a pull request from `feat/<scope>` to `main` only when the feature is complete: its Definition of Done is met, no intermediate or parallel implementation remains, the complete feature flow is runnable, and the required regression checks pass.
- The feature-to-`main` pull request is the only path for that feature into `main`. Its title, branch name, or at least one commit must include the relevant Linear identifier; its body must list all related Linear issues and the validation results.
- Do not push directly to `main`, and do not merge a partial feature into `main` merely to continue work there. Keep unfinished integration work on its `feat/<scope>` branch until it is ready for the final merge.

## Code organization

- Do not concentrate new UI, input, animation, persistence, or gameplay behavior in `Game.gd` or `PuzzleBoard.gd`. These files should coordinate lifecycle and delegate work to focused collaborators.
- Keep one primary responsibility per script. Screen construction, gesture handling, motion, data access, and gameplay rules should live in separate controllers, services, factories, or feature modules.
- When a change introduces a new responsibility or makes an existing script materially larger, extract that responsibility before considering the change complete.
- Prefer small public coordination methods over reaching across modules for implementation details. Add focused validation coverage alongside the module that owns the behavior.

## Animation ownership

- Use `.tscn` scenes plus `AnimationPlayer` for stable composition and repeatable timelines such as modal open/close, fixed screen entrances, and completion sequences.
- Use Tween or focused motion controllers for drag-following gestures, paging, puzzle-piece movement, dynamic layout, hints, cameras, particles, and other programmatic motion.
- Preserve the current visual timing and behavior unless the task explicitly asks for a redesign. Do not migrate a Tween solely because an editor tool can create an animation.
- Reduced Motion must jump to the correct end state, and interrupted/repeated transitions must not flash, leak nodes, or leave active motion behind.

## Generated image assets

- Never ask image generation tools for a transparent background. Generated
  "transparent" images can contain a baked checkerboard or another fake
  background even when the preview looks transparent.
- When a runtime asset needs transparency, generate it on a perfectly flat,
  high-contrast solid-color background that does not occur in the subject.
  Remove that background with the repository Python image tools, trim excess
  transparent margins, then resize and encode the final runtime format.
- Before importing the asset into Godot, inspect the actual alpha channel and
  edge pixels. A preview or filename is not evidence that the image has real
  transparency.
- Generated UI foreground assets must not contain baked cast, contact, ambient,
  or drop shadows. When the interface needs depth, implement the shadow in
  Godot with scene styles, shaders, or dedicated runtime nodes so it remains
  adjustable and does not create an inner border when the asset is resized.
- Keep the generated source outside the runtime asset path. Only the processed,
  alpha-verified, trimmed, and compressed result belongs under `assets/`.

## Godot AI editor loop

Godot AI is an optional development bridge, not a runtime dependency or the source of truth for correctness. When it is available, use this order:

1. Inspect editor state and select the session whose project path is this repository.
2. Read the relevant scene tree and node properties before mutating them.
3. After every script write, inspect the returned structured diagnostics before continuing.
4. Start the game and require the reported game status to be `live`.
5. Use `Game.debug_execute()` to enter a deterministic state instead of replaying a long manual input sequence.
6. Inspect `debug_state_snapshot()`, editor/game logs, and the screenshot together.
7. Run the smallest relevant existing repository test, then the existing baseline set before handoff.

If evidence disagrees, diagnose in this order: structured command/state result, script diagnostics and runtime logs, scene/node properties, screenshot, then focused/full tests. MCP unavailability must never block the CLI validation path.
