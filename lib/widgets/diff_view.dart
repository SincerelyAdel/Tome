import 'package:flutter/material.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:flutter_highlight/themes/github.dart';
import 'package:highlight/highlight.dart' show highlight, Node;
import '../models/github_models.dart';
import '../theme.dart';
import 'file_icon.dart';
import 'gh_widgets.dart';

/// Green used for additions in diffs.
Color get diffAddText => ghOpen;
Color get diffAddBg => ghOpen.withOpacity(AppColors.isDark ? 0.16 : 0.12);
Color get diffDelBg => ghClosed.withOpacity(AppColors.isDark ? 0.16 : 0.10);

/// "+12 −3" summary text.
Widget diffStat(int additions, int deletions, {double fontSize = 13}) {
  return Text.rich(
    TextSpan(children: [
      TextSpan(text: '+$additions ', style: TextStyle(color: diffAddText)),
      TextSpan(text: '−$deletions', style: TextStyle(color: ghClosed)),
    ]),
    style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600),
  );
}

/// GitHub's five-square bar showing the share of additions vs deletions.
Widget diffBar(int additions, int deletions) {
  final total = additions + deletions;
  final green = total == 0 ? 0 : (additions / total * 5).round();
  final red = total == 0 ? 0 : 5 - green;
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: List.generate(5, (i) {
      final color = i < green
          ? diffAddText
          : i < green + red
              ? ghClosed
              : AppColors.border;
      return Container(
        margin: const EdgeInsets.only(left: 2),
        width: 9,
        height: 9,
        decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(2)),
      );
    }),
  );
}

/// Highlights [code] as [language] and returns the spans of each line, so
/// diff lines can be coloured one by one. Falls back to plain text.
List<List<TextSpan>> highlightLines(String code, String language) {
  List<List<TextSpan>> plain() =>
      [for (final l in code.split('\n')) [TextSpan(text: l)]];
  if (language == 'plaintext') return plain();
  List<Node>? nodes;
  try {
    nodes = highlight.parse(code, language: language).nodes;
  } catch (_) {}
  if (nodes == null) return plain();

  final theme = AppColors.isDark ? atomOneDarkTheme : githubTheme;
  final lines = <List<TextSpan>>[[]];
  void add(String text, TextStyle? style) {
    final parts = text.split('\n');
    for (var i = 0; i < parts.length; i++) {
      if (i > 0) lines.add([]);
      if (parts[i].isNotEmpty) {
        lines.last.add(TextSpan(text: parts[i], style: style));
      }
    }
  }

  void walk(Node n, TextStyle? style) {
    final t = n.className == null ? null : theme[n.className];
    // Only colour and weight: the diff rows keep their own backgrounds.
    final own = t == null
        ? style
        : (style ?? const TextStyle()).merge(TextStyle(
            color: t.color, fontWeight: t.fontWeight, fontStyle: t.fontStyle));
    if (n.value != null) {
      add(n.value!, own);
    } else {
      for (final c in n.children ?? const <Node>[]) {
        walk(c, own);
      }
    }
  }

  for (final n in nodes) {
    walk(n, null);
  }
  return lines;
}

enum _Kind { hunk, context, add, del, note }

class _Line {
  _Line(this.kind, this.text, {this.oldNo, this.newNo, this.index = -1});
  final _Kind kind;
  final String text;
  final int? oldNo, newNo;

  /// Line number inside the old or new code stream used for highlighting.
  final int index;
}

/// One changed file: header with name and counts, then a colored diff.
/// Tap the header to collapse it.
class DiffFileCard extends StatefulWidget {
  const DiffFileCard(this.file, {super.key});

  final GhFileChange file;

  @override
  State<DiffFileCard> createState() => _DiffFileCardState();
}

class _DiffFileCardState extends State<DiffFileCard> {
  bool _collapsed = false;

  // Parsed and highlighted diff, rebuilt when the theme changes.
  List<_Line>? _lines;
  List<List<TextSpan>> _old = [], _new = [];
  bool? _builtDark;
  int _numWidth = 1;

