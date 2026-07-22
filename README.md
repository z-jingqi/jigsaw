# Jigsaw

Jigsaw 是一个使用 Godot 4.6+ 开发的移动端竖屏轮廓拼图游戏。关卡由 `levels/catalog.json` 与各关卡目录中的 `level.json` 驱动，运行时读取 level-editor 预生成的碎片数据，不在游戏内临时切图。

## 当前功能

- 首页、主题分页、小关卡分页与模式选择。
- 多边形、经典凹凸和方格交换三种玩法。
- 拼图、吸附、旋转、提示、暂停、重新开始和通关流程。
- 设置、教程、相册、进度保存与解锁演出。
- 手机与平板竖屏布局，以及 Reduced Motion 动画降级。

## 项目结构

- `scenes/Main.tscn`：主场景。
- `scenes/ui/`：适合编辑器维护的稳定 UI 场景和固定时间轴。
- `scripts/app/`：应用生命周期与协调层；`Game.gd` 保持为 facade。
- `scripts/catalog/`：主题、关卡、模式选择与资源目录。
- `scripts/gameplay/`：游戏流程和棋盘模块；`PuzzleBoard.gd` 保持为 facade。
- `scripts/ui/`：可复用 UI 控件与外观组件。
- `scripts/tests/`：流程、状态、布局、动画与视觉验证脚本。
- `levels/`：运行时关卡目录与导出数据。
- `level-editor/`：独立的关卡制作工具。
- `tools/ai_dev.py`：统一的 Godot/Codex 开发、测试和证据收集入口。
- `addons/godot_ai/`：固定版本的可选编辑器桥接插件，只参与开发，不进入游戏逻辑。

稳定、可重复的 UI 结构和固定转场优先放在 `.tscn` 与 `AnimationPlayer` 中；手势跟手、拼图片移动、动态布局和程序化效果继续由脚本与 Tween 实现。

## 运行项目

使用 Godot 4.6 或更新版本打开仓库根目录，运行 `scenes/Main.tscn`。macOS 也可以执行：

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

## iOS

iOS 导出步骤和设备测试重点见 [IOS_BUILD.md](IOS_BUILD.md)。
