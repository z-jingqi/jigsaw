#!/usr/bin/env bash
set -euo pipefail

godot_bin="${GODOT_BIN:-godot}"
log_file="$(mktemp "${TMPDIR:-/tmp}/jigcat-gdunit4.XXXXXX.log")"
trap 'rm -f "$log_file"' EXIT

if [[ ! -x "$godot_bin" ]] && ! command -v "$godot_bin" >/dev/null 2>&1; then
	echo "GODOT_BIN must point to an executable Godot binary: $godot_bin" >&2
	exit 1
fi

"$godot_bin" \
	--log-file "$log_file" \
	--path . \
	-s -d res://addons/gdUnit4/bin/GdUnitCmdTool.gd \
	"$@"
