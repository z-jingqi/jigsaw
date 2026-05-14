# iOS Build Notes

This project is prepared as a Godot 4 mobile-first prototype for iPhone and iPad. The current game uses a landscape layout and supports touch input.

## Current iOS Controls

- Drag a piece with one finger.
- Double tap a piece to rotate it by 90 degrees.
- Move neighboring pieces near their correct relative position to snap them together.

## Recommended Project Settings

Set these in Godot before exporting the first iOS build:

- `Display > Window > Handheld > Orientation`: `Landscape`
- `Display > Window > Stretch > Mode`: `canvas_items`
- `Display > Window > Stretch > Aspect`: `expand`
- `Rendering > Renderer > Rendering Method`: `gl_compatibility`

The prototype already uses a 1280x800 landscape viewport. That works as a development baseline for both iPhone and iPad, but the final game should add stronger responsive layout rules before production.

## Export Requirements

To export an iOS build, the local machine needs:

- Godot 4.4 or newer.
- Godot iOS export templates installed.
- Xcode installed.
- An Apple Developer account.
- A valid bundle identifier, signing team, provisioning profile, and signing certificate.

## First Export Steps

1. Open the project root in Godot.
2. Open `Project > Install Export Templates` and install templates if missing.
3. Open `Project > Export`.
4. Add an `iOS` preset.
5. Set the bundle identifier, for example `com.yourstudio.jigsaw`.
6. Enable signing with your Apple team and provisioning profile.
7. Export the Xcode project.
8. Open the exported project in Xcode.
9. Build and run on an iPhone or iPad.

## Next iOS Work

- Replace prototype UI sizing with safe-area-aware layout.
- Add pinch zoom or camera panning if larger puzzles need more table space.
- Add a dedicated rotate control near the selected piece for thumb-friendly play.
- Save progress when the app is backgrounded.
- Test on one small iPhone, one large iPhone, and one iPad.
