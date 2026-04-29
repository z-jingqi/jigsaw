# Project Specification

## 1. Game Overview

### 1.1 Concept

A jigsaw puzzle game built around **silhouette assembly**. Instead of cutting a rectangular photo into rectangular pieces, the game starts from a transparent-background subject (portrait, character art, object, etc.) and produces an irregular set of pieces whose outermost edges trace the original subject's silhouette. The completed puzzle preserves the subject's natural outline rather than forming a rectangle.

### 1.2 Core Gameplay

The player operates pieces on a canvas. Each piece carries a portion of the original image and an irregular boundary.

Basic operations:

- Hold left mouse button to drag a piece.
- Right mouse button rotates a piece 90 degrees per click.
- Move a piece near another piece's edge.
- When two edges match correctly (position + rotation), pieces auto-snap.
- Snapped pieces merge into a single group that can be dragged and rotated as one.

There is no manual confirmation step. As long as position, orientation, and edge relationship are correct, the system merges automatically. The player focuses on observation, trial, and progression.

### 1.3 Piece Shapes

The first version must support pieces generated from the subject's silhouette. The original image is not required to be rectangular.

Supported edge types:

- Outer edges following the subject's silhouette.
- Classic jigsaw knob-and-socket edges (concave/convex).
- Multi-segment arc or curve edges.
- Decorative shapes such as circles or curves in special cases.

The final result should feel like assembling a real subject, not a rectangle that happens to contain a subject.

### 1.4 Level Structure

Each level centers on one source image with a clear subject and transparent background.

A level contains:

- One transparent-background source image.
- A set of pieces generated from the subject silhouette.
- Initial scatter position for each piece.
- Initial rotation for each piece.
- The correct adjacency relationship between pieces.
- Completion condition: all pieces merged into the full subject.

Difficulty is controlled by piece count, shape complexity, initial rotation entropy, scatter radius, and subject detail.

### 1.5 Player Experience Goals

- Stable drag feel; piece movement is clear and controllable.
- Clear rotation feedback; each rotation is easy to understand.
- Timely snap feedback; the player feels the "click" of correctness.
- Merged groups remain a single operable unit to avoid repeated work.
- Clear completion feedback and final artwork presentation.

The fun comes from the gradual reveal of the subject. Pieces evolve from chaos into a complete silhouette, providing continuous small rewards and a final completion moment.

### 1.6 Controls per Platform

**Steam (desktop, mouse-first):**

- Left button drag.
- Right button rotate (90° steps).
- Free large canvas for organizing pieces.

**iOS (touch-first):**

- One-finger drag.
- Tap / double tap / on-screen button / gesture for rotation.
- Adapt to multiple screen sizes and safe areas.

---

## 2. Tech Stack

| Concern | Choice |
| --- | --- |
| Language | TypeScript |
| Build tool | Vite |
| Renderer | PixiJS (WebGL 2D) |
| Geometry libs | `paper.js`, `flatten-js`, `poly-decomp`, `martinez-polygon-clipping`, `marching-squares` |
| State | Plain TypeScript modules (no framework) |
| Desktop / Steam wrapper | Electron + `electron-builder` |
| iOS wrapper | Capacitor |
| Steam SDK (later) | `steamworks.js` |
| Slicing tool | Node.js CLI (TypeScript) |
| Package manager | pnpm |

No game engine (Unity / Godot / etc.) is used. The runtime is a pure web application; native shells are added only at the packaging stage.

---

## 3. Project Structure

```
/jigsaw
  /src                          Game runtime (browser)
    /core                       Engine-agnostic logic
      geometry.ts               Polygon math, snapping, adjacency
      level-loader.ts           Reads level + pieces JSON
      input.ts                  Pointer / mouse / touch abstraction
      snap.ts                   Edge matching and merging
      group.ts                  Merged-piece group management
    /render                     PixiJS rendering layer
      piece-view.ts
      tablecloth-view.ts
      stage.ts
    /ui                         HUD, menus, completion screen
    /dev                        Dev-only debug panel (stripped in prod)
    main.ts                     Entry point

  /tools
    slice.ts                    CLI: source.png + level.json -> pieces.json
    /algorithms
      contour.ts                Alpha threshold + marching squares
      sampling.ts               Voronoi / Poisson scatter
      knobs.ts                  Classic knob-and-socket edge generator
      adjacency.ts              Neighbor graph builder

  /levels
    /cats
      series.json
      /001-orange-tabby
        source.png
        level.json
        pieces.json
      /002-black-cat
        ...
    /paintings
      series.json
      /001-mona-lisa
        ...

  /assets
    /tablecloths                Shared background images
      wood-desk.jpg
      linen-beige.jpg
    /ui

  /platform
    /electron                   Desktop / Steam wrapper config
    /capacitor                  iOS wrapper config

  /schemas                      JSON Schema definitions
    series.schema.json
    level.schema.json
    pieces.schema.json

  package.json
  tsconfig.json
  vite.config.ts
```

Levels and assets are plain files. No database, no backend.

---

## 4. Data Schemas

### 4.1 `series.json`

```json
{
  "id": "cats",
  "title": "Cats",
  "description": "A collection of cat portraits.",
  "cover": "001-orange-tabby/source.png",
  "order": 1,
  "levels": [
    "001-orange-tabby",
    "002-black-cat"
  ]
}
```

### 4.2 `level.json` (hand-authored)

