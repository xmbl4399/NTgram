#!/usr/bin/env python3
"""Migrate fire-and-forget SnackBars to AppToast.

Rewrites

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.chatDeleted), duration: const Duration(seconds: 1)),
    );

into

    AppToast.show(context, l10n.chatDeleted, duration: const Duration(seconds: 1));

Rules:
  * only `ScaffoldMessenger.of(<ctx>).showSnackBar(SnackBar(...))` is touched;
    calls through a captured `messenger` variable are reported for manual work
  * SnackBars carrying an `action:` stay as they are (they need to be tappable)
  * `backgroundColor: Colors.red`      -> AppToast.error
  * `backgroundColor: <cond> ? Colors.orange : Colors.green`
                                        -> kind: <cond> ? error : success
  * `behavior:` is dropped (the toast has its own placement)
  * explicit `duration:` is preserved; missing ones fall back to
    AppToast.defaultDuration

Usage:  python tools/migrate_snackbar_to_toast.py [--apply]
"""

from __future__ import annotations

import argparse
import pathlib
import re
import sys

SHOW = 'showSnackBar('
IMPORT_LINE = "import 'package:native_tavern/presentation/widgets/app_toast.dart';"
SKIP_FILES = {'snackbar_utils.dart', 'app_toast.dart'}
LINE_BUDGET = 80


def match_paren(text: str, open_idx: int) -> int:
    """Index of the ')' matching the '(' at open_idx, ignoring strings."""
    depth = 0
    i = open_idx
    n = len(text)
    while i < n:
        c = text[i]
        if c == "'" or c == '"':
            quote = c
            i += 1
            while i < n:
                if text[i] == '\\':
                    i += 2
                    continue
                if text[i] == quote:
                    break
                i += 1
        elif c == '(':
            depth += 1
        elif c == ')':
            depth -= 1
            if depth == 0:
                return i
        i += 1
    raise ValueError('unbalanced parentheses')


def split_top_level(text: str) -> list[str]:
    """Split on top-level commas."""
    out: list[str] = []
    depth = 0
    cur = ''
    i = 0
    n = len(text)
    while i < n:
        c = text[i]
        if c in "'\"":
            quote = c
            cur += c
            i += 1
            while i < n:
                cur += text[i]
                if text[i] == '\\':
                    cur += text[i + 1:i + 2]
                    i += 2
                    continue
                if text[i] == quote:
                    break
                i += 1
        elif c in '([{':
            depth += 1
            cur += c
        elif c in ')]}':
            depth -= 1
            cur += c
        elif c == ',' and depth == 0:
            out.append(cur)
            cur = ''
        else:
            cur += c
        i += 1
    if cur.strip():
        out.append(cur)
    return out


def split_kv(part: str) -> tuple[str, str]:
    depth = 0
    for idx, c in enumerate(part):
        if c in '([{':
            depth += 1
        elif c in ')]}':
            depth -= 1
        elif c == ':' and depth == 0:
            return part[:idx].strip(), part[idx + 1:].strip()
    return part.strip(), ''


def receiver_span(text: str, show_idx: int) -> tuple[int, str | None]:
    """Return (start index, context expression) for the receiver of showSnackBar.

    context is None when the receiver is a plain variable (manual work).
    """
    i = show_idx - 1
    while i >= 0 and text[i] in ' \t\r\n':
        i -= 1
    if i < 0 or text[i] != '.':
        raise ValueError('unexpected receiver')
    i -= 1
    while i >= 0 and text[i] in ' \t\r\n':
        i -= 1

    if text[i] == ')':
        # ScaffoldMessenger.of(<ctx>) / foo.bar(<ctx>)
        close_idx = i
        depth = 0
        j = close_idx
        while j >= 0:
            if text[j] == ')':
                depth += 1
            elif text[j] == '(':
                depth -= 1
                if depth == 0:
                    break
            j -= 1
        open_idx = j
        ctx_raw = text[open_idx + 1:close_idx]
        ctx_args = [a.strip() for a in split_top_level(ctx_raw) if a.strip()]
        if len(ctx_args) != 1:
            raise ValueError(f'of() takes {len(ctx_args)} arguments')
        ctx = ctx_args[0]
        # walk back over `of`
        k = open_idx - 1
        while k >= 0 and text[k] in ' \t\r\n':
            k -= 1
        end_of_name = k
        while k >= 0 and (text[k].isalnum() or text[k] == '_'):
            k -= 1
        name = text[k + 1:end_of_name + 1]
        if name != 'of':
            raise ValueError(f'unexpected callee {name!r}')
        k -= 1  # the dot
        k -= 0
        # walk back over the class name
        while k >= 0 and text[k] in ' \t\r\n':
            k -= 1
        end_of_cls = k
        while k >= 0 and (text[k].isalnum() or text[k] in '_.'):
            k -= 1
        cls = text[k + 1:end_of_cls + 1]
        if cls != 'ScaffoldMessenger':
            raise ValueError(f'unexpected receiver class {cls!r}')
        return k + 1, ctx

    # plain identifier (messenger, _messengerKey.currentState, ...)
    end = i
    while i >= 0 and (text[i].isalnum() or text[i] in '_.'):
        i -= 1
    return i + 1, None


