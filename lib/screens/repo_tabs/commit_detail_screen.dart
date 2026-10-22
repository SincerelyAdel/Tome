import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/github_models.dart';
import '../../services/github_service.dart';
import '../../theme.dart';
import '../../widgets/gh_widgets.dart';

/// One commit: message, author, and each changed file with its diff.
class CommitDetailScreen extends StatefulWidget {
  const CommitDetailScreen({
    super.key,
    required this.owner,
    required this.repo,
    required this.github,
    required this.summary,
  });

  final String owner;
  final String repo;
  final GitHubService github;

  /// The commit from the list (no files yet); details load on open.
  final GhCommit summary;

  @override
  State<CommitDetailScreen> createState() => _CommitDetailScreenState();
}

class _CommitDetailScreenState extends State<CommitDetailScreen> {
  GhCommit? _commit;
  String? _error;
  final Set<String> _collapsed = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final c = await widget.github
          .getCommit(widget.owner, widget.repo, widget.summary.sha);
      if (mounted) setState(() => _commit = c);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Green get _add => Green(AppColors.isDark);

  @override
  Widget build(BuildContext context) {
    final c = _commit ?? widget.summary;
    final who = c.author?.login ?? c.authorName;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text('Commit ${c.shortSha}',
            style: TextStyle(
                color: AppColors.text, fontFamily: 'monospace', fontSize: 16)),
        iconTheme: IconThemeData(color: AppColors.text),
        actions: [
          IconButton(
            icon: Icon(Icons.copy, color: AppColors.muted, size: 20),
            tooltip: 'Copy SHA',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: c.sha));
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Commit SHA copied')));
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          Text(c.title,
              style: TextStyle(
                  color: AppColors.text,
                  fontSize: 20,
                  fontWeight: FontWeight.w600)),
          if (c.description.isNotEmpty) ...[
            const SizedBox(height: 10),
            SelectableText(c.description,
                style: TextStyle(
                    color: AppColors.muted, fontSize: 14, height: 1.5)),
          ],
          const SizedBox(height: 14),
          Row(children: [
            Avatar(c.author?.avatarUrl ?? '', size: 22),
            const SizedBox(width: 8),
            Text('$who committed ${timeAgo(c.date)}',
                style: TextStyle(color: AppColors.muted, fontSize: 13.5)),
          ]),
          const SizedBox(height: 18),
          if (_commit == null)
            Padding(
              padding: const EdgeInsets.all(24),
              child: tabMessage(error: _error, onRetry: _load),
            )
          else ...[
            Text.rich(TextSpan(children: [
              TextSpan(
                  text: '${c.files.length} changed file'
                      '${c.files.length == 1 ? '' : 's'}  '),
              TextSpan(
                  text: '+${c.additions} ', style: TextStyle(color: _add.text)),
              TextSpan(
                  text: '−${c.deletions}', style: TextStyle(color: ghClosed)),
            ]), style: TextStyle(color: AppColors.text, fontSize: 14)),
            const SizedBox(height: 12),
            ...c.files.map(_fileCard),
          ],
        ],
      ),
    );
  }

  Widget _fileCard(GhFileChange f) {
    final collapsed = _collapsed.contains(f.filename);
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
            onTap: () => setState(() => collapsed
                ? _collapsed.remove(f.filename)
                : _collapsed.add(f.filename)),
            child: Container(
              color: AppColors.surfaceAlt,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(children: [
                Icon(collapsed ? Icons.chevron_right : Icons.expand_more,
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
                if (f.status == 'added') outlineBadge('new', color: _add.text),
                if (f.status == 'removed')
                  outlineBadge('deleted', color: ghClosed),
                if (f.status == 'renamed') outlineBadge('renamed'),
                const SizedBox(width: 8),
                Text('+${f.additions}',
                    style: TextStyle(color: _add.text, fontSize: 12.5)),
                const SizedBox(width: 6),
                Text('−${f.deletions}',
                    style: TextStyle(color: ghClosed, fontSize: 12.5)),
              ]),
            ),
          ),
          if (!collapsed) _diff(f),
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
    final del = ghClosed;
    final lines = patch.split('\n').map((line) {
      Color? bg;
      Color fg = AppColors.text;
      if (line.startsWith('@@')) {
        bg = AppColors.accent.withOpacity(0.10);
        fg = AppColors.muted;
      } else if (line.startsWith('+')) {
        bg = _add.bg;
      } else if (line.startsWith('-')) {
        bg = del.withOpacity(AppColors.isDark ? 0.16 : 0.10);
      }
      return Container(
        color: bg,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 1),
        child: Text(line.isEmpty ? ' ' : line,
            softWrap: false,
            style: TextStyle(
                color: fg, fontFamily: 'monospace', fontSize: 12.5, height: 1.45)),
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

/// Green used for additions in diffs.
class Green {
  Green(this.dark);
  final bool dark;
  Color get text => ghOpen;
  Color get bg => ghOpen.withOpacity(dark ? 0.16 : 0.12);
}
