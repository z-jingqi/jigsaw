# JigCat Level Editor

新的关卡编辑器只负责管理关卡与编辑 polygon 模式。图片需要在外部处理完成后上传为 JPG 3:4。

## 启动

```bash
pnpm install
pnpm dev
```

- Web: `http://localhost:5173`
- API: `http://localhost:8787`

## 数据规则

- 关卡结构：主题 -> 分组 -> 关卡。
- 主题配置包含封面、主题色和 icon，封面支持 JPG / PNG / WebP，icon 支持 SVG / PNG。
- 分组配置包含颜色。
- 关卡配置包含列表封面，支持 JPG / PNG / WebP。
- 每个关卡只有一张 `source.jpg`。
- editor 只写入 `modes.polygon.pieces`。
- `knob` 默认自动配置为 `6x8`。
- `polygon` 默认目标块数为 `36`。
- `polygon` 只使用版本 4 的不规则混合边规则：在整张图片内完全随机撒点生成 Voronoi 分区，不使用行列或网格；再反复拆分超大块、把过小块与相邻块合并，直到所有碎片进入宽高范围；最后只将部分内部共享边成对曲线化（每块最多两条曲边）。宽度为图片宽度的 `0.10x`–`0.32x`，高度为 `0.085x`–`0.17x`，不再支持特殊形状配置。目标块数是初始随机种子数，修复后的实际块数可能变化，尺寸范围优先。
- `swap` 默认自动配置为 `5x7`。
