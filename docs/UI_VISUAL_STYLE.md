# JigCat UI visual style

## 统一尺寸规范（当前实现）

尺寸源为 `scripts/ui/foundation/UiMetrics.gd`，颜色、字体及按钮状态源为
`CleanTheme.gd`。页面不得各自定义同一角色的字号、按钮高度或缩放公式。
旧章节中的历史美术说明不覆盖这里的当前运行时规范。

- 基准画布为 390 × 844；逻辑单位使用宽高等比缩放的较小值。
- 系统安全区只加一次；顶部栏额外留白 12，左右内容边距 24。
- 间距使用 8 / 16 / 24 / 32；导航与分页触摸区 48，主按钮高 52。
- 页面标题 26，正文及主按钮 18，辅助说明与页数 14；标题先按字体测量缩小，最低为辅助文字 14 逻辑单位。首页、完成页和相册名称允许两行，主题卡片允许三行；可用空间仍不足时才省略并保留完整名称。
- 多列主题卡片名称从正文 18 开始适配；名称区域固定，禁止按文字最小宽度扩大卡片标题区域。
- 普通按钮圆角 12、横向内边距 16、焦点描边 2，均随逻辑单位缩放。导航图标基准笔画 1.5；所有返回箭头共用 `NavigationGlyph.gd`，不得另写绘制比例。
- Logo 为 144 × 48；菜单宽 224、行高 48，使用与页面相同的逻辑单位。
- 原生像素换算 `CleanTheme.canvas_scale` 仅用于输入阈值等需要设备像素的场景；
  不再用于分页和菜单的视觉尺寸，不新建页面专属比例。
- 首页、关卡列表、模式选择、游戏顶部栏、完成页、相册与作品详情、设置已接入共同角色。
  棋盘与托盘保留玩法几何缩放；纸盒保留透视布局，选项名称和状态使用共同文字规格。
- 相册主题选择为居中淡入淡出弹窗；只有首页的全部主题使用顶部落下、向上收起。

首页从上至下为顶部栏、固定主题名称、横向滚动图片、分页控件、数字页数、固定进入按钮。
标题只改变透明度，不移动位置；透明度由实际视觉分页进度计算，中点完全淡出并切换文案，
再渐显下一标题。拖动、回弹、连续切换和 Reduced Motion 共用图片的分页状态。
页数表示当前选择，进入按钮只在选中页稳定后可用；未开放主题显示“敬请期待”。
图片只负责分页，进入主题由固定按钮负责。

模式页优先选中第一个进行中的可用模式，否则选中第一个未完成的模式；全部完成时选中第一个已完成模式供重玩。关闭请求需在发出信号前完成本地关闭标记，取消关闭后必须重新启用交互。

纸盒印刷属于透视美术，不使用屏幕字号：在 80 到 56 的印刷字号范围内适配，必要时分为两行并让出图片空间，仍无法容纳才省略。纸盒标题样式版本参与缩略图缓存键。

## Shared screen palette

Home, level selection, and gameplay share the warm ivory background in
`assets/ui/home/library/page.webp`, ink-green text (`#194F47`), and pale sage
controls (`#DDE3CF`, pressed `#BCCDAF`). Album, settings, pause, and the home
gesture guide use the same palette. Gameplay uses this same background for
every theme. Foreground navigation controls are flat vector icons without
external shadows. `GameplayStyle.gd` owns the gameplay palette.

The completion page contains only the artwork name, the complete image, and
one Done action. Album pages use the same paper background and vector controls;
collected artworks open at their full aspect ratio. See `ALBUM_AND_ARTWORK.md`
for collection rules, content processing, and current validation.

## Existing clay assets

The approved `assets/ui/home/start-button-3d.webp` is the source of truth for
the handcrafted-clay color used by existing clay assets and progress marks.
Retain this palette when processing those assets; new gameplay navigation
controls use the shared screen palette above. Mode-status glyphs retain their
documented state colors.

- Primary surface midtone: `#D35929`
- Common surface range: `#CC5021` to `#D86A41`
- Deep intrinsic edge shade: approximately `#7B240C`
- Flat generation key background: `#1647FF`

Use `tools/recolor_clay_to_reference.py` after background removal to transfer
the approved button palette while retaining an icon's internal light and clay
texture. Do not recolor by eye.

## Mode icon states

Mode selection uses the shared flat SVGs under
`assets/ui/levels/mode-icons/`: three regular honeycomb cells, a classic interlocking piece,
and two opposing curved arrows. All three use ink-green strokes (`#194F47`);
puzzle shapes have a pale sage fill (`#DDE3CF`). Glyphs have no sticker edge,
material texture, or external shadow.

Identity, saved status, and selection remain separate:

- not started: a softer green glyph and muted-green status text;
- in progress: the normal glyph with amber status text;
- completed: the normal glyph on a pale-green card with green status text;
- selected: an ink-green card border, independent of saved status.

