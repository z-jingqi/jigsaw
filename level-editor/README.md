# JigCat Level Editor

新的关卡编辑器只负责管理关卡与编辑 polygon 模式。图片需要在外部处理完成后上传为 JPG 4:3。

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
- `knob` 默认自动配置为 `8x6`。
- `polygon` 默认目标块数为 `36`。
- `swap` 默认自动配置为 `7x5`。
