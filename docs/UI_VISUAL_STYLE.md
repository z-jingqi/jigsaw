# JigCat UI visual style

## Primary coral

The approved `assets/ui/home/start-button-3d.webp` is the source of truth for
the primary handcrafted-clay color. New navigation controls, action controls,
and completion marks must be calibrated against that runtime asset rather than
an approximate color name. Mode-status glyphs are the documented exception.

- Primary surface midtone: `#D35929`
- Common surface range: `#CC5021` to `#D86A41`
- Deep intrinsic edge shade: approximately `#7B240C`
- Flat generation key background: `#1647FF`

Use `tools/recolor_clay_to_reference.py` after background removal to transfer
the approved button palette while retaining an icon's internal light and clay
texture. Do not recolor by eye.

## Mode icon states

Mode glyphs use the approved level-list design palette instead of the primary
coral palette:

- completed: full-opacity sage/olive-green clay icon;
- not started: full-opacity warm parchment-clay icon;
- in progress: not-started icon plus a full-opacity primary-coral dot;
- unavailable: parchment-clay icon at 38% runtime opacity.

The state dot is a code-drawn shape, not part of a generated icon.

## Sticker borders

Controls that need separation from a detailed background may use the same
cream-white sticker border as the Logo. The current sampled border color is
`#F3E5CE`. The border is a uniform silhouette expansion, not an inner outline,
second rim, glow, or shadow.

## Depth and shadows

Generated foreground assets must contain no cast, contact, ambient, or drop
shadow outside their silhouette. They may contain restrained highlights and
intrinsic edge shading inside the material. Runtime depth is code-owned and
uses a lower-right shadow consistent with the upper-left scene light.

Do not generate inner outlines, concentric rims, doubled borders, or inset
copies for mode icons. Each glyph has one silhouette and one softly rounded
outer edge.
