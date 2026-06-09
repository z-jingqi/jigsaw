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
- 每个关卡只有一张 `source.jpg`。
- editor 只写入 `modes.polygon.pieces`。
- `knob` 默认自动配置为 `6x8`。
- `swap` 默认自动配置为 `3x4`。
