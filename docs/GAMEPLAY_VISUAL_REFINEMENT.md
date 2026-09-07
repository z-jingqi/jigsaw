# Gameplay visual refinement

Implemented the approved four-button preview on `feat/gameplay-visual-refinement`.
Generated source images stay under `.artifacts/gameplay-visual-refinement/source`;
only processed WebP assets and their Godot imports are shipped under assets.
Source prompts and processing settings are recorded in
`assets/ui/gameplay/SOURCES.md`.

- Four independent coral controls retain left/up/down/right order, use a shared
  upright base and separately rotated arrow, and have more compact spacing.
- Gameplay uses a diffuse-light tabletop. Levels retain the original texture;
  opening a modal above gameplay keeps the quiet texture.
- All modes receive a narrow ivory rim outside the original artwork. The rim
  participates in camera bounds and survives immediate board rebuilds.

Validation on macOS Godot 4.6.2 in a normal window:

- Processed base 384x384 and arrow 256x256: border alpha maximum 0, no opaque
  blue pixels. Base palette calibrated to the existing approved start button.
- Actual four-direction button clicks produced the expected cyclic slot changes;
  all four bases remained unrotated. Structured result `ok: true`.
- Nine-tail fox swap/knob/polygon runtime frames contain their artwork bounds,
  ignore input, and use the calm background. Modal and return checks passed.
- Resizing between 390x844 and 650x1414 preserves the named frame in all modes;
  swap hit areas remain within screen and above 44 display pixels at these
  desktop sizes. This is layout evidence, not a real-device touch certification.
- Screenshots of all three modes saved; swap and knob visually inspected.
- Final game run has no script/runtime errors, only the expected macOS
  orientation warning. Game stopped; diagnostic user-data backup restored.
- Existing pre-commit formatting/lint checks run before handoff.
- Automated test suites remain paused by repository policy; no tests or visual
  baselines were added or changed. Real-device validation remains pending.

Evidence: `.artifacts/gameplay-visual-refinement/` contains alpha-report.json,
controls-review.json, surfaces-review.json, resize-review.json, final-logs.json,
and final-swap.png / final-knob.png / final-polygon.png.
