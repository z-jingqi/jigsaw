#!/usr/bin/env bash
set -euo pipefail

godot_bin="${GODOT_BIN:-godot}"
log_file="${GDUNIT_LOG_FILE:-}"
temporary_log=""

if [[ -z "$log_file" ]]; then
	log_file="$(mktemp "${TMPDIR:-/tmp}/jigcat-gdunit4.XXXXXX.log")"
	temporary_log="$log_file"
else
	mkdir -p "$(dirname "$log_file")"
fi

cleanup() {
	if [[ -n "$temporary_log" ]]; then
		rm -f "$temporary_log"
	fi
}
trap cleanup EXIT

if [[ ! -x "$godot_bin" ]] && ! command -v "$godot_bin" >/dev/null 2>&1; then
	echo "GODOT_BIN must point to an executable Godot binary: $godot_bin" >&2
	exit 1
fi

"$godot_bin" \
	--log-file "$log_file" \
	--path . \
	-s -d res://addons/gdUnit4/bin/GdUnitCmdTool.gd \
	"$@"
