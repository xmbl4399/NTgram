# -*- coding: utf-8 -*-
"""安全地把白名单 SnackBar 的 duration 统一为 1s。
- 块感知括号配对（跳过字符串字面量/转义）
- 仅处理白名单 key（成功/完成反馈类），失败/引导/长任务类不动
- 无 duration -> 插入 1s；有 duration 且 !=1s -> 改为 1s
用法: python tool/fix_snackbar_whitelist.py
"""
import re
import sys
from pathlib import Path

WHITELIST = {
    "copiedToClipboard", "backupCreated", "settingsResetToDefaults",
    "restoreComplete", "signedInSuccessfully", "languageChanged", "groupSaved",
    "characterDuplicated", "bookmarkCreated", "storyNoteSaved", "savedPreset",
    "deletedPreset", "appliedPreset", "importedAndApplied",
    "live2dModelDeleted", "statisticsReset", "collectionExported",
    "collectionImported", "documentAdded", "updated", "presetScriptsAdded",
}

_SB = re.compile(r"(?<!show)SnackBar\s*\(")
_KEY_RE = re.compile(r"(?:l10n|l10n!|\w+\.l10n)\.(\w+)")
_KEY_RE2 = re.compile(r"AppLocalizations\.of\([^)]*\)!\.(\w+)")
_SEC_RE = re.compile(r"(?:const\s+)?Duration\(seconds:\s*(\d+)\)")


def find_blocks(text):
    out = []
    i = 0
    while True:
        m = _SB.search(text, i)
        if not m:
            break
        start = m.start()
        line = text.count("\n", 0, start) + 1
        j = m.end() - 1
        depth = 0
        instr = None
        esc = False
        while j < len(text):
            c = text[j]
            if instr:
                if esc:
                    esc = False
                elif c == "\\":
                    esc = True
                elif c == instr:
                    instr = None
            else:
                if c in "'\"":
                    instr = c
                elif c == "(":
                    depth += 1
                elif c == ")":
                    depth -= 1
                    if depth == 0:
                        break
            j += 1
        if j >= len(text):
            break
        out.append((start, j, line))
        i = j + 1
    return out


def duration_range(text, s, e):
    """返回块内顶层 duration 参数中 seconds 数值的 (start,end)；无 duration 返回 None。"""
    i = s
    instr = None
    esc = False
    found = []
    while i < e:
        c = text[i]
        if instr:
            if esc:
                esc = False
            elif c == "\\":
                esc = True
            elif c == instr:
                instr = None
            i += 1
            continue
        if c in "'\"":
            instr = c
            i += 1
            continue
        if text.startswith("duration", i) and (i == s or not text[i - 1].isalnum()):
            k = i + 8
            while k < e and text[k] in " \t\r\n":
                k += 1
            if k < e and text[k] == ":":
                found.append(i)
                # 跳过该参数（到顶层逗号/右括号）
                depth = 0
                while k < e:
                    ck = text[k]
                    if ck == "(":
                        depth += 1
                    elif ck == ")":
                        if depth == 0:
                            break
                        depth -= 1
                    elif ck == "," and depth == 0:
                        break
                    k += 1
        i += 1
    if not found:
        return None
    # 取第一个 duration 参数里的 seconds 数值区间
    for di in found:
        sm = _SEC_RE.search(text[di:e])
        if sm:
            return (di + sm.start(1), di + sm.end(1))
    return None


def main():
    dry = "--dry" in sys.argv
    root = Path("lib")
    total_ins = 0
    total_rep = 0
    report = []
    for p in sorted(root.rglob("*.dart")):
        if "generated" in str(p):
            continue
        text = p.read_text(encoding="utf-8")
        blocks = find_blocks(text)
        edits = []  # (pos, endpos_or_None, newtext_or_None, desc)
        for s, e, line in blocks:
            seg = text[s : min(e, s + 600)]
            km = _KEY_RE.search(seg)
            if not km:
                km = _KEY_RE2.search(seg)
            key = km.group(1) if km else None
            if key not in WHITELIST:
                continue
            dr = duration_range(text, s, e)
            if dr is None:
                k = e - 1
                while text[k] in " \t\r\n":
                    k -= 1
                ins_at = k + 1
                prefix = "" if text[k] == "," else ","
                body = text[s : e + 1]
                nl = body.find("\n")
                if nl != -1:
                    ls = text.rfind("\n", 0, s) + 1
                    indent = "\n" + " " * ((s - ls) + 10)
                else:
                    indent = ""
                edits.append(
                    (ins_at, None, prefix + indent + "duration: const Duration(seconds: 1)",
                     f"INSERT  {key:<28s} {p}:{line}")
                )
                total_ins += 1
            else:
                v0, v1 = dr
                val = text[v0:v1]
                if val != "1":
                    edits.append((v0, v1, "1", f"REPLACE {key:<28s} {p}:{line} ({val}s->1s)"))
                    total_rep += 1
        if not edits:
            continue
        nt = text
        for a, b, new, desc in sorted(edits, key=lambda x: x[0], reverse=True):
            if b is None:
                nt = nt[:a] + new + nt[a:]
            else:
                nt = nt[:a] + new + nt[b:]
            report.append(desc)
        if not dry:
            p.write_text(nt, encoding="utf-8")

    print(f"\n=== {'[DRY-RUN] ' if dry else ''}insert={total_ins} replace={total_rep} ===")
    for r in sorted(report):
        print(r)


if __name__ == "__main__":
    main()
