# Vendored Godot AI

This directory is vendored from the upstream Godot AI release and is used only
as an editor-side development aid. The game and its command-line tests must not
depend on the MCP server being available.

- Source: https://github.com/hi-godot/godot-ai
- Release: https://github.com/hi-godot/godot-ai/releases/tag/v3.0.5
- Tag: `v3.0.5`
- Commit: `2313b6441ae605ee6cf49dd69f74cab30231da39`
- Archive: https://github.com/hi-godot/godot-ai/archive/refs/tags/v3.0.5.tar.gz
- Archive SHA-256: `fa3fc45849e9aa652d6689612252de1f251f8a34ad5dfc7cbb72d94a9845ee05`
- Vendored subtree: `plugin/addons/godot_ai`
- License: MIT; see `LICENSE` in this directory.

Local compatibility patch:

- `plugin.gd` does not register Godot AI's editor-process `Logger` while the
  GdUnit4 editor plugin is enabled. Godot 4.6.2 on macOS otherwise aborts
  during process shutdown when both plugins keep GDScript loggers active.
  Scene tools, runtime control, MCP transport, game logs, screenshots, and
  structured command diagnostics remain available; only passive editor error
  capture is disabled for that combined-plugin session.

Do not use the plugin's self-update action in this repository. Upgrade by
reviewing a specific upstream release, replacing the complete vendored subtree,
reapplying the compatibility patch if it is still necessary, and updating the
commit and archive checksum above.
