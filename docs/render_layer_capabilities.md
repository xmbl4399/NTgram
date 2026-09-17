# NTgram 原始渲染层能力清档

> 核对时间：2026-09-16　|　核对方式：逐文件读源码 + 读依赖包源码（非猜测）
> 关键依赖：`flutter_markdown` 0.6.23（pubspec 写 `^0.6.18`）、`markdown` 7.3.1、`flutter_inappwebview` 6.0.0

---

## 0. 一句话总览

消息正文只有**两条真实渲染路径**：绝大多数内容走 `MarkdownBody`，只有「含白名单 HTML 标签 + 非流式 + 命中复杂度正则」才升级到 WebView。注释里宣称的第三条「纯文本路径」是**死代码**。

---

## 1. 实际渲染路由

`lib/presentation/widgets/chat/message_content_widget.dart:215-251`

```
hasHtml = _containsHtml(content)          // 白名单 43 个标签名
│
├─ hasHtml 且 !isStreaming 且 isComplexHtml(content)
│     → HtmlWebViewWidget（真 WebView，完整 CSS）
│
└─ 其余全部
      content' = hasHtml ? _convertHtmlToMarkdown(content) : content
      → MarkdownBody
```

### 死代码（重要）

| 符号 | 位置 | 状态 |
|---|---|---|
| `_containsMarkdown()` | `message_content_widget.dart:88-124` | 完整实现了 12 条 Markdown 探测正则，**零调用** |
| `_buildPlainText()` | `message_content_widget.dart:560-585` | **零调用** |
| `widget.selectable` | 构造参数 | 只在死代码 `_buildPlainText` 里被读；活路径 `_buildMarkdownContent` 恒定包 `SelectionArea`，**所以传 `selectable: false` 不生效** |

→ 结论：**不存在「纯文本直渲」的旁路**。任何内容只要没进 WebView，都会过一遍 Markdown 解析器。副作用是：正文里的 `*` `_` `#` `>` `` ` `` 等符号**可能被解析成格式**而不是原样显示。

---

## 2. 路径 A · MarkdownBody（默认路径，占绝大多数）

### 2.1 解析器配置

| 项 | 值 | 来源 |
|---|---|---|
| `extensionSet` | **未传** → 默认 `md.ExtensionSet.gitHubFlavored` | `flutter_markdown/src/widget.dart:355` |
| `blockSyntaxes` / `inlineSyntaxes` | 未传 | — |
| `builders` | 未传（无自定义元素构建器） | — |
| `shrinkWrap` | `true` | `message_content_widget.dart:424` |
| `softLineBreak` | **`true`** | `message_content_widget.dart:425` |
| `styleSheetTheme` | 未传 → 默认 `material` | `flutter_markdown/src/widget.dart:191` |
| `encodeHtml` | `false`（内部固定） | `flutter_markdown/src/widget.dart:357` |

**`softLineBreak: true` 的后果**：原文里的**单个 `\n` 会被渲染成真正的换行**（不是 CommonMark 标准的"合并成空格"）。所以模型输出的换行在 UI 上是**能看见的**。

### 2.2 支持的语法

`gitHubFlavored` = 下面这些。

**块级**

| 语法 | 支持 | 说明 |
|---|---|---|
| 段落、软换行 | ✅ | 单 `\n` 即换行（见上） |
| ATX 标题 `#` ~ `######` | ✅ | |
| Setext 标题（`===` / `---` 下划线） | ✅ | CommonMark 基础块 |
| 引用 `>` | ✅ | |
| 无序列表 `-` `*` `+` | ✅ | |
| 有序列表 `1.` | ✅ | |
| 列表嵌套 / 多段列表项 | ✅ | |
| 任务列表 `- [ ]` / `- [x]` | ✅ | `UnorderedListWithCheckboxSyntax` |
| 围栏代码块 ```` ``` ```` | ✅ | `FencedCodeBlockSyntax` |
| 缩进代码块（4 空格） | ✅ | |
| 分隔线 `---` | ✅ | |
| **GFM 管道表格** | ✅ | `TableSyntax` — **表格是支持的** |
| 脚注定义 `[^1]: …` | ✅ | `FootnoteDefSyntax` |

**行内**

| 语法 | 支持 | 说明 |
|---|---|---|
| `**粗**` / `__粗__` | ✅ | |
| `*斜*` / `_斜_` | ✅ | |
| `~~删除线~~` | ✅ | `StrikethroughSyntax` |
| `` `行内代码` `` | ✅ | 样式见 2.3 |
| `[文字](链接)` | ✅ | 点击走 `onTapLink` |
| `![alt](图片)` | ✅ | 走自定义 `imageBuilder` |
| 裸链接自动识别 | ✅ | `AutolinkExtensionSyntax` |
| 行内 HTML 透传 | ✅ | `InlineHtmlSyntax`（标签会原样进 AST） |
| 反斜杠转义 `\*` | ✅ | CommonMark 基础 |
| 硬换行（行尾两空格） | ✅ | |

**不支持**（相对 `gitHubWeb` 缺的四项）

| 语法 | 状态 |
|---|---|
| `:smile:` emoji 短代码 | ❌ `EmojiSyntax` 不在集合内 |
| `ColorSwatchSyntax` | ❌ |
| `> [!NOTE]` 提示块 | ❌ `AlertBlockSyntax` 不在集合内 |
| 标题锚点 ID | ❌ 用 `gitHubFlavored` 而非 `gitHubWeb` |

### 2.3 样式表：项目覆盖了哪些

项目在 `message_content_widget.dart:464-550` 显式设了 24 个键：

`p` `strong` `em` `del` `code` `codeblockDecoration` `codeblockPadding` `blockquote` `blockquoteDecoration` `blockquotePadding` `h1`~`h6` `a` `listBullet` `horizontalRuleDecoration`

**实际生效的样式语义**

| 元素 | 样式 |
|---|---|
| 正文 `p` | `color: textColor`（AI 用 `neko.textPrimary`，用户气泡 `Colors.white`），`fontSize: 14`（可由 `widget.fontSize` 覆盖） |
| 粗体 | `fontWeight.bold` |
| 斜体 | `FontStyle.italic` |
| 删除线 | `TextDecoration.lineThrough` |
| 行内代码 `` ` `` | `fontFamily: 'monospace'` + `fontSize ×0.9` + **背景 `context.neko.background @50%`** ← 「Thoughts 暗底块」的成因 |
| 代码块 | 同色背景 @50% + 圆角 8 + `padding: 12` |
| 引用 `>` | 灰字 + 斜体 + **左侧 3px 主色竖线**，左内边距 12 |
| 标题 h1~h6 | `fontSize × 1.8 / 1.5 / 1.3 / 1.1 / 1.0 / 0.9`，全部 bold |
| 链接 | `AppTheme.primaryColor` + 下划线 |
| 分隔线 | 1px `context.neko.divider` |

