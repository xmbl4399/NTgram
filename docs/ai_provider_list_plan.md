# AI 配置「默认提供商列表」改造方案 v3

> v3 相对 v2 的变更：**① 引入中转站真实 token 消耗数据做重排依据**；**② 新增腾讯混元（v2 完全缺失）**；
> **③ 给出两套排序供你选**；**④ 修正 v2 里 Qwen / MiMo / MiniMax 的错位**。
> 状态：**✅ 用户已选方案 B，代码已落地（2026-09-16，未 commit、未发版）。**
> 实际写入顺序见 `ai_config_screen.dart` 的 `_orderedProviders` 常量。

---

## ✅ 最终采纳（方案 B 已落地）

| # | 枚举值 | 提供商 | Base URL | 默认模型 | 单价 / 1M |
|---|---|---|---|---|---|
| 1 | `openAICompatible` | OpenAI 兼容（自定义） | `http://localhost:8080/v1` | （空） | 自备 |
| 2 | `deepSeek` | DeepSeek 深度求索 | `https://api.deepseek.com/v1` | `deepseek-flash` | $0.14 / $0.28 |
| 3 | `tencentHunyuan` | **腾讯混元（本次新增）** | `https://api.hunyuan.cloud.tencent.com/v1` | `hunyuan-turbos` | ¥0.8 / ¥2 |
| 4 | `zai` | 智谱 GLM (Z.ai) | `https://open.bigmodel.cn/api/paas/v4` | `glm-5.3-flash` | ¥0.8 / ¥2.8 |
| 5 | `xiaomiMiMo` | 小米 MiMo | `https://api.xiaomimimo.com/v1` | `mimo-v2.5` | 比 -pro 便宜约 3 倍 |
| 6 | `miniMax` | MiniMax | `https://api.minimaxi.com/v1` | `MiniMax-M3` | $0.30 / $1.20 |
| 7 | `moonshot` | Kimi Moonshot | `https://api.moonshot.cn/v1` | `kimi-k2.5` | ¥4 / ¥21 |
| 8 | `qwen` | 通义千问 Qwen | `https://dashscope.aliyuncs.com/compatible-mode/v1` | `qwen3.8-flash` | ¥0.8 / ¥2.7 |
| 9 | `siliconFlow` | 硅基流动 SiliconFlow | `https://api.siliconflow.cn/v1` | `deepseek-ai/DeepSeek-V4-Flash` | — |
| 10 | `openRouter` | OpenRouter | `https://openrouter.ai/api/v1` | `z-ai/glm-5.3-flash` | $0.15 / $0.50 |
| 11 | `openai` | OpenAI | `https://api.openai.com/v1` | `gpt-5.6-luna` | $0.20 / $1.20 |
| 12 | `claude` | Anthropic Claude | `https://api.anthropic.com` | `claude-haiku-4-5` | $1 / $5 |
| 13 | `gemini` | Google Gemini | `https://generativelanguage.googleapis.com/v1` | `gemini-3.8-flash` | $0.75 / $3.75（首发价） |
| 14 | `ollama` | Ollama（本地） | `http://localhost:11434` | `llama3.2` | 本地 |
| 15 | `koboldCpp` | KoboldCpp（本地） | `http://localhost:5001` | （空） | 本地 |

> **默认模型一律取各家的 flash / 低价档（2026-09-16 更新）**，不再填旗舰。原则：新装机默认花几分钱，
> 想升级自己从配置页拉 `/models` 列表选。三处例外说明：
> - `MiniMax-M3` —— 它本身就是 M 系列唯一在售型号，同时也是最便宜的一档（$0.30/$1.20），无下探空间。
> - `kimi-k2.5` —— K3 虽新但**拒收 temperature/top_p**（本应用恒定发送），K2.5 是既便宜又协议兼容的档位。
> - `hunyuan-turbos` —— 更便宜的 `hunyuan-lite` 免费但能力太弱，不适合 RP 场景；Hy4 preview 是旗舰。

落地文件：`llm_service.dart`（枚举追加 `tencentHunyuan` + 5 处 switch）·
`settings_providers.dart`（URL / 模型 / 错误文案 switch）·
`ai_config_screen.dart`（`_orderedProviders` 重排 + 名称 / 描述）·
`tool_generation_loop.dart`（工具调用适配器）。

---

## 0. 数据口径

- 来源：中转站（OpenRouter 类聚合平台）「Model rankings by tokens processed」Top 20。
- 第三列是**环比增幅**，不是份额（有 `new` 值、有 133%，份额不可能是这量级）。
- Top 20 样本合计 **≈ 100.4T tokens**，下文百分比均以该合计为分母。

---

## 1. 热度分析

### 1.1 按厂商汇总（这是排序依据）

