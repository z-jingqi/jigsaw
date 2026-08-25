# Gameplay UI asset sources

- `hint-bulb-primary.webp`: ordinary lightbulb generated on the documented
  flat-blue key background. It deliberately has no cat ears or secondary
  symbol. The coral clay was calibrated to the approved home start button and
  the cream-white sticker edge was preserved.
- `move-row-up-primary.webp`: icon-only rounded-square row movement control,
  generated on the same flat-blue key background and calibrated to the same
  primary-coral reference. The cream arrow has no baked shadow. The move-down
  control reuses this exact texture rotated 180 degrees at runtime.

Solid-background sources are archived under
`/.artifacts/gameplay-redesign/source/`. The runtime files were background
removed, alpha-trimmed, resized, cleared under transparent pixels, and encoded
as transparent WebP assets with the repository image tools. Both assets contain
no baked external shadow; the lower-right shadows are composed in Godot.
