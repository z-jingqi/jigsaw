# 按钮与交换模式验证

2026-09-07，Godot 4.6.2，普通窗口在 Mac 内置屏 0，650 × 1414。

## 修复和行为

- 棋盘此前吞掉按钮区域的松手事件，导致 GUI 收不到完整点击。现仅消费棋盘自身已捕获指针的释放；未捕获的释放交给 GUI。
- 两行托盘使用绝对层级后，提示碎片的旧层级低于托盘底板。现使用高于普通托盘碎片的绝对层级。
- 交换提示按格子行优先顺序选择首个错误格，标出应在此格的正确块及当前占用块；跳过正确前缀，不受碎片数组和置顶顺序影响。只提示，不自动交换。
- 新增整盘左右循环移动一列，边缘绕回另一侧。行列平移共用 SwapGridShift；底部按钮为左、上、下、右，沿用箭头资源旋转，命中区域不旋转。

## 已检查路径

以下使用 viewport.push_input 注入真实鼠标按下／松手，经过 Game 输入路由和 GUI 分发，不直接 emit 按钮 pressed 信号。

- 九尾狐 polygon、knob、swap：点击提示后 hint_count 增加且可见高亮存在；从关卡页进入再点返回，回到关卡页。
- swap 左／右／上／下：普通动画和 Reduced Motion 各检查一次；所有 35 块槽位符合循环位移公式，动画结束后位置与槽位一致，无残留 is_animating。相反方向连用恢复排列。
- 单独排列前三个错误格并反转碎片数组：提示先选择第一个错误格，修正后跳到下一个错误格；检查返回 true。
- 首页设置入口、设置关闭、音乐／音效／震动／Reduced Motion 四个开关：点击生效，随后还原测试前值。
- 首页开始、关卡页返回、九尾狐关卡卡片、三个模式选项、开始游戏、完成预览返回：点击生效，目标状态符合预期。
- 查看四向按钮截图，按钮在窗口内，命中区域互不重叠。截图：本机 `.artifacts/v1-experience-polish/swap-four-directions.png`。

最终本次运行日志没有脚本错误，只有已知 macOS Orientation not supported 警告。Godot 静态导入及提交格式／lint 检查通过，OpenSpec 严格校验通过。

## 边界

测试套件仍按 AGENTS.md 暂停，未运行，未新增测试或更改视觉基线。未将鼠标事件检查当作真机触控验收；未穷举所有主题、教程页、锁定内容和异常弹窗。完成按钮通过已有完成预览进入验证，没有用预览冒充完整通关。早期临时诊断因超过桥接 8 秒限制及错误节点名称失败，已修正诊断并在新运行中重新验证；这些失败不是上述最终通过证据。

结果文件在本机忽略目录 `.artifacts/v1-experience-polish/`：`button-review-polygon.json`、`button-review-knob.json`、`button-review-swap.json`、`navigation-button-review.json`、`mode-button-review.json`、`buttons-final-logs.json`。
