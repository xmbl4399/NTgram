# NTgram RP 提示词测试工具

离线测试台：**直接调用本地 llama.cpp 端点，完全复刻 App 的 messages 拼装**，自动统计格式指标。
比"改代码 → 构建 APK → 装模拟器 → 手动聊 → 截图"快一个数量级。

## 环境

- 端点：`http://127.0.0.1:9931/v1/chat/completions`（llama.cpp server）
- Key：`12345678`
- 模型：换过多次 —— `D:\llama\Gemma-4-E4B.gguf`（非思考）/ `D:\llama\Qwen3.5-4B.gguf`（思考模型）
- **端点可用环境变量切换**（同一套用例在本地小模型与线上大模型之间切换，不用改代码）：
  `NTGRAM_TEST_API` / `NTGRAM_TEST_KEY` / `NTGRAM_TEST_MODEL` /
  `NTGRAM_TEST_MERGE_SYSTEM` / `NTGRAM_TEST_NO_THINK` / `NTGRAM_TEST_ALLOW_SEED`
- **打 DeepSeek 官方 API 用包装脚本**（key 从 `Z:\备份误删.txt` 现读，不落盘、不入库）：

  ```bash
  bash tools/run_deepseek.sh tools/prompt_compare.py --only "v23,v27" --n 8 --msg "你还好吗？"
  bash tools/run_deepseek.sh tools/llm_rp_test.py --prompt docs/system_prompt_v23.md --msg "你还好吗？"
  ```

  默认 `deepseek-chat`；自动设 `MERGE_SYSTEM=0`（大模型模板不受限，用 App 原生拼装更真实）、
  `NO_THINK=0`、`ALLOW_SEED=0`（DeepSeek 不接受 seed）。
- 启动示例：`cd /d/llama && ./llama-server.exe -m D:/llama/Qwen3.5-4B.gguf --host 127.0.0.1 --port 9931 -c 8192`
- 关闭：Git Bash 下必须 `MSYS_NO_PATHCONV=1 taskkill /F /IM llama-server.exe`（`taskkill //F` 会报"无效参数"）
- 依赖：仅标准库 + `PIL`（本脚本用手写 struct 解析 PNG，实际不依赖 PIL）

## 用法

```bash
PY="C:/Users/ASUS/.workbuddy/binaries/python/versions/3.13.12/python.exe"

# 单次测试，打印完整指标
$PY tools/llm_rp_test.py --prompt docs/system_prompt_v9.md --msg "你还好吗？"

# 打印完整 messages（核对拼装是否正确）
$PY tools/llm_rp_test.py --raw

# 无系统提示词（对照基线）
$PY tools/llm_rp_test.py --neutral

# 多版本并排对照
$PY tools/prompt_compare.py --msg "你还好吗？" --n 4
$PY tools/prompt_compare.py --only "v8,v9" --n 4        # 只跑指定版本
$PY tools/prompt_compare.py --card-data                  # 卡片数据影响对照

# ★ 配对采样（本地对照请务必带 --seed）：所有版本第 i 次共用 seed+i，版本间可逐次比对
$PY tools/prompt_compare.py --only "v23,v27,v28" --n 8 --seed 4242 --msg "你还好吗？"

# 打真实 DeepSeek（详见「环境」一节的包装脚本）
bash tools/run_deepseek.sh tools/prompt_compare.py --only "v23,v27" --n 8 --msg "你还好吗？"
```

## ⚠️ 为什么本地对照必须用 `--seed`

`chat()` 一直支持 `seed`，但 `run()` 从没传过 —— 所以历史每一轮都是**全新随机采样**。
后果实测过：同一个版本（v23）、同一个输入（「你还好吗？」），两轮相差

| | 字数 | 最长描写 | 情绪解说 |
|---|---|---|---|
| 随机第 1 轮 | 194 | 79 | 0.4 |
| 随机第 2 轮 | 130 | 33 | 0.0 |

**这种量级的抖动足以把"哪个版本更好"的结论整个翻转**（我们确实被翻转过一次：
第一轮判 v20 完胜 v21，第二轮 v21 反而更好）。加了 `--seed` 之后，所有版本的第 i 次共用 `seed+i`，
版本之间可以逐次对比，方差被压到只剩"提示词差异"那一部分。

**DeepSeek 官方 API 不接受 `seed` 字段**，所以线上对照只能是无种子随机采样 —— 靠加大 `--n` 抵消。

## 指标含义

