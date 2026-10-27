# Curved cardboard rendering

Polygon and knob use this renderer on both board and tray. It is the only
production face style for these modes, not an optional preview. There are no
legacy style or per-piece environment switches. Swap remains its separate
flat-tile rendering because its mechanics differ.

The original Polygon2D coverage, texture coordinates, artwork, input geometry,
snap rules and gray backgrounds remain unchanged. Separate local-space slope
data derives normals from an inner distance height field:
`h=H*(2t-t*t)`, t=clamp(distance/width,0,1), H=.36*width.
The centre is flat and unchanged; the narrow band descends to the thin side.
Adjacent normals are smoothly weighted to avoid sharp medial creases. Diffuse
illumination is normalized to 1 on the flat face; there is no specular, artwork
blur/noise/edit, displacement, or new collision geometry. This is derived-normal
relief, not a new 3D silhouette or physically simulated paper.

## Bounded rendering work

`PieceCurveField` generates local signed RG16F slope fields once, with spatial
edge bins and a bounded 64-entry LRU. The full polygon and curve width form the
key; IDs/artwork are not used to alias geometry. Padding supports bilinear rim
sampling. Flat pixels store exact zero. The shader samples one extra texture,
not a fragment loop over high-point-count knob outlines. Dragging and tray/board
scale changes reuse the same field, with fixed screen-space light orientation.
The displayed face and hit silhouette still use the original polygon.

Old decorative bevel lines are hidden on curved pieces. Existing
settled-group handling removes the external side/contact shadow on snapped
pieces; their two adjoining curved faces remain visible as a narrow seam.
The approved visual path is now active by default; no physical mobile GPU
performance claim is made.

References:
- https://docs.godotengine.org/en/4.6/tutorials/shaders/shader_reference/canvas_item_shader.html
- https://docs.godotengine.org/en/4.6/tutorials/shaders/shader_reference/shader_functions.html
- https://developer.nvidia.com/gpugems/gpugems/part-i-natural-effects/chapter-1-effective-water-simulation-physical-models

Automated suites remain paused. Native evidence and precise assisted/manual
coverage are recorded outside the source tree for each review iteration.

## Responsive preparation and cache lifecycle

Cold field generation runs in at most two CPU WorkerThreadPool jobs. Every job
owns its input copy and Image; no worker touches the scene tree, GPU textures or
memory LRU. A row-boundary mutex-protected cancel flag is checked during baking.
The main thread polls completion, reaps each task, and publishes at most one small
texture per frame. Board generation tokens are checked before applying results;
returning immediately cancels the generation without clearing the outgoing
visible board mid-transition. Saves require the fully restored live board.

A versioned lossless disk cache stores bounded JSON metadata and signed RG16F
bytes with dimensions/bounds/key/length/checksum validation. Corrupt/torn entries
are misses; rebuild uses the same 192px calculation. Disk bounds:64 entries and
12MiB; memory LRU:64 textures (active materials may also retain textures). Current
catalog has at most30 pieces per mode; larger future catalogs need batch pinning
or segmented preparation before exceeding the64-field batch capacity.

The curved-rendering path enters a cancellable gameplay page immediately with concise
localized preparation feedback rather than holding an input-locked modal.
Only Back is available before the complete board is restored; puzzle actions
remain disabled. This path is now the default for polygon and knob.

Historical prototype desktop Compatibility cold run with empty disk+memory:30 knob fields,
0 disk hits,3.000s asynchronous batch wall time,5.562s summed worker time across
two lanes,0.235ms maximum main-thread texture publication,22.904ms maximum frame
interval while workers were active. This removes the earlier213ms per-piece
main-thread bake stall without lowering field quality. It does NOT claim zero
first-use waiting or universal60fps: whole-route first-load maximum133ms was
also present without curvature (control149ms), due to other existing entry work.
These are desktop observations, not a physical-phone benchmark.

Threading references:
- https://docs.godotengine.org/en/4.6/classes/class_workerthreadpool.html
- https://docs.godotengine.org/en/4.6/tutorials/performance/thread_safe_apis.html

Preparation frame waits are cancellation-aware: board-generation cancellation
synchronously wakes CPU-preparation, layout, navigation-idle and post-draw waits
before freeing their owners. This releases full-art references even if shutdown
stops the next frame; worker cancellation/reaping remains separate. The previous
pending-exit artwork/RID and suspended preparation coroutine leak is fixed in
the historical effect-on/off abrupt controls. A no-inspection-driver product run, pointer
Start then title-bar X, exited cleanly. The artificial two-frame abrupt harness
can still report Dummy Audio Ogg/WAV resources, distinguished from the now-fixed
artwork lifecycle; no logging suppression or added harness drain was used.

If a curve field fails preparation/publication, board construction aborts rather than silently displaying a legacy face.
