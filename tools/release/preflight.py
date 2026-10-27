#!/usr/bin/env python3
"""Release configuration/package checks, not gameplay or the paused test suites."""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pack", type=Path, help="Inspect an already exported PCK in an isolated cwd")
    parser.add_argument("--godot", default="godot")
    args = parser.parse_args()
    project = (ROOT / "project.godot").read_text()
    game = (ROOT / "scripts/app/Game.gd").read_text()
    presets = (ROOT / "export_presets.cfg").read_text()
    checks = {
        "no_ai_autoload": "_mcp_game_helper" not in project,
        "ai_editor_plugin_opt_in": "res://addons/godot_ai/plugin.cfg" not in project,
        "debug_router_not_preloaded": 'preload("res://scripts/debug/' not in game,
        "debug_router_gated": 'if OS.is_debug_build() and ResourceLoader.exists(' in game,
        "content_json_included": 'include_filter="levels/*.json,levels/**/*.json"' in presets,
        "release_check_preset": 'name="Linux Release Check"' in presets,
    }
    for key in ("addons/*", "scripts/tests/*", "scripts/debug/*"):
        checks[f"export_excludes_{key}"] = all(
            key in line for line in presets.splitlines() if line.startswith("exclude_filter=")
        )
    for match in re.finditer(r"func (debug_\w+)\([^\n]*\) -> void:\n([^\n]+)", game):
        checks[match[1] + "_release_guard"] = "if not OS.is_debug_build():" in match[2]
    if args.pack:
        pack = args.pack.resolve(strict=True)
        with tempfile.TemporaryDirectory(prefix="jigcat-release-check-") as temporary:
            base = Path(temporary)
            env = os.environ.copy()
            for variable, directory in (("XDG_DATA_HOME", "data"), ("XDG_CONFIG_HOME", "config"), ("XDG_CACHE_HOME", "cache")):
                target = base / directory
                target.mkdir()
                env[variable] = str(target)
            run = subprocess.run(
                [args.godot, "--headless", "--main-pack", str(pack), "--script", str(ROOT / "tools/release/inspect_pack.gd")],
                cwd=base, env=env, text=True, capture_output=True, check=False,
            )
            print(run.stdout, end="")
            print(run.stderr, end="")
            checks["pack_inspection"] = run.returncode == 0 and "ERROR:" not in run.stderr + run.stdout
    print(json.dumps({"kind": "release_configuration_not_gameplay_suite", "ok": all(checks.values()), "checks": checks}, indent=2))
    return 0 if all(checks.values()) else 1


if __name__ == "__main__":
    raise SystemExit(main())
