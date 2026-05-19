# Jigcat Level Editor

`level-editor` 是一个 pnpm workspace + Turbo monorepo，用来编辑关卡并通过本地 API 直接保存到 Godot 项目的 `levels/` 文件夹。

## 结构

```text
level-editor/
  apps/
    web/   React + Vite 编辑器
    api/   Hono + TypeScript 本地保存服务
```

## 启动

```bash
cd level-editor
pnpm install
pnpm dev
```

`pnpm dev` 会通过 Turbo 同时启动：

- Web: `http://127.0.0.1:5173`
- API: `http://127.0.0.1:5174`

也可以单独启动：

```bash
pnpm dev:web
pnpm dev:api
```

## Google Drive

如果只给自己使用，可以在 `apps/web/.env.local` 配置 Google Picker：

```bash
VITE_GOOGLE_CLIENT_ID=你的 OAuth Client ID
VITE_GOOGLE_API_KEY=你的 API Key
```

需要在 Google Cloud Console 启用 Google Picker API 和 Google Drive API，并把本地地址加入 OAuth Web Client 的授权来源，例如：

```text
http://127.0.0.1:5173
```

## 保存关卡

当前流程是：

- `图片处理`：导入本地图片或 Google Drive 图片，处理并确认。
- `编辑`：选择已处理图片，编辑多边形或凹凸模式。
- `关卡`：管理主题、关卡、排序和文本信息。

编辑页保存时会选择目标主题、关卡和模式，然后调用 Hono API，把当前模式图片和碎片数据写入 `../levels/<topic>/<level>/level.json`。

导出的碎片坐标始终是源图像素坐标，不绑定编辑器或桌面分辨率。Godot 运行时读取 `runtime_layout`，按实际移动端竖屏安全区域把完整源图等比缩放到可操作区域内。

API endpoint:

```text
POST /api/editor/save-mode
```

请求体：

```json
{
  "level": {
    "id": "cat_moon_01"
  }
}
```

## 构建

```bash
pnpm build
```

该命令会运行 Turbo，并分别构建 `apps/web` 和 `apps/api`。
