# Sticker Talk Edit · 贴纸讲解剪辑

让口播里的重点随着声音出现：人物加上白色描边，关键词变成贴纸，观点逐项展开，图片和视频在讲到的时候进入画面。

这是一个面向 Codex 等支持 `SKILL.md` 的助手环境的可复用剪辑 Skill。提供口播原片和配套素材，它会根据内容安排留白、文字、章节和素材展示；有几点就讲几点，不预设四个观点或总分总。

## 灵感与致谢

这个项目受 **[Zara Zhang（@zarazhangrui）](https://x.com/zarazhangrui)** 在 X 分享的 **[这条关于 taste 的口播视频](https://x.com/zarazhangrui/status/2116281211962454056)** 启发。视频里，白描边人物、随讲解出现的文字贴纸、逐项展开的观点和案例素材，让信息的层次清楚又轻快。感谢 Zara 分享这个作品，带来关于“怎样把口播讲得更清楚”的启发。

Ryan 在剪映中逐帧拆解这条视频，并借助 Codex，把人物构图、关键词出场、章节导航和素材展示整理成了这份 Skill。它根据新视频的内容选择剪法，使用用户自己的口播和素材。

欢迎关注她的 [X](https://x.com/zarazhangrui) 和 [GitHub](https://github.com/zarazhangrui)，看看更多有趣的作品。

> Inspired by [Zara Zhang’s video on X](https://x.com/zarazhangrui/status/2116281211962454056) and its clear, expressive use of cutout portraits, sticker typography, progressive lists, and supporting visuals. Thank you, Zara, for sharing your work! Ryan analyzed the video and worked with Codex to turn those observations into a reusable editing skill.

## 能做什么

- **人物抠像与白描边**：默认 16:9 横屏、本人原声，人物头顶和两侧留出舒服的空间。
- **关键词贴纸**：在讲到重点时出现，铺垫和过渡可以保持干净，普通词不会一直堆积。
- **有层级的字样**：圆润重点字、真实手写注释与安静的章节角标，按语义加入 🤔、🧩、🎬 等彩色 emoji。
- **动态闪卡**：主标题和大编号带虹彩、细闪与柔和反光，停留时也有轻微前后倾斜；列表每行独立轻摆，阅读位置保持稳定。
- **语义对比**：明确说“不是 A，而是 B”时，默认左侧否定、右侧肯定；并列关系和输入输出按真实含义呈现。
- **渐进列表**：人物移左，右侧先标题、再随口播逐项加入，数量跟随内容。
- **章节导航**：大编号与短标题引入要点，随后换成左上角小标签，讲解期间保留。
- **图片与视频插入**：检查配套素材，根据讲述匹配片段，安排位置、大小与展示时长。
- **重点与收束**：重要概念可换背景色；口播确有回顾或建议时，复用已有标签或逐条呈现。
- **可检查交付**：要求实际视频预览、可编辑工程或源文件、剪辑表与必要的质量检查。

## 安装

将完整仓库放入个人 Skills 目录，保留 `SKILL.md`、`agents/` 与 `references/` 的相对位置。例如：

```bash
git clone https://github.com/ryanchenxr/sticker-talk-edit.git \
  "${CODEX_HOME:-$HOME/.codex}/skills/sticker-talk-edit"
```

如果目标位置已有同名 Skill，请先检查已有版本，保留自己的改动。

## 用法

附上口播原片，以及需要配合讲解的图片、录屏或视频，告诉助手：

```text
使用 $sticker-talk-edit 剪辑这段视频。
```

默认采用 16:9、本人原声和白描边人物。助手会根据口播内容匹配图片和视频素材，安排出场位置与时间。

有特殊要求时再追加，例如：

```text
使用 $sticker-talk-edit 剪辑这段视频。
先选一段约 30 秒、语义完整的片段试剪，等我看过再做全片。
```

也可以说明“这张只是风格参考”“这些素材全部要用”“这段演示必须完整保留”或“这次做竖屏”。如果素材用途确实无法判断，助手应向你确认。

不支持加载 Skill 的环境，可以复制 [完整独立提示词](references/standalone-prompt.md)。该提示词默认先做 20–45 秒试剪；需要整片时改成本次实际范围。

## 怎样选择画面

| 讲述内容 | 对应剪法 |
| --- | --- |
| 铺垫、过渡、没有新重点 | 人物居中，保留空白 |
| 否定转折、误区纠正 | 左右对比，分别随语义出现 |
| 宣布重要主题 | 头顶主标题，关键文字保持可读 |
| 列举方法、原因、步骤 | 人物移左，右侧逐项出现 |
| 展开某一个要点 | 大编号与标题 → 左上角小标签 |
| 术语、问题、重要数字 | 少量短贴纸，突出一个主焦点 |
| 案例、截图、演示 | 人物配对应素材，必要时放大细节 |
| 关系、结论、建议 | 按原意使用换色、连线或回顾列表 |

这些画面可以自由组合。故事不必有编号，单一观点不必补出多个章节，中途出现一小段列表也不代表整片都要改成总分总。

## 运行环境

这个仓库提供剪辑方法、视觉规范、质量检查流程，以及一个 **macOS 动态贴纸组件**。完整视频制作需要宿主环境提供以下能力：

- 读取本地视频和素材，获得可核对的转写与时间码。
- 完成人物分割、透明通道合成或合适的绿幕处理。
- 排版文字、处理动画、合成声音并导出视频。

可以沿用支持上述能力的剪辑器或本地工具链。

执行前会检查所需工具；素材上传、付费服务和成片发布按用户的明确授权处理。

## 字效样片与复用

`scripts/StickerKit.swift` 实现圆体/手写字样、彩色 emoji、珠光底纸、虹彩细闪和整贴轻摆。字体从本机加载，所在环境需要 macOS、Metal 和 Swift Command Line Tools。

从仓库根目录生成一段 18 秒无声字效样片：

```bash
swiftc -O scripts/StickerKit.swift scripts/render_sticker_demo.swift \
  -o /tmp/sticker-demo
/tmp/sticker-demo --output /absolute/output/sticker-demo.mp4 \
  --hand-font /absolute/path/to/your-handwriting-font.ttf
```

圆体可通过 `--rounded-font` 指定本机字体的 PostScript 名称；默认使用本机 `STYuanti-SC-Bold`。不提供手写字体时会明确提示降级为圆体。示例只演示字效，不会自动转写或剪辑整段视频。

具体材质、运动幅度和集成方式见 [动态贴纸与闪卡材质](references/sticker-materials.md)。其他编辑器可以按同一规范实现。

## 仓库内容

```text
sticker-talk-edit/
├── SKILL.md                         # 核心语义规则与制作流程
├── agents/openai.yaml               # Skill 名称与调用提示
├── references/
│   ├── visual-grammar.md             # 构图、字体、贴纸和动效建议
│   ├── sticker-materials.md          # emoji、虹彩细闪、手写字与轻摆规范
│   ├── zara-reference.md             # 原视频的文字拆解与来源
│   └── standalone-prompt.md          # 可独立复制的完整提示词
├── scripts/
│   ├── StickerKit.swift              # macOS 动态贴纸组件
│   └── render_sticker_demo.swift     # 18 秒无声字效样片
├── README.md
└── LICENSE
```

视觉规范中的尺寸、字号、颜色和动效时长可按具体视频调整。

## 许可

项目代码、文档与配置采用 [MIT License](LICENSE)。使用素材和字体时，请遵循各自的授权。
