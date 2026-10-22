import 'package:flutter/material.dart';
import '../../models/github_models.dart';
import '../../services/github_service.dart';
import '../../theme.dart';
import '../../widgets/commit_graph.dart';
import '../../widgets/gh_widgets.dart';
import 'commit_detail_screen.dart';

/// Commit history of the selected branch, with a branch/merge graph.
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
  static const _rowHeight = 66.0;
  static const _maxLanes = 10;

  List<GhCommit>? _commits;
  List<GraphRow> _graph = [];
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
      if (mounted && branch == widget.branch) {
        setState(() {
          _commits = c;
          _graph = layoutGraph(c);
        });
      }
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

    final lanes = _graph
        .map((r) => r.width)
        .fold<int>(1, (a, b) => a > b ? a : b)
        .clamp(1, _maxLanes);
    final graphWidth = lanes * laneWidth + 16;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 32),
        itemExtent: _rowHeight,
        itemCount: commits.length,
        itemBuilder: (_, i) => _row(commits[i], _graph[i], graphWidth),
      ),
    );
  }

  Widget _row(GhCommit c, GraphRow g, double graphWidth) {
    final who = c.author?.login ?? c.authorName;
    final isMerge = c.parents.length > 1;
    return InkWell(
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
      child: Row(children: [
        SizedBox(
          width: graphWidth,
          height: _rowHeight,
          child: ClipRect(
            child: CustomPaint(
              painter: GraphRowPainter(g,
                  isMerge: isMerge, dark: AppColors.isDark),
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: _rowHeight,
            padding: const EdgeInsets.only(left: 4, right: 8),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: isMerge ? AppColors.muted : AppColors.text,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 5),
                    Row(children: [
                      Avatar(c.author?.avatarUrl ?? '', size: 18),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                            '$who committed ${timeAgo(c.date)}'
                            '${c.date == null ? '' : '  ·  ${_date(c.date!.toLocal())}'}',
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
      ]),
    );
  }
}

String _date(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  return '${months[d.month - 1]} ${d.day}, ${d.year}';
}
