import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import '../theme.dart';
import 'gh_widgets.dart';

/// GitHub-flavored markdown (tables, task lists, strikethrough, autolinks)
/// styled to match the app.
class GhMarkdown extends StatelessWidget {
  const GhMarkdown(this.data, {super.key, this.imageBase, this.fontSize = 14.5});

  final String data;

  /// Base URL for relative image paths (e.g. raw files of a README's repo).
  final String? imageBase;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return MarkdownBody(
      data: _fromGitHubHtml(data),
      selectable: true,
      extensionSet: md.ExtensionSet.gitHubWeb,
      inlineSyntaxes: [MentionSyntax()],
      styleSheet: _styleSheet(fontSize),
      onTapLink: (text, href, title) {
        if (href == null) return;
        if (href.startsWith(MentionSyntax.scheme)) {
          openProfile(context, href.substring(MentionSyntax.scheme.length));
          return;
        }
        Clipboard.setData(ClipboardData(text: href));
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Link copied: $href')));
      },
      sizedImageBuilder: (config) => _image(config),
    );
  }

  Widget _image(MarkdownImageConfig c) {
    var uri = c.uri;
    if (!uri.hasScheme && imageBase != null) {
      uri = Uri.parse(imageBase!).resolveUri(uri);
    }
    final fallback = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.image_outlined, size: 16, color: AppColors.faint),
        const SizedBox(width: 6),
        Text((c.alt ?? '').isEmpty ? 'image' : c.alt!,
            style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
      ]),
    );
    if (!uri.hasScheme) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.network(
        uri.toString(),
        width: c.width,
        height: c.height,
        errorBuilder: (_, __, ___) => fallback,
      ),
    );
  }
}

/// @user and @org/team mentions: bold, gold, and tappable (opens the
/// profile), like GitHub's.
class MentionSyntax extends md.InlineSyntax {
  MentionSyntax()
      : super(
            r'(?<![\w@/`.])@([A-Za-z0-9](?:[A-Za-z0-9]|-(?=[A-Za-z0-9])){0,38})'
            r'(?:/[A-Za-z0-9_.-]+)?(?![\w@])',
            startCharacter: 0x40);

  static const scheme = 'mention:';

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final link = md.Element.text('a', match[0]!)
      ..attributes['href'] = '$scheme${match[1]}';
    parser.addNode(md.Element('strong', [link]));
    return true;
  }
}

/// Turns the HTML GitHub allows in comments into markdown the renderer
/// understands: <img> becomes an image, <br> a line break, and
/// <details>/<summary> wrappers are dropped (their contents stay).
String _fromGitHubHtml(String s) {
  s = s.replaceAllMapped(RegExp(r'<img\b[^>]*>', caseSensitive: false), (m) {
    final tag = m[0]!;
    final src = RegExp(r'''src=["']([^"']+)["']''').firstMatch(tag)?[1];
    final alt = RegExp(r'''alt=["']([^"']*)["']''').firstMatch(tag)?[1] ?? '';
    return src == null ? '' : '![$alt]($src)';
  });
  s = s.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '  \n');
  s = s.replaceAllMapped(
      RegExp(r'<summary>(.*?)</summary>', caseSensitive: false, dotAll: true),
      (m) => '**${m[1]!.trim()}**\n');
  s = s.replaceAll(
      RegExp(r'</?(details|p|div|sub|sup)\b[^>]*>', caseSensitive: false), '');
  s = s.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');
  return s;
}

MarkdownStyleSheet _styleSheet(double size) {
  final body = TextStyle(color: AppColors.text, fontSize: size, height: 1.55);
  TextStyle heading(double scale) => TextStyle(
      color: AppColors.text,
      fontSize: size * scale,
      fontWeight: FontWeight.w600,
      height: 1.3);
  final rule = BoxDecoration(
      border: Border(bottom: BorderSide(color: AppColors.border)));
  return MarkdownStyleSheet(
    p: body,
    a: TextStyle(color: AppColors.accent),
    strong: const TextStyle(fontWeight: FontWeight.w700),
    em: const TextStyle(fontStyle: FontStyle.italic),
    del: TextStyle(decoration: TextDecoration.lineThrough, color: AppColors.muted),
    code: TextStyle(
        fontFamily: 'monospace',
        fontSize: size - 1.5,
        color: AppColors.text,
        backgroundColor: AppColors.surfaceAlt),
    codeblockPadding: const EdgeInsets.all(14),
    codeblockDecoration: BoxDecoration(
      color: AppColors.surfaceAlt,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppColors.border),
    ),
    h1: heading(1.75),
    h1Padding: const EdgeInsets.only(top: 8, bottom: 6),
    h2: heading(1.45),
    h2Padding: const EdgeInsets.only(top: 8, bottom: 4),
    h3: heading(1.22),
    h4: heading(1.08),
    h5: heading(1.0),
    h6: heading(0.95).copyWith(color: AppColors.muted),
    listBullet: body,
    listIndent: 24,
    blockSpacing: 12,
    blockquote: TextStyle(color: AppColors.muted, fontSize: size, height: 1.55),
    blockquotePadding: const EdgeInsets.fromLTRB(14, 4, 8, 4),
    blockquoteDecoration: BoxDecoration(
        border: Border(left: BorderSide(color: AppColors.border, width: 4))),
    tableHead: TextStyle(
        color: AppColors.text, fontWeight: FontWeight.w600, fontSize: size - 1),
    tableBody: TextStyle(color: AppColors.text, fontSize: size - 1),
    tableBorder: TableBorder.all(color: AppColors.border),
    tableCellsPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    horizontalRuleDecoration: rule,
    checkbox: TextStyle(color: AppColors.accent, fontSize: size),
  );
}