| 指标 | 目标 | 说明 |
|---|---|---|
| 字数 | 80–140 | 去空白后的字符数 |
| 描写块 | ≤2 | **`*…*` 整行包裹**的动作行数（v22 起；v20 及更早是 `（…）`，跨版本别比这列） |
| 最长描写 | ≤80 | 单个描写块的字符数（猫箱样张动作段本身 60 字，卡太死没意义） |
| 台词行 | 2–3 | 非括号非空行 |
| 引用块 | 2–3 | `>` 开头的块数（v15 起的台词方案） |
| 引用块后吞行 | **0** | `>` 行下一行不是空行 → 正文会被解析器吸进引用块（见下） |
| 内心 | 0–1 | `（…）` 整行包裹（v22 起；v20 及更早写作 `（内心os：…）`） |
| 情绪解说 | **0** | 描写块里的情绪标签/比喻/推测（核心指标） |
| 裸星号 / 反引号 | 0 | **不成对或没整行包裹的 `*`**（v22 起 `*动作*` 是合法语法，所以指标改成"裸星号"）。实测残留形态 = 模型把动作写成 `> *动作*` |
| 名前缀 | 0 | `Aqua: "…"` 角色名前缀泄漏 |

## Markdown 解析探针（`tools/md_probe.dart`）

跑的是与 App 同源的 `markdown 7.3.1`，用来确认渲染层的真实解析行为（不信直觉，只看输出）：

```bash
"C:/Users/ASUS/flutter-3472/flutter/bin/dart.bat" run tools/md_probe.dart
```

**实测结论（引用块是"不对称"的）：**

| 写法 | 解析结果 |
|---|---|
| `> 台词` + 紧接正文（无空行） | ❌ **正文被吸进引用块** `<blockquote><p>台词 正文</p></blockquote>` |
| `> 台词` + 空行 + 正文 | ✅ 正常分开 |
| 正文 + 紧接 `> 台词`（无空行） | ✅ 正常分开（`>` 能中断段落） |
| `> 句一` + `> 句二`（连续） | 合并为**一个**引用块，块内软换行 |
| `> 句一` + 空行 + `> 句二` | 两个**独立**引用块，有段间距 |

→ 这就是 CommonMark 的 lazy continuation。**写"台词用引用块"的提示词时必须带"引用块后空一行"这条约束。**


## messages 拼装（复刻 `chat_providers.dart:_buildSectionMessages`）

```
[system]    <systemPrompt section>        ← 提示词
[system]    Description:\n<description>
[system]    Personality:\n<personality>
[system]    Scenario:\n<scenario>
[system]    Example dialogue:\n<mes_example>
[assistant] <first_mes>                   ← chatHistory
[user]      <用户输入>
[system]    <postHistoryInstructions>     ← 实测中传空
```

## 已发现的两个卡片数据噪声（应用层可优化）

AQUA 卡（`D:\HONOR Share\Honor Share\AQUA _ The Useless Goddess.card.png`）：

| 字段 | 问题 |
|---|---|
| `personality` | 4096 字符 HTML 垃圾（原作者宣传页 `<p><img src=...>`），App 不清洗直接发 |
| `mes_example` | 1486 字符英文 ST 格式示例（`<START>` + `{{CHAR}}: "…"`），诱发英文输出与角色名前缀 |

## 实测结论（temp 0.7，AQUA 卡，输入「你还好吗？」）

| 配置 | 提示词字符 | 字数 | 描写块 | 台词行 | 情绪解说 | 星号 |
|---|---|---|---|---|---|---|
| 无提示词 | — | 1403 | 0 | 5.5 | 0 | **2/2** |
| v6 | 814 | 561 | 0 | 2.5 | 0 | **2/2** |
| v7 | 1116 | 280 | 2.0 | 2.0 | 0 | 0 |
| v8 | 1202 | 204 | 2.5 | 2.2 | 1.5 | 0 |
| v9 | 1289 | 199 | 2.5 | 2.2 | 0.2 | 0 |
| **v11** | **642** | 211 | 2.8 | 2.8 | 1.0 | 0 |
| **v15**（引用块） | **666** | 202 | 1.5 | 3.5 | 1.2 | 0 |
| 目标 | — | 80–140 | ≤2 | 2–3 | 0 | 0 |

要点：
1. **无提示词时输出 1403 字全英文 ST 格式** —— 卡片本体是英文 ST 卡，few-shot 会把模型拽回英文
2. **v6 残留星号** —— 卡里 `mes_example` 满是 `*星号*` 示例，**模型模仿示例 > 遵守规则**
3. **v7 起星号归零** —— "不用星号" + "不用引号"两条同时给出才生效
4. **v8 把字数压掉 85%**，但比喻式解说残留多
5. **v9 把情绪解说压到 0.2**，靠的是把"像是在…一样"句式单独列为禁令并给正反例
6. **长 ≠ 好**：v11（642 字符）指标全面不劣于 v9（1289 字符）。v11 删掉【推荐的结构】后反而修好了 v6 的"六组机械交替"病根
7. **v15 引用块生效**（1.5 块/轮，格式正确），但有 **1/4 采样踩「引用块后未空行」坑** → 见 md_probe 一节

