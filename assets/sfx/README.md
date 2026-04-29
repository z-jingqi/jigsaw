# Sound effects

Replace each empty placeholder file below with a real `.mp3` (or `.wav` — update the extension in code if you change format). Free sources: Mixkit, Freesound, Pixabay Audio, Zapsplat.

## Required

### `snap.mp3`
**When it plays:** every time two pieces (or groups) successfully snap together.
**Length:** ~80–200 ms.
**Character:** a soft, satisfying wooden click / cardboard thump. Avoid anything sharp, metallic, or synthetic — it'll fire often, so it must not get annoying.
**Search terms:** "puzzle click", "wood click", "soft snap", "pop short".

### `complete.mp3`
**When it plays:** once, when the final piece merges and the puzzle is finished.
**Length:** ~1–2 s.
**Character:** a short, warm chime / bell / arpeggio that signals success without being triumphal. Think jigsaw-app gentle, not video-game victory fanfare.
**Search terms:** "success chime", "soft bell", "achievement gentle", "small win".

## Optional (nice-to-have, not wired up yet)

If you want to add these later, drop them in this folder and tell me; I'll hook them up.

- `pickup.mp3` — soft thunk on left-click pickup. ~60 ms. A muted tap or paper rustle.
- `rotate.mp3` — quiet whoosh on right-click rotate. ~120 ms. A subtle air-swish.
- `drop.mp3` — soft thud on release-without-snap. ~80 ms. Quieter than `snap.mp3` so the contrast tells the player "no match here".

## Notes

- Volume: aim for files that are pre-mixed at a comfortable -12 to -6 dB peak. The runtime will play them at full gain by default.
- Format: `.mp3` keeps file size tiny. `.wav` is fine for shorter sounds; `.ogg` works in browsers too if you prefer.
- Once any file here is non-empty, ping me and I'll wire the loader + trigger points (`runSnap` for `snap.mp3`, `checkComplete` for `complete.mp3`).
