# Clean player UI redesign

## Contract

Warm paper canvas, charcoal hierarchy/actions, sage/apricot/lavender selection surfaces,
weighted Noto Sans SC, no material/glass shadows. Shared `CleanTheme` and resource fonts
own visual tokens. Original small botanical line drawing belongs to the home identity;
puzzle artwork remains the hero. Pagination is numeric with previous/next, never dots.
No level-editor website changes. Portrait phone and tablet are supported; landscape is
not a product target (`project.godot` requests portrait). Gameplay rules/save schemas remain
unchanged. New interface copy follows existing English/Chinese/Japanese locale selection.

## Runtime surface inventory

| Surface | States covered by implementation |
| --- | --- |
| Home | populated, theme swipe, previous/next with wrapping, restored selection, unavailable theme, empty library |
| Theme library | playable/unavailable cards, scroll/restoration, empty |
| Level list | revealed/unrevealed previews, recommended/newly revealed animation, partial/full completion, empty; reusable locked-card fallback |
| Mode picker | polygon/knob/swap, selected/unselected, start/continue/replay, no playable modes |
| Gameplay | polygon and knob board/tray, swap board/action bar, hint enabled/disabled/active, back, completion presentation |
| Album overview | themed groups, all-art entry, empty/loading |
| Album gallery | single-theme/all-art gallery, loading/empty |
| Artwork detail | image, caption, numeric position, previous/next endpoint disabled states |
| Settings | on/off, persistence pending/error, reduced motion, close/reopen, focus |
| First-run guide | swipe/enter steps (1/2 and 2/2), skip, passthrough interaction, reduced motion |
| Completion | artwork, description empty/long, replay, next-level/final-level unavailable action |
| Shared | safe insets, focus rings, >=44 logical-point navigation targets, modal transitions, interrupted navigation |

Current catalog deliberately emits `locked: false` for all levels. Unvisited artwork
previews are desaturated, not locked; no new progression restriction was introduced.
There is no runtime per-mode tutorial route in this checkout, only stale test references.
Album artwork is browsable without unlocking. Completion status dots are not pagination.

## Verification policy and findings

Repository automated suites are paused by `AGENTS.md`; they are not run and no tests or
visual baselines are added/changed. Validation uses compiler/import diagnostics, formatter,
linter, real non-headless Godot windows, existing runtime debug commands and manual input.
External inspection scripts, isolated profile, screenshots and logs stay outside the repo.
Screenshot evidence is accompanied by state and runtime results, not treated as a pass alone.

Issues found and fixed during review: weak variable-font defaults (numeric OpenType axes),
safe-area header collisions, font fitting before weight application, guide root swallowing
swipes, guide footer peeking, asymmetric undo-vs-next pagination, localization mismatch,
and disabled hint contrast. Final verification details are maintained in the delivered QA
report rather than embedding machine-specific artifacts in source control.
