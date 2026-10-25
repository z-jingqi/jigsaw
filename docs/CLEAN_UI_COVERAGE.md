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

### Native inspection findings (2026-10-25)

The integration review exercised real, non-headless Godot windows at **320×568,
430×900, and 768×1024**, all portrait. Landscape is not claimed. Evidence includes
visible controls, runtime state snapshots, logs, and native-pixel touch-target inspection;
the external screenshot manifest is delivered separately. Native 44-pixel minimums are
translated through the canvas stretch, rather than assuming 44 canvas units are sufficient.

Normal-motion interaction smoke in all three modes (polygon, knob, swap) passed using
real `handle_input` paths, including the applicable snap, hint, tray, and swap interactions.
Forced completion was used **only** to inspect the completion overlay and resulting save
presentation: this is not evidence of manually solving an entire puzzle. The first-run
home guide's swipe/enter transition and numeric step indicator were inspected. There are
no live per-mode tutorial routes to claim coverage for.

Reduced-motion polygon interaction smoke did **not** pass its immediate
`lifted_at_same_size` expectation: the observed scale was 0.85281 before the expected
immediate 1.0. The untouched baseline produced the same result. This remains a disclosed
pre-existing discrepancy, not a passing reduced-motion gameplay assertion or a redesign
regression claim. Reduced-motion UI screenshots alone do not resolve that discrepancy.

The environment's Dummy audio backend produced an Ogg decoder exit leak also reproduced
unchanged on the baseline. The external inspection harness exits cleanly when it stops
audio and allows a 0.5-second drain before teardown. No soundcard or audible-output
verification was possible; music/sound setting state checks do not imply audio playback
was heard. Repository test suites remain paused and were **not run**; no tests or visual
baselines were created or updated. These targeted runtime exercises are not a full-suite
or full-device-certification pass.

Final real desktop-pointer checks additionally verified polygon and classic tray pickup
and snap (joined artwork visibly changed and group/tray counts decreased), native tray
scrolling, swap tile exchange, and the shift action. Arbitrary unsnapped tray drops return
to the tray by design; observing only the final frame had initially obscured the successful
pickup. A read-only held-lift observation confirmed correct drag ownership, reentry, and
release with Reduced Motion enabled. The baseline-identical smoke scale expectation above
was not altered or relabeled as passing. Normal/reduced-motion navigation interruptions
settled with zero active motions; partial progress reopened with the Continue action.

English and Japanese home/settings were inspected in native windows alongside the Chinese
page set. Empty, unavailable, locked, pending/error and long/empty-description captures
use explicitly labeled presentation-only fixtures where the live catalog does not expose
those states. They do not establish live locked progression or persistence behavior.

Final Godot editor import/parse completed without script errors. All pre-commit lint/format
and safety hooks passed using an external temporary Python 3.12 configuration because this
environment lacks the repository-pinned Python 3.11 interpreter; repository hook and CI
configuration are unchanged. Feature-branch backups do not trigger the main/PR-only CI,
so no green CI result is claimed. Physical mobile safe-area/haptics remain unverified.
