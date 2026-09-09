# NTgram

> ⚠️ **免责声明**：本文档由 AI 辅助生成，可能存在错误或与实际情况不符之处（功能描述、版本号、commit 引用等请以源码与 Release 为准）。

<p align="center">
  <a href="README.md">简体中文</a> | <a href="README.en.md">English</a>
</p>

<p align="center">
  🌐 <a href="https://github.com/fatsnk/NativeTavern">上游 NativeTavern</a> · Android applicationId <code>com.xmbl4399.ntgram</code> · 当前 <code>v0.1.12+28</code>
</p>

NativeTavern 的二次改造 fork。整体 UI 重写为 **Neko 风格**（视觉范式参考 Telegram 第三方客户端 [Nekogram](https://github.com/Nekogram/Nekogram)），同时扩展数据模型、修复上游构建链路、精简原生层。


## 截图

<p align="center">
  <img src="photo/Chat.png" width="220" alt="聊天界面"/>
  <img src="photo/AiConfig.png" width="220" alt="AI 配置"/>
  <img src="photo/Character.png" width="220" alt="角色列表"/>
</p>

| 聊天 | AI 配置 | 角色 |
|:---:|:---:|:---:|
| Neko 风格列表卡片 + 玻璃化底栏 | 当前预设 / 模板 / LLM 连接分组 | 头像 + 描述卡片化呈现 |


## 相对上游 fatsnk/NativeTavern 的更改

### 🎨 UI：Neko 风格重写（参考 Nekogram）

整体视觉范式参考 Nekogram Telegram 客户端的深色玻璃化语言——背景 `#222931` / 卡片 `#2A313D`、融合式顶栏、玻璃化底部 Tab 栏、彩色线性图标、Material ripple 卡片，按 5 个 commit 逐层落地：

| Commit | 改动 |
|---|---|
| `d733da7` | Neko-ify 核心主题、GlassTab、聊天气泡、AI 配置 |
| `9d31989` | Neko 列表卡片、融合顶栏、自适应高度、分组设置 |
| `a57f0fc` | 对齐 Neko 真实调色板（#222931 / #2A313D）、Material ripple 卡片 |
| `1e60dcd` | Neko 手势/搜索/菜单、彩色导航图标、Tab 栏自动隐藏 |
| `454a74c` | Neko 风格收尾、智能 Splash 退出、1s toast |

### 📦 数据 / 功能扩展（相对上游多 14 个 screen）

- **RPG**：场景编辑器（`rpg_scenario_editor_screen`）+ 游戏面板（`rpg_game_panel`）+ 持久化仓库 + 验证规则
- **Moments**（朋友圈）：动态发布 + 时间线屏
- **Story**：剧情章节模型 + 时间线源
- **Data Bank**（资料库）：screen + 仓库 + 上下文注入
- **MCP**（Model Context Protocol）：工具调用设置
- **Tool Calling**：OpenAI / Anthropic / Gemini 三家独立 adapter
- **Memory Inbox**：长短期记忆收件箱
- **Live2D 设置 / Play Hub / Capability Diagnostics / Storage Management**

### 🚀 启动优化

- **SplashGate 智能退出**：原版固定 1000ms hold + 350ms 淡出（人为多等约 1s）→ 改为首帧渲染后最短 400ms 自动放行
- **CI 即 release 构建**：原版 CI 出 debug，本版三 ABI 分发 release APK，AOT 比 JIT 冷启动显著更快

### 🔧 构建链路修复（vendor + CI）

| Commit | 问题 | 修复 |
|---|---|---|
| `58e2c25` | 根 `.gitignore` 裸 `android` 规则 → `android/` + gradle wrapper 从未入库 | 解除 ignore、一次性补 25 文件 |
| `d6704b6` | `pdfrx` 阻断构建、`spine` compileSdk 不匹配 | 砍 pdfrx、修 spine compileSdk |
| `cc74994` | 上游 `flutter_inappwebview_android` 1.1.3 用 `proguard-android.txt` → AGP9 release 拒收 | vendor 改 `proguard-android-optimize.txt` |
| `99595b4` | 上游 `flutter_live2d` pin `cmake;3.10.2` + NDK 27.2（Google 仓库已下架）→ CI CXX1300 | vendor 为本机已装版本（cmake 3.22.1 / NDK 28.2.13676358）+ abiFilters 裁剪至 arm64-v8a + x86_64 |
| `e9cc339/d402732/5bd261a` | CI runner 缺 cmake/NDK | workflow 预装 + 修正 sdkmanager 路径 |
| `266dc84` | 单包 release 大、ABI 冗余 | split-per-abi release：arm64-v8a / armeabi-v7a / x86_64 三包分发 |

### 🗑 移除

- **Rust 原生核心**：上游用 Rust + FFI 实现 PNG/CharX 解析，本版全 Dart 实现，去掉 Rust 工具链依赖


## 功能特性

> 本节沿用上游功能集，本版**未删减**——上游 2187 条 l10n 文案与 38 个 screen 全数保留，并在此基础上叠加上述扩展。

### 核心功能 ✅
- 📱 **原生移动应用** — Flutter 构建，支持 iOS 和 Android
- ⚡ **高性能** — 针对移动设备优化
- 🤖 **多提供商 LLM** — OpenAI、Claude、OpenRouter、Gemini、DeepSeek、Qwen、SiliconFlow、Moonshot(Kimi)、Z.AI(GLM)、MiniMax、Ollama、KoboldCpp、自定义 OpenAI 兼容端点
- 📦 **完全兼容 ST** — 导入/导出 PNG 卡片、CharX、JSON
- 💬 **流式响应** — 所有提供商的实时 SSE 流式传输

### 角色管理 ✅
- 📥 **导入** — PNG V2/V3、CharX（V3 规范）、JSON
- 📤 **导出** — PNG V3、带资源的 CharX、JSON
- ✏️ **角色编辑器** — 创建/编辑角色的所有字段
- 🖼️ **头像支持** — 自定义头像，支持图片选择器
- 📚 **嵌入式知识库** — 完整的 CharX 知识库支持

### 聊天功能 ✅
- 💬 **消息操作** — 编辑、删除、重新生成、滑动备选
- 🎛️ **Swipe Picker** — 浏览/跳转/删除备选回复
- 👥 **群聊** — 多角色对话，5 种响应模式
- 🔖 **书签** — 创建检查点和分支对话
- 📝 **作者注释** — 可配置深度的注入
- 🎭 **人设** — 用户档案管理
- 📄 **HTML/Markdown** — 富文本渲染

### 世界书 ✅
- 🌍 关键词匹配、📍 多位置注入、🔄 递归支持、📊 分组评分

### 提示词管理 ✅
- 📋 提示词管理器、📥 ST 预设导入、🎯 自定义提示词、📍 深度注入

### 高级设置 ✅
- 🎛️ 完整采样器控制（Temp / Top-P / Top-K / Min-P / Typical-P）
- 🔁 重复惩罚、🎲 Mirostat、✂️ 无尾采样（TFS / Top-A）、🛑 停止序列
- 🧠 推理强度（Claude 自适应思考 / Gemini thinkingBudget / OpenAI reasoning_effort）
- 💰 Claude Prompt Caching、🔖 连接档案、🔀 消息合并

### 主题 ✅
- 🎨 **18 个内置主题**（7 深 + 11 浅）+ 🖌️ 主题编辑器

### 思维链 ✅
- 🧠 OpenAI o1/o3（`reasoning_content`）、💭 Claude（`thinking` 块含自适应思考）、🤔 Gemini 2.0 Flash Thinking（`thought`）、🏷️ DeepSeek R1 `<think>` 标签
- 💾 推理存储、📦 可折叠 UI、⏳ 流式显示（脉冲动画）

### 角色标签 ✅
- 🏷️ 标签管理、🎨 十六进制颜色、😀 表情图标、🔗 角色分配、🔍 标签过滤

### Markdown 输入 ✅
- ⌨B/I/U 快捷键、📝 工具栏、🔗 ⌘K 链接、💻 代码块

### 表情精灵 ✅
- 🎭 情绪检测（15 种）、📁 每角色精灵文件夹、✨ 动画过渡、⚙ 大小/位置/透明度自定义

### 文字转语音 🚧
- 🔊 ElevenLabs、Azure、火山引擎、GPT-SoVITS、OpenAI 兼容端点 — 接口层就绪，播放集成开发中

### 语音转文字 🚧
- 🎤 系统 STT、Whisper、Azure — 接口层就绪，录音集成开发中

### 翻译 ✅
- 🌐 30+ 种语言 · 🔄 Google / DeepL / LibreTranslate · 🔀 自动翻译 · 🔍 语言检测

### 图像生成 ✅
- 🎨 GPT-Image-2、Gemini、NovelAI、Pollinations（免费）、ComfyUI、Automatic1111
- 📐 尺寸预设、⚙ 生成设置（步数 / CFG / 采样器）、🚫 负面提示词、🔧 API 配置

### 正则脚本 ✅
- 🔍 查找/替换模式 · 📝 脚本管理 · 🎯 应用位置 · 📦 内置预设 · 🔄 导入/导出 · 🧪 测试工具

### 变量系统 ✅
- 🌐 全局变量 / 💬 本地变量 / 📝 宏（`{{getvar}}` / `{{setvar}}` / `{{incvar}}` 等）/ 🔢 数字·字符串·数组·对象

### RAG / 向量存储 🚧
- 🧲 Embedding 提供商（OpenAI 兼容 / SiliconFlow / Cohere / Gemini / Ollama）
- 📚 知识库集合、🔍 Top-K + 阈值检索、💬 按最新用户消息注入

### 聊天备份 ✅
- 💾 自动备份（小时 / 天 / 周）、📁 单聊天 JSONL、📦 完整 JSON、🗑️ 保留策略、👁️ 浏览/恢复

### 宏系统 ✅（Macros 2.0）
- `{{user}}` / `{{char}}` · `{{time}}` / `{{date}}` / `{{weekday}}`
- `{{random:min:max}}` · `{{roll:NdM}}` · `{{pick::...}}`
- `{{if 条件}}...{{else}}...{{/if}}`（作用域、惰性求值、嵌套）
- `{{.局部变量}}` / `{{$全局变量}}`（`= += -= ++ -- == != > < ?? ||`）
- `{{greeting::N}}` · `{{maxContextTokens}}` · `{{idle_duration}}` · `{{lastMessage}}` ...

### 斜杠命令 ✅
`/continue` · `/regenerate` · `/swipe` · `/persona` · `/sys` · `/bg` · `/help` · `/clear` · `/edit` · `/delete` · `/bookmark` · `/note`

### 背景 ✅
🖼️ 自定义背景 · 📁 图库 · 🎚️ 透明度 · 💬 每聊天独立背景


## 技术栈

| 组件 | 技术 |
|---|---|
| UI 框架 | Flutter (Dart) |
| 状态管理 | Riverpod |
| 导航 | go_router |
| 数据库 | SQLite (drift) |
| HTTP 客户端 | Dio |

> 上游的 Rust 原生核心（PNG/CharX 解析）在本版已全 Dart 化，无 FFI、无 Rust 工具链依赖。


## 项目结构

```
ntgram/
├── lib/                    # Flutter / Dart 代码
│   ├── main.dart          # 入口点
│   ├── app.dart           # 应用配置
│   ├── core/              # 核心工具（flags / services / utils）
│   ├── data/              # 数据层（models / database / repositories）
│   ├── domain/            # 业务逻辑（services / repositories / models）
│   └── presentation/      # UI 层（providers / screens / widgets / theme / router）
├── android/                # Android 平台代码（含 gradle wrapper）
├── ios/                    # iOS 平台代码
├── photo/                  # README 截图
├── third_party/            # vendor 依赖（flutter_inappwebview_android、flutter_live2d）
├── .github/workflows/      # CI：split-per-abi release
├── pubspec.yaml            # 依赖与 override
└── LICENSE
```


## 开始使用

### 前置要求

- Flutter SDK ≥ 3.47
- Xcode（iOS 开发）/ Android Studio（Android 开发）

### 安装

```bash
git clone https://github.com/xmbl4399/NTgram.git
cd NTgram
flutter pub get
flutter run
```


## SillyTavern 兼容性

### 支持的导入格式

| 格式 | 描述 | 状态 |
|---|---|---|
| PNG V2 | 带 `chara` tEXt 块的角色卡片 | ✅ |
| PNG V3 | 带 `ccv3` tEXt 块的角色卡片 | ✅ |
| CharX | card.json + 资源的 ZIP 归档 | ✅ |
| JSON | 原始角色 JSON | ✅ |
| ST 预设 | SillyTavern AI 预设 JSON | ✅ |

### 支持的导出格式

| 格式 | 描述 | 状态 |
|---|---|---|
| PNG V3 | 嵌入元数据的 PNG | ✅ |
| CharX | 包含所有资源 | ✅ |
| JSON | 备份导出 | ✅ |


## 开发阶段

| 阶段 | 功能 | 状态 |
|---|---|---|
| 1–2 | 核心基础、聊天核心 | ✅ |
| 3A | 消息操作、人设、指令模式 | ✅ |
| 3B | 世界书、CharX 完整导入、角色编辑器 | ✅ |
| 4A | 群聊、聊天书签 | ✅ |
| 4B | 宏系统 | ✅ |
| 5 | 作者注释、提示词管理、高级设置、快捷回复、主题、统计、思维链 | ✅ |
| 6 | 斜杠命令、标签、背景、HTML/Markdown | ✅ |
| 7 | 表情精灵、TTS、STT、翻译、图像生成 | ✅ |
| 8 | 正则脚本、变量、聊天备份 | ✅ |
| 9 | RAG / 向量 | 🚧 基础可用 |
| 10 | Neko UI 重构、RPG / Moments / Story / Data Bank / MCP / Tool Calling | ✅（本版新增） |
| 11 | TTS / STT 播放集成 | ⏳ 计划中 |


## 与 SillyTavern 功能对比

| 功能 | SillyTavern Web | NTgram | 状态 |
|---|---|---|---|
| 角色导入/导出 | ✅ | ✅ | 完全对等 |
| LLM 提供商 | 10+ | 13 | 含国产主流模型 |
| 流式传输 | ✅ | ✅ | 完全对等 |
| 消息操作 | ✅ | ✅ | 完全对等 |
| 群聊 / 世界书 / 提示词管理 / 宏 / 主题 | ✅ | ✅ | 完全对等 |
| 斜杠命令 / 背景 / HTML-Markdown / 思维链 / 角色标签 | ✅ | ✅ | 完全对等 |
| 推理 UI / Markdown 快捷键 / 表情精灵 | ✅ | ✅ | 完全对等 |
| TTS / STT | ✅ | 🚧 | 接口就绪，播放/录音开发中 |
| 翻译 / 图像生成 / 正则脚本 / 变量系统 / 聊天备份 | ✅ | ✅ | 完全对等 |
| RAG / 向量存储 | ✅ | 🚧 | 基础可用 |
| RPG / Moments / Story / Data Bank | — | ✅ | 本版新增 |
| MCP / Tool Calling 适配 | — | ✅ | 本版新增 |
| Neko UI（Nekogram 风格） | — | ✅ | 本版新增 |


## 许可证

AGPL-3.0 — 详见 [LICENSE](LICENSE)。

## 致谢

- [fatsnk/NativeTavern](https://github.com/fatsnk/NativeTavern) — 上游项目
- [SillyTavern](https://github.com/SillyTavern/SillyTavern) — 原始 Web 项目
- [Nekogram](https://github.com/Nekogram/Nekogram) — Neko 视觉风格灵感来源
- [Flutter](https://flutter.dev) · [Riverpod](https://riverpod.dev)