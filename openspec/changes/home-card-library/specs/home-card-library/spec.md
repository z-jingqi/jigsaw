## Purpose
提供统一清新的主题浏览入口，让玩家通过叠卡和完整主题目录选择内容，同时可明确识别仅有封面的未来主题，并在导航与撤回时获得连续且可理解的卡片运动反馈。
## ADDED Requirements
### Requirement: Stack browsing
首页 SHALL 展示叠卡、主题名称、纯文字开始按钮、主题目录和设置按钮，不展示 logo 或分页圆点。
#### Scenario: Swipe and undo
- **WHEN** 玩家向左或右完成一次拖动并随后撤回
- **THEN** 两个方向均显示下一主题，撤回恢复上一个主题并支持连续操作，最后主题之后循环。
### Requirement: Theme library
目录 SHALL 展示可滚动双列封面和名称，标题与右上角关闭按钮同排，不显示当前标记。关闭时目录下落并露出首页。选择可玩主题后 SHALL 直接进入对应关卡列表；从关卡列表返回时 SHALL 显示首页且选中该主题。
#### Scenario: Cover-only theme
- **WHEN** 目录展示花间集、海之境、飞羽或林间且该主题没有关卡
- **THEN** 目录展示正式封面和敬请期待，封面入口禁用，不允许进入空关卡页；首页仍可浏览这些封面。
### Requirement: Card navigation
页面 SHALL 先轻微上提再向下加速离场，关闭目录时恢复首页，滚动目录不触发导航。
#### Scenario: Interrupted or reduced motion
- **WHEN** 动画被结束、取消或启用减少动态效果
- **THEN** 页面恢复正确可交互状态，不残留变换或输入锁；减少动态效果采用短淡变。
