# Single-piece down-curved cardboard prototype

Opt-in only: launch with `JIGSAW_CURVED_EDGE_PIECE=piece_7` to shade that ID in
polygon mode. With no environment variable the existing rendering is unchanged.
This is a prototype selector (IDs may repeat between levels), not a saved setting.
Initial visual inspection uses topic_01/shanhai_v2_01, piece_7.

The original Polygon2D coverage, texture coordinates, artwork, input geometry,
snap rules and background remain unchanged. A separate material derives normals
from an inner distance height field: `h=H*(2t-t*t)`, t=clamp(distance/width,0,1).
The centre is flat and unchanged; the narrow band descends to the existing thin
side. Adjacent normals are smoothly weighted to avoid sharp medial creases.
Diffuse illumination is normalized to 1 on the flat face; there is no specular,
noise, blur, texture edit or displacement. Old decorative bevel lines are hidden
only on the selected prototype piece. This is derived-normal relief, not a new
3D silhouette or physically simulated paper.

No CPU work/mesh/texture upload per drag frame. The prototype shader traverses
up to 64 outline edges twice per pixel, including exponentials. This is explicitly
NOT approved for every piece or mode without profiling/normal-field caching.
No physical mobile GPU benchmark or deeply concave knob geometry validation.

References consulted for implementation:
- https://docs.godotengine.org/en/4.6/tutorials/shaders/shader_reference/canvas_item_shader.html
- https://docs.godotengine.org/en/4.6/tutorials/shaders/shader_reference/shader_functions.html
- https://developer.nvidia.com/gpugems/gpugems/part-i-natural-effects/chapter-1-effective-water-simulation-physical-models

Native QA: 430x900 / 320x568 Compatibility window, same-piece shader-off/on
comparison with shadow disabled, enlarged live-node close-up, injected native
touch pickup/drop. Normal artwork remains crisp. Automated suites remain paused.
