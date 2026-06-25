# Jigcat Web Prototype

This is a Phaser + React comparison prototype for the existing Godot version.

## Commands

```bash
pnpm --dir web-game install
pnpm --dir web-game dev --host 127.0.0.1
pnpm --dir web-game build
```

The local frontend runs at `http://127.0.0.1:5180/`.

The dev server serves the repository `levels/` and `assets/` folders directly.
The production build copies those folders into `web-game/dist`.

## Scope

- React renders the topic list, grouped level list, mode dialog, HUD, and completion dialog.
- Phaser renders and handles the puzzle playfield.
- `polygon` and `knob` use seed pieces plus a bottom tray.
- `swap` uses draggable tile swapping.
- Progress is stored in `localStorage` under `jigcat-web-progress-v1`.

This prototype intentionally reuses the current Godot v3 level data instead of
introducing a separate web-only format.
