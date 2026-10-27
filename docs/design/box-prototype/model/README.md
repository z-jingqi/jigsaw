# Upright tuck-top paper carton — model checkpoint, not runtime integration

Built locally with Blender 4.3.2. No model/texture download. Reproduce:

```sh
blender -b --python docs/design/box-prototype/model/build_tuck_carton.py -- \
  --repo "$PWD" --qa /path/outside/repository
```

## Geometry / coordinates
GLB is exported in its **closed pose**, Godot Y-up, front facing +Z. Body width 2.25, height 3.0, nominal depth .48. Bottom Y=0, top Y=3. Thin-board/cut/hinge allowances extend a few hundredths outside these nominal dimensions. FrontArtwork is fixed 2.25×3.0 = exact 3:4, a separate mesh with exact UV [0,1] × [0,1] and independently replaceable material. Its local position is baked into the mesh; never animate/reparent this front surface with the lid.

The shell consists of individually extruded polygon panels, .018 thick, small .003 cut-edge bevels and weighted normals. It is not a solid cube with a rotating front. The top panel is .48 deep (not 3.0 tall). Rounded tuck tongue, tapered side dust ears, restrained hinge scores, and rear manufacture/glue overlap are actual meshes. Front/rear/side outer faces use white; their inner faces use kraft, with separate brown cut-edge faces. Materials are not a single double-sided color.

## Node/axis contract after Godot glTF import
All hinge nodes have identity local rotation in the closed GLB. Positions below use Godot XYZ:

| Node | Parent | Local hinge position | Closed rotation_degrees | Example open rotation_degrees |
|---|---|---|---|---|
| FrontArtwork | TuckCarton | (0,0,0), vertices contain full face position | (0,0,0) | **unchanged** |
| TopFlapPivot | TuckCarton | (0,3.016,-.24), rear upper edge | (0,0,0) | (-105,0,0) |
| TuckTab | TopFlapPivot | (0,0,.460), front edge of top flap | (0,0,0) | (-82,0,0) |
| SideEarLeft | TuckCarton | (-1.116,2.992,0), left top edge | (0,0,0) | (0,0,64) |
| SideEarRight | TuckCarton | (1.116,2.992,0), right top edge | (0,0,0) | (0,0,-64) |

Suggested opening choreography: first release/extract the tuck tongue with the top lid beginning to lift, then unfold the tongue and open ears after the main top panel clears them. Reverse this sequence when closing. Do not drive all hinges at their final angles instantaneously during production interpolation without checking clearance. Example open pose is the structural inspection pose, not an animation clip or final list camera. This checkpoint does not yet claim collision-free runtime choreography.

## Material/source notes
Exterior is matte white. Inner faces/back of lid/cut edges are deep golden-brown kraft. Blender Noise → Bump nodes provide restrained procedural paper-fiber texture in inspection renders. No generated/painted bitmap, texture download or baking. These Blender procedural nodes are not portable through glTF; GLB intentionally exports plain base materials for Godot to replace with its own procedural paper shader. Material slots remain separate. Editable closed `.blend` source excludes QA cameras/lights. `.gdignore` keeps authoring files out of Godot runtime imports.

## Inspection outputs (outside repo)
- `01-carton-closed-front.png`: orthographic exact front, no top-down viewpoint; blank white FrontArtwork intentionally shows only structural greybox/proportion, not selected game art.
- `02-carton-open-structure.png`: open 3/4 structural/material inspection; not the final gameplay/list camera.

These are **Blender renders**, not Godot runtime screenshots. No runtime code/routes/assets have been switched to this model by this checkpoint. Automated game suites remain paused and were not run.
