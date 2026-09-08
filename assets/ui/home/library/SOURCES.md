# Theme cover sources

Generated with the built-in imagegen tool on 2026-09-08 from the approved theme-library mockup. The four illustrations are original generated botanical, ocean, bird, and woodland covers; no new playable levels are included.

Source: `exec-0d069a77-c922-445b-a7b0-047922bcf78b.png` in the Codex generated_images archive, outside runtime assets.

Reproduce: `python3 tools/prepare_theme_covers.py <source-sheet.png>`.
The 2x2 sheet is split at exact midpoints, resized with Lanczos and saved as 600×900 RGB WebP, quality 92. Covers are intentionally opaque full-bleed art; rounded corners are applied by the runtime shader. No baked UI shadows or transparency extraction is required.

Additional approved home assets: `shanhai.webp` from `exec-f7f35b62-6da1-4895-8a68-77bf5fcafbf6.png` (600×900, WebP quality 92); `page.webp` from `exec-d6bbac80-36b2-459e-9f2c-27f2278b0a40.png` (1206×2622, WebP quality 88). Both generated with built-in imagegen, converted to RGB and resized using Pillow Lanczos. The fox is a theme cover; playable puzzle source images are unchanged.

Title cloud ornament: `title-cloud.webp` from built-in imagegen source `exec-63edcb88-eee0-4557-a734-fa3ec5843fcd.png`, generated on 2026-09-08 against a flat `#ff00ff` chroma background using the approved home mockup as a style reference. Prompt: one horizontal, slender Chinese auspicious-cloud line ornament in pale sage green, with a compact outer curl and thin trailing strokes toward the title; no paired ornament, text, shadow, glow, texture, watermark, or transparency. The archival source is also copied to `.artifacts/home-card-library/source/title-cloud-magenta.png`. Background removal used `tools/remove_background.py` with explicit `#ff00ff`, interior removal, despill, trimming, and 8 source-pixel padding. The cutout was resized with Lanczos to 256×70 and encoded as lossless RGBA WebP. Alpha and edge inspection confirmed a transparent border, meaningful two-pixel padding at alpha 8, and no visible magenta-like pixels.