**未设、继承 fallback 的（容易被忽略）**

| 键 | 实际值 | 来源 |
|---|---|---|
| `p.height`（**行高**） | **1.43** | 继承 `theme.textTheme.bodyMedium`（Material 3 默认） |
| `pPadding` | `EdgeInsets.zero` | `MarkdownStyleSheet.fromTheme` |
| `blockSpacing` | `8.0` | kFallbackStyle |
| `listIndent` | `24.0` | kFallbackStyle |
| `tableHead` / `tableBody` | `FontWeight.w600` / `bodyMedium` | kFallbackStyle |
| `tableBorder` | `TableBorder.all(0x1F000000)` | kFallbackStyle |
| `tableHeadAlign` | `TextAlign.center` | kFallbackStyle |
| `tableCellsPadding` / `tableColumnWidth` / `tableCellsDecoration` | 默认 | kFallbackStyle |

**合并语义**：`MarkdownBody` 内部是 `fallback.merge(项目传入)`，即 `p = fallback.p.merge(项目.p)`。
→ **项目里没写的字段保留 fallback 值，不是被清空。** 所以想改行高，得显式写 `height`。

### 2.4 两个自定义钩子

**`imageBuilder`**（`:426-463`）—— 所有 `![]()` 图片走这里：
`CachedNetworkImage`，`BoxFit.contain`，圆角 8，上下外边距 8；
加载中 → 高 200 的 `CircularProgressIndicator`；
失败 → 高 150 的 `broken_image` 图标 + 文案 `Image failed to load`。

**`onTapLink`**（`:551-555`）—— `LaunchMode.externalApplication`，即**跳出 App 用系统浏览器打开**。

---

## 3. 路径 B · WebView（复杂 HTML）

文件：`lib/presentation/widgets/chat/html_webview_widget.dart`

### 3.1 触发条件 `isComplexHtml()`（`:705-738`）

命中**任一**即升级：

| # | 正则 | 拦的是什么 |
|---|---|---|
| 1 | `display:\s*flex` | flex 布局 |
| 2 | `display:\s*grid` | grid 布局 |
| 3 | `box-shadow:` | 阴影 |
| 4 | `transition:` | 过渡 |
| 5 | `transform:` | 变换 |
| 6 | `animation:` | 动画 |
| 7 | `@keyframes` | 关键帧 |
| 8 | `object-fit:` | 对象适配 |
| 9 | `background:\s*linear-gradient` | 线性渐变 |
| 10 | `background:\s*radial-gradient` | 径向渐变 |
| 11 | `overflow:\s*(hidden\|auto\|scroll)` | 溢出控制 |
| 12 | `height:\s*\d+` | 显式高度 |
| 13 | `<[^>]+style="[^"]{10,}"` | 任一 style 属性值 ≥10 字符 |
| 14 | 带 `style` 的 `<div>` 计数 **≥3** | 疑似复杂布局 |

