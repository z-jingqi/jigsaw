# Jigsaw Level Editor

独立于 Godot 主逻辑的关卡编辑器。

## 启动

```powershell
cd D:\jigsaw\level-editor
pnpm install
pnpm dev
```

Vite 默认从 `http://127.0.0.1:5173` 开始，如果端口被占用会自动切到下一个端口。

## 功能

- TypeScript + React + Tailwind
- 上传透明背景原图预览
- 自动检测图片外轮廓
- 使用 Voronoi/Delaunay 生成非网格碎片切割线
- 拖拽切割线或控制点微调
- 端点吸附到图片外轮廓和已有分割线
- 添加经典凹凸、圆形、五角星、圆润块、折线、月牙预设
- 导出 `jigsaw.level.v1` JSON

当前 JSON 会保存 `editor.outline`、`editor.cuts`、`editor.shapes` 和 `editor.pieces`。Godot 已经能读取同一份关卡 JSON 的图片、背景、标题和介绍；下一步可以把这些编辑器切割数据接入 Godot 的正式碎片生成。
