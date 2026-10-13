# JigCat UI visual style

## Shared screen palette

Home, level selection, and gameplay share the warm ivory background in
`assets/ui/home/library/page.webp`, ink-green text (`#194F47`), and pale sage
controls (`#DDE3CF`, pressed `#BCCDAF`). Album, settings, pause, and the home
gesture guide use the same palette. Gameplay uses this same background for
every theme. Foreground navigation controls are flat vector icons without
external shadows. `GameplayStyle.gd` owns the gameplay palette.

The completion page contains only the artwork name, the complete image, and
one Done action. Album pages use the same paper background and vector controls;
collected artworks open at their full aspect ratio. See `ALBUM_AND_ARTWORK.md`
for collection rules, content processing, and current validation.

## Existing clay assets

The approved `assets/ui/home/start-button-3d.webp` is the source of truth for
the handcrafted-clay color used by existing clay assets and progress marks.
Retain this palette when processing those assets; new gameplay navigation
controls use the shared screen palette above. Mode-status glyphs retain their
documented state colors.

- Primary surface midtone: `#D35929`
- Common surface range: `#CC5021` to `#D86A41`
- Deep intrinsic edge shade: approximately `#7B240C`
- Flat generation key background: `#1647FF`

Use `tools/recolor_clay_to_reference.py` after background removal to transfer
the approved button palette while retaining an icon's internal light and clay
texture. Do not recolor by eye.

## Mode icon states

Mode selection uses the shared flat SVGs under
`assets/ui/levels/mode-icons/`: three regular honeycomb cells, a classic interlocking piece,
and two opposing curved arrows. All three use ink-green strokes (`#194F47`);
puzzle shapes have a pale sage fill (`#DDE3CF`). Glyphs have no sticker edge,
material texture, or external shadow.

Identity, saved status, and selection remain separate:

- not started: a softer green glyph and muted-green status text;
- in progress: the normal glyph with amber status text;
- completed: the normal glyph on a pale-green card with green status text;
- selected: an ink-green card border, independent of saved status.

Mode glyphs share a lighter 3.5-unit stroke and centered 96-unit geometry.
Status uses one centered text row below the mode name, without a duplicate
clock or check. Glyph selection and entrance motion retain their existing
timing and Reduced Motion behavior. SVG import uses a 2x raster with mipmaps
for clear edges at phone sizes.

Completed-mode marks use the Python-processed transparent WebP glyphs in the
same folder. Three small slots stay fixed at the image's bottom-right, in a
vertical column: polygon, knob, swap. Only completed modes appear; empty slots
keep their position. The honeycomb has a gold upper cell and two sage lower
cells; the knob piece is terracotta; the curved swap arrows are blue and gold.
A thin ivory silhouette edge separates the glyph from detailed artwork. There
is no backing disc or external shadow. The 96px assets use lossless WebP with
verified alpha and linear mipmap filtering.

All level cards are playable. Unvisited cards retain the muted preview; every
theme's first card is always in full color. Opening mode selection reveals the
card and saves that visit, even if the player returns without starting a game.

## Sticker borders

Controls that need separation from a detailed background may use the same
cream-white sticker border as the Logo. The current sampled border color is
`#F3E5CE`. The border is a uniform silhouette expansion, not an inner outline,
second rim, glow, or shadow.

## Depth and shadows

Generated foreground assets must contain no cast, contact, ambient, or drop
shadow outside their silhouette. They may contain restrained highlights and
intrinsic edge shading inside the material. Gameplay buttons and tray surfaces
use no runtime drop shadows; puzzle pieces retain their existing intrinsic
side faces and bevels.

Do not generate concentric rims, doubled borders, or inset copies for mode
icons. Shared SVG glyphs use one clear contour and only the cuts or arrows
needed to identify each mode.

## First-release gameplay surfaces

Shared puzzle pieces use a thin lower-right side and restrained directional bevels; source artwork and cut geometry remain unchanged. Side faces reuse source triangulation to avoid unstable concave fills at different display scales. Drag positions follow input directly; lift decoration must not delay them. Reduced Motion grid shifts use a single 0.2-second opacity recovery without spatial movement.

The board uses a pale sage surface (`#DDE5D5`) with an ivory rim (`#FAF8EF`),
and the two-row tray uses `#E7EBDD`. Completion frames fit the original artwork
rather than cropping it. Mode selection includes visible names; the
reference-image entry and explanatory captions have been removed.


## Shared gameplay layout

Modal overlays inherit the underlying screen's background. All three modes use
a thin ivory board rim expanded outside the artwork bounds without clipping
the image. Camera bounds include this rim.

The header has Back on the left and Pause, Hint on the right. Hint is a bulb
outline and base, without rays. The centered title retains mirrored cloud
ornaments; long names use a second title row when needed to avoid the controls.
Header controls use 144 design units with 24-unit gaps.

The rounded tray has two rows, horizontal scrolling, and a position indicator.
Its clipped piece host preserves the existing screen-coordinate system, so
picking up a piece keeps its size and pointer position. Horizontal movement
past the tray's side edges continues scrolling; vertical movement locks the
scroll for lifting a piece. Board input ignores emulated counterparts of real
pointer events while leaving those events available to GUI controls.

Swap has four independent sage controls in left/up/down/right order, using the
same vector icon and press-feedback component as the header. Buttons use 156
design units with 40-unit gaps. Bottom panels have a 168-unit bottom inset.

Mode selection keeps its Continue button. Pressing it transitions directly
from the mode page to gameplay with the level list hidden throughout. Returning
from completion also goes directly to the level list without exposing gameplay.

Completion reuses the gameplay texture and its current canvas bounds. The clean
image dissolves over the assembled pieces for 0.2 seconds, then eases to a fit
at most 88 percent of the original width. The shared paper background and green
level title and Done button enter in the same 0.96-second AnimationPlayer
timeline. The completion screen contains only the level title, artwork, and
Done button. The entire artwork stays visible. Reduced Motion
uses the settled layout immediately.
