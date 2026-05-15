# Jigcat Level Editor

`level-editor` 是一个 pnpm workspace + Turbo monorepo，用来编辑关卡并通过本地 API 直接保存到 Godot 项目的 `levels/` 目录。

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

## 保存关卡

编辑器右侧导出区域包含：

- `生成 JSON`：生成当前 JSON 文本。
- `下载 JSON`：下载 JSON 文件。
- `保存到 Godot`：调用 Hono API，把关卡写入 `../levels/<level.id>.json`。

API endpoint:

```text
POST /api/levels
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
