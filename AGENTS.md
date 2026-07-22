# Repository Instructions

When the game UI, layout, or visual flow needs validation, prefer running a Godot validation script in a normal non-headless window. This exercises the real display server, runs the relevant screens automatically, prints explicit pass/fail results, and exits without requiring manual window control. Do not add `--headless` when the purpose is visual validation.

Examples:

```bash
# macOS
/Applications/Godot.app/Contents/MacOS/Godot --path "$PWD" --script res://scripts/tests/GameFlowTest.gd

# Windows, if Godot is on PATH
Godot.exe --path <repo-root> --script res://scripts/tests/GameFlowTest.gd
```

Use the most focused existing script when one matches the change, such as `GameFlowTest.gd`, `ResponsiveLayoutTest.gd`, `TransitionVisualTest.gd`, or `InteractionSmokeTest.gd`. Treat a zero exit code together with the script's `"ok": true` results as the validation criterion.

Do not treat a screenshot by itself as a pass. A visual change passes only when the process exits zero, the final JSON has `"ok": true`, the relevant state and layout assertions pass, and logs contain no script/runtime errors. AI development tooling must not create new tests or alter visual baselines automatically.

Only launch the project interactively when the validation scripts cannot expose the visual detail that needs inspection:

```bash
# macOS
/Applications/Godot.app/Contents/MacOS/Godot --path "$PWD"

# Windows, if Godot is on PATH
Godot.exe --path <repo-root>
```

For interactive inspection, wait briefly for the scene to render, then inspect the displayed game window. Press `D` while the game window is focused to toggle the in-game Dev Test panel when needed. For a quick smoke run, start the window, wait about 2 seconds, then terminate the process. On macOS desktop runs, the warning `Orientation not supported by this display server` is expected and does not block launch.

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
