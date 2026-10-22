import 'package:flutter/material.dart';
import '../../models/github_models.dart';
import '../../services/github_service.dart';
import '../../theme.dart';
import '../../widgets/gh_widgets.dart';

/// One issue or pull request: description and comments.
class IssueDetailScreen extends StatefulWidget {
  const IssueDetailScreen({
    super.key,
    required this.owner,
    required this.repo,
    required this.github,
    required this.issue,
  });

  final String owner;
  final String repo;
  final GitHubService github;
  final GhIssue issue;

  @override
  State<IssueDetailScreen> createState() => _IssueDetailScreenState();
}

class _IssueDetailScreenState extends State<IssueDetailScreen> {
  List<GhComment>? _comments;
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
          .getComments(widget.owner, widget.repo, widget.issue.number);
      if (mounted) setState(() => _comments = c);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final i = widget.issue;
    final width = MediaQuery.of(context).size.width;
    final hPad = width > 1000 ? (width - 920) / 2 : 16.0;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text('${widget.repo} #${i.number}',
            style: TextStyle(color: AppColors.text, fontSize: 17)),
        iconTheme: IconThemeData(color: AppColors.text),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 40),
        children: [
          Text.rich(
            TextSpan(children: [
              TextSpan(text: i.title),
              TextSpan(
                  text: '  #${i.number}',
                  style: TextStyle(
                      color: AppColors.faint, fontWeight: FontWeight.w300)),
            ]),
            style: TextStyle(
                fontFamily: kSerif,
                color: AppColors.text,
                fontSize: 26,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _statePill(i),
              Text(_summary(i),
                  style: TextStyle(color: AppColors.muted, fontSize: 13.5)),
            ],
          ),
          if (i.labels.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
                spacing: 6,
                runSpacing: 6,
                children: i.labels.map((l) => LabelChip(l)).toList()),
          ],
          const SizedBox(height: 20),
          Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 20),
          _commentCard(i.user, i.createdAt, i.body, author: true),
          if (_comments == null)
            Padding(
              padding: const EdgeInsets.all(24),
              child: _error == null
                  ? const Center(child: CircularProgressIndicator())
                  : tabMessage(error: _error, onRetry: _load),
            )
          else
            ..._comments!.map((c) => _commentCard(c.user, c.createdAt, c.body)),
        ],
      ),
    );
  }

  String _summary(GhIssue i) {
    if (i.isPullRequest && i.headRef != null) {
      final verb = i.isMerged ? 'merged' : 'wants to merge';
      return '${i.user.login} $verb ${i.headRef} into ${i.baseRef}';
    }
    final n = i.comments;
    return '${i.user.login} opened this ${timeAgo(i.createdAt)}'
        ' · $n comment${n == 1 ? '' : 's'}';
  }

  Widget _statePill(GhIssue i) {
    late final String text;
    late final Color color;
    late final IconData icon;
    if (i.isPullRequest) {
      if (i.isMerged) {
        (text, color, icon) = ('Merged', ghMerged, Icons.merge);
      } else if (i.isOpen) {
        (text, color, icon) = i.isDraft
            ? ('Draft', ghDraft, Icons.call_split)
            : ('Open', ghOpen, Icons.call_split);
      } else {
        (text, color, icon) = ('Closed', ghClosed, Icons.call_split);
      }
    } else {
      (text, color, icon) = i.isOpen
          ? ('Open', ghOpen, Icons.radio_button_checked)
          : ('Closed', ghMerged, Icons.check_circle_outline);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
          color: color, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: Colors.white),
        const SizedBox(width: 6),
        Text(text,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13.5)),
      ]),
    );
  }

  Widget _commentCard(GhUser user, DateTime? at, String body,
      {bool author = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Avatar(user.avatarUrl, size: 36),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                  color: author
                      ? AppColors.accent.withOpacity(0.5)
                      : AppColors.border),
              borderRadius: BorderRadius.circular(10),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  color: AppColors.surfaceAlt,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  child: Text.rich(TextSpan(children: [
                    TextSpan(
                        text: user.login,
                        style: TextStyle(
                            color: AppColors.text,
                            fontWeight: FontWeight.w600)),
                    TextSpan(
                        text: '  commented ${timeAgo(at)}',
                        style: TextStyle(color: AppColors.muted)),
                  ]), style: const TextStyle(fontSize: 13.5)),
                ),
                Container(
                  color: AppColors.surface,
                  padding: const EdgeInsets.all(14),
                  child: SelectableText(
                    body.trim().isEmpty ? 'No description provided.' : body,
                    style: TextStyle(
                        color: body.trim().isEmpty
                            ? AppColors.faint
                            : AppColors.text,
                        fontSize: 14.5,
                        height: 1.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}
