# Reproducible release preflight

This is build/package inspection, **not** execution of the paused gameplay test suites.
Follow `AGENTS.md`; enabling CI/tests requires an explicit change of that policy.

## Development tooling boundary

Normal startup no longer installs the Godot AI helper autoload. Its source remains
under `addons/godot_ai` for deliberate editor-only opt-in. Re-enabling that plugin
can write the helper autoload back into `project.godot`; preflight rejects that.
The game creates its command router only in a debug engine build and when the
script exists. Direct debug mutators also reject release builds.

Export presets exclude developer addons, test scripts, debug command adapters,
docs, and tooling. JSON content is explicitly included. This does not remove
runtime state/metrics helpers used internally by navigation.

## Local commands

```sh
python tools/release/preflight.py
# Use isolated writable XDG_DATA_HOME / XDG_CONFIG_HOME / XDG_CACHE_HOME in CI.
godot --headless --editor --path . --export-pack "Linux Release Check" /absolute/output/game.pck
python tools/release/preflight.py --pack /absolute/output/game.pck
# Requires matching Godot 4.6.3 export templates:
godot --headless --path . --export-release "Linux Release Check" /absolute/output/Jigcat.x86_64
```

The PCK check intentionally runs from a fresh directory outside the checkout;
otherwise Godot may resolve a file from the source filesystem and make a removed
addon falsely appear present. The checker creates a disposable user-data profile.
A PCK is content, **not an executable release**. A successful pack check does not
prove a release binary launches, signing works, or a device is supported.

## Verified Linux template source

Use only the official [Godot 4.6.3 release](https://github.com/godotengine/godot-builds/releases/tag/4.6.3-stable)
for `Godot_v4.6.3-stable_export_templates.tpz` and `SHA512-SUMS.txt`.
Verify the archive against its exact filename entry before extracting it:

```sh
grep '  Godot_v4.6.3-stable_export_templates.tpz$' SHA512-SUMS.txt | sha512sum -c -
```

For a Linux-only check, extract only `templates/version.txt`,
`templates/linux_debug.x86_64` and `templates/linux_release.x86_64` into
`$XDG_DATA_HOME/godot/export_templates/4.6.3.stable/`; `version.txt` must read
`4.6.3.stable`. Keep the downloaded archive, checksum and binaries in an external
tool cache, not in source control. This does not install mobile SDKs or authorize
signing, changing package identities, or uploading a release.

Run the exported executable from its output directory with a separate writable
user profile. The release template does not serve as the editor's external-script
inspection runner: inspect its PCK with `preflight.py`, then boot the actual binary
without `--script`. Preserve verbose exit logs; an exit code of zero alone does
not imply there are no leaked resources.

## Release gates requiring owner/environment input

- Keep matching export templates available and validate the resulting executable in a normal window.
  Headless boot verifies startup/packaging, not rendered UI, hardware audio or gameplay.
- Android preset currently retains the existing `com.zjingqi.jigcat.debug` identity;
  do not silently choose a store identity or sign/upload with guessed credentials.
  Confirm app identity, signing key custody, version code, target SDK and store
  requirements before producing a distributable mobile build.
- No credentials belong in source control. Godot export credentials are local.
- Run the authorized core gameplay regression and normal-window matrix after the
  suite policy is explicitly reopened; this change does not bypass that pause.
- Validate keyboard/screen-reader labels in supported locales. Desktop code-level
  labels are not proof of VoiceOver/TalkBack behavior on a real device.

Official references: [Godot 4.6 exporting projects](https://docs.godotengine.org/en/4.6/tutorials/export/exporting_projects.html),
[Android Godot export](https://developer.android.com/games/engines/godot/godot-export).
