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

核心操作包括：

- 拖动碎片进行观察、整理和对齐。
- 按固定角度旋转碎片。
- 将正确相邻的碎片靠近后自动吸附。
- 已吸附的碎片作为一个整体继续移动和旋转。
- 当所有碎片合并为完整轮廓时完成关卡。

游戏的主要体验来自逐步揭示主体图像：零散碎片先组合成局部，再形成更大的可识别区域，最终还原成完整的自然轮廓。

## 当前原型

当前版本已经实现一个可走通的完整 mock 流程，所有主题和关卡暂时复用同一张原图。已包含：

- 首页。
- 主题选择。
- 小关卡列表。
- 模式选择弹窗。
- 可游玩的拼图界面。
- 暂停弹窗和重新开始确认。
- 设置弹窗。
- 通关弹窗。
- 相册和相册大图查看。

当前玩法支持两种碎片模式：

- 经典凹凸：内部边生成传统拼图的凸起和凹口。
- 不规则：内部边生成波浪形的不规则切线。

操作方式：

- 单指拖动碎片。
- 双击碎片旋转 90 度。
- 将相邻碎片靠近正确相对位置后自动吸附。
- 吸附后的碎片组会作为整体继续移动和旋转。

## 逻辑结构

当前玩法逻辑已经从主场景脚本里拆出：

- `scripts/PieceGroup.gd`：管理一个可操作碎片组，以及吸附后的组合并。
- `scripts/SnapSolver.gd`：判断两个碎片组是否满足旋转和距离条件，可以自动吸附。
- `scripts/Game.gd`：负责输入、UI、节点创建和调用逻辑模块。

正式关卡必须使用 level-editor 导出的预生成 JSON。游戏运行时不再生成碎片；如果某个模式缺少 `modes.<mode>.pieces`，该关卡会被视为配置不完整。

关卡 JSON 中的碎片坐标使用源图像素坐标。Godot 运行时会按实际移动端竖屏安全区域动态缩放，使完整图像能在不同手机和 iPad 视口内一次性完整显示，并保留周围操作间距。

当前 UI 是最小可用实现，用 Godot 原生控件搭建，重点是验证完整游戏流程。项目只支持竖屏，设备旋转时不会切到横屏，不再优先适配桌面端。

## 运行方式

使用与 `project.godot` 的 `config/features` 声明兼容的 Godot 版本（或更新版本）打开项目根目录，然后运行主场景。不要从本文档中的固定版本号推断项目要求；`project.godot` 是版本要求的唯一来源。

```text
scenes/Main.tscn
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

## iOS

iOS 导出步骤和设备测试重点见 [IOS_BUILD.md](IOS_BUILD.md)。
