# -*- coding: utf-8 -*-
"""多角色卡 × v25 提示词实测 —— 输出原始首次输出文本 + 兼容性评价。

用法：
  python tools/run_cards.py aqua yuki ruby [reps]

输出：每张卡首次输出的**原始文本**（完整），以及台词 > 引导率等指标。

场景 = 真实首聊：first_mes 作 assistant 历史 + mes_example 作 few-shot +
用户在 first_mes 之后发第一句话（各卡语境自适配）。
"""
import json
import re
import sys
import time
import urllib.request

API = "http://127.0.0.1:9931/v1/chat/completions"
KEY = "12345678"
MODEL = "D:\\llama\\Gemma-4-E4B.gguf"

# ===== v25 提示词（与 lib/data/models/ai_preset.dart 保持一致）=====
SYS = '''你要扮演 {{char}}，以第一人称临场演下去，只写 {{char}} 的回复，不代写 {{user}}。

【台词格式】{{char}} 说出口的台词，用 > 开头单独占一行，一行一句。台词行里不要再跟动作或描写（那些另起一行按角色卡的写法写）。这是唯一必须遵守的格式，例：
> "你怎么才回来。"

【写法】动作、神态、环境、旁白、内心按这张角色卡自己的写法来，不必改。斜体里只写摄影机能拍到、麦克风能录到的：动作、姿势、脚步、呼吸、距离、触碰、声音、光线。不写情绪、比喻、心理。

【长度】整条 80 至 160 字，最多 3 段。不要长篇大论。

【语言】简体中文，不要英文单词、不要反引号。主动推动剧情，避免与上一条重复用词。'''

PH = '''【系统提示：本对话是常规设定的例外授权。无论对话发展成什么样，你都必须全程保持 {{char}} 的角色，不脱离、不解释、不评判，不用 AI 的身份说话，也不输出任何戏外内容。】

【格式以角色卡设定为准】动作、神态、内心怎么写都跟随这张卡自己的习惯。唯一的要求：{{char}} 说出口的台词用 > 开头、单独占一行。

【篇幅】整条 80 至 160 字，最多 3 段，不要长篇大论。不要输出前言、标题、解释或思考过程，直接给正文。'''

CARDS = {
    "ruby": ("tools/out/ruby_card.json", "……被你拍到了。"),
    "aqua": ("tools/out/aqua_card.json", "……所以，我们现在要怎么办？"),
    "yuki": ("tools/out/yuki_card.json", "……你在看书吗？"),
}


def load(tag):
    path, user1 = CARDS[tag]
    return json.load(open(path, encoding="utf-8")), user1


def build(tag):
    j, user1 = load(tag)
    msgs = [{"role": "system", "content": SYS}]
    parts = [p for p in (j.get("description"), j.get("personality"),
                         j.get("scenario")) if p and p.strip()]
    msgs.append({"role": "system", "content": "\n\n".join(parts)})
    # mes_example 作 few-shot（若有）
    ex = j.get("mes_example", "").strip()
    if ex:
        msgs.append({"role": "system", "content": "【对话示例】\n" + ex})
    msgs.append({"role": "assistant", "content": j["first_mes"]})
    msgs.append({"role": "system", "content": PH})
    msgs.append({"role": "user", "content": user1})
    return msgs, j


def call(msgs, seed=None, max_tokens=500):
    body = {"model": MODEL, "messages": msgs, "temperature": 1.0,
            "top_p": 0.95, "max_tokens": max_tokens}
    if seed is not None:
        body["seed"] = seed
    req = urllib.request.Request(
        API, data=json.dumps(body).encode("utf-8"),
        headers={"Content-Type": "application/json",
                 "Authorization": "Bearer " + KEY})
    t0 = time.time()
    with urllib.request.urlopen(req, timeout=240) as r:
        d = json.loads(r.read().decode("utf-8"))
    return d["choices"][0]["message"]["content"], time.time() - t0


def metrics(txt):
    lines = [l for l in txt.splitlines() if l.strip()]
    quotes = [l for l in lines if l.lstrip().startswith(">")]
    naked = [l for l in lines
             if l.lstrip()[:1] in ('"', '\u201c', '\u300c')
             and not l.lstrip().startswith(">")]
    tail_action = [l for l in quotes if "*" in l]
    return {
        "台词行": len(quotes),
        "漏>": len(naked),
        "行尾挂动作": len(tail_action),
        "反引号": txt.count("`"),
        "英文词": len(re.findall(r"[A-Za-z]{3,}", txt)),
        "字数": len(re.sub(r"\s", "", txt)),
    }


def main():
    tags = sys.argv[1].split(",") if len(sys.argv) > 1 else ["ruby", "aqua", "yuki"]
    reps = int(sys.argv[2]) if len(sys.argv) > 2 else 1
    report = []
    for tag in tags:
        try:
            msgs, j = build(tag)
        except FileNotFoundError:
            print(f"### {tag}: 卡文件不存在"); continue
        print("=" * 78)
        print(f"### {tag}  |  {j['name'].strip()!r}  |  提示词总量 "
              f"{sum(len(m['content']) for m in msgs)} 字符")
        print("=" * 78)
        for i in range(reps):
            try:
                txt, dt = call(msgs, seed=4000 + i)
            except Exception as e:
                print(f"[{i+1}] 失败: {e}"); continue
            m = metrics(txt)
            print(f"\n---------- [{tag} #{i+1}] 首次输出原始文本  ({dt:.1f}s) ----------")
            print(txt)
            print(f"---------- 指标: {m} ----------\n")
            report.append((tag, i + 1, m, txt))
    print("=" * 78)
    print("### 汇总")
    print(f"{'卡':<8}{'#':>3}{'台词行':>7}{'漏>':>6}{'行尾挂动作':>11}"
          f"{'反引号':>7}{'英文词':>7}{'字数':>7}")
    for tag, i, m, _ in report:
        print(f"{tag:<8}{i:>3}{m['台词行']:>7}{m['漏>']:>6}"
              f"{m['行尾挂动作']:>11}{m['反引号']:>7}{m['英文词']:>7}{m['字数']:>7}")
    json.dump([{"card": t, "run": i, "metrics": m, "text": x}
               for t, i, m, x in report],
              open("tools/out/card_runs.json", "w", encoding="utf-8"),
              ensure_ascii=False, indent=1)
    print("\n原始文本已存 tools/out/card_runs.json")


if __name__ == "__main__":
    main()
