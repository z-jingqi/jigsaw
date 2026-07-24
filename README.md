# Jigsaw

Jigsaw 是一个使用 Godot 4.6+ 开发的移动端竖屏轮廓拼图游戏。关卡由 `levels/catalog.json` 与各关卡目录中的 `level.json` 驱动，运行时读取 level-editor 预生成的碎片数据，不在游戏内临时切图。

## 当前功能

- 主题首页轮播、主题总览、关卡列表和模式选择。
- 多边形、经典凹凸和方格交换三种玩法。
- 拼图、吸附、旋转、提示、托盘或行交换和通关流程。
- 设置、首次引导、分玩法教程、进度保存与解锁演出。
- 手机与平板竖屏布局，以及 Reduced Motion 动画降级。

## 项目结构

- `scenes/app/Game.tscn`：运行时组合根，包含导航、世界、页面、转场和弹窗 Host。
- `scenes/screens/`、`scenes/modals/`、`scenes/overlays/`：可编辑、独立的运行时页面与覆盖层。
- `scenes/ui/foundation/`：稳定的可复用 UI 组件和固定时间轴。
- `scripts/app/`：应用入口；`Game.gd` 仅保留 facade 职责。
- `scripts/runtime/`：应用状态、持久化、内容服务与 ViewModel/presenter。
- `scripts/navigation/`：路由注册、生命周期和单一活动转场。
- `scripts/screens/`、`scripts/modals/`、`scripts/onboarding/`：页面行为、弹窗和引导控制器。
- `scripts/gameplay/board/`：棋盘模块；`PuzzleBoard.gd` 保持为 facade。
- `scripts/ui/foundation/`：Safe Area、ThemeProgress、卡片和控件基础组件。
- `scripts/tests/`：真实流程、状态、布局、动画与视觉验证脚本。
- `test/unit/`：GdUnit4 单元测试。
- `levels/`：运行时关卡目录与导出数据。
- `level-editor/`：独立的关卡制作工具。
- `tools/ai_dev.py`：统一的 Godot/Codex 开发、测试和证据收集入口。
- `addons/godot_ai/`：固定版本的可选编辑器桥接插件，只参与开发，不进入游戏逻辑。

稳定、可重复的 UI 结构和固定转场优先放在 `.tscn` 与 `AnimationPlayer` 中；手势跟手、拼图片移动、动态布局和程序化效果继续由脚本与 Tween 实现。

## 运行项目

核心操作包括：

- 拖动碎片进行观察、整理和对齐。
- 按固定角度旋转碎片。
- 将正确相邻的碎片靠近后自动吸附。
- 已吸附的碎片作为一个整体继续移动和旋转。
- 当所有碎片合并为完整轮廓时完成关卡。

游戏的主要体验来自逐步揭示主体图像：零散碎片先组合成局部，再形成更大的可识别区域，最终还原成完整的自然轮廓。

正式关卡必须使用 level-editor 导出的预生成 JSON。游戏运行时不再生成碎片；如果某个模式缺少 `modes.<mode>.pieces`，该关卡会被视为配置不完整。

关卡 JSON 中的碎片坐标使用源图像素坐标。Godot 运行时会按实际移动端竖屏安全区域动态缩放，使完整图像能在不同手机和 iPad 视口内一次性完整显示，并保留周围操作间距。

页面通过语义信号向协调层通信，页面不直接读取存储或访问其他页面的内部节点。固定页面/弹窗时间轴由 `AnimationPlayer` 管理；手势、拼图、动态布局和程序化效果由控制器与 Tween 管理。项目只支持竖屏，设备旋转时不会切到横屏。

## 运行方式

使用与 `project.godot` 的 `config/features` 声明兼容的 Godot 版本（或更新版本）打开项目根目录，然后运行主场景。不要从本文档中的固定版本号推断项目要求；`project.godot` 是版本要求的唯一来源。

```text
scenes/app/Game.tscn
```

也可以在命令行验证项目能加载：

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path "$PWD"
```

项目只支持竖屏。macOS 出现 `Orientation not supported by this display server` 属于预期警告，不影响启动。

## 开发与验证

统一入口负责检查本地开发环境和打开启用 Godot AI 的编辑器，并把诊断结果写入 `.artifacts/ai-dev/<UTC-run-id>/`：

```bash
python3 tools/ai_dev.py doctor
python3 tools/ai_dev.py open
```

每条命令用退出码和 stdout 最后一行的 `JIGSAW_AI_RESULT` JSON 共同表示结果。仓库原有验证脚本仍按 `AGENTS.md` 中的正常窗口方式直接运行；AI 开发入口不会创建或改写测试。

Godot AI/MCP 是可选的编辑器观察与控制层。插件关闭时，项目启动和上述 CLI 测试仍应独立工作。完整配置、调试命令和 AI 内循环见 [AI 开发说明](docs/AI_DEVELOPMENT.md)。

提交前安装并运行质量检查：

```bash
uv sync --locked --group dev
uv run pre-commit install
uv run pre-commit run --all-files
GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot ./tools/run_gdunit4.sh -a ./test/unit
```

`pyproject.toml` 与 `uv.lock` 固定本地和 CI 使用的 Python 开发工具版本。GDScript 仅检查本项目的 `scripts/` 与 `test/`，不检查固定的第三方编辑器插件。`gdlintrc` 保留 Godot 的声明顺序，并对刻意暴露协调 API 的 facade/repository 关闭了两条不适用的数量型规则。

## iOS

iOS 导出步骤和设备测试重点见 [IOS_BUILD.md](IOS_BUILD.md)。