Mode glyphs share a lighter 3.5-unit stroke and centered 96-unit geometry.
Status uses one centered text row below the mode name, without a duplicate
clock or check. Glyph selection and entrance motion retain their existing
timing and Reduced Motion behavior. SVG import uses a 2x raster with mipmaps
for clear edges at phone sizes.

Completed-mode marks use the Python-processed transparent WebP glyphs in the
same folder. Three small slots stay fixed at the image's bottom-right, in a
vertical column: polygon, knob, swap. Only completed modes appear; empty slots
keep their position. The honeycomb has a gold upper cell and two sage lower
cells; the knob piece is terracotta; the curved swap arrows are blue and gold.
A thin ivory silhouette edge separates the glyph from detailed artwork. There
is no backing disc or external shadow. The 96px assets use lossless WebP with
verified alpha and linear mipmap filtering.

All level cards are playable. Unvisited cards retain the muted preview; every
theme's first card is always in full color. Opening mode selection reveals the
card and saves that visit, even if the player returns without starting a game.

## Sticker borders

Controls that need separation from a detailed background may use the same
cream-white sticker border as the Logo. The current sampled border color is
`#F3E5CE`. The border is a uniform silhouette expansion, not an inner outline,
second rim, glow, or shadow.

## Depth and shadows

Generated foreground assets must contain no cast, contact, ambient, or drop
shadow outside their silhouette. They may contain restrained highlights and
intrinsic edge shading inside the material. Gameplay buttons and tray surfaces
use no runtime drop shadows; puzzle pieces retain their existing intrinsic
side faces and bevels.

Do not generate concentric rims, doubled borders, or inset copies for mode
icons. Shared SVG glyphs use one clear contour and only the cuts or arrows
needed to identify each mode.

## First-release gameplay surfaces

Shared puzzle pieces use a thin lower-right side and restrained directional bevels; source artwork and cut geometry remain unchanged. Side faces reuse source triangulation to avoid unstable concave fills at different display scales. Drag positions follow input directly; lift decoration must not delay them. Reduced Motion grid shifts use a single 0.2-second opacity recovery without spatial movement.

The board uses a pale sage surface (`#DDE5D5`) with an ivory rim (`#FAF8EF`),
and the two-row tray uses `#E7EBDD`. Completion frames fit the original artwork
rather than cropping it. Mode selection includes visible names; the
reference-image entry and explanatory captions have been removed.


## Shared gameplay layout

Modal overlays inherit the underlying screen's background. All three modes use
a thin ivory board rim expanded outside the artwork bounds without clipping
the image. Camera bounds include this rim.

The header has Back on the left and Pause, Hint on the right. Hint is a bulb
outline and base, without rays. The centered title retains mirrored cloud
ornaments; long names use a second title row when needed to avoid the controls.
Header controls use 144 design units with 24-unit gaps.

The rounded tray has two rows, horizontal scrolling, and a position indicator.
Its clipped piece host preserves the existing screen-coordinate system, so
picking up a piece keeps its size and pointer position. Horizontal movement
past the tray's side edges continues scrolling; vertical movement locks the
scroll for lifting a piece. Board input ignores emulated counterparts of real
pointer events while leaving those events available to GUI controls.

Swap has four independent sage controls in left/up/down/right order, using the
same vector icon and press-feedback component as the header. Buttons use 156
design units with 40-unit gaps. Bottom panels have a 168-unit bottom inset.

Mode selection keeps its Continue button. Pressing it transitions directly
from the mode page to gameplay with the level list hidden throughout. Returning
from completion also goes directly to the level list without exposing gameplay.

Completion reuses the gameplay texture and its current canvas bounds. The clean
image dissolves over the assembled pieces for 0.2 seconds, then eases to a fit
at most 88 percent of the original width. The shared paper background and green
level title and Done button enter in the same 0.96-second AnimationPlayer
timeline. The completion screen contains only the level title, artwork, and
Done button. The entire artwork stays visible. Reduced Motion
uses the settled layout immediately.

## Shared navigation motion

Only All Themes uses a top sheet: drop down to open, retract upward to close.
Other full route pages, including mode selection, enter from the right
and leave to the right on Back. The navigation host owns these transitions;
page-local content animations must not add another route entrance or exit.
Reduced Motion settles the route immediately. Settings remains a popup with its
own open/close animation; native Back dismisses it without a horizontal drag.

Back starts only within the leftmost 24 logical design units (UiMetrics.BACK_EDGE).
The route follows the finger; release past 30 percent of screen width or a
qualified rightward fling commits, otherwise it returns to its starting position.
GestureArena reserves the pointer on press: edge gestures cannot page content,
and a paging drag cannot become Back when it reaches the edge. All Themes keeps
its sheet close control and does not claim horizontal edge Back.
