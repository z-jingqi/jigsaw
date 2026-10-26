# Shared theme carton runtime (v6)

This supersedes the initial single-fox prototype scope in README.md.

## Runtime composition

All playable level cards and mode selectors use the same authored thin-board tuck carton. `ThemePackaging` supplies one palette/motif per theme; `CartonAppearance` prints the full aspect-preserved original level artwork, top-left title and lower-right polygon/knob/swap completion SVGs. There is no printed theme name, per-deity symbol, outside duplicate caption or list piece count. Shanhai packaging anticipates the mineral-green/ochre mural direction; existing artwork is unchanged.

The model opens only its narrow top flap, tuck tab and dust ears. Existing geometric preview data supplies textured polygon/knob samples and scrambled swap strips. Gameplay configuration, Start/Continue/Replay and save semantics still use the existing coordinator and board paths.

`BoxThumbnailCache` owns one reusable offscreen renderer, serial 512×683 captures and a 24-entry LRU (about 32 MiB raw RGBA). Keys include theme, level, art, title, reveal/lock state and all three completion states. Pooled cards reject stale generation callbacks; canceled invisible jobs are skipped. The cache renderer stops while a mode selector is active, leaving one updating 3D viewport. List cards use static textures, not per-card viewports. Pre-multiplied alpha composition is shared between live and cached surfaces.

The original source card remains in layout but its picture is hidden while the live carton moves. Back cancels gameplay preparation before retracting samples, reversing the flap and shrinking to the recorded source rectangle. Source visibility restores on modal removal; scroll position remains unchanged. Reduced motion settles directly. Entry without a list rectangle stays in local destination coordinates and returns to its underlying route.

## Assets and provenance

- Existing original Blender-authored `tuck-carton.glb` and model source; no downloaded model.
- Original six approved `assets/ui/mode-status/*.svg`, unchanged geometry.
- Existing repository level artwork and fonts; no original artwork edits or new font dependencies.
- Theme motifs, paper/ink and composition shaders are original code-native geometry/shaders, not copied brand artwork.
- No fixture or screenshot is shipped as user progress.

## Validation scope

Automated suites and baselines remain paused under AGENTS.md. Normal-window Godot 4.6.3 Compatibility validation uses an isolated external XDG profile. Evidence is outside the repository. Existing debug interaction smoke is explicitly distinct from natural solving: it exercises board interaction APIs and forces completion at the end; completion-derived card updates use the real isolated progress store. Physical pointer navigation and swap dragging, exact resume session equality, multiple themes/levels, reduced motion, early/repeated Back, compact layouts and cache lifecycle are additionally checked.

Desktop software rendering does not establish real-phone performance, touch hardware, safe-area hardware, haptics or audio output. Left-edge back swipe and theme navigation redesign are not added by this packaging change. Tiny status SVGs distinguish completed color from incomplete outlines; individual dashed segments are not promised legible at every compact scale.
