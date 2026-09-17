# 猫箱式「双色渲染」设计方案

> 起因：2026-09-16 用户指出猫箱故事模式的台词是纯黑、括号内容（动作/内心os）是灰字。
> 像素实测（截图 `clipboard-2026-09-16T12-33-58-683Z-6f1ffb77.png`）：
> 台词核心 `#35373e`（近纯黑）、括号内容 `#8c8987`（中灰）。

---

## 一、关键结论

**猫箱的"台词 / 动作分离"是渲染层做的，不是提示词做的。**

一段流、不加引号、不换行，靠两套字色把成分分级。这解释了为什么它读起来清楚却不臃肿。

对 NTgram 的三点意义：

1. **提示词可以大幅简化**——不用再教"台词单独占一行"、不用再跟 Markdown 换行规则搏斗。模型只负责「用（ ）包住动作」，视觉分级由 App 保证，**100% 可控**。
2. **回到一段流**（v13 路线）——猫箱本身就是一段流，之前 v6~v14 的"独立行"是在用排版硬凑分离效果，属于绕路。
3. **现有渲染链做不了**——`MarkdownBody` 的 `p` 样式是整段一个 `TextStyle`，无段内分色能力。

---

## 二、现状（待改点）

`lib/presentation/widgets/chat/message_content_widget.dart`

| 行 | 现状 | 问题 |
|---|---|---|
| 421-425 | `MarkdownBody(...)` | `p` 样式对整段生效，无法段内分色 |
| 464-468 | `p: TextStyle(color: widget.textColor, fontSize: effectiveFontSize)` | **未设 `height`** → 合并时保留 fallback 值，即 `theme.textTheme.bodyMedium` 的 **`height: 1.43`**；猫箱实测约 1.6 |
| 215-251 | `_buildContent` 双路由：复杂 HTML → WebView；其余 → `_convertHtmlToMarkdown` + Markdown | 没有"纯 RP 文本"这条更轻的路 |

---

## 三、方案：加第三条渲染路由「对话文本」

### 3.1 路由改造

```
_buildContent:
  ① 含复杂 HTML 且非流式        → HtmlWebViewWidget（不动）
  ② 含 Markdown 语法            → MarkdownBody（不动，保留富格式能力）
  ③ 纯 RP 文本（新增）           → _DialogueText：按括号切段 + 双色 InlineSpan
```

判定条件 ③：`!_containsHtml(content) && !_containsMarkdown(content) && 含「（」`
—— RP 提示词已明令禁用 `*` 与反引号，所以 RP 输出天然落在 ③。

### 3.2 切段规则

```
RegExp(r'（[^）]*）|（[^）]*$|\([^)]*\)|\([^)]*$')
```

- 全角 `（）` 与半角 `()` 都识别
- **匹配未闭合的开括号到文末** —— 流式输出时括号刚打出、右括号还没来，这一段也要正确变灰，避免闪烁

### 3.3 样式

| 成分 | 颜色 | 说明 |
|---|---|---|
| 括号段（含括号本身） | `AppTheme.textSecondary` | 猫箱 `#8c8987` 量级；暗色主题下需给对应浅灰 |
| 其余（台词/叙述） | `widget.textColor` | 不变 |

`height: 1.6`（统一应用到 ③，以及 MarkdownBody 的 `p`，改善整体观感）。

### 3.4 实现要点

- 用 `Text.rich` / `SelectableText.rich` 构造 `TextSpan` 树；`SelectableText` 与现有 `SelectionArea` 二选一，避免嵌套冲突
- 保留 `GestureDetector` 的长按菜单（`onLongPressStart` → `_showContextMenu`）
- 缓存键需带上"渲染路径"，避免 ②③ 切换时复用错 widget（现有 `_cachedContent` 机制可直接复用，路径由 content 推导）

---

## 四、连带简化：提示词回到「一段流」

渲染层接管分级后，v11/v14 里这些规则**全部可以删**：

- ✗ 「台词单独占一行」
- ✗ 「动作、神态、环境描写用（）包裹，占独立行」
- ✗ 「行与行之间只换行，不要留空行」
- ✗ 「不要空行分段」

保留的只剩三条硬约束：

1. **用（）包住动作/神态/环境**（渲染层靠它切色）
2. **描写的括号里只写能拍到的**（不写情绪、不写比喻）
3. **长度**（80–140 字，按猫箱实测 73 字量级）

即 `docs/system_prompt_v13.md`（猫箱一段流版）。

---

## 五、待定项

| 项 | 说明 |
|---|---|
| 灰值微调 | 亮色主题用 `AppTheme.textSecondary`；暗色需实测是否够对比 |
| 是否也灰化 `「」` | 若保留 ST 系台词符号，可一并降级；当前方案不动 |
| 是否做立绘 + 浮层字幕 | 猫箱的气泡是半透明卡片压在立绘上，属更大的 UI 改造，本方案不含 |
