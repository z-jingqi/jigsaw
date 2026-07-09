# Imagegen Artifact Guidelines

Use this file before generating images for this project.

## Main Risk

GPT Image 2 can produce visible artifacts when a prompt asks for too many fine, organic, or repeating structures at once. High-risk elements include dense foliage, fog, smoke, clouds, waves, particles, fur, feathers, scales, fabric weave, cracked surfaces, and glitter-like highlights.

## Prompt Rules

- Prefer one clear subject and a few large readable shapes.
- Describe the image as a layout: foreground, subject, background, accent elements.
- Avoid stacking many high-risk textures in the same prompt.
- Use recognized art styles or direct visual qualities; avoid invented style names.
- Keep style instructions compatible. Do not mix soft watercolor with hyper-realistic sharp detail, or dreamy softness with hard technical precision.
- For fantasy subjects, reduce micro-detail: use broad plates, clean silhouette, smooth large forms, and simplified background masses.
- Add explicit negative constraints when needed:
  - no cellular texture
  - no webbing
  - no neural-network pattern
  - no repeating Voronoi pattern
  - no noisy micro-detail clusters
  - no glitter particles
  - no dense small leaves
- Use reference images only when the new prompt is close to the reference in subject, style, and composition.

## Project Defaults

For theme covers:

- Use 16:9 landscape source images.
- No text, logo, UI, frame, buttons, or progress elements.
- Keep the main subject inside the center safe area for card cropping.
- Favor clean, game-readable illustration over maximum detail.
- Generate each unrelated theme as a fresh image request.

## Shan Hai Jing Adjustment

For Shan Hai Jing covers, avoid combining detailed dragon scales, dense cloud swirls, complex waves, distant mountains, glowing particles, and foliage all at once. Prefer a cleaner composition:

- foreground: one large Zhulong head and simple body curve
- middle ground: broad jade mountains and smooth mist bands
- background: simple red sun accent and light sky
- texture: limited large-scale scale plates, no tiny scale fields

Source investigated: https://apipass.dev/blogs/how-to-solve-gpt-image-2-artifacting-issues