## ⚠️ 两个已修的工具坑

1. **`load_prompt` 取错代码块**（已修）：原实现取文档里第一个 ``` 块。遇到文档把示例（```dart）或引用块内的 ``` 排在提示词之前时会静默取错——**v15 首次实测因此完全失效**（喂给模型的是 Dart 源码，输出 1298 字英文），v5 也一直取错。
   现按「『## 直接复制这段』之后的块 → 第一个无语言标记块 → 第一个块」定位，正则锚定行首。
   **约定：提示词文档的正文必须放在第一个代码块。**
2. **分析器误报**（已修）：`情绪词 + 地 + 动词`（如"得意地扬起下巴"）属动作方式，原先被误判成情绪解说。
3. **多条 system 被模板拒收**（已修，2026-09-17）：App 的拼装会连发 5 条 system（提示词 + 卡片各 section），
   Qwen 系模板只允许第一条是 system，直接 `raise_exception('System message must be at the beginning.')` → **HTTP 500**。
   现在 `MERGE_SYSTEM = True`：把开头连续的多条 system 合并成一条再发（文本不丢，仅本地测试台行为，App 不变）。
4. **思考模型答不出来**（已修，2026-09-17）：Qwen3.5-4B 会把 token 全烧在 thinking 里，
   `max_tokens` 给到 3000 时 `content` 仍是空串。现在 `NO_THINK = True`，
   请求体带 `chat_template_kwargs: {"enable_thinking": false}`（Gemma 等非思考模型会忽略该字段）。
5. **`run()` 从不传 seed**（已修，2026-09-17）：导致历史所有对照都是无种子随机采样，
   n=5 的方差足以翻转结论（见上节表格）。现在 `--seed N` 启用配对采样；
   `ALLOW_SEED=0`（DeepSeek 走这个）时不下发 seed 字段，避免线上 API 报未知参数。


## 通知迁移脚本（`tools/migrate_snackbar_to_toast.py`）

把 `ScaffoldMessenger.showSnackBar(SnackBar(content: Text(x)))` 批量改成
`AppToast.show(context, x)`（见 `lib/presentation/widgets/app_toast.dart`）。

```bash
python tools/migrate_snackbar_to_toast.py            # 干跑（默认），只打印统计
python tools/migrate_snackbar_to_toast.py --apply    # 落盘
python tools/migrate_snackbar_to_toast.py --repair --apply   # 修复早期版本留下的 ;; 与 import 位置
```

规则与边界：

| 情况 | 处理 |
|---|---|
| 非首条 `system` 之外的普通通知 | 转换 |
| 带 `action:` 的 SnackBar（撤销 / 打开系统设置） | **保留**，toast 不可点击 |
| `backgroundColor: Colors.red` | → `AppToast.error` |
| `backgroundColor: <cond> ? Colors.orange : Colors.green` | → `kind: <cond> ? AppToastKind.error : AppToastKind.success` |
| `behavior:` | 丢弃（toast 自己定位） |
| 显式 `duration:` | 保留；缺失的落到 `AppToast.defaultDuration`（1.8 s） |
| receiver 是变量（`messenger.showSnackBar`）或级联 `..showSnackBar` | 跳过并报告，手工改 |

**坑（踩过的）：**

1. 替换区间只到 `showSnackBar(...)` 的右括号，**不要在生成文本里再带一个 `;`** —— 否则出现 `;;`（149 处全中）。
2. `ScaffoldMessenger.of(\n context,\n)` 这种多行写法取出的 ctx 带尾逗号，会拼出 `context,,`。
   取 `of()` 的首个顶层实参，不要直接 `strip()`。
3. `ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(...)` 是级联，前面那个
   `..hideCurrentSnackBar()` 会让 receiver 回溯落到 `hideCurrentSnackBar` 上 → 报
   `unexpected callee`，属正常跳过。
4. 调用本地私有 helper（如 `chat_screen._showSnackBar(msg)`）的行会被 `showSnackBar(` 正则误命中，
   报 `unexpected receiver`。**只需改 helper 本体，调用点自动生效**，这类"跳过"是噪音。
5. `MaterialApp` 内部的 `ScaffoldMessenger` 在 `builder` **外层**，所以 builder 里的控件能 `ScaffoldMessenger.of`
   但拿不到 `Overlay`（Overlay 在 Navigator 内层）。这类调用点走 `AppToast.rootOverlayResolver`
   （由 `app.dart` 指向 `app_router.rootNavigatorKey`）。

**验收方法（证明零回归）：**

```bash
flutter analyze lib > after.txt            # 1) 静态分析
git stash push -m verify -- lib/           # 2) 同一份代码回退到改动前
flutter analyze lib > before.txt
git stash pop
# 3) 按 (文件, lint码) 计数做差集，应无新增；再同样跑一遍 flutter test 对比失败清单
```


