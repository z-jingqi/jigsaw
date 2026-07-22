# Repository Instructions

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

Only launch the project interactively when the validation scripts cannot expose the visual detail that needs inspection:

```text
# macOS
/Applications/Godot.app/Contents/MacOS/Godot --path "$PWD"

# Windows, if Godot is on PATH
Godot.exe --path <resolved-repository-root>
```

For interactive inspection, wait briefly for the scene to render, then inspect the displayed game window. Press `D` while the game window is focused to toggle the in-game Dev Test panel when needed. For a quick smoke run, start the window, wait about 2 seconds, then terminate the process. On macOS desktop runs, the warning `Orientation not supported by this display server` is expected and does not block launch.

## Code organization

- Do not concentrate new UI, input, animation, persistence, or gameplay behavior in `Game.gd` or `PuzzleBoard.gd`. These files should coordinate lifecycle and delegate work to focused collaborators.
- Keep one primary responsibility per script. Screen construction, gesture handling, motion, data access, and gameplay rules should live in separate controllers, services, factories, or feature modules.
- When a change introduces a new responsibility or makes an existing script materially larger, extract that responsibility before considering the change complete.
- Prefer small public coordination methods over reaching across modules for implementation details. Add focused validation coverage alongside the module that owns the behavior.
