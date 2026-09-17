#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""多版本 / 多卡片数据 并排对照

用法:
  python tools/prompt_compare.py                  # 提示词版本对照
  python tools/prompt_compare.py --card-data      # 卡片数据对照（mes_example / personality 影响）
  python tools/prompt_compare.py --msg "..." --n 3
"""
import argparse
import os
import statistics
import sys
import importlib.util

sys.stdout.reconfigure(encoding='utf-8', errors='replace')
_here = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location('t', os.path.join(_here, 'llm_rp_test.py'))
T = importlib.util.module_from_spec(spec)
sys.modules['t'] = T
spec.loader.exec_module(T)

PROMPT_VERSIONS = [
    ('无提示词(baseline)', None),
    ('v6 台词独立行', 'docs/system_prompt_v6.md'),
    ('v7 节奏控制', 'docs/system_prompt_v7.md'),
    ('v8 能拍到的东西', 'docs/system_prompt_v8.md'),
    ('v9 去比喻+保台词', 'docs/system_prompt_v9.md'),
    ('v10 精简版', 'docs/system_prompt_v10.md'),
    ('v11 精简+补反例', 'docs/system_prompt_v11.md'),
    ('v12 压输出长度', 'docs/system_prompt_v12.md'),
    ('v13 猫箱一段流', 'docs/system_prompt_v13.md'),
    ('v14 独立行+压长度', 'docs/system_prompt_v14.md'),
    ('v15 台词引用块', 'docs/system_prompt_v15.md'),
    ('v16 只有台词加>', 'docs/system_prompt_v16.md'),
    ('v17 精简+强示例', 'docs/system_prompt_v17.md'),
    ('v18 极简编号', 'docs/system_prompt_v18.md'),
    ('v19 示例先行', 'docs/system_prompt_v19.md'),
    ('v20 精简补空行', 'docs/system_prompt_v20.md'),
    ('v21 补空行后果', 'docs/system_prompt_v21.md'),
    ('v22 ST写法', 'docs/system_prompt_v22.md'),
    ('v23 ST精简', 'docs/system_prompt_v23.md'),
    ('v24 ST极简', 'docs/system_prompt_v24.md'),
    ('v25 ST无示例', 'docs/system_prompt_v25.md'),
    ('v26 ST压动作>', 'docs/system_prompt_v26.md'),
    ('v27 消冲突·删旁白', 'docs/system_prompt_v27.md'),
    ('v28 消冲突·单点声明', 'docs/system_prompt_v28.md'),
    ('v29 双通道明确', 'docs/system_prompt_v29.md'),
]

CARD_VARIANTS = [
    ('完整卡片(原样)', lambda c: c),
    ('去掉 mes_example', lambda c: {k: v for k, v in c.items() if k != 'mes_example'}),
    ('去掉 personality', lambda c: {k: v for k, v in c.items() if k != 'personality'}),
    ('去 mes+persona', lambda c: {k: v for k, v in c.items()
                                  if k not in ('mes_example', 'personality')}),
]


def run(prompt_path, card, msg, n, temp=0.7, seed=None):
    sp = T.load_prompt(os.path.join(T.ROOT, prompt_path)) if prompt_path else ''
    msgs = T.build_messages(card, sp, '', msg)
    msgs = [m for m in msgs if m['content'].strip()]
    runs, first, tok = [], None, 0
    for i in range(n):
        # 配对采样：所有版本的第 i 次共用 seed+i，版本间可逐次比对。
        # 不传 seed 时（None）每轮全新随机，单轮 n=5 的方差足以把结论翻转 —— 别那样比。
        text, el, usage = T.chat(msgs, temperature=temp, max_tokens=900,
                                 seed=None if seed is None else seed + i)
        runs.append(T.analyze(text))
        tok = usage.get('prompt_tokens', 0)
        if i == 0:
            first = text
    return {
        'chars': int(statistics.mean(r['total_chars'] for r in runs)),
        'desc': statistics.mean(r['n_desc'] for r in runs),
        'maxdesc': max(r['max_desc'] for r in runs),
        'line': statistics.mean(r['n_line'] for r in runs),
        'quota': statistics.mean(r.get('n_quote', 0) for r in runs),
        'swallow': sum(1 for r in runs if r.get('quote_swallow')),
        'inner': statistics.mean(r['n_inner'] for r in runs),
        'narr': statistics.mean(len(r['narration']) for r in runs),
        'star': sum(1 for r in runs if r['has_star']),
        'newname': sum(1 for r in runs if r['name_prefix']),
        'eng': sum(1 for r in runs if r['has_english']),
        'tok': tok,
    }, first


HEAD = (f'{"配置":<22} {"tok":>5} {"字数":>6} {"描写块":>7} {"最长描写":>9} '
        f'{"台词行":>7} {"引用块":>7} {"吞行":>5} {"解说":>6} {"裸星号":>6} {"名前缀":>6} {"英文":>5}')


def table(rows, n):
    print('\n' + '=' * 118)
    print(HEAD)
    print('-' * 118)
    for label, a, _ in rows:
        print(f'{label:<22} {a["tok"]:>5} {a["chars"]:>6} {a["desc"]:>7.1f} {a["maxdesc"]:>9} '
              f'{a["line"]:>7.1f} {a.get("quota",0):>7.1f} {a.get("swallow",0):>3}/{n} '
              f'{a["narr"]:>6.1f} '
              f'{a["star"]:>3}/{n}{a["newname"]:>3}/{n}{a["eng"]:>3}/{n}')
    print('=' * 118)
    print('目标                        80-140    <=2       <=80    2-3    2-3     0/0    0     0/0   0/0  0/0')


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--msg', default='你还好吗？')
    ap.add_argument('--n', type=int, default=2)
    ap.add_argument('--temp', type=float, default=0.7)
    ap.add_argument('--seed', type=int, default=None,
                    help='固定随机种子（配对采样）。所有版本第 i 次共用 seed+i，'
                         '版本间可逐次比对；复现同一轮实验用同一个 seed')
    ap.add_argument('--card-data', action='store_true',
                    help='对照卡片数据影响（固定用 v8 提示词）')
    ap.add_argument('--only', default=None,
                    help='只跑匹配该子串的版本，逗号分隔，如 "v8,v9"')
    args = ap.parse_args()

    base_card = T.read_card(T.DEFAULT_CARD)
    print(f'角色卡: {base_card.get("name")}\n测试输入: 「{args.msg}」\n'
          f'每配置采样: {args.n} 次  温度: {args.temp}  '
          f'种子: {args.seed if args.seed is not None else "随机（版本间不可比）"}\n')

    rows = []
    if args.card_data:
        for label, fn in CARD_VARIANTS:
            a, sample = run('docs/system_prompt_v8.md', fn(dict(base_card)), args.msg,
                            args.n, args.temp, args.seed)
            rows.append((label, a, sample))
            print(f'  ✓ {label}')
        table(rows, args.n)
        title = '卡片数据对照（固定 v8 提示词）'
    else:
        keys = args.only.split(',') if args.only else None
        for label, rel in PROMPT_VERSIONS:
            if keys and not any(k.strip() in label for k in keys):
                continue
            if rel and not os.path.exists(os.path.join(T.ROOT, rel)):
                print(f'  skip {label}')
                continue
            a, sample = run(rel, dict(base_card), args.msg, args.n, args.temp, args.seed)
            rows.append((label, a, sample))
            print(f'  ✓ {label}')
        table(rows, args.n)
        title = '提示词版本对照（完整卡片）'

    for label, a, sample in rows:
        print(f'\n{"-"*100}\n[{title}] {label} — 首次采样\n{"-"*100}')
        print(sample)


if __name__ == '__main__':
    main()