  /// Splits the patch into lines with their old/new line numbers, and
  /// highlights the old and new code separately so strings and comments
  /// spanning several lines still colour right.
  void _parse(String patch) {
    final lines = <_Line>[];
    final oldCode = <String>[], newCode = <String>[];
    var o = 0, n = 0;
    final hunk = RegExp(r'^@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@');
    for (final raw in patch.split('\n')) {
      final m = hunk.firstMatch(raw);
      if (m != null) {
        o = int.parse(m.group(1)!);
        n = int.parse(m.group(2)!);
        lines.add(_Line(_Kind.hunk, raw));
      } else if (raw.startsWith('\\')) {
        lines.add(_Line(_Kind.note, raw));
      } else if (raw.startsWith('+')) {
        lines.add(_Line(_Kind.add, raw.substring(1),
            newNo: n++, index: newCode.length));
        newCode.add(raw.substring(1));
      } else if (raw.startsWith('-')) {
        lines.add(_Line(_Kind.del, raw.substring(1),
            oldNo: o++, index: oldCode.length));
        oldCode.add(raw.substring(1));
      } else {
        final text = raw.isEmpty ? '' : raw.substring(1);
        lines.add(_Line(_Kind.context, text,
            oldNo: o++, newNo: n++, index: newCode.length));
        oldCode.add(text);
        newCode.add(text);
      }
    }
    final lang = languageForFile(widget.file.filename);
    _old = highlightLines(oldCode.join('\n'), lang);
    _new = highlightLines(newCode.join('\n'), lang);
    _numWidth = '${o > n ? o : n}'.length;
    _lines = lines;
    _builtDark = AppColors.isDark;
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.file;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _collapsed = !_collapsed),
            child: Container(
              color: AppColors.surfaceAlt,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(children: [
                Icon(_collapsed ? Icons.chevron_right : Icons.expand_more,
                    size: 18, color: AppColors.muted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(f.filename,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: AppColors.text,
                          fontFamily: 'monospace',
                          fontSize: 13)),
                ),
                if (f.status == 'added') outlineBadge('new', color: diffAddText),
                if (f.status == 'removed')
                  outlineBadge('deleted', color: ghClosed),
                if (f.status == 'renamed') outlineBadge('renamed'),
                const SizedBox(width: 8),
                diffStat(f.additions, f.deletions, fontSize: 12.5),
                const SizedBox(width: 6),
                diffBar(f.additions, f.deletions),
              ]),
            ),
          ),
          if (!_collapsed) _diff(f),
        ],
      ),
    );
  }

  Widget _diff(GhFileChange f) {
    final patch = f.patch;
    if (patch == null || patch.isEmpty) {
      return Container(
        color: AppColors.surface,
        padding: const EdgeInsets.all(14),
        child: Text('Binary file or diff too large to show.',
            style: TextStyle(color: AppColors.faint, fontSize: 13)),
      );
    }
    if (_lines == null || _builtDark != AppColors.isDark) _parse(patch);
    final num = TextStyle(color: AppColors.faint);
    String pad(int? x) => (x?.toString() ?? '').padLeft(_numWidth);
    final lines = _lines!.map((l) {
      Color? bg;
      final spans = <InlineSpan>[];
      switch (l.kind) {
        case _Kind.hunk:
        case _Kind.note:
          bg = l.kind == _Kind.hunk ? AppColors.accent.withOpacity(0.10) : null;
          spans.add(TextSpan(
              text: '${' ' * (_numWidth * 2 + 4)}${l.text}',
              style: TextStyle(color: AppColors.muted)));
        default:
          final (String mark, List<List<TextSpan>> src) = switch (l.kind) {
            _Kind.add => ('+', _new),
            _Kind.del => ('-', _old),
            _ => (' ', _new),
          };
          bg = switch (l.kind) {
            _Kind.add => diffAddBg,
            _Kind.del => diffDelBg,
            _ => null,
          };
          spans.add(TextSpan(
              text: '${pad(l.oldNo)} ${pad(l.newNo)} ', style: num));
          spans.add(TextSpan(
              text: '$mark ',
              style: TextStyle(
                  color: l.kind == _Kind.add
                      ? diffAddText
                      : l.kind == _Kind.del
                          ? ghClosed
                          : AppColors.faint)));
          final code = l.index >= 0 && l.index < src.length
              ? src[l.index]
              : [TextSpan(text: l.text)];
          spans.addAll(code);
      }
      return Container(
        color: bg,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 1),
        child: Text.rich(TextSpan(children: spans),
            softWrap: false,
            style: TextStyle(
                color: AppColors.text,
                fontFamily: 'monospace',
                fontSize: 12.5,
                height: 1.45)),
      );
    }).toList();

    return Container(
      color: AppColors.surface,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: IntrinsicWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: lines,
          ),
        ),
      ),
    );
  }
}
