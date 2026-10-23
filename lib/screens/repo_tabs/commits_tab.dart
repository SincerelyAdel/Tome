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
  static const _pageSize = 100;

  List<GhCommit>? _commits;
  List<GraphRow> _graph = [];
  String? _error;

  /// Older history loads a page at a time as the list nears its end.
  int _page = 1;
  bool _hasMore = true;
  bool _loadingMore = false;
  String? _moreError;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.extentAfter < _rowHeight * 12) _loadMore();
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
      final c = await widget.github.getCommits(widget.owner, widget.repo,
          branch: branch, perPage: _pageSize);
      if (mounted && branch == widget.branch) {
        setState(() {
          _commits = c;
          _graph = layoutGraph(c);
          _page = 1;
          _hasMore = c.length == _pageSize;
          _moreError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<void> _loadMore() async {
    final commits = _commits;
    if (commits == null || !_hasMore || _loadingMore || _moreError != null) {
      return;
    }
    final branch = widget.branch;
    setState(() => _loadingMore = true);
    try {
      final next = await widget.github.getCommits(widget.owner, widget.repo,
          branch: branch, page: _page + 1, perPage: _pageSize);
      if (!mounted || branch != widget.branch || _commits != commits) return;
      // Pages can overlap if new commits were pushed meanwhile.
      final seen = commits.map((c) => c.sha).toSet();
      final all = [...commits, ...next.where((c) => !seen.contains(c.sha))];
      setState(() {
        _commits = all;
        _graph = layoutGraph(all);
        _page++;
        _hasMore = next.length == _pageSize;
        _loadingMore = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingMore = false;
          _moreError = e.toString().replaceFirst('Exception: ', '');
        });
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
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 32),
        itemExtent: _rowHeight,
        itemCount: commits.length + 1,
        itemBuilder: (_, i) => i < commits.length
            ? _row(commits[i], _graph[i], graphWidth)
            : _footer(commits.length),
      ),
    );
  }

  /// Spinner while the next page loads, a retry on error, or the end.
  Widget _footer(int count) {
    if (_moreError != null) {
      return Center(
        child: TextButton.icon(
          icon: Icon(Icons.refresh, color: AppColors.danger, size: 18),
          label: Text('Couldn’t load more. Retry',
              style: TextStyle(color: AppColors.danger)),
          onPressed: () {
            setState(() => _moreError = null);
            _loadMore();
          },
        ),
      );
    }
    if (_hasMore) {
      return const Center(
        child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5)),
      );
    }
    return Center(
      child: Text('$count commits · start of history',
          style: TextStyle(color: AppColors.faint, fontSize: 12.5)),
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
                      Avatar(c.author?.avatarUrl ?? '', size: 18, login: c.author?.login),
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
