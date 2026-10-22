import 'package:flutter/material.dart';
import '../../models/org_models.dart';
import '../../services/github_org.dart';
import '../../services/github_service.dart';
import '../../theme.dart';
import '../../widgets/gh_widgets.dart';
import '../../widgets/loader.dart';
import '../repo_tabs/issue_detail_screen.dart';

/// An org Project as a board: one column per Status, cards for its issues,
/// pull requests and drafts. Tapping an issue or PR opens it.
class ProjectBoardScreen extends StatelessWidget {
  const ProjectBoardScreen(
      {super.key, required this.org, required this.number, required this.github});

  final String org;
  final int number;
  final GitHubService github;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        iconTheme: IconThemeData(color: AppColors.text),
        title: Text('$org · Project #$number'),
      ),
      body: Loader<GhProjectBoard>(
      load: () => github.getProjectBoard(org, number),
      builder: (context, board, reload) {
        final columns = [...board.columns];
        if (board.items.any((i) => !columns.contains(i.status))) {
          columns.insert(0, 'No status');
        }
        List<GhProjectItem> itemsIn(String c) => board.items
            .where((i) => c == 'No status'
                ? !board.columns.contains(i.status)
                : i.status == c)
            .toList();
        return Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 12, 0),
            child: Row(children: [
              Expanded(
                child: Text(board.title,
                    style: TextStyle(
                        fontFamily: kSerif,
                        color: AppColors.text,
                        fontSize: 22)),
              ),
              IconButton(
                  icon: Icon(Icons.refresh, color: AppColors.muted),
                  onPressed: reload),
            ]),
          ),
          Expanded(
            child: columns.isEmpty
                ? emptyNote('This project has no items yet.')
                : ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.all(16),
                    children: [
                      for (final c in columns) _column(context, c, itemsIn(c)),
                    ],
                  ),
          ),
        ]);
      },
      ),
    );
  }

  Widget _column(BuildContext context, String name, List<GhProjectItem> items) {
    return Container(
      width: 330,
      margin: const EdgeInsets.only(right: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(children: [
            Expanded(
              child: Text(name,
                  style: TextStyle(
                      color: AppColors.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('${items.length}',
                  style: TextStyle(color: AppColors.muted, fontSize: 12)),
            ),
          ]),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
            children: [for (final i in items) _card(context, i)],
          ),
        ),
      ]),
    );
  }

  Widget _card(BuildContext context, GhProjectItem item) {
    final issue = item.issue;
    return Card(
      color: AppColors.bg,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: issue == null
            ? null
            : () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => IssueDetailScreen(
                        owner: item.owner,
                        repo: item.repo,
                        github: github,
                        issue: issue),
                  ),
                ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                issue == null
                    ? Icon(Icons.edit_note, size: 17, color: AppColors.muted)
                    : issueStateIcon(issue, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                      issue == null
                          ? 'Draft'
                          : '${item.repo} #${issue.number}',
                      style: TextStyle(color: AppColors.muted, fontSize: 12)),
                ),
                if (issue != null)
                  Avatar(issue.user.avatarUrl,
                      size: 18, login: issue.user.login),
              ]),
              const SizedBox(height: 6),
              Text(item.title,
                  style: TextStyle(
                      color: AppColors.text, fontSize: 14, height: 1.35)),
            ],
          ),
        ),
      ),
    );
  }
}
