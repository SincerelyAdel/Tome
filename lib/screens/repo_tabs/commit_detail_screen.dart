import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/github_models.dart';
import '../../services/github_service.dart';
import '../../theme.dart';
import '../../widgets/diff_view.dart';
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
            Row(children: [
              Text(
                  '${c.files.length} changed file'
                  '${c.files.length == 1 ? '' : 's'}  ',
                  style: TextStyle(color: AppColors.text, fontSize: 14)),
              diffStat(c.additions, c.deletions, fontSize: 14),
              const SizedBox(width: 6),
              diffBar(c.additions, c.deletions),
            ]),
            const SizedBox(height: 12),
            ...c.files.map((f) => DiffFileCard(f)),
          ],
        ],
      ),
    );
  }
}
