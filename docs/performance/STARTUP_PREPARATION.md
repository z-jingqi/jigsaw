# Startup preparation — official Godot 4.6.3

The user approved an explicit preparation phase before Home becomes interactive.
This moves unavoidable first-render compilation into a visible preparation phase;
it does not eliminate that cost or guarantee immediate cancellation inside a driver call.

## Implementation

- Warm-white brand screen with localized preparing, failure and retry states; no fake percentage.
- Render actual box material families, closed/revealed and unrevealed artwork, polygon/knob/swap samples, and real 2D curved pieces, lift shadow, snap preview and original success flash behind an opaque cover.
- Render bounded material families sequentially rather than all variants in one frame.
- Reuse the prepared bounded ContentRepository, avoiding duplicate initial artwork decode.
- Home is revealed only after its first rendered frame. Held and focus-orphaned input chains cannot turn into Home taps.
- Cancellation invalidates asynchronous work and releases temporary views. A 45-second watchdog exposes failure/retry instead of indefinite waiting. Escape/system Back and window close can cancel; a blocking driver call can delay handling.
- Same official engine, 192-resolution curve field, artwork, UV and original flash. No experimental GL engine or audio fork is required.

## Measurements (desktop Compatibility / llvmpipe)

Fresh driver and application caches, 430×900 normal windows. Samples are observations, not a device-wide latency guarantee.

| Measurement | Cold polygon | Cold knob |
|---|---:|---:|
| Internal Game loading → runtime creation | 4694 ms | 4426 ms |
| Largest preparation frame | 573.871 ms | 549.644 ms |
| Largest subsequent picker/Start frame | 58.764 ms | 53.128 ms |
| First actual legal drop, including preview/flash, largest frame | 12.193 ms | 17.480 ms |

A separate external monotonic process-launch measurement includes engine startup,
Game loading, preparation, Home's first draw and cover removal: **5855.94 ms cold**,
**2499.57 ms hot**. An immediate real viewport-input More tap opened the menu at
**5870.50 ms cold / 2516.91 ms hot**. These are stdout-observed upper bounds;
the earlier internal measurements must not be described as total startup time.

Hot restart internal runtime creation was 1760 ms. Hot processes still submit the
finite real draws to validate their context; they benefit from driver/disk caches,
not a persistent flag that skips necessary preparation.

## Validation and limits

- Both first drops used genuine input events and read-only geometry planning, not forced success.
- Fifteen boundary checks cover failure/retry, held input across readiness and focus loss/orphaned release. Chinese/English include retry/input checks; Japanese covers preparation/failure layout. 430/320 layouts were inspected.
- Cancellation at the first frame, during box preparation and real watchdog timeout exited without pending artwork resources. Scheduled cancel/timeout handling was delayed approximately 408/422 ms during compilation: not instant responsiveness.
- Official Linux release export and normal-window navigation were checked separately at its default 1180×812 window (CLI dimensions were ignored); 430/320 evidence uses official editor normal windows. No signing or store upload.
- Automated suites remain paused by AGENTS; they were not run. Native phones, real screen readers and all possible driver variants remain untested.
- Official-engine audio shutdown resource retention, including the observed release title-bar close, is a separate unresolved adoption decision. An isolated audio backport has evidence, but is not silently made a production dependency here.