| 排名 | 厂商 | 入榜模型数 | 合计 tokens | 占比 | 国模 |
|---|---|---|---|---|---|
| 1 | **DeepSeek** | 4 | **25.28T** | 25.2% | ✅ |
| 2 | OpenAI | 2 | 19.14T | 19.1% | — |
| 3 | **腾讯混元 Tencent** | 2 | **17.89T** | 17.8% | ✅ |
| 4 | **智谱 Z.ai (GLM)** | 3 | **15.15T** | 15.1% | ✅ |
| 5 | **小米 MiMo** | 1 | **7.96T** | 7.9% | ✅ |
| 6 | NVIDIA | 1 | 3.41T | 3.4% | — |
| 7 | Google | 1 | 2.43T | 2.4% | — |
| 8 | Meta | 1 | 1.96T | 2.0% | — |
| 9 | Upstage | 1 | 1.69T | 1.7% | — |
| 10 | Anthropic | 1 | 1.47T | 1.5% | — |
| 11 | **MiniMax** | 1 | **1.45T** | 1.4% | ✅ |
| 12 | **月之暗面 Kimi** | 1 | **1.40T** | 1.4% | ✅ |
| 13 | Poolside | 1 | 1.15T | 1.1% | — |

**国模合计 69.13T / 68.9%；国外合计 31.25T / 31.1%。Top 20 里 12 席（60%）是国模。**

### 1.2 三条结论

1. **国模在中转站已占三分之二以上消耗**。这个 app 面向国内用户，「国内优先」的排序原则被数据验证了。
2. **腾讯混元是国模第二（17.89T），而我们的列表里根本没有它** —— 这是 v2 方案最大的遗漏。
   且混元有 `hunyuan-role-latest`（腾讯官方**角色扮演**模型），对一个 RP 应用是天然的强项项。
3. **通义千问在 Top 20 里零席**。Qwen 开源下载量极大，但中转站 token 消耗榜上完全看不到
   —— 说明它的消耗集中在百炼/火山自建渠道，而不是中转站。当前列表把 Qwen 排在国产第 2 位（仅次于 DeepSeek）**是虚高的**。

### 1.3 增速信号（环比）

| 模型 | 增幅 | 读法 |
|---|---|---|
| **MiMo-V2.5** | **+133%** | 全榜第一，且是新进榜，属爆发期 |
| GLM 5.2 | +39% | 老版本仍在放量 |
| GLM 5.3 | +33% | 新旗舰爬坡快 |
| DeepSeek V4 Pro 0423 | +30% | — |
| Hy4 preview | +27% | 混元新旗舰，与我们新增决策同向 |
| Kimi K3 | +27% | 但绝对值仅 1.40T |

> 另注：**GLM 5.3 Flash（11.4T）反超 GLM 5.3 全量版（2.26T）5 倍**，说明中转站用户高度价格敏感。
> 本应用是 RP 长文本场景，仍建议默认全量 `glm-5.3`（质量优先），Flash 写进描述文案即可。

---

## 2. 当前列表 vs 数据的 4 个偏差

| # | 现状 | 数据 | 判定 |
|---|---|---|---|
| P1 | 腾讯混元**不存在** | 国模第 2、单模型榜第 2 | **必须补** |
| P1 | Qwen 排国产第 2 | Top 20 **零席** | 降位 |
| P2 | MiMo 排第 8 | 7.96T（国产第 4）、增速 +133% 全榜第一 | 提位 |
| P3 | MiniMax / Kimi 排在 MiMo 前 | 1.45T / 1.40T，均低于 MiMo | 降位 |

---

## 3. 新排序（两套，选一套）

### 方案 A — 纯热度序（严格按厂商 token 降序）

「自定义」作为已拍板的固定槽位保留第 1（不参与热度排序），其余 14 项严格按 token 降序：

```
1  OpenAI 兼容（自定义）  固定槽位
2  DeepSeek              25.28T
3  OpenAI                19.14T
4  腾讯混元               17.89T   ★新增
5  智谱 GLM               15.15T
6  小米 MiMo               7.96T
7  Google Gemini          2.43T
8  Anthropic Claude       1.47T
9  MiniMax                1.45T
10 Kimi Moonshot          1.40T
11 通义千问 Qwen          （榜单外）
12 硅基流动 SiliconFlow    聚合
13 OpenRouter             聚合
14 Ollama                 本地
15 KoboldCpp              本地
```

优点：单一维度、完全可解释，无主观成分。
缺点：**OpenAI 落到第 3 位**，国内用户点进去大概率连不上，体验倒挂；且把「聚合站」排在官方 API 之后，与国内实际访问路径相反。

### 方案 B — 推荐序（热度 × 国内可达性 × 本应用场景）★建议

排序原则：**自定义首位（你已拍板）→ 国模按热度降序 → 国内聚合 → 国际聚合 → 国际官方 → 本地。**

