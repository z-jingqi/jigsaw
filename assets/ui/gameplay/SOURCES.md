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

## Refined direction controls (2026-09-07)

`direction-button-base.webp` and `direction-arrow-up.webp` replace the combined
row-control texture in SwapActionBar. Generated with the built-in imagegen tool
from the approved gameplay preview, on solid blue with no external shadow.
The base stays upright; only the isolated arrow rotates for four directions.

Prompt: two separated sprites, a blank shallow coral rounded-square matte clay
base and a cream rounded upward arrow, orthographic, subtle internal upper-left
light, no inset rim, text, or cast shadow, flat blue #1647FF background.

Sources and preview: `.artifacts/gameplay-visual-refinement/source/`.
Python processing: crop the two halves, `tools/remove_background.py --trim
--trim-padding 8 --spill-radius 2`, calibrate the base with
`tools/recolor_clay_to_reference.py` against `start-button-3d.webp`, then
alpha-bound crop, Lanczos resize, center with transparent padding and WebP
quality 93. Runtime sizes: base 384x384, arrow 256x256. Both final images have
border alpha maximum 0 and no opaque blue pixels; the original sources remain
outside runtime assets. Existing Godot-owned button shadows are retained.

## Quiet gameplay tabletop (2026-09-07)

`tabletop-calm.webp`: generated with the built-in imagegen tool using
`assets/ui/shared/tabletop-desk.webp` as the edit target. Prompt: preserve the
portrait composition, honey wood, top-left woven cloth, bottom-left rope and
notebook, bottom-right leaves; replace harsh diagonal sunlight with even
soft diffuse light, reduce grain contrast, keep the center empty; no UI,
text, new objects, frame, or transparency. Python Pillow converts to RGB,
Lanczos fits to 1206x2622, and encodes WebP quality 88 / method 6.
Source: `.artifacts/gameplay-visual-refinement/source/tabletop-source.png`.
This asset is selected only while the underlying screen is gameplay.
