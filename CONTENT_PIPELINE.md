# Content Pipeline

This project now has two lightweight content tools:

- `pnpm level:create <series-id> <level-id> [--title "..."] [--series-title "..."] [--source /abs/path/to/source.png]`
- `pnpm levels:check`

## Recommended workflow

1. Prepare a transparent-background source image.
2. Run `pnpm level:create cats 002-sleepy --title "Sleepy" --source /path/to/source.png`
3. Open the generated `levels/<series>/<level>/level.json` and tune:
   - `displayScale`
   - `difficulty.scatterRadius`
   - `slice.cols` / `slice.rows`
   - `slice.shapeStyle`
4. Adjust the generated difficulty presets in `levels/index.json` if this level wants a different ramp.
5. Run `pnpm levels:check` before launching the game.

## Shape style guide

- `straight`: beginner-friendly, easiest to read
- `curve`: softer internal cuts with less visual noise
- `mixed`: best default for mid difficulties
- `classic-knob`: most puzzle-like and the hardest to scan quickly

## Image guidelines

- Keep the subject centered and well separated from the transparent background.
- Favor a silhouette with clear ears, limbs, or outline changes.
- Avoid extremely thin appendages unless they are visually important.
- Start with square-ish source art for easier scaling and camera fit.
