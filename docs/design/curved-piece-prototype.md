# Opt-in curved cardboard preview

Default rendering remains unchanged. `JIGSAW_CURVED_EDGE_PREVIEW=1` enables all
pieces in polygon and knob modes only (never swap). The earlier single-piece
selector `JIGSAW_CURVED_EDGE_PIECE=piece_7` is also retained. These are development
launch switches, not saved settings; piece IDs can repeat between levels.

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

Old decorative bevel lines are hidden only on prototype pieces. Existing
settled-group handling removes the external side/contact shadow on snapped
pieces; their two adjoining curved faces remain visible as a narrow seam.
This is still a visual preview: no physical mobile GPU performance claim.

References:
- https://docs.godotengine.org/en/4.6/tutorials/shaders/shader_reference/canvas_item_shader.html
- https://docs.godotengine.org/en/4.6/tutorials/shaders/shader_reference/shader_functions.html
- https://developer.nvidia.com/gpugems/gpugems/part-i-natural-effects/chapter-1-effective-water-simulation-physical-models

Automated suites remain paused. Native evidence and precise assisted/manual
coverage are recorded outside the source tree for each review iteration.