| # | 提供商 | 热度依据 | 变动 |
|---|---|---|---|
| 1 | **OpenAI 兼容（自定义）** | 你已拍板首位 + 首次启动默认 | 保持 |
| 2 | **DeepSeek 深度求索** | 25.3T，厂商第 1 | 保持 |
| 3 | **腾讯混元 Tencent Hunyuan** | 17.9T，国模第 2 + 有 RP 专用模型 | **★新增** |
| 4 | **智谱 GLM (Z.ai)** | 15.2T，3 款入榜 | 保持 |
| 5 | **小米 MiMo** | 7.96T，增速 +133% 全榜第一 | **8 → 5 ↑** |
| 6 | MiniMax | 1.45T | 保持 |
| 7 | Kimi Moonshot | 1.40T | 保持 |
| 8 | **通义千问 Qwen** | Top 20 零席，但国内云厂旗舰、装机量大 | **3 → 8 ↓** |
| 9 | 硅基流动 SiliconFlow | 国内聚合 | 保持 |
| 10 | OpenRouter | 国际聚合（本榜单来源平台） | 保持 |
| 11 | OpenAI | 19.1T，厂商第 2；单模型 GPT-5.6 Luna 17.4T 全榜第 1 | 保持 |
| 12 | Anthropic Claude | 1.47T | 保持 |
| 13 | Google Gemini | 2.43T | 保持 |
| 14 | Ollama（本地） | — | 保持 |
| 15 | KoboldCpp（本地） | — | 保持 |

> 第 10 位 OpenRouter 放在第 11 位 OpenAI 之前是**刻意的**：国内用户要够到 OpenAI/Claude/Gemini，
> 现实中第一条路就是聚合站。数据也印证了这些聚合平台的量级。

**两套只差 4 个位置（混元插入 + MiMo/Qwen 换位），改动量完全相同。**

---

## 4. 新增项：腾讯混元

| 项 | 值 |
|---|---|
| 枚举值 | `tencentHunyuan`（**末尾追加**，预设按 `provider.name` 字符串序列化，安全） |
| Base URL | `https://api.hunyuan.cloud.tencent.com/v1`（官方 OpenAI 兼容接口，已核文档） |
| 默认模型 | `hunyuan-hy4-preview` ⚠️ **ID 需在控制台核对**（腾讯侧命名不统一，落地前用 `GET /v1/models` 确认） |
| 强烈建议写进描述的备选 | `hunyuan-role-latest` —— 腾讯官方**角色扮演**模型，28K 上下文，对本应用是差异化优势 |
| Hy4 preview 规格 | 770B 总参 / 49B 激活 MoE，1M 上下文，Apache 2.0 开源，2026-08-28 发布 |
| 价格 | 输入 ¥6/M（命中缓存 ¥0.3/M）、输出 ¥18/M |
| 接入成本 | **零**，直接并入现有 `_generateOpenAIWithReasoning` 分支 |
| 注意 | ① 官方公告混元兼容接口**正逐步迁移至 TokenHub**，原平台不再新增模型；② 生文接口默认 **5 并发**；③ 需腾讯云实名认证后才可创建 Key |
| 名称 / 描述文案 | `Tencent Hunyuan (腾讯混元)` / `Hy4 preview, Hunyuan Role` |

---

## 5. 改动清单（与 v2 相同的工程量）

| # | 文件 | 改什么 | 量 |
|---|---|---|---|
| 1 | `domain/services/llm_service.dart` | 枚举末尾追加 `tencentHunyuan`；各 switch 补 case | +1 枚举 +5 case |
| 2 | `presentation/providers/settings_providers.dart` | `_getDefaultUrl` / `_getDefaultModel` 加混元 | +2 行 |
| 3 | `presentation/screens/ai_config/ai_config_screen.dart` | **`_orderedProviders` 常量重排**（就是 §3 那张表）；`_providerName` / `_providerDescription` 加混元 | ~12 行 |
| 4 | 其它 switch 文件 | 编译器穷尽性报错逐个补 | ~5 行 |

合计 **5 个文件、约 25 行**（排序本身只动一个 `const List`，零风险）。

---

## 6. 待拍板

| # | 问题 | 我的建议 |
|---|---|---|
| 1 | **选方案 A 还是 B？** | **B**（A 会让 OpenAI 排第 2，国内点进去连不上，体验倒挂） |
| 2 | **是否新增腾讯混元？** | **是**（国模第 2 且缺失，且有 RP 专用模型；接入零成本） |
| 3 | **Qwen 降到第 8 可接受吗？** | 可以。它的量在国内自有渠道，不在中转站；降到国模末尾但不删 |
| 4 | 混元默认给 `hunyuan-hy4-preview` 还是 `hunyuan-role-latest`？ | Hy4 preview（更通用）；Role 写进描述，你 RP 时可手动切 |

**已拍板并已落地（2026-09-16，未 commit）**：OpenAI 恢复显示 · Kimi 默认 `kimi-k2.6` · 自定义首位且为首次启动默认 · P0 名称 bug 与 3 处 `non_exhaustive_switch` 已修。

**仍未决**：v16 提示词（台词走 `>` 引用块）尚未写入 `ai_preset.dart`。