**硬约束**：`message_content_widget.dart:223` 是 `hasHtml && !widget.isStreaming && isComplexHtml(...)` —— **流式输出期间一律不走 WebView**，避免内容高频变化导致重排。流式由 true→false 时 `_contentVersion++`（`:69-74`）触发一次强制重载。

### 3.2 注入的默认 CSS（`_buildHtml`，`:138-235`）

外层是固定模板，`$content` 插在 `<div id="measure-root">` 里。

| 选择器 | 注入的样式 |
|---|---|
| `html, body` | `margin/padding: 0`；`background: transparent`；`color:` 主题 `textPrimary`；`font-size: 14px`（或传入 fontSize）；**`line-height: 1.5`**；`word-wrap: break-word`；`overflow-wrap: anywhere`；`height/max-height/overflow` 全部 `!important` 放开 |
| `#measure-root` | `display: flow-root`；`padding: 8px` |
| `img` | `max-width: 100%`；圆角 8；`display: block`；**加载中骨架动画**（`@keyframes imageLoading`，1.5s 循环滑条） |
| `a` | **`color: #7C4DFF`　`text-decoration: underline`** ← **硬编码，不跟主题** |
| `h1`~`h4` | `1.8em / 1.5em / 1.3em / 1.1em`，bold |
| `p` | `margin: 0 0 0.5em 0` |
| 滚动条 | `::-webkit-scrollbar` 6px + `thumb: rgba(255,255,255,0.2)` |

**文本预处理**：`<details` → **`<details open`**（`:141-144`，强制展开）。

**字体族**：`-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif` —— **不含任何中文字体**，中文靠系统 fallback。

### 3.3 高度自适应

- JS `sendHeight()` → `window.flutter_inappwebview.callHandler('contentHeight', h)`
- Flutter 侧 `resolveHtmlWebViewHeight()`（`:742-754`）：新高度 = 实测 + 12；**随时可增长**，但只在 `updateCount <= 6` 的前 6 次允许收缩
- 初始高度 100，`_minHeight` 50；JS 侧上报前有 1px 死区去抖

---

## 4. 路径 C · HTML→Markdown 预转换（简单 HTML）

任何含白名单标签的内容，只要**没**升级到 WebView，都会先过 `_convertHtmlToMarkdown()`（`:254-394`）。

### 4.1 标签映射表

| HTML | → Markdown |
|---|---|
| `<b>` `<strong>` | `**…**` |
| `<i>` `<em>` | `*…*` |
| `<u>` | `**…**`（Markdown 无下划线，降级为粗体） |
| `<s>` `<del>` `<strike>` | `~~…~~` |
| `<code>` | `` `…` `` |
| `<pre>` | 围栏代码块 ```` ``` ```` |
| `<h1>`~`<h6>` | `#`~`######` |
| `<a href="…">` | `[文字](href)` |
| `<img src="…">` | `![image](src)` |
| `<blockquote>` | 内容每行加 `> ` |
| `<hr>` | `---` |
| `<br>` | `\n` |
| `<p>` `<div>` | `\n…\n` |
| `<ul> <li>` | `- 内容` |
| `<ol> <li>` | `1. 2. 3. …`（序号自动递增） |
| **其余所有标签** | **直接删除**（兜底 `replaceAll(RegExp(r'<[^>]+>'), '')`） |

### 4.2 实体解码（12 个，硬编码）

`&nbsp;` `&amp;` `&lt;` `&gt;` `&quot;` `&#39;` `&apos;` `&mdash;` `&ndash;` `&hellip;` `&copy;` `&reg;` `&trade;`

⚠️ **数值/十六进制实体不解码** —— `&#x4E2D;` `&#20013;` 会原样显示。

末尾还有 `\n{3,}` → `\n\n` 的连续空行压缩。

### 4.3 转换丢失清单（实测会掉样式的标签）

这些标签在 `_containsHtml` 白名单里（能触发 `hasHtml = true`），但 `_convertHtmlToMarkdown` **不处理** → 被兜底删除，**样式与内容结构一起丢失**：

| 标签 | 丢失的东西 |
|---|---|
| `<span style="color: …">` | 颜色 |
| `<font color="…">` | 颜色/字号 |
| `<center>` | 居中 |
| `<sub>` `<sup>` | 上下标 |
| `<mark>` | 高亮 |
| `<small>` `<big>` | 字号 |
| `<q>` `<cite>` `<abbr>` | 语义（语义本身无视觉） |
| `<details>` `<summary>` | 折叠结构（**只有进 WebView 路径才会展开**） |
| `<table>` `<tr>` `<td>` `<th>` | **整个表格结构被删**，只剩单元格文字连成一片 |
| `<em>` 以上的任意 `style` / `class` / `id` | 全部属性 |

