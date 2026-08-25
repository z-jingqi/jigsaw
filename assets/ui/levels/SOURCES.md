# Level UI assets

- `completion-paw-primary.webp`: regenerated from the approved level-list paw
  crop, calibrated to the `start-button-3d.webp` primary-coral palette, and
  processed without a baked external shadow. It marks cards whose three modes
  are complete and is also reused as the selected-mode marker.

- `mode-progress-bell.webp`: generated with the built-in image generation tool as a
  shadow-free golden cat bell with a coral paw on a cobalt-blue matte. The matte was
  removed with `tools/remove_background.py`, then the result was trimmed, resized,
  and encoded as WebP with the repository image tools.
- `level-lock-bell.webp`: derived from the same bell design with a caramel keyhole,
  then processed through the same background-removal and WebP pipeline.
- Mode status asset provenance is documented in
  `assets/icons/status/SOURCES.md`.
