# Home UI asset sources

- `settings-3d.webp`: generated for JigCat with OpenAI image generation.
- `settings-clay-3d.webp`: generated on a flat blue background, background-removed,
  and calibrated against `start-button-3d.webp` so functional icons share the
  approved primary-coral palette.
- `logo-sticker-3d.webp`: generated on a flat blue background, then background-removed;
  the `G` remains a plain readable letter, the lowercase `i` uses one paw-print dot,
  and the capital `A` carries the only pair of cat ears as an equal-size mirrored pair.
- `progress-paw-3d.webp`: legacy generated paw asset retained for provenance;
  current completion markers use `assets/ui/levels/completion-paw-primary.webp`.
- `progress-plaque-3d.webp`: generated on a flat blue background, then background-removed;
  its outer radius matches the approved rounded-rectangle progress tag.
- `title-ornament-3d.webp`: generated on a flat blue background, then background-removed.
- `title-leaf-ornament-3d.webp`: the single left-side leaf ornament derived from the
  generated flat-blue source; runtime mirrors the same file for the right side.
- `start-button-3d.webp`: generated on a flat blue background, background-removed,
  and calibrated to the approved burnt-coral handcrafted material.
- `background-mint.webp`: generated for JigCat with OpenAI image generation.

The shared `assets/ui/shared/tabletop-desk.webp` background was generated as an
opaque full-scene plate and resized to the 1206x2622 design viewport.

The runtime files were background-removed, alpha-trimmed, resized, and encoded
as transparent WebP assets with the repository image tools.

All foreground assets are generated without baked cast, contact, ambient, or
drop shadows. The approved tabletop design's contact depth is applied in the
Godot scene at runtime.
