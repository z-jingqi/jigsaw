#!/usr/bin/env bash
set -euo pipefail

godot_bin="${GODOT_BIN:-godot}"
artifact_dir="${CI_ARTIFACT_DIR:-.artifacts/ci/runtime-validation}"
mkdir -p "$artifact_dir"

if [[ ! -x "$godot_bin" ]] && ! command -v "$godot_bin" >/dev/null 2>&1; then
	echo "GODOT_BIN must point to an executable Godot binary: $godot_bin" >&2
	exit 1
fi

candidates=()
while IFS= read -r candidate; do
	candidates+=("$candidate")
done < <(find scripts/tests -type f -name '*Test.gd' -print | sort)
selected_tests=()
for candidate in "${candidates[@]}"; do
	if grep -Eq 'RUNTIME_ARCHITECTURE_VALIDATION|OFFLINE_CONTENT_VALIDATION' "$candidate"; then
		selected_tests+=("$candidate")
	fi
done

if [[ ${#selected_tests[@]} -ne 2 ]]; then
	echo "Expected runtime architecture and offline content validation scripts; found ${#selected_tests[@]}." >&2
	exit 1
fi

runner=()
if command -v xvfb-run >/dev/null 2>&1; then
	runner=(xvfb-run -a "$godot_bin")
else
	runner=("$godot_bin")
fi

for test_path in "${selected_tests[@]}"; do
	if [[ ! -f "$test_path" ]]; then
		echo "Validation script no longer exists: $test_path" >&2
		exit 1
	fi
	name="$(basename "${test_path%.gd}")"
	output_path="$artifact_dir/${name}.out"
	log_path="$artifact_dir/${name}.godot.log"
	"${runner[@]}" --log-file "$log_path" --path . --script "res://$test_path" 2>&1 | tee "$output_path"
	grep -q '"ok":true' "$output_path"
	if grep -En 'SCRIPT ERROR|Parse Error|Invalid call|Invalid get index|Attempt to call function' "$output_path" "$log_path"; then
		echo "Runtime diagnostics failed for $test_path" >&2
		exit 1
	fi
done
