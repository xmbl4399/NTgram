#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
NTgram RP 提示词离线测试台

直接调用本地 llama.cpp (http://127.0.0.1:9931)，完整复刻 NTgram 的 messages 拼装，
并自动统计输出格式指标（描写块数 / 台词行数 / 字数 / 情绪解说命中）。

用法：
  python tools/llm_rp_test.py                          # 用 v8 提示词跑默认测试
  python tools/llm_rp_test.py --prompt docs/system_prompt_v8.md
  python tools/llm_rp_test.py --msg "你还好吗？" --n 3
  python tools/llm_rp_test.py --raw                    # 打印完整 messages 供核对
"""
import argparse
import json
import os
import re
import struct
import sys
import time
import base64
import urllib.request

sys.stdout.reconfigure(encoding='utf-8', errors='replace')

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# 端点可用环境变量覆盖，便于同一套用例在本地小模型与线上大模型之间切换：
#   NTGRAM_TEST_API / NTGRAM_TEST_KEY / NTGRAM_TEST_MODEL
# 例（DeepSeek 官方）：
#   export NTGRAM_TEST_API=https://api.deepseek.com/chat/completions
#   export NTGRAM_TEST_KEY=sk-xxx
#   export NTGRAM_TEST_MODEL=deepseek-chat
#   export NTGRAM_TEST_MERGE_SYSTEM=0   # 大模型模板不受限，用 App 原生拼装更真实
#   export NTGRAM_TEST_NO_THINK=0       # 非 Qwen 思考模型不需要关思考
API = os.environ.get('NTGRAM_TEST_API', 'http://127.0.0.1:9931/v1/chat/completions')
KEY = os.environ.get('NTGRAM_TEST_KEY', '12345678')
MODEL = os.environ.get('NTGRAM_TEST_MODEL', 'D:\\llama\\Gemma-4-E4B.gguf')

DEFAULT_CARD = r'D:\HONOR Share\Honor Share\AQUA _ The Useless Goddess.card.png'
DEFAULT_MSG = '你还好吗？'


# ---------------------------------------------------------------- 角色卡读取
def read_card(path):
    """从 ST 卡片 PNG 的 tEXt:chara chunk 读出 JSON（纯 struct，不依赖 PIL）"""
    data = open(path, 'rb').read()
    if data[:8] != b'\x89PNG\r\n\x1a\n':
        raise SystemExit('不是 PNG 文件')
    i, found = 8, None
    while i < len(data):
        ln = struct.unpack('>I', data[i:i + 4])[0]
        typ = data[i + 4:i + 8].decode('latin-1')
        body = data[i + 8:i + 8 + ln]
        if typ == 'tEXt':
            kw, _, val = body.partition(b'\x00')
            if kw.decode('latin-1').lower() in ('chara', 'ccv3'):
                found = val
                break
        if typ == 'IEND':
            break
        i += 12 + ln
    if not found:
        raise SystemExit('卡片里没有 chara chunk')
    return json.loads(base64.b64decode(found).decode('utf-8'))


def process_macros(text, char_name, user_name='You'):
    return text.replace('{{char}}', char_name).replace('{{user}}', user_name)


# ------------------------------------------------------- 系统提示词从 md 提取
def load_prompt(path):
    """从 .md 提取提示词正文；.txt 取全文。

    定位顺序（防呆：文档里可能有 ```dart / ```json 示例块、或 **引用块内的** ``` 排在前头）：
      1) 「## 直接复制这段」标题之后的第一个代码块
      2) 第一个**无语言标记**的代码块
      3) 第一个代码块

    正则一律锚定行首（re.M），否则 `> ``` ` 这种引用块里的围栏会被误匹配。
    """
    FENCE = r'^```([a-zA-Z]*)[ \t]*\n(.*?)\n^```'
    txt = open(path, encoding='utf-8').read()
    if path.endswith('.md'):
        for marker in ('## 直接复制这段', '## 复制这段', '## 提示词正文'):
            i = txt.find(marker)
            if i >= 0:
                m = re.search(FENCE, txt[i:], re.S | re.M)
                if m:
                    return m.group(2).strip()
        for m in re.finditer(FENCE, txt, re.S | re.M):
            if not m.group(1).strip():
                return m.group(2).strip()
        m = re.search(FENCE, txt, re.S | re.M)
        if m:
            return m.group(2).strip()
    return txt.strip()


# ------------------------------------------------------------ messages 拼装
def build_messages(card, system_prompt, post_history, user_msg, history=None):
    """完全复刻 NTgram chat_providers._buildSectionMessages 的顺序"""
    name = card.get('name', 'Assistant')
    msgs = []

    # order 0: systemPrompt
    msgs.append({'role': 'system', 'content': process_macros(system_prompt, name)})
    # order 2: characterDescription
    if card.get('description'):
        msgs.append({'role': 'system',
                     'content': 'Description:\n' + process_macros(card['description'], name)})
    # order 3: characterPersonality
    if card.get('personality'):
        msgs.append({'role': 'system',
                     'content': 'Personality:\n' + process_macros(card['personality'], name)})
    # order 4: characterScenario
    if card.get('scenario'):
        msgs.append({'role': 'system',
                     'content': 'Scenario:\n' + process_macros(card['scenario'], name)})
    # order 5: exampleMessages
    if card.get('mes_example'):
        msgs.append({'role': 'system',
                     'content': 'Example dialogue:\n' + process_macros(card['mes_example'], name)})
    # order 8: chatHistory —— 开场白
    if history:
        msgs.extend(history)
    elif card.get('first_mes'):
        msgs.append({'role': 'assistant',
                     'content': process_macros(card['first_mes'], name)})
    # 用户输入
    if user_msg:
        msgs.append({'role': 'user', 'content': user_msg})
    # order 10: postHistoryInstructions
    if post_history:
        msgs.append({'role': 'system', 'content': process_macros(post_history, name)})
    return merge_leading_system(msgs)


# llama.cpp 上部分模型的 jinja 模板（如 Qwen3.5）只允许**第一条**是 system，
# 见到第二条 system 就 `raise_exception('System message must be at the beginning.')` → HTTP 500。
# 本 App 的拼装会连发多条 system（提示词 + 卡片的 5 个 section），
# 所以测试台默认把「开头连续的多条 system」合并成一条（文本不丢），
# 让 Gemma / Qwen 两种模板都能跑。设 MERGE_SYSTEM=False 可还原 App 的原始拼装。
MERGE_SYSTEM = os.environ.get('NTGRAM_TEST_MERGE_SYSTEM', '1') == '1'
# 见 chat() 注释：思考模型需关思考才能拿到正文
NO_THINK = os.environ.get('NTGRAM_TEST_NO_THINK', '1') == '1'
# 部分线上 API（如 DeepSeek 官方）不接受 seed 字段，设 0 时不下发
ALLOW_SEED = os.environ.get('NTGRAM_TEST_ALLOW_SEED', '1') == '1'


def merge_leading_system(msgs):
    if not MERGE_SYSTEM:
        return msgs
    out, head = [], []
    for m in msgs:
        if m['role'] == 'system' and not out:
            head.append(m['content'])
        else:
            out.append(m)
    if len(head) <= 1:
        return msgs
    return [{'role': 'system', 'content': '\n\n'.join(head)}] + out


# ------------------------------------------------------------------ API 调用
def chat(messages, temperature=0.7, top_p=0.95, max_tokens=1024, seed=None):
    payload = {
        'model': MODEL,
        'messages': messages,
        'temperature': temperature,
        'top_p': top_p,
        'max_tokens': max_tokens,
        'stream': False,
    }
    # Qwen3.5 / Qwen3 这类「思考模型」在 llama.cpp 上会把 token 全烧在 thinking 里，
    # content 一直是空串（3000 token 也答不出来）。显式关掉思考才能拿到正文。
    # 换回 Gemma 等非思考模型时该字段会被忽略，无副作用。
    if NO_THINK:
        payload['chat_template_kwargs'] = {'enable_thinking': False}
    if seed is not None and ALLOW_SEED:
        payload['seed'] = seed
    req = urllib.request.Request(
        API,
        data=json.dumps(payload).encode('utf-8'),
        headers={'Content-Type': 'application/json',
                 'Authorization': f'Bearer {KEY}'},
    )
    t0 = time.time()
    with urllib.request.urlopen(req, timeout=600) as r:
        d = json.loads(r.read().decode('utf-8'))
    return d['choices'][0]['message']['content'], time.time() - t0, d.get('usage', {})


# ---------------------------------------------------------------- 输出统计
RE_KAOMOJI = re.compile(r'^[（(]内心\s*os\s*[:：].*[）)]$', re.S)
RE_PAREN = re.compile(r'^[（(].*[）)]$', re.S)
# v22 起：动作 / 神态 / 环境整段用 * 包住（对齐 SillyTavern 社区写法）
RE_STAR = re.compile(r'^\*[^*\n]+\*$', re.S)
RE_BLANK = re.compile(r'^\s*$')

# 情绪解说 / 旁白式描写检测
EMOTION_WORDS = (
    '喜悦|愤怒|得意|紧张|不安|傲慢|满足|期待|兴奋|失落|尴尬|委屈|骄傲|无奈'
    '|犹豫|心虚|恼火|烦躁|惊讶|震惊|悲伤|恐惧|厌恶|欣慰|怜悯|愧疚|嫉妒'
    '|被重视|被认可|被肯定|被冒犯|被忽视'
)
NARRATION_PATTERNS = [
    (r'带着.{0,8}的(表情|神情|神色|笑意|弧度)', '表情解说'),
    (r'(眼神|眼中|眼里|眼眸|眸子|眼底|目光|视线).{0,8}(充满|闪过|带着|流露|透着|移开|瞥)', '眼神解说'),
    (r'像是(刚刚)?(经历|遭遇|承受)', '比喻式解说'),
    (r'(语气|声音|语调|嗓音|哭腔).{0,6}(一|骤|微)(转|变|收|敛)', '语气解说'),
    (r'丝毫(没有|未减|不减|不弱)', '程度解说'),
    (r'取而代之的是', '转折解说'),
    (r'(透露出|流露出|诉说着)', '心理解说'),
    # 描写块内只要出现推测引导词即为解说（"像是在确认" "像是评估着" 都要抓；
    # 此规则仅在 kind == '描写' 的行上生效，不会误伤台词里的"好像"）
    (r'(像是|仿佛|似乎|好像)', '比喻/推测式'),
    (r'带着.{0,10}的(意味|感觉|气息|氛围|态度|神气)', '意味解说'),
    (r'(那份|这一切|这种).{0,10}(劲儿|气焰|傲气|心情|情绪)', '抽象概括'),
    (r'(情绪|心情).{0,6}(波动|起伏|变化)', '情绪概括'),
    (r'(显得|看上去|看起来|似乎)(很|有点|非常|格外|格外地)', '评价式解说'),
]
# 括号描写里出现情绪词即记为解说（模型应写动作而非情绪标签）
RE_EMO_IN_PAREN = re.compile(EMOTION_WORDS)


def analyze(text):
    lines = text.split('\n')
    blocks = []          # (kind, line, nchars)
    for raw in lines:
        s = raw.strip()
        if not s:
            continue
        if s.startswith('>'):
            body = s.lstrip('>').strip()
            blocks.append(('引用台词', body, len(body)))
        elif RE_STAR.match(s):
            # `*动作*` 整行包裹 → 描写块（v22 起的 ST 写法）
            blocks.append(('描写', s, len(s)))
        elif RE_KAOMOJI.match(s) or RE_PAREN.match(s):
            # （……）→ 内心（v22 起）；v20 及更早的（动作）也会落这里，跨版本别比这一列
            blocks.append(('内心', s, len(s)))
        else:
            blocks.append(('台词', s, len(s)))

    # 引用块后未空行 → 下一段正文会被解析器吸进引用块（Markdown lazy continuation）
    quote_swallow = 0
    for idx, raw in enumerate(lines):
        if not raw.strip().startswith('>'):
            continue
        nxt = lines[idx + 1] if idx + 1 < len(lines) else ''
        if nxt.strip() and not nxt.strip().startswith('>'):
            quote_swallow += 1
    # 引用块个数（连续 > 行算一块）
    n_quote = 0
    prev_is_quote = False
    for raw in lines:
        is_q = raw.strip().startswith('>')
        if is_q and not prev_is_quote:
            n_quote += 1
        prev_is_quote = is_q

    narr_hits = []
    for kind, s, _ in blocks:
        if kind != '描写':
            continue
        for pat, label in NARRATION_PATTERNS:
            m = re.search(pat, s)
            if m:
                narr_hits.append((label, m.group(0)))
        for m in RE_EMO_IN_PAREN.finditer(s):
            # 排除副词用法（情绪词 + 地 + 动词 = 动作方式，可接受）
            tail = s[m.end():m.end() + 2]
            if tail.startswith('地'):
                continue
            narr_hits.append(('情绪标签', m.group(0)))

    # 角色名前缀泄漏（如 `Aqua: "..."` / `Aqua | The Useless Goddess: "..."`）
    name_prefix = bool(re.search(r'^[\w\s|]*(Aqua|{{char}})[\w\s|]*\s*[:：]', text, re.M))

    total = len(re.sub(r'\s', '', text))
    d_blocks = [b for b in blocks if b[0] == '描写']

    # 裸星号：出现 * 但没构成"整行被 * 包住"的规范写法 → 渲染层会露出星号
    bare_star_lines = 0
    for raw in lines:
        s = raw.strip()
        if '*' not in s:
            continue
        if RE_STAR.match(s) and s.count('*') == 2:
            continue
        bare_star_lines += 1

    return {
        'total_chars': total,
        'blocks': blocks,
        'n_desc': len(d_blocks),
        'n_line': sum(1 for b in blocks if b[0] in ('台词', '引用台词')),
        'n_quote': n_quote,
        'quote_swallow': quote_swallow,
        'n_inner': sum(1 for b in blocks if b[0] == '内心'),
        'desc_lens': [b[2] for b in d_blocks],
        'max_desc': max([b[2] for b in d_blocks], default=0),
        'narration': narr_hits,
        'name_prefix': name_prefix,
        'bare_star': bare_star_lines,
        'has_star': bare_star_lines > 0,
        'has_backtick': '`' in text,
        'has_english': len(re.findall(r'\b[a-zA-Z]{4,}\b', text)) > 2,
    }


def report(text, stats, elapsed, usage):
    bar = '─' * 66
    print(f'\n{bar}\n原始输出\n{bar}')
    print(text)
    print(f'{bar}\n指标\n{bar}')
    print(f'总字数          : {stats["total_chars"]}')
    print(f'描写块          : {stats["n_desc"]}  长度 {stats["desc_lens"]}   最长 {stats["max_desc"]}')
    print(f'台词行          : {stats["n_line"]}')
    if stats.get('n_quote'):
        print(f'引用块          : {stats["n_quote"]} 个')
        print(f'引用块后吞行    : {stats["quote_swallow"]} 处 {"✗" if stats["quote_swallow"] else "✓"}')
    print(f'内心行          : {stats["n_inner"]}')
    print(f'裸星号(未成对)  : {"是 ✗ %d 行" % stats.get("bare_star", 0) if stats["has_star"] else "否 ✓"}')
    print(f'反引号残留      : {"是 ✗" if stats["has_backtick"] else "否 ✓"}')
    print(f'英文残留        : {"是 ✗" if stats["has_english"] else "否 ✓"}')
    print(f'角色名前缀泄漏  : {"是 ✗" if stats["name_prefix"] else "否 ✓"}')
    if stats['narration']:
        print(f'情绪解说命中    : {len(stats["narration"])} 处 ✗')
        for label, s in stats['narration']:
            print(f'    [{label}] {s}')
    else:
        print('情绪解说命中    : 0 ✓')
    print(f'耗时            : {elapsed:.1f}s   tokens: {usage}')


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--prompt', default='docs/system_prompt_v8.md',
                    help='系统提示词文件（.md 取代码块 / .txt 取全文）')
    ap.add_argument('--neutral', action='store_true',
                    help='不加载任何系统提示词（对照基线，用 getDefaultContent 的英文默认）')
    ap.add_argument('--card', default=DEFAULT_CARD)
    ap.add_argument('--msg', default=DEFAULT_MSG)
    ap.add_argument('--n', type=int, default=1, help='重复采样次数')
    ap.add_argument('--temp', type=float, default=0.7)
    ap.add_argument('--max-tokens', type=int, default=1024)
    ap.add_argument('--raw', action='store_true', help='打印完整 messages 后退出')
    ap.add_argument('--no-personality', action='store_true',
                    help='跳过 personality 字段（它在本卡里是 4096 字符 HTML 垃圾）')
    args = ap.parse_args()

    card = read_card(args.card)
    print(f'角色卡: {card.get("name")}  (description {len(card.get("description",""))} / '
          f'personality {len(card.get("personality",""))} / '
          f'scenario {len(card.get("scenario",""))} / '
          f'first_mes {len(card.get("first_mes",""))} / '
          f'mes_example {len(card.get("mes_example",""))})')

    if args.no_personality:
        card.pop('personality', None)
        print('  ⚠ 已跳过 personality 字段')

    if args.neutral:
        system_prompt = ''
        post_history = ''
        print('模式: 中性对照（无系统提示词）')
    else:
        path = os.path.join(ROOT, args.prompt) if not os.path.isabs(args.prompt) else args.prompt
        system_prompt = load_prompt(path)
        post_history = ''
        print(f'提示词: {path}  ({len(system_prompt)} 字)')

    msgs = build_messages(card, system_prompt, post_history, args.msg)
    # 去掉空 system
    msgs = [m for m in msgs if m['content'].strip()]

    print(f'\n=== messages ({len(msgs)} 条) ===')
    for i, m in enumerate(msgs):
        c = m['content']
        preview = c.replace('\n', ' ⏎ ')
        print(f'[{i}] {m["role"]:9s} {len(c):6d} 字 | {preview[:90]}{"..." if len(preview) > 90 else ""}')

    if args.raw:
        print('\n=== FULL DUMP ===')
        for i, m in enumerate(msgs):
            print(f'\n---- [{i}] {m["role"]} ----\n{m["content"]}')
        return

    for k in range(args.n):
        if args.n > 1:
            print(f'\n{"="*66}\n第 {k+1}/{args.n} 次采样\n{"="*66}')
        text, el, usage = chat(msgs, temperature=args.temp,
                               max_tokens=args.max_tokens, seed=None)
        report(text, analyze(text), el, usage)


if __name__ == '__main__':
    main()
