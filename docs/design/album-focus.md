# Unlocked single-artwork album

## Product flow

- A picture is discovered when its theme is first entered (that theme’s first picture only), or its playable level is clicked. Discovery uses existing visited_levels and is independent of mode completion; canceling the box does not undo it. Existing completed_modes also remain visible for legacy compatibility. No synthetic first-picture unlock is assigned to unvisited themes, and the progress schema is unchanged.
- With no unlocked artworks, Home omits the Album menu item entirely. There is no empty-album page or Play CTA. Availability follows discovery, and updates on progress changes and each menu opening; direct album entries reject unavailable data. If progress becomes empty while browsing, invalid album history is discarded atomically back to the nearest valid page.
- The album opens directly on one artwork. The theme menu contains only nonempty unlocked themes; there is no aggregate all-artworks collection.
- The focus page keeps a per-theme selected index in its coordinator. The thumbnail strip scrolls independently, and tapping a thumbnail selects that artwork. Returning from pure viewing preserves the latest selection.
- The theme chooser is a reversible top sheet with Close/Escape/outside dismissal. A dismissal tap cannot activate the picture underneath.
- At fit scale the pure viewer pages horizontally. A two-finger gesture initiated before horizontal direction ownership can pinch; zoomed dragging pans. Once horizontal paging owns the gesture, later fingers are ignored. A third finger cannot operate controls. Edge Back has priority.

## Image lifetime

AlbumPresenter returns metadata and resource paths, not loaded originals. AlbumImageCache is a navigator child and survives page navigation:

- two threaded ResourceLoader requests maximum;
- replaceable owner/slot requests, priority for current artwork, and generation checks in consumers;
- full cache at most three entries / 24 MiB estimated uncompressed RGBA with mip allowance;
- thumbnail cache at most sixteen entries / 12 MiB;
- three full-image display slots and seven thumbnail slots, independent of collection length;
- current/neighbor thumbnail fallback while the full original loads;
- old in-flight IO cannot be forcibly canceled by ResourceLoader; unwanted results are collected and discarded, not published;
- ordinary route exit unregisters requests without waiting; only whole-product teardown joins the at-most-two outstanding engine jobs to release their bookkeeping resources.

Cache bounds are not the entire process memory footprint. Retained focus and pure-viewer controls can each hold three original textures for interactive Back. Their references overlap the cache where possible. Debug snapshots report live display bytes separately. The eight theme subjects are small independent resources, never full artwork previews.

## Verification (2026-10-27)

Normal, non-headless desktop windows at 430x900 and 320x568. External QA harnesses live outside the repository; the paused repository suites and baselines were not run or modified.

- 45 input checks: holds, release cancellation/commit, reversal/re-grab, vertical rejection, secondary/third touch isolation, pinch/pan, pure-viewer return and chooser dismissal.
- 24 additional checks: previously uncached theme, reduced motion during hold/settle, edge Back during settling, 100-item temporary metadata list with bounded live nodes/cache and forward/back filmstrip traversal.
- 54 data/cache checks: empty, visited-only, each completed mode, nonempty themes, metadata-only paths, 160 coalesced intents, late-result discard and cache ceilings.
- Whole-process pending exit with two active image requests was tested. Explicit teardown collection removed the prior two zero-reference engine-task leftovers; observed join time was 47 microseconds in this desktop run, not a platform-wide latency guarantee.
- Initial data harness immediate DummyAudio shutdown retained the pre-existing Ogg music resources. An isolated audio-disabled image-only run exited cleanly, as did the final normal visual/input runs. This task does not claim an audio-engine fix.

Input gestures were injected native Godot InputEvents in a real rendered window, not physical iPhone testing. Unlocks used isolated completion fixtures, not claims of natural puzzle solving. Cold timings mean empty application image cache; OS filesystem caches were not flushed. An initial empty-array type error and missing initial viewer identity were fixed and the original failed evidence retained externally.

### Discovery rule correction

The later user clarification supersedes completion-only unlocking: entering a theme discovers its first picture, and clicking any playable level discovers that picture immediately, even if its box is canceled. Mode completion stamps remain independent. Existing visited records and historical completions are honored; unvisited themes do not receive synthetic first-picture migration.

The corrected flow was checked in normal 430x900/320x568 windows with isolated saves: fresh menu omission, first-theme isolation, a real injected pointer click on an unlit second card, cancel without losing discovery, two album pictures without completion, another theme, disk reload, legacy completion-only records for all three modes, zero-data invalidation during edge/entry, and application reconstruction. External fixtures were used only to construct legacy/reset states; this is not natural puzzle completion. Earlier completion-only QA results above describe the preceding version, not the current availability rule.
