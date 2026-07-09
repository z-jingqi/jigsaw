# Repository Instructions

Before using `$imagegen` or the built-in `image_gen` tool for this project, read `docs/imagegen-artifact-guidelines.md` and apply its prompt constraints.

When visual inspection of the Godot game is needed, launch the project in a normal non-headless Godot window instead of using `--headless`. Use the local Godot executable for the current OS and pass the repository root with `--path`.

Examples:

```bash
# macOS
/Applications/Godot.app/Contents/MacOS/Godot --path "$PWD"

# Windows, if Godot is on PATH
Godot.exe --path <repo-root>
```

After launch, wait briefly for the scene to render, then capture or inspect the displayed game window for UI/layout/visual QA. Press `D` while the game window is focused to toggle the in-game Dev Test panel when needed. For a quick smoke run, start the window, wait about 2 seconds, then terminate the process. On macOS desktop runs, the warning `Orientation not supported by this display server` is expected and does not block launch.
