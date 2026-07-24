# GdUnit4

This repository vendors GdUnit4 `v6.1.3` from `godot-gdunit-labs/gdUnit4`.

- Source commit: `1579130d73f15f628fd0cfdbf7d60bdc39144a26`
- Godot compatibility: 4.5 through 4.6.2
- License: MIT, retained at `addons/gdUnit4/LICENSE`

Run focused unit suites through the repository wrapper:

    GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot ./tools/run_gdunit4.sh -a ./test/unit

The wrapper writes Godot's log to a temporary location. This keeps unit tests
independent from an open Godot editor, which otherwise shares this project's
`user://logs` directory on macOS.

The vendored copy intentionally excludes GdUnit4's own `test/` directory.
JIGCAT runs only its project test suites under `test/`.