def line_indent(text: str, idx: int) -> str:
    start = text.rfind('\n', 0, idx) + 1
    indent = ''
    for c in text[start:]:
        if c in ' \t':
            indent += c
        else:
            break
    return indent


def indent_block(expr: str, indent: str) -> str:
    lines = expr.split('\n')
    if len(lines) == 1:
        return expr
    # re-indent continuation lines relative to their current minimum indent
    base = min(
        (len(l) - len(l.lstrip()) for l in lines[1:] if l.strip()),
        default=0,
    )
    out = [lines[0]]
    for l in lines[1:]:
        out.append(indent + '  ' + l[base:] if l.strip() else l)
    return '\n'.join(out)


def build_replacement(text: str, start: int, msg: str, ctx: str,
                      duration: str | None, kind_suffix: str,
                      kind_note: str | None) -> str:
    indent = line_indent(text, start)
    msg = indent_block(msg, indent)
    args: list[str] = [ctx, msg]
    if kind_suffix:
        args.append(f'kind: {kind_suffix}')
    if duration:
        args.append(f'duration: {duration}')

    callee = 'AppToast.show'
    one_line = f'{callee}({", ".join(args)})'
    if '\n' not in msg and len(indent) + len(one_line) <= LINE_BUDGET:
        return one_line
    body = ',\n'.join(f'{indent}  {a}' for a in args)
    return f'{callee}(\n{body},\n{indent})'


def migrate_file(path: pathlib.Path, apply: bool) -> tuple[int, list[str], list[str]]:
    text = original = path.read_text(encoding='utf-8')
    notes: list[str] = []
    skipped: list[str] = []
    replaced = 0

    while True:
        idxs = [m.start() for m in re.finditer(re.escape(SHOW), text)]
        if not idxs:
            break
        changed = False
        for show_idx in reversed(idxs):
            open_idx = show_idx + len(SHOW) - 1
            close_idx = match_paren(text, open_idx)
            block = text[open_idx + 1:close_idx]
            line = text[:show_idx].count('\n') + 1

            try:
                start, ctx = receiver_span(text, show_idx)
            except ValueError as exc:
                skipped.append(f'{path}:{line}  {exc}')
                continue
            if ctx is None:
                skipped.append(f'{path}:{line}  receiver is a variable (manual)')
                continue
            stripped = block.strip()
            if not stripped.startswith('SnackBar('):
                skipped.append(f'{path}:{line}  not a SnackBar literal (manual)')
                continue

            inner_close = match_paren(stripped, len('SnackBar(') - 1)
            inner = stripped[len('SnackBar('):inner_close]
            props: dict[str, str] = {}
            for part in split_top_level(inner):
                if not part.strip():
                    continue
                key, value = split_kv(part)
                props[key] = value

            if 'action' in props:
                skipped.append(f'{path}:{line}  has action -> stays a SnackBar')
                continue
            if 'content' not in props:
                skipped.append(f'{path}:{line}  no content (manual)')
                continue

            content = props['content'].strip()
            if not content.startswith('Text('):
                skipped.append(f'{path}:{line}  content is not Text (manual)')
                continue
            text_close = match_paren(content, len('Text(') - 1)
            text_args = split_top_level(content[len('Text('):text_close])
            if len(text_args) != 1:
                skipped.append(f'{path}:{line}  Text has extra args (manual)')
                continue
            msg = text_args[0].strip()

            kind_suffix = ''
            bg = props.get('backgroundColor')
            if bg:
                if 'Colors.red' in bg:
                    kind_suffix = 'AppToastKind.error'
                elif '?' in bg and ':' in bg:
                    cond = bg.split('?', 1)[0].strip()
                    kind_suffix = (
                        f'{cond} ? AppToastKind.error : AppToastKind.success'
                    )
                else:
                    notes.append(f'{path}:{line}  dropped backgroundColor: {bg}')

            duration = props.get('duration')
            if 'behavior' in props:
                notes.append(f'{path}:{line}  dropped behavior')

            known = {'content', 'duration', 'backgroundColor', 'behavior'}
            for extra in set(props) - known:
                notes.append(f'{path}:{line}  dropped prop {extra!r}')

            replacement = build_replacement(
                text, start, msg, ctx, duration, kind_suffix, None
            )
            text = text[:start] + replacement + text[close_idx + 1:]
            replaced += 1
            changed = True
        if not changed:
            break

    if 'AppToast.' in text and IMPORT_LINE not in text:
        lines = text.split('\n')
        last_import = -1
        for i, l in enumerate(lines):
            if l.startswith('import '):
                last_import = i
        if last_import == -1:
            raise ValueError(f'{path}: no import section')
        lines.insert(last_import + 1, IMPORT_LINE)
        text = '\n'.join(lines)

    if apply and text != original:
        path.write_text(text, encoding='utf-8')
    return replaced, notes, skipped


