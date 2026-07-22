# Godot + AI 开发说明

本项目以 Godot CLI、项目自己的测试和正常窗口视觉验证作为最终验收标准。Godot AI 只负责把 Codex 接到正在运行的编辑器，让 AI 能读取场景、属性、日志和运行画面，并缩短进入指定 UI 状态的路径。

## 一次性手动配置

仓库固定使用 Godot AI `v3.0.5`。来源、tag、commit 与压缩包 SHA-256 记录在 `addons/godot_ai/UPSTREAM.md`，不要从 Asset Library 或 `main` 覆盖它。

1. 安装 Godot 4.6+ 与 `uv`。
2. 执行 `python3 tools/ai_dev.py open`。该命令会设置 `GODOT_AI_DISABLE_TELEMETRY=true` 并打开正常编辑器。
3. 在 Godot AI 的 Clients & Tools 中确认端口为 `8000`，Allow remote hosts 留空，然后执行 Codex Configure。
4. 检查 Codex 用户配置包含：

```toml
[mcp_servers."godot-ai"]
url = "http://127.0.0.1:8000/mcp"
enabled = true
```

5. 重启 Codex，保持这个 jigsaw 项目的 Godot 编辑器窗口打开，再执行 `python3 tools/ai_dev.py doctor`。

`doctor` 会检查 Godot、`uv`、插件版本与启用状态、回环地址、端口、MCP 会话和 Codex 配置。它不会下载依赖，也不会终止占用端口的进程；失败结果中的 `actions` 会给出需要人工处理的步骤。

## 统一命令

```bash
python3 tools/ai_dev.py doctor
python3 tools/ai_dev.py open
```

所有命令使用明确退出码，stdout 最后一行为：

```text
JIGSAW_AI_RESULT {"ok":true,...}
```

每次诊断或启动操作生成：

```text
.artifacts/ai-dev/<UTC-run-id>/
  manifest.json
  logs/editor.json
  logs/game.json
```

`manifest.json` 记录 Godot 和插件版本、耗时、退出码、错误与 artifact 路径。该入口不创建新测试，也不写入视觉基准；需要验证时直接运行 `AGENTS.md` 中列出的既有 Godot 脚本。

## 确定性调试接口

`Game.gd` 只转发下面两个 debug-only 方法，具体命令由 `GameDebugAdapter` 实现：

```gdscript
debug_execute(command: String, args: Dictionary = {}) -> Dictionary
debug_state_snapshot() -> Dictionary
```

支持的命令：

- `state`
- `show_topics`
- `show_levels(topic_id)`
- `show_mode_select(topic_id, level_id)`
- `show_settings`
- `show_tutorial`
- `enter_level(topic_id, level_id, mode)`
- `preview_complete`
- `close_modal`
- `set_viewport(width, height)`
- `set_reduced_motion(enabled)`

成功响应包含 `ok`、`command` 和 `state`。状态至少包含 screen、modal、topic/level/mode、实际窗口 `viewport`、拉伸后的 `content_viewport`、Reduced Motion 与活动动画数量。失败使用 `debug_only`、`unknown_command`、`invalid_argument`、`not_found` 或 `wrong_screen`。release export 不执行这些操作并返回 `debug_only`。

## AI 修改与验证顺序

1. 读取编辑器状态，按绝对项目路径选中 jigsaw 会话。
2. 先读相关场景树、节点属性和现有脚本，再修改。
3. 每次写脚本都检查结构化 diagnostics；有错误立即停止后续编辑。
4. 启动游戏并确认插件报告的运行状态为 `live`。
5. 用 `debug_execute()` 进入目标 screen/modal/level，避免依赖脆弱的坐标点击链。
6. 同时核对状态快照、编辑器/游戏日志和截图。
7. 运行最小相关既有验证脚本；交付前再运行现有基线集合。

截图用于说明“看起来怎样”，状态和断言用于证明“处于什么状态、行为是否正确”。两者不能互相替代。插件或 MCP 不可用时，直接走 CLI 测试路径，不修改游戏代码来适配插件。

## UI 与动画边界

- `.tscn` + `AnimationPlayer`：稳定节点结构、弹窗开关、固定页面入场、固定通关演出。
- Tween/脚本：手势跟手、分页拖动、拼图片、镜头适配、动态布局、提示和程序化粒子。
- `Game.gd`、`PuzzleBoard.gd` 只协调，不承载新增 UI、动画或玩法实现。
- Reduced Motion 直接到达正确终态；中断、反向和快速重复操作必须从当前属性继续，不得闪跳或遗留节点。
