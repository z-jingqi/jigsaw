## Purpose
提供统一清新的主题浏览入口，让玩家通过叠卡和完整主题目录选择内容，同时可明确识别仅有封面的未来主题，并在导航与撤回时获得连续且可理解的卡片运动反馈。
## ADDED Requirements
### Requirement: Stack browsing
首页 SHALL 展示叠卡、主题名称、纯文字开始按钮、主题目录和设置按钮，不展示 logo 或分页圆点。
#### Scenario: Swipe and undo
- **WHEN** 玩家向左或右完成一次拖动并随后撤回
- **THEN** 两个方向均显示下一主题，撤回恢复上一个主题并支持连续操作，最后主题之后循环。
### Requirement: Theme library
目录 SHALL 展示可滚动双列封面和名称，不显示名称副文案或当前标记。目录标题 SHALL 以屏幕中心轴水平居中，关闭按钮保持同排右上角。关闭时目录下落并露出首页。选择可玩主题后 SHALL 直接进入对应关卡列表；从关卡列表返回时 SHALL 显示首页且选中该主题。
#### Scenario: Cover-only theme
- **WHEN** 目录展示花间集、海之境、飞羽或林间且该主题没有关卡
- **THEN** 目录展示正式封面与主题名，封面入口禁用且 tooltip 显示敬请期待，不允许进入空关卡页；首页仍可浏览这些封面并通过禁用的敬请期待按钮表达状态。
### Requirement: Adaptive decorated title
首页 SHALL 只显示主题名称，并在名称两侧复用同一祥云素材，右侧旋转 180°。标题 SHALL 按真实字体整形结果在一行或最多两行内动态选择字号，窗口变化与主题切换时重新排版。
#### Scenario: Long English theme name
- **WHEN** 主题名称为 `the classic mountains and seas` 或同等长度文本
- **THEN** 完整名称保持在标题边界内且不与祥云重叠，祥云与最终文字块整体垂直居中，不因旧标题的最小尺寸缓存撑开边界。
### Requirement: Natural library scrolling
主题目录 SHALL 使用统一滚动控制器，拖动时内容直接跟随，松手后按近期有效速度减速，在边界使用阻尼与回弹，并在形成滚动后抑制卡片点击。桌面触控板事件 SHALL 避免叠加第二套惯性。
#### Scenario: Gesture ownership and interruption
- **WHEN** 玩家滚动目录、到达边界、再次按下或导航锁定输入
- **THEN** 内容保持连续且停在有效边界，再次按下立即接管并清除旧速度，滚动手势不误选主题，导航锁定期间偏移不变化。
### Requirement: Card navigation
页面 SHALL 先轻微上提再向下加速离场，关闭目录时恢复首页，滚动目录不触发导航。
#### Scenario: Interrupted or reduced motion
- **WHEN** 动画被结束、取消或启用减少动态效果
- **THEN** 页面恢复正确可交互状态，不残留变换或输入锁；减少动态效果采用短淡变。
