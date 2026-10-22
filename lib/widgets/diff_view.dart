import 'package:flutter/material.dart';
import '../models/github_models.dart';
import '../theme.dart';
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
    final lines = patch.split('\n').map((line) {
      Color? bg;
      Color fg = AppColors.text;
      if (line.startsWith('@@')) {
        bg = AppColors.accent.withOpacity(0.10);
        fg = AppColors.muted;
      } else if (line.startsWith('+')) {
        bg = diffAddBg;
      } else if (line.startsWith('-')) {
        bg = diffDelBg;
      }
      return Container(
        color: bg,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 1),
        child: Text(line.isEmpty ? ' ' : line,
            softWrap: false,
            style: TextStyle(
                color: fg,
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
