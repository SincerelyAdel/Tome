import 'package:flutter/material.dart';
import '../../models/github_models.dart';
import '../../services/github_service.dart';
import '../../theme.dart';
import '../../widgets/gh_widgets.dart';
import 'commit_detail_screen.dart';

/// Commit history of the selected branch, grouped by day like GitHub.
class CommitsTab extends StatefulWidget {
  const CommitsTab({
    super.key,
    required this.owner,
    required this.repo,
    required this.github,
    this.branch,
  });

  final String owner;
  final String repo;
  final GitHubService github;
  final String? branch;

  @override
  State<CommitsTab> createState() => _CommitsTabState();
}

class _CommitsTabState extends State<CommitsTab> {
  List<GhCommit>? _commits;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant CommitsTab old) {
    super.didUpdateWidget(old);
    if (old.branch != widget.branch) {
      _commits = null;
      _load();
    }
  }

  Future<void> _load() async {
    final branch = widget.branch;
    setState(() => _error = null);
    try {
      final c = await widget.github
          .getCommits(widget.owner, widget.repo, branch: branch);
      if (mounted && branch == widget.branch) setState(() => _commits = c);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final commits = _commits;
    if (commits == null) return tabMessage(error: _error, onRetry: _load);
    if (commits.isEmpty) return tabMessage(empty: 'No commits');

    // Day headers between commits from different days.
    final rows = <Widget>[];
    String? day;
    for (final c in commits) {
      final d = c.date == null ? '' : _dayLabel(c.date!.toLocal());
      if (d != day) {
        day = d;
        rows.add(Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
          child: Row(children: [
            Icon(Icons.commit, size: 16, color: AppColors.muted),
            const SizedBox(width: 8),
            Text('Commits on $d',
                style: TextStyle(color: AppColors.muted, fontSize: 13)),
          ]),
        ));
      }
      rows.add(_row(c));
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: rows,
      ),
    );
  }

  Widget _row(GhCommit c) {
    final who = c.author?.login ?? c.authorName;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          left: BorderSide(color: AppColors.border),
          right: BorderSide(color: AppColors.border),
          bottom: BorderSide(color: AppColors.border),
          top: BorderSide(color: AppColors.border, width: 0.5),
        ),
      ),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CommitDetailScreen(
              owner: widget.owner,
              repo: widget.repo,
              github: widget.github,
              summary: c,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: AppColors.text,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Row(children: [
                    Avatar(c.author?.avatarUrl ?? '', size: 18),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text('$who committed ${timeAgo(c.date)}',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: AppColors.muted, fontSize: 12.5)),
                    ),
                  ]),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(c.shortSha,
                  style: TextStyle(
                      fontFamily: 'monospace',
                      color: AppColors.muted,
                      fontSize: 12.5)),
            ),
          ]),
        ),
      ),
    );
  }
}

String _dayLabel(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  return '${months[d.month - 1]} ${d.day}, ${d.year}';
}