CALLEES = ('AppToast.show(', 'AppToast.success(', 'AppToast.error(')


def repair_file(path: pathlib.Path, apply: bool) -> tuple[int, bool]:
    """Fix a tree migrated by an earlier, buggy run of this script.

    * collapse the duplicated `;;` left behind when the replacement itself
      carried a semicolon
    * move the AppToast import into its alphabetical slot
    """
    text = original = path.read_text(encoding='utf-8')
    if 'AppToast.' not in text:
        return 0, False

    fixed = 0
    for callee in CALLEES:
        pos = 0
        while True:
            idx = text.find(callee, pos)
            if idx == -1:
                break
            close = match_paren(text, idx + len(callee) - 1)
            if text[close + 1:close + 3] == ';;':
                text = text[:close + 1] + text[close + 2:]
                fixed += 1
                pos = close + 1
            else:
                pos = close + 1

    # re-place the import
    lines = [l for l in text.split('\n') if l.strip() != IMPORT_LINE]
    if IMPORT_LINE in text:
        nt_prefix = "import 'package:native_tavern/"
        idxs = [i for i, l in enumerate(lines) if l.startswith(nt_prefix)]
        if idxs:
            insert_at = idxs[-1] + 1
            for i in idxs:
                if lines[i] > IMPORT_LINE:
                    insert_at = i
                    break
        else:
            imports = [i for i, l in enumerate(lines) if l.startswith('import ')]
            insert_at = (imports[-1] + 1) if imports else 0
        lines.insert(insert_at, IMPORT_LINE)
        text = '\n'.join(lines)

    if apply and text != original:
        path.write_text(text, encoding='utf-8')
    return fixed, text != original


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument('--apply', action='store_true')
    ap.add_argument('--repair', action='store_true')
    ap.add_argument('--root', default='lib')
    args = ap.parse_args()

    root = pathlib.Path(args.root)

    if args.repair:
        total = 0
        touched = 0
        for f in sorted(root.rglob('*.dart')):
            if f.name in SKIP_FILES or 'app_toast' in f.name:
                continue
            n, changed = repair_file(f, args.apply)
            total += n
            touched += 1 if changed else 0
        status = 'REPAIRED' if args.apply else 'DRY RUN'
        print(
            f'{status}: collapsed {total} duplicate semicolons, '
            f'import re-placed in {touched} files'
        )
        return 0

    total = 0
    all_notes: list[str] = []
    all_skipped: list[str] = []
    files: list[tuple[pathlib.Path, int]] = []
    for f in sorted(root.rglob('*.dart')):
        if f.name in SKIP_FILES:
            continue
        n, notes, skipped = migrate_file(f, args.apply)
        if n:
            files.append((f, n))
        total += n
        all_notes += notes
        all_skipped += skipped

    print(f'{"APPLIED" if args.apply else "DRY RUN"}: {total} call sites '
          f'in {len(files)} files\n')
    print('--- top files ---')
    for f, n in sorted(files, key=lambda x: -x[1])[:15]:
        print(f'  {n:3d}  {f}')
    if all_notes:
        print(f'\n--- dropped props ({len(all_notes)}) ---')
        for x in all_notes:
            print('  ', x)
    if all_skipped:
        print(f'\n--- skipped / manual ({len(all_skipped)}) ---')
        for x in all_skipped:
            print('  ', x)
    return 0


if __name__ == '__main__':
    sys.exit(main())
