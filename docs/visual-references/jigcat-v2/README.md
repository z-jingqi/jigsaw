# Jigcat visual reference set

Generated with the built-in `image_gen` workflow as high-fidelity visual direction for the existing Godot game. These are design references, not production UI assets and not screenshots of implemented code.

## Shared direction

- Warm ivory paper, cocoa brown type, soft orange interaction accents, restrained sage and jade-teal.
- Reuse the same cream Jigcat mascot with cocoa markings, orange paw pads, and a cocoa-orange striped tail.
- Keep the current four-topic catalog, three play modes, progress system, tutorial, settings, and completion flow.
- Do not introduce currency, rankings, shops, daily tasks, lives, or advertising.
- Keep the mascot supportive and outside the puzzle's critical interaction area.

## Reference screens

| File | Screen | Main design intent |
| --- | --- | --- |
| `00-jigcat-character-anchor.png` | Mascot anchor | One stable character design and its core expressions/actions |
| `01-home-theme-list.png` | Theme list | Branded welcome, real topic covers, compact album cards |
| `02-level-list-shanhai.png` | Level list | Clear current/completed/locked states in the existing two-column grid |
| `03-mode-select.png` | Mode selection | Three visually distinct modes with concise explanations |
| `04-game-polygon.png` | Polygon gameplay | Irregular pieces, piece tray, selected-piece feedback, compact bottom dock |
| `05-game-knob.png` | Classic knob gameplay | Familiar interlocking pieces with the same gameplay shell |
| `06-game-swap.png` | Swap gameplay | Strong blue temporary hint and five centered controls, including row shift |
| `07-tutorial-swap.png` | Tutorial | Cat-led gesture teaching for swapping and cyclic row movement |
| `08-settings.png` | Settings | Current controls plus reduced motion and edge contrast preferences |
| `09-completion.png` | Completion | Full artwork reveal, mode stamps, cat celebration, and next-level priority |

## Prompt set

All screens used the local mascot anchor and relevant existing Jigcat assets as image references. The shared prompt requested a shippable portrait mobile-game UI, practical safe-area layout, large touch targets, paper-cut watercolor texture, and strict preservation of existing functionality. Per-screen prompts specified the exact screen structure and Chinese labels shown in the table above. Gameplay prompts used the real `天狗` level artwork and explicitly distinguished irregular polygon pieces, classic knob pieces, and rectangular swap tiles. The settings correction used a precise edit prompt that changed only the dimmed background and removed invented meta-game UI while preserving the foreground panel.

When implementing, render all labels with the game's real font and localization system. Treat generated text placement as a composition reference rather than a final rasterized UI asset.
