// 验证 message_content_widget.dart 的 _normalizeQuoteBlocks 是否真的能把
// 「动作行」从 `>` 引用块里剥离出来（与 App 渲染同源：markdown 7.3.1）。
//
// 用法：dart run tools/quote_fix_probe.dart
import 'package:markdown/markdown.dart' as md;

// —— 与 lib/presentation/widgets/chat/message_content_widget.dart 保持一致的副本
String normalizeQuoteBlocks(String source) {
  if (!source.contains('>')) return source;

  bool isFence(String line) {
    final trimmed = line.trimLeft();
    return trimmed.startsWith('```') || trimmed.startsWith('~~~');
  }

  bool isQuote(String line) => line.trimLeft().startsWith('>');

  final unwrapped = <String>[];
  var inFence = false;
  for (final raw in source.split('\n')) {
    if (isFence(raw)) inFence = !inFence;
    if (!inFence && isQuote(raw)) {
      final body = raw.trimLeft().substring(1).trimLeft();
      if (body.startsWith('（') || body.startsWith('(')) {
        unwrapped.add(body);
        continue;
      }
    }
    unwrapped.add(raw);
  }

  final out = <String>[];
  inFence = false;
  for (var i = 0; i < unwrapped.length; i++) {
    final line = unwrapped[i];
    if (isFence(line)) inFence = !inFence;
    if (!inFence && i > 0) {
      final prev = unwrapped[i - 1];
      final isBoundary = prev.trim().isNotEmpty &&
          line.trim().isNotEmpty &&
          !isFence(prev) &&
          isQuote(prev) &&
          !isQuote(line);
      if (isBoundary) out.add('');
    }
    out.add(line);
  }
  return out.join('\n');
}

String render(String input) => md
    .markdownToHtml(input, extensionSet: md.ExtensionSet.gitHubFlavored)
    .replaceAll('\n', '');

void probe(String label, String input) {
  final before = render(input);
  final after = render(normalizeQuoteBlocks(input));
  final blocks = RegExp(r'<blockquote>').allMatches(after).length;
  print('===== $label =====');
  print('修复前: $before');
  print('修复后: $after');
  print('修复后引用块数: $blocks');
  print('');
}

void main() {
  // v15 在 Gemma-4-E4B 上的真实输出（动作被加了 >，且块内用 > 空行分段）
  const v15Bad = '（她猛地停下脚步，身体微微前倾，蓝色的眼睛直直地看着你。）\n'
      '\n'
      '> 我还好吗？ 唔... 哼！\n'
      '>\n'
      '> （她噘起嘴，用手背轻轻蹭了蹭脸颊，做出一个夸张的表情。）\n'
      '>\n'
      '> 當然是很好啦！ 誰敢說我不好？\n'
      '\n'
      '（内心os：不過... 就覺得還不錯啦。）';

  // 模型忘了在台词块后空行 —— CommonMark lazy continuation 吞掉动作段
  const lazyContinuation = '（她拧了一下袖口。）\n'
      '\n'
      '> 你怎么才回来。\n'
      '（她把手插进兜里。）';

  // 正常输出，应保持不变（除了台词块后本来就有的空行）
  const good = '（她把伞靠在门边，伞尖还在滴水。）\n'
      '\n'
      '> 你怎么才回来。\n'
      '\n'
      '（她拧了一下袖口，没抬头。）\n'
      '\n'
      '> 锅里还有粥，自己盛。';

  // 代码块里的 > 不能被改动
  const codeBlock = '看看这段：\n'
      '\n'
      '```bash\n'
      '> npm install\n'
      '(echo hi)\n'
      '```';

  probe('1) v15 真实失败样本（动作行带 >）', v15Bad);
  probe('2) lazy continuation 吞掉动作段', lazyContinuation);
  probe('3) 正常输出（应零改动）', good);
  probe('4) 代码块内 > 不受影响', codeBlock);

  print('===== 幂等性检查 =====');
  for (final [label, src] in [
    ['v15Bad', v15Bad],
    ['lazy', lazyContinuation],
    ['good', good],
  ]) {
    final once = normalizeQuoteBlocks(src);
    final twice = normalizeQuoteBlocks(once);
    print('$label: ${once == twice ? "✅ 稳定" : "❌ 不幂等"}');
  }
}
