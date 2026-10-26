# Puzzle box prototype — approved design checkpoint

This checkpoint saves approved design assets; it does **not** claim the new box flow is already implemented.

## Assets
- `assets/ui/mode-status`: exact six approved SVGs. Completed = sage honeycomb / apricot knob / lavender swap; incomplete = explicitly segmented gray geometry, not automatic dash phase.
- `shared-spec.json` and `icon-spec.md`: original geometry and segment rules.
- `source/cat-original.png`: unchanged original generated transparent cat artwork, design source only (not loaded into runtime).

## Runtime prototype scope
One existing level (`topic_01/shanhai_v2_01`), three existing game modes. Keep all other game routes and save/progression semantics.
The 2D list shows the box cover, level name at left, three small completion SVGs at right; no piece count. A closed box moves from its list rectangle to the center, opens its independent hinged lid, then presents three mode choices. Mode information and piece count appear only after selection. Honeycomb / knob selection displays a few matching textured shapes from the box cavity; swap displays scrambled image strips. Start uses the existing 2D puzzle implementation. Back closes and shrinks to the preserved list position.

Use one live orthographic SubViewport only while the prototype selector is active, with a reusable floor, four walls, interior and lid pivot. List cards must remain lightweight 2D, never persistent per-card 3D viewports. Respect reduced motion, interruption and repeated inputs. Left-edge back swipe is separate from page/puzzle gestures; disclose if not included in the first prototype.

## Deferred, not silently implemented
The wider theme-grid / pagination / cat-footer concept is not part of this first box slice. Cat/dog catalog covers are long originals without a confirmed matching uncropped 3:4 source. Do not crop/stretch or substitute different first-level artwork to fake a match. Preserve those original resources. New page-specific concept permits KAMI-style dots but does not require changing unrelated pagination in this slice.

## Validation
Use a normal Godot window and actual interactions. Repository test suites remain paused under AGENTS.md; do not add tests or update baselines automatically. Deliver only affected list/selector/gameplay evidence and key animation frames, ideally a short clip, labelled accurately.
