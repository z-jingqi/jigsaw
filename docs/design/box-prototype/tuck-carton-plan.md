# Upright tuck carton — structural correction

Supersedes the shallow full-face hinged-lid prototype. This is a modelling checkpoint, not a claim of runtime integration.

- Original model authored with the installed Blender 4.3.2; no third-party model, download, or installation.
- Upright playing-card-style paperboard carton. The large 3:4 front cover stays fixed throughout opening and closing.
- Only the narrow top closure moves: rear top fold, small top flap, rounded tuck tab, and two side dust flaps. Thin board cross-sections, restrained bevels, seams and fold lines establish paperboard construction rather than a solid cube.
- Godot coordinates: Y up, front +Z, width 2.25, height 3.0, depth 0.48, bottom Y=0. Front artwork has full 0–1 UVs, matching the existing uncropped 3:4 level image.
- List render is strictly frontal orthographic: no yaw, tilt, or elevated camera. The full front image is fixed; only the small top elements articulate in the selector.
- Existing single-level selection, start/resume/replay, reduced-motion, cancellation and reverse transition contracts stay unchanged. Samples emerge vertically through the narrow top opening and retract before closure.
- First gate: inspect a closed front render, open structural gray model, exported GLB hierarchy and pivots before substantial runtime integration.
- Scope remains the first fox level only; other artwork, cat/dog covers and theme navigation remain unchanged. Test suites remain paused.