> 表格特别注意：`<table>` 走**路径 C 会被抹平**；能正常显示表格的只有两种情形 —— ① 模型直接输出 GFM 管道表格（走路径 A 的 `TableSyntax`）② HTML 表格里带 `style="…"` 触发路径 B。

---

## 5. 渲染外壳（两套 UI 模式）

`lib/presentation/screens/chat/chat_layout_mode.dart` 定义枚举：`bubble` / `visualNovel`。

| 模式 | 承接文件 | 传给渲染层的 `textColor` |
|---|---|---|
| **bubble** | `chat_screen.dart:3344` | AI：`context.neko.textPrimary`；用户：`Colors.white` |
| **visualNovel** | `visual_novel_message_view.dart:250` | **恒 `Colors.white`** |
| 思维链面板 | `reasoning_widget.dart:188` / `:382` | 面板内嵌 `MessageContentWidget` |

**visualNovel 模式细节**（已经是"立绘 + 浮层字幕"形态）：
- 启用条件：`chat_screen.dart:1603` —— **必须 `hasBackground \|\| hasLive2D`**，否则不生效
- 浮层：`LinearGradient` 黑 60% → 黑 80%，顶部圆角 20，`BackdropFilter` `blur(10)`
- 内含 `PageView` 翻页 + `1 / N` 页码胶囊 + 左右圆形按钮
- 顶部有说话人栏：头像 + 名字（AI 用 `Colors.amber`，用户用 `AppTheme.accentColor`）

---

## 6. 能力边界（改提示词 / 改样式前必读）

| # | 限制 | 依据 |
|---|---|---|
| **P0** | **无段内分色** —— `p` 样式对整段生效，一个 `TextStyle` 走到底。做不了"括号灰、台词黑" | `MarkdownStyleSheet.p` 是段级样式，无 inline span 机制 |
| **P0** | 不存在"纯文本直渲"旁路，所有内容都过 Markdown 解析器 → 正文里的 `*` `_` `#` 可能被吃成格式 | 见 §1 死代码 |
| **P1** | 行高固定继承 `1.43`（Material `bodyMedium`），且项目未显式设 `height` | 见 §2.3 |
| **P1** | 无法按成分区分字体族 / 字号 | 同上 |
| **P1** | WebView 里 `a { color: #7C4DFF }` 硬编码，暗色/亮色主题不一致 | `html_webview_widget.dart:204` |
| **P2** | 表格样式未配置，用 kFallbackStyle 默认黑边框 `0x1F000000`，深色主题下偏扎眼 | 见 §2.3 |
| **P2** | `_containsHtml` 只匹配**开标签**形态（`<p ` / `<p>` / `<p/>`）。正文若只含闭标签（孤立 `</div>`）不会触发 HTML 路径 | `:80-84` 正则结构 |
| **P2** | HTML 白名单 43 个标签；`<video>` `<iframe>` `<ruby>` 等**不在**白名单 → `hasHtml=false` → 尖括号原样显示 | 同上 |
| **P2** | 数值实体不解码 | §4.2 |
| **P3** | `_containsHtml` 白名单与 `_convertHtmlToMarkdown` 能力不匹配（白名单 43 个，转换只支持 20 个）→ 中间那批标签静默丢样式 | §4.3 |
| **P3** | 流式期间不走 WebView；若模型输出依赖 CSS 的内容，会先闪 Markdown 版再切换 | `:223` |

---

## 7. 可改点速查

| 想改什么 | 改哪里 |
|---|---|
| 正文行高（1.43 → 1.6） | `message_content_widget.dart:465-468` 的 `p: TextStyle` 加 `height:` |
| 段内分色（括号变灰） | §1 路由处新增第三条路径，用 `TextSpan` 自行构造 |
| 表格外观 | 同上 `styleSheet` 补 `tableHead` / `tableBody` / `tableBorder` / `tableCellsPadding` |
| 引用块外观 | `:492-504` |
| 行内代码"暗底块" | `:481-486`（`backgroundColor` 那行，Thoughts 暗底的根源） |
| 链接颜色（Markdown 路径） | `:535-538` |
| 链接颜色（WebView 路径） | `html_webview_widget.dart:204` |
| 图片失败占位 | `:442-459` |
| 哪些 HTML 升级到 WebView | `html_webview_widget.dart:705-738` |
| 白名单标签 | `message_content_widget.dart:80-84` |
| HTML→Markdown 映射 | `message_content_widget.dart:254-394` |
| 视觉小说浮层样式 | `visual_novel_message_view.dart:188-201` |
