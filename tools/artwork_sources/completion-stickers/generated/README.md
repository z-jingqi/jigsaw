# 完成模式贴纸素材

2026-10-06，使用内置 ImageGen 生成。最终样式为完整平整的米白色裁切贴纸：哑光纸面、细微纸张厚度，没有撕起、翘角、折边或外部投影。

| 模式 | 当前生成源 | 运行素材 | 配色与形状 |
| --- | --- | --- | --- |
| 多边形 | `polygon.png` | `assets/ui/levels/mode-icons/polygon-complete.webp` | 上方一个暖金色六边形，下方两个鼠尾草绿六边形 |
| 凹凸 | `knob.png` | `assets/ui/levels/mode-icons/knob-complete.webp` | 陶土色拼图片，保留凸头与凹口 |
| 交换 | `swap.png` | `assets/ui/levels/mode-icons/swap-complete.webp` | 蓝绿与暖金色的两条弧线箭头 |

[生成与编辑提示](prompts.json) 保存实际使用的提示和文件位置。最初生成的翘边效果已在最终编辑提示中明确移除；这里的三个 PNG 是最终完整边缘版本。上一级 SVG 保留为旧轮廓参考，当前运行素材由这里的 PNG 处理得到。

Python 检查真实透明通道，清理轮廓之外的零散透明像素，裁切留白，使用 Lanczos 等比缩小至 240 像素以内并居中放入 256×256 透明画布，再以无损 WebP 编码。三个运行文件合计 162,192 字节。透明外围、抗锯齿边缘和编码后的像素一致性均已核对。

父目录 `tools/artwork_sources/.gdignore` 排除生成源和此说明，只有处理后的 WebP 进入运行资源与 APK。运行时继续使用 mipmap、固定模式位置和已有尺寸，不增加逐帧处理或阴影。
