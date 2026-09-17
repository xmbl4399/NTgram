// 验证 markdown 包对引用块的解析行为（与 App 渲染同源：markdown 7.3.1）
import 'package:markdown/markdown.dart' as md;

void probe(String label, String input) {
  final html = md.markdownToHtml(input, extensionSet: md.ExtensionSet.gitHubFlavored);
  print('===== $label =====');
  print('输入: ${input.replaceAll('\n', ' ⏎ ')}');
  print('输出: ${html.replaceAll('\n', ' ')}');
  print('');
}

void main() {
  const q = '> 你怎么才回来。';
  const act = '（她把伞收起来靠在门边。）';

  probe('1) 引用块后紧跟正文（无空行）', '$q\n$act');
  probe('2) 引用块后空行再正文', '$q\n\n$act');
  probe('3) 正文后紧跟引用块（无空行）', '$act\n$q');
  probe('4) 正文后空行再引用块', '$act\n\n$q');
  probe('5) 连续引用行', '> 你怎么才回来。\n> 路上堵车了吗。');
  probe('6) 引用块中间空行', '> 你怎么才回来。\n\n> 路上堵车了吗。');
  probe('7) 引用块内含空行', '> 你怎么才\n>\n> 回来。');
  probe('8) 正文内单换行', '（第一段）\n（第二段）');
}