```json
{
  "id": "cats/001-orange-tabby",
  "title": "Napping Tabby",
  "source": "source.png",
  "tablecloth": {
    "type": "color",
    "value": "#2b2b2b"
  },
  "difficulty": {
    "pieceCount": 24,
    "shapeStyle": "classic-knob",
    "rotationEnabled": true,
    "scatterRadius": 600
  },
  "snap": {
    "positionTolerance": 12,
    "angleTolerance": 8
  }
}
```

`tablecloth` accepts either:

- `{ "type": "color", "value": "#hex" }`
- `{ "type": "image", "value": "wood-desk.jpg" }` (path relative to `/assets/tablecloths`)

`shapeStyle` values: `"classic-knob"`, `"curve"`, `"mixed"`.

### 4.3 `pieces.json` (generated, do not hand-edit)

```json
{
  "sourceHash": "sha1-of-source-png",
  "generatedAt": "2026-04-26T06:00:00Z",
  "bounds": { "width": 1024, "height": 1024 },
  "pieces": [
    {
      "id": "p0",
      "polygon": [[x0, y0], [x1, y1], "..."],
      "uv": [[u0, v0], [u1, v1], "..."],
      "centroid": [cx, cy],
      "neighbors": [
        { "pieceId": "p1", "edge": [[x, y], [x, y]] }
      ]
    }
  ]
}
```

The `polygon` is in source-image coordinates. `uv` maps each polygon vertex to a normalized texture coordinate on `source.png` for rendering.

---

## 5. Asset Pipeline

### 5.1 Slicing Tool

CLI command:

```bash
pnpm slice levels/cats/001-orange-tabby
```

Pipeline:

1. Read `level.json` for difficulty parameters.
2. Load `source.png`.
3. Extract subject silhouette from alpha channel via marching squares.
4. Sample interior points (Poisson disk or Voronoi seeds) based on `pieceCount`.
5. Build Voronoi cells, clip against silhouette polygon.
6. Replace shared straight edges with knob/curve edges according to `shapeStyle`.
7. Compute adjacency (shared edge segments per piece pair).
8. Compute UV coordinates by mapping polygon vertices to normalized image coordinates.
9. Write `pieces.json`.

The tool is deterministic: same `source.png` + same difficulty parameters = same output. A `seed` field may be added later for variation.

### 5.2 No Visual Level Editor in v1

Level authoring workflow:

1. Place `source.png` in a new `/levels/<series>/<id>` folder.
2. Write `level.json` by hand or via AI.
3. Run `pnpm slice <path>` to produce `pieces.json`.
4. Open the game in dev mode and tune parameters using the dev panel.

### 5.3 Dev Panel (in-game, dev build only)

Available only when running `pnpm dev`. Stripped from production builds.

Capabilities:

- Switch the currently loaded level (dropdown over `/levels`).
- Live-edit `difficulty` fields; "Re-slice" button invokes the slicing tool and reloads.
- Live-edit `tablecloth` (color picker / image dropdown).
- Live-edit `snap` tolerances.
- "Save to level.json" button writes current values back to disk.

This panel is the de-facto level editor for v1.

---

## 6. Build & Distribution

### 6.1 Web (development)

```bash
pnpm dev          # Vite dev server, hot reload
pnpm build        # Static build to /dist
pnpm preview      # Preview production build locally
```

### 6.2 Steam (Electron)

- Wrap `/dist` with Electron via `electron-builder`.
- Output: Windows and macOS installers.
- Steam Direct fee: USD 100 one-time per title.
- Steamworks features (achievements, cloud saves, overlay) integrated later via `steamworks.js`. Not required for v1.

### 6.3 iOS (Capacitor)

- Wrap `/dist` with Capacitor; output is a native Xcode project under `/platform/capacitor/ios`.
- Apple Developer Program: USD 99 / year.
- App Store Connect handles signing, screenshots, review submission.
- IAP (if added later) must use StoreKit.

### 6.4 WeChat Mini Game

Out of scope for v1. Reserved as a possible future target.

---

## 7. First Version Scope

In scope:

- Silhouette-based piece generation from transparent PNG.
- Irregular pieces with classic knob-and-socket edges.
- Drag, rotate (90° steps), snap, merge.
- One complete playable level end-to-end.
- Start screen, gameplay, completion feedback.
- Dev panel as level-tuning tool.
- Web build runnable in browser.

Out of scope:

- Visual level editor.
- Large level library.
- Story or progression systems.
- Multiplayer.
- Leaderboards, achievements, cloud saves.
- WeChat Mini Game build.
- Steam / iOS packaging (deferred until gameplay is validated).

---

## 8. Roadmap

### Phase 1 — Runtime Skeleton

- Vite + TypeScript + PixiJS scaffold.
- Load a `level.json` and a placeholder `pieces.json` (single rectangle treated as one "piece").
- Implement drag, rotate, snap, merge against placeholder data.
- Validate input feel before any algorithm work.

### Phase 2 — Slicing Tool

- Implement `tools/slice.ts`.
- Generate real `pieces.json` from a transparent PNG.
- Replace placeholder data; play through a real level.

### Phase 3 — Dev Panel

- In-game debug UI for switching levels and tuning parameters.
- Re-slice from inside the game.

### Phase 4 — Content & Polish

- Author 5–10 levels across at least two series.
- Tablecloth presets.
- Completion screen, transitions, audio.

### Phase 5 — Packaging

- Electron build for Steam.
- Capacitor build for iOS.
- Store assets (screenshots, descriptions, icons).

### Phase 6 — Submission

- Steam Direct registration and store page.
- Apple Developer enrollment and App Store Connect submission.

Steps 5 and 6 only begin after Phase 4 confirms the game is fun.
