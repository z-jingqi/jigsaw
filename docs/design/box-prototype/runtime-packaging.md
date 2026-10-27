# Shared theme carton runtime (v6)

This supersedes the initial single-fox prototype scope in README.md.

## Runtime composition

All playable level cards and mode selectors use the same authored thin-board tuck carton. `ThemePackaging` supplies one palette/motif per theme; `CartonAppearance` prints the full aspect-preserved original level artwork, top-left title and lower-right polygon/knob/swap completion SVGs. There is no printed theme name, per-deity symbol, outside duplicate caption or list piece count. Shanhai packaging anticipates the mineral-green/ochre mural direction; existing artwork is unchanged.

The model opens only its narrow top flap, tuck tab and dust ears. Existing geometric preview data supplies textured polygon/knob samples and scrambled swap strips. Gameplay configuration, Start/Continue/Replay and save semantics still use the existing coordinator and board paths.

`BoxThumbnailCache` owns one reusable offscreen renderer, serial 512×683 captures and a 24-entry LRU (about 32 MiB raw RGBA). Keys include theme, level, art, title, reveal/lock state and all three completion states. Pooled cards reject stale generation callbacks; canceled invisible jobs are skipped. The cache renderer stops while a mode selector is active, leaving one updating 3D viewport. List cards use static textures, not per-card viewports. Pre-multiplied alpha composition is shared between live and cached surfaces.

The original source card remains in layout but its picture is hidden while the live carton moves. Back cancels gameplay preparation before retracting samples, reversing the flap and shrinking to the recorded source rectangle. Source visibility restores at the live-to-cached handoff before modal removal; the selected four-card page remains unchanged. The current source rectangle is refreshed after viewport resize. Reduced motion settles directly. Entry without a list rectangle stays in local destination coordinates and returns to its underlying route.

## Assets and provenance

- Existing original Blender-authored `tuck-carton.glb` and model source; no downloaded model.
- Original six approved `assets/ui/mode-status/*.svg`, unchanged geometry.
- Existing repository level artwork and fonts; no original artwork edits or new font dependencies.
- Theme motifs, paper/ink and composition shaders are original code-native geometry/shaders, not copied brand artwork.
- No fixture or screenshot is shipped as user progress.

## Validation scope

Automated suites and baselines remain paused under AGENTS.md. Normal-window Godot 4.6.3 Compatibility validation uses an isolated external XDG profile. Evidence is outside the repository. Existing debug interaction smoke is explicitly distinct from natural solving: it exercises board interaction APIs and forces completion at the end; completion-derived card updates use the real isolated progress store. Physical pointer navigation and swap dragging, exact resume session equality, multiple themes/levels, reduced motion, early/repeated Back, compact layouts and cache lifecycle are additionally checked.

Desktop software rendering does not establish real-phone performance, touch hardware, safe-area hardware, haptics or audio output. Left-edge back swipe is not implemented. Home remains the existing card stack; the existing theme library, not a newly invented home route, shares the paginated indicator. Tiny status SVGs distinguish completed color from incomplete outlines; individual dashed segments are not promised legible at every compact scale.


## Shallow-ledge paging (B)

`PagedLevelShelf` replaces scrolling only in the level list; album keeps its original virtual grid. Four original-aspect cartons occupy a two-by-two page. Both thin ledges are drawn in a stationary parent; only old/new card-page layers translate horizontally. Tall-screen row height is capped to keep the group compact. Partial final pages retain empty slots without duplicating cards.

`WindowedDotPager` is shared by the level list and existing theme library. It exposes at most five dots, 44-logical-pixel hit areas, localized page/current-page accessibility names and left/right keyboard navigation. There are no visible numerical counters or previous/next page buttons. Pointer/touch swipes exclude the leftmost 24 logical pixels, reserved for a possible future edge-back gesture. Canceled touches, multiple pointers, focus loss and pause settle interaction; resize and queued page requests settle to one selected page. Refreshing progress does not reset that page.

Only current/adjacent card pages are allocated/prewarmed, with the existing 24-entry texture LRU and serial renderer. Opening a carton pauses cache rendering. Returning retracts samples, closes the narrow top and returns to the same page/card without two visible source cartons; mode heading and CTA fade with the reverse transition.

### B acceptance evidence (2026-10-26)

Normal-window Godot 4.6.3 Compatibility, isolated profile: 430×900 and 320×568; Greek/Shanhai/flowers; physical horizontal swipe, pointer dots and keyboard navigation; first/last boundary, two-item last page; theme page retained across level navigation; quick queued pages plus resize; canceled-touch recovery; 100-page indicator stays five 44-pixel targets; reduced-motion paging/open/return; early/repeated Back; progress-store completion fixture refresh without changing page. The fixture is not a natural solve and never touches the normal profile.

Physical swap dragging changed the session; Back returned to page 2, reopening showed Continue, and the resumed session was exactly equal. Recorded native frames contain one invariant pair of shelf rectangles while box-layer X positions change; independent frame review found no duplicate source box, board bleed-through or former heading/CTA residue. Cache drained to zero jobs with 24/24 entries; only one 3D viewport updated during a modal. Final native quit returned `ok: true`, exit 0 and no script/runtime errors. Changed-script lint and diff checks passed. Automated suites remain paused, and desktop evidence is not real-device touch/performance/safe-area or audio validation.
