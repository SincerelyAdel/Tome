import 'package:flutter/material.dart';
import '../../models/github_models.dart';
import '../../services/github_service.dart';
import '../../theme.dart';
import '../../widgets/gh_widgets.dart';
import 'issue_detail_screen.dart';

/// Open/closed list of issues, or of pull requests when [pulls] is true.
class IssuesTab extends StatefulWidget {
  const IssuesTab({
    super.key,
    required this.owner,
    required this.repo,
    required this.github,
    required this.pulls,
    this.onOpenCount,
  });

  final String owner;
  final String repo;
  final GitHubService github;
  final bool pulls;

  /// Reports how many are open, for the count on the tab.
  final ValueChanged<int>? onOpenCount;

  @override
  State<IssuesTab> createState() => _IssuesTabState();
}

class _IssuesTabState extends State<IssuesTab> {
  bool _showOpen = true;
  final Map<bool, List<GhIssue>> _lists = {};
  final Map<bool, String> _errors = {};

  @override
  void initState() {
    super.initState();
    _load(true);
  }

  Future<void> _load(bool open) async {
    setState(() => _errors.remove(open));
    try {
      final list = widget.pulls
          ? await widget.github
              .getPulls(widget.owner, widget.repo, open: open)
          : await widget.github
              .getIssues(widget.owner, widget.repo, open: open);
      if (!mounted) return;
      setState(() => _lists[open] = list);
      if (open) widget.onOpenCount?.call(list.length);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errors[open] =
          e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _select(bool open) {
    setState(() => _showOpen = open);
    if (!_lists.containsKey(open)) _load(open);
  }

  @override
  Widget build(BuildContext context) {
    final list = _lists[_showOpen];
    final noun = widget.pulls ? 'pull requests' : 'issues';
    return Column(children: [
      _buildFilterBar(),
      Divider(height: 1, color: AppColors.border),
      Expanded(
        child: list == null
            ? tabMessage(
                error: _errors[_showOpen], onRetry: () => _load(_showOpen))
            : list.isEmpty
                ? tabMessage(
                    empty: 'No ${_showOpen ? 'open' : 'closed'} $noun')
                : RefreshIndicator(
                    onRefresh: () => _load(_showOpen),
                    child: ListView.separated(
                      itemCount: list.length,
                      separatorBuilder: (_, __) =>
                          Divider(height: 1, color: AppColors.border),
                      itemBuilder: (_, i) => _row(list[i]),
                    ),
                  ),
      ),
    ]);
  }

  Widget _buildFilterBar() {
    Widget option(bool open) {
      final count = _lists[open]?.length;
      final selected = _showOpen == open;
      final icon = widget.pulls
          ? (open ? Icons.call_split : Icons.check)
          : (open ? Icons.radio_button_checked : Icons.check);
      return InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _select(open),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon,
                size: 16, color: selected ? AppColors.text : AppColors.muted),
            const SizedBox(width: 6),
            Text(
              '${count == null ? '' : '${count == 100 ? '100+' : count} '}'
              '${open ? 'Open' : 'Closed'}',
              style: TextStyle(
                  color: selected ? AppColors.text : AppColors.muted,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  fontSize: 14),
            ),
          ]),
        ),
      );
    }

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(children: [option(true), option(false)]),
    );
  }

  Widget _row(GhIssue i) {
    final verb = i.isOpen
        ? 'opened ${timeAgo(i.createdAt)}'
        : i.isMerged
            ? 'merged ${timeAgo(i.closedAt)}'
            : 'closed ${timeAgo(i.closedAt)}';
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => IssueDetailScreen(
            owner: widget.owner,
            repo: widget.repo,
            github: widget.github,
            issue: i,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: issueStateIcon(i, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(i.title,
                        style: TextStyle(
                            color: AppColors.text,
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                    if (i.isDraft) outlineBadge('Draft'),
                    ...i.labels.map((l) => LabelChip(l)),
                  ],
                ),
                const SizedBox(height: 4),
                Text.rich(
                    TextSpan(children: [
                      TextSpan(text: '#${i.number} $verb by '),
                      userSpan(i.user.login,
                          style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600)),
                    ]),
                    style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
              ],
            ),
          ),
          if (i.comments > 0) ...[
            const SizedBox(width: 12),
            Icon(Icons.chat_bubble_outline, size: 15, color: AppColors.muted),
            const SizedBox(width: 4),
            Text('${i.comments}',
                style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
          ],
        ]),
      ),
    );
  }
}
