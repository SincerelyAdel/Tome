import 'package:flutter/material.dart';
import '../../models/actions.dart';
import '../../models/github_models.dart';
import '../../models/org_models.dart';
import '../../models/repo_item.dart';
import '../../services/github_org.dart';
import '../../services/github_service.dart';
import '../../theme.dart';
import '../../widgets/gh_markdown.dart';
import '../../widgets/gh_widgets.dart';
import '../../widgets/loader.dart';
import '../actions_screen.dart';
import '../repo_browser_screen.dart';
import '../repo_tabs/issue_detail_screen.dart';
import 'org_admin_tabs.dart';
import 'project_board_screen.dart';

/// An organization, like its page on github.com plus the owner's views:
/// Overview, Repositories, Inbox, Actions, Projects, People, Teams,
/// Security and Settings (secrets, variables, billing, audit log).
class OrgScreen extends StatefulWidget {
  const OrgScreen({super.key, required this.profile, required this.github});

  final GhProfile profile;
  final GitHubService github;

  @override
  State<OrgScreen> createState() => _OrgScreenState();
}

class _OrgScreenState extends State<OrgScreen> {
  static const _tabs = [
    (Icons.menu_book_outlined, 'Overview'),
    (Icons.book_outlined, 'Repositories'),
    (Icons.inbox_outlined, 'Inbox'),
    (Icons.play_circle_outline, 'Actions'),
    (Icons.view_kanban_outlined, 'Projects'),
    (Icons.people_outline, 'People'),
    (Icons.groups_outlined, 'Teams'),
    (Icons.shield_outlined, 'Security'),
    (Icons.settings_outlined, 'Settings'),
  ];

  int _tab = 0;
  final Set<int> _visited = {0};
  String? _role;

  String get _org => widget.profile.login;

  @override
  void initState() {
    super.initState();
    widget.github.getMyOrgRole(_org).then((r) {
      if (mounted) setState(() => _role = r);
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    final gh = widget.github;
    // Tabs are built the first time they're opened, then kept.
    Widget tab(int i, Widget Function() build) =>
        _visited.contains(i) ? build() : const SizedBox.shrink();
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        iconTheme: IconThemeData(color: AppColors.text),
        title: Text(p.login),
      ),
      body: Column(children: [
        _header(p),
        _tabBar(),
        Expanded(
          child: IndexedStack(index: _tab, children: [
            tab(0, () => _OverviewTab(profile: p, github: gh)),
            tab(1, () => _ReposTab(org: _org, github: gh)),
            tab(2, () => _InboxTab(org: _org, github: gh)),
            tab(3, () => _ActionsTab(org: _org, github: gh)),
            tab(4, () => _ProjectsTab(org: _org, github: gh)),
            tab(5, () => PeopleTab(org: _org, github: gh, isOwner: _role == 'admin')),
            tab(6, () => TeamsTab(org: _org, github: gh)),
            tab(7, () => SecurityTab(org: _org, github: gh)),
            tab(8, () => SettingsTab(org: _org, github: gh)),
          ]),
        ),
      ]),
    );
  }

  Widget _header(GhProfile p) {
    final meta = [
      if (p.location.isNotEmpty) (Icons.location_on_outlined, p.location),
      if (p.blog.isNotEmpty) (Icons.link, p.blog),
      if (p.email.isNotEmpty) (Icons.mail_outline, p.email),
      if (p.twitter.isNotEmpty) (Icons.alternate_email, '@${p.twitter}'),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            color: AppColors.surfaceAlt,
            child: Image.network(p.avatarUrl,
                width: 76,
                height: 76,
                errorBuilder: (_, __, ___) => const SizedBox(width: 76, height: 76)),
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(p.name.isEmpty ? p.login : p.name,
                      style: TextStyle(
                          fontFamily: kSerif,
                          color: AppColors.text,
                          fontSize: 26,
                          fontWeight: FontWeight.w600)),
                  if (_role == 'admin') pill('Owner', AppColors.accent),
                  if (_role == 'member') pill('Member', AppColors.muted),
                ],
              ),
              if (p.bio.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(p.bio,
                    style: TextStyle(color: AppColors.muted, fontSize: 14)),
              ],
              if (meta.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(spacing: 18, runSpacing: 4, children: [
                  for (final m in meta)
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(m.$1, size: 15, color: AppColors.muted),
                      const SizedBox(width: 5),
                      Text(m.$2,
                          style:
                              TextStyle(color: AppColors.text, fontSize: 13)),
                    ]),
                ]),
              ],
            ],
          ),
        ),
      ]),
    );
  }

  Widget _tabBar() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          for (var i = 0; i < _tabs.length; i++)
            InkWell(
              onTap: () => setState(() {
                _tab = i;
                _visited.add(i);
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 13),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                        color:
                            i == _tab ? AppColors.accent : Colors.transparent,
                        width: 2),
                  ),
                ),
                child: Row(children: [
                  Icon(_tabs[i].$1,
                      size: 17,
                      color: i == _tab ? AppColors.text : AppColors.muted),
                  const SizedBox(width: 7),
                  Text(_tabs[i].$2,
                      style: TextStyle(
                          color: AppColors.text,
                          fontSize: 14,
                          fontWeight:
                              i == _tab ? FontWeight.w600 : FontWeight.w400)),
                ]),
              ),
            ),
        ],
      ),
    );
  }
}

/// Padding shared by the org tabs' lists.
const orgPad = EdgeInsets.fromLTRB(24, 18, 24, 48);

// ================================================================ overview

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.profile, required this.github});

  final GhProfile profile;
  final GitHubService github;

  @override
  Widget build(BuildContext context) {
    final org = profile.login;
    return Loader<(String?, GhProfileExtras?)>(
      load: () async {
        final r = await github.getProfileReadme(org, isOrg: true);
        GhProfileExtras? x;
        try {
          x = await github.getProfileExtras(org, isOrg: true);
        } catch (_) {}
        return (r, x);
      },
      builder: (context, data, reload) {
        final (readme, extras) = data;
        final pinned = extras?.pinned ?? [];
        return RefreshIndicator(
          onRefresh: reload,
          child: ListView(padding: orgPad, children: [
            if (readme != null)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: GhMarkdown(readme,
                    imageBase: 'https://raw.githubusercontent.com/$org/.github/HEAD/profile/',
                    fontSize: 15),
              ),
            if (pinned.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text('Pinned',
                  style: TextStyle(color: AppColors.text, fontSize: 16)),
              const SizedBox(height: 10),
              rowsBox([
                for (final r in pinned)
                  _repoTile(context, github, r.owner, r.name, r.description,
                      r.language, r.stars, null, null),
              ]),
            ],
            if (readme == null && pinned.isEmpty)
              emptyNote('This organization has no profile README or pinned '
                  'repositories yet.\nAdd one in a repo named .github, at '
                  'profile/README.md.'),
          ]),
        );
      },
    );
  }
}

Widget _repoTile(BuildContext context, GitHubService gh, String owner,
    String name, String description, String language, int stars,
    DateTime? updated, Widget? badge) {
  final muted = TextStyle(color: AppColors.muted, fontSize: 12.5);
  return InkWell(
    onTap: () => Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            RepoBrowserScreen(owner: owner, repo: name, token: gh.token),
      ),
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.book_outlined, size: 16, color: AppColors.muted),
            const SizedBox(width: 8),
            Flexible(
              child: Text(name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: AppColors.accent,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600)),
            ),
            if (badge != null) ...[const SizedBox(width: 8), badge],
          ]),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: AppColors.muted, fontSize: 13.5, height: 1.4)),
          ],
          const SizedBox(height: 6),
          Text(
              [
                if (language.isNotEmpty) language,
                if (stars > 0) '★ $stars',
                if (updated != null) 'Updated ${timeAgo(updated)}',
              ].join('  ·  '),
              style: muted),
        ],
      ),
    ),
  );
}

// ============================================================ repositories

class _ReposTab extends StatefulWidget {
  const _ReposTab({required this.org, required this.github});

  final String org;
  final GitHubService github;

  @override
  State<_ReposTab> createState() => _ReposTabState();
}

class _ReposTabState extends State<_ReposTab> {
  final _filter = TextEditingController();
  int _type = 0; // All, Public, Private, Sources, Forks

  @override
  void initState() {
    super.initState();
    _filter.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Loader<List<RepoInfo>>(
      load: () => widget.github.getOrgRepos(widget.org),
      builder: (context, repos, reload) {
        final q = _filter.text.trim().toLowerCase();
        final shown = repos.where((r) {
          final typeOk = switch (_type) {
            1 => !r.isPrivate,
            2 => r.isPrivate,
            3 => !r.isFork,
            4 => r.isFork,
            _ => true,
          };
          return typeOk &&
              (q.isEmpty ||
                  r.name.toLowerCase().contains(q) ||
                  r.description.toLowerCase().contains(q));
        }).toList();
        return RefreshIndicator(
          onRefresh: reload,
          child: ListView(padding: orgPad, children: [
            TextField(
              controller: _filter,
              style: TextStyle(color: AppColors.text, fontSize: 14),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Find a repository…',
                hintStyle: TextStyle(color: AppColors.faint),
                prefixIcon:
                    Icon(Icons.search, size: 20, color: AppColors.muted),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: AppColors.border)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: AppColors.border)),
              ),
            ),
            const SizedBox(height: 10),
            segmentChips([
              'All ${repos.length}',
              'Public ${repos.where((r) => !r.isPrivate).length}',
              'Private ${repos.where((r) => r.isPrivate).length}',
              'Sources',
              'Forks',
            ], _type, (i) => setState(() => _type = i)),
            const SizedBox(height: 12),
            if (shown.isEmpty)
              emptyNote('No repositories match.')
            else
              rowsBox([
                for (final r in shown)
                  _repoTile(
                      context,
                      widget.github,
                      r.owner,
                      r.name,
                      r.description,
                      r.language,
                      r.stars,
                      r.updatedAt,
                      outlineBadge(r.isPrivate ? 'Private' : 'Public')),
              ]),
          ]),
        );
      },
    );
  }
}

// =================================================================== inbox

class _InboxTab extends StatefulWidget {
  const _InboxTab({required this.org, required this.github});

  final String org;
  final GitHubService github;

  @override
  State<_InboxTab> createState() => _InboxTabState();
}

class _InboxTabState extends State<_InboxTab> {
  int _view = 0;

  List<(String, String)> get _views => [
        ('Review requests', 'is:open is:pr review-requested:@me'),
        ('Assigned to you', 'is:open assignee:@me'),
        ('Your pull requests', 'is:open is:pr author:@me'),
        ('Mentions', 'is:open mentions:@me'),
        ('All open PRs', 'is:open is:pr'),
        ('All open issues', 'is:open is:issue'),
        ('Recently closed', 'is:closed'),
      ];

  @override
  Widget build(BuildContext context) {
    final (label, q) = _views[_view];
    final query = '$q org:${widget.org} archived:false';
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 4),
        child: segmentChips(
            _views.map((v) => v.$1).toList(), _view,
            (i) => setState(() => _view = i)),
      ),
      Expanded(
        child: Loader<List<GhSearchItem>>(
          key: ValueKey(query),
          load: () => widget.github.searchIssues(query),
          builder: (context, items, reload) => RefreshIndicator(
            onRefresh: reload,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 48),
              children: [
                if (items.isEmpty)
                  emptyNote('Nothing here: ${label.toLowerCase()} is empty.')
                else
                  rowsBox([
                    for (final it in items)
                      searchRow(context, widget.github, it),
                  ]),
              ],
            ),
          ),
        ),
      ),
    ]);
  }
}

/// An issue or PR row that opens its page; shows which repo it's in.
Widget searchRow(BuildContext context, GitHubService gh, GhSearchItem it) {
  final i = it.issue;
  return InkWell(
    onTap: () => Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => IssueDetailScreen(
            owner: it.owner, repo: it.repo, github: gh, issue: i),
      ),
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
            padding: const EdgeInsets.only(top: 2),
            child: issueStateIcon(i, size: 18)),
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
                  Text(it.repo,
                      style: TextStyle(color: AppColors.muted, fontSize: 14)),
                  Text(i.title,
                      style: TextStyle(
                          color: AppColors.text,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                  ...i.labels.map((l) => LabelChip(l)),
                ],
              ),
              const SizedBox(height: 4),
              Text.rich(
                TextSpan(children: [
                  TextSpan(
                      text: '#${i.number} opened ${timeAgo(i.createdAt)} by '),
                  userSpan(i.user.login,
                      style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600)),
                  if (it.updatedAt != null)
                    TextSpan(text: '  ·  updated ${timeAgo(it.updatedAt)}'),
                ]),
                style: TextStyle(color: AppColors.muted, fontSize: 12.5),
              ),
            ],
          ),
        ),
        if (i.comments > 0) ...[
          const SizedBox(width: 10),
          Icon(Icons.chat_bubble_outline, size: 15, color: AppColors.muted),
          const SizedBox(width: 4),
          Text('${i.comments}',
              style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
        ],
      ]),
    ),
  );
}

// ================================================================= actions

class _ActionsTab extends StatefulWidget {
  const _ActionsTab({required this.org, required this.github});

  final String org;
  final GitHubService github;

  @override
  State<_ActionsTab> createState() => _ActionsTabState();
}

class _ActionsTabState extends State<_ActionsTab> {
  int _view = 0; // runs, failures, runners

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 4),
        child: segmentChips(['Recent runs', 'Failed runs', 'Self-hosted runners'],
            _view, (i) => setState(() => _view = i)),
      ),
      Expanded(
        child: _view == 2
            ? Loader<List<GhRunner>>(
                key: const ValueKey('runners'),
                load: () => widget.github.getOrgRunners(widget.org),
                builder: (context, runners, reload) => RefreshIndicator(
                  onRefresh: reload,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(24, 10, 24, 48),
                    children: [
                      if (runners.isEmpty)
                        emptyNote('This organization has no self-hosted '
                            'runners. Jobs run on GitHub-hosted machines.')
                      else
                        rowsBox(runners.map(_runnerRow).toList()),
                    ],
                  ),
                ),
              )
            : Loader<List<(String, WorkflowRun)>>(
                key: const ValueKey('runs'),
                load: () => widget.github.getOrgRuns(widget.org),
                builder: (context, all, reload) {
                  final runs = _view == 1
                      ? all
                          .where((r) =>
                              r.$2.conclusion == 'failure' ||
                              r.$2.conclusion == 'timed_out' ||
                              r.$2.conclusion == 'startup_failure')
                          .toList()
                      : all;
                  return RefreshIndicator(
                    onRefresh: reload,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(24, 10, 24, 48),
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text(
                              'Latest runs from the 15 most recently pushed repos.',
                              style: TextStyle(
                                  color: AppColors.muted, fontSize: 12.5)),
                        ),
                        if (runs.isEmpty)
                          emptyNote(_view == 1
                              ? 'No failed runs. 🎉'
                              : 'No workflow runs yet.')
                        else
                          rowsBox([
                            for (final r in runs) _runRow(context, r.$1, r.$2),
                          ]),
                      ],
                    ),
                  );
                },
              ),
      ),
    ]);
  }

  Widget _runRow(BuildContext context, String repo, WorkflowRun r) {
    final muted = TextStyle(color: AppColors.muted, fontSize: 12.5);
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RunDetailScreen(
              owner: widget.org, repo: repo, github: widget.github, run: r),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(children: [
          StatusIcon(status: r.status, conclusion: r.conclusion),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: AppColors.text,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('$repo  ·  ${r.name} #${r.runNumber}  ·  ${r.event}',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: muted),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            branchChip(r.branch),
            const SizedBox(height: 5),
            Text('${timeAgo(r.createdAt)}  ·  ${formatDuration(r.duration)}',
                style: muted),
          ]),
        ]),
      ),
    );
  }

  Widget _runnerRow(GhRunner r) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
      child: Row(children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: r.online ? ghOpen : AppColors.faint,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(r.name,
                  style: TextStyle(
                      color: AppColors.text,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 5),
              Wrap(spacing: 6, runSpacing: 4, children: [
                for (final l in r.labels) outlineBadge(l),
              ]),
            ],
          ),
        ),
        Text(r.os, style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
        const SizedBox(width: 12),
        r.busy
            ? pill('Busy', AppColors.warning)
            : pill(r.online ? 'Idle' : 'Offline',
                r.online ? ghOpen : AppColors.muted),
      ]),
    );
  }
}

// ================================================================ projects

class _ProjectsTab extends StatelessWidget {
  const _ProjectsTab({required this.org, required this.github});

  final String org;
  final GitHubService github;

  @override
  Widget build(BuildContext context) {
    return Loader<List<GhProject>>(
      load: () => github.getProjects(org),
      builder: (context, projects, reload) => RefreshIndicator(
        onRefresh: reload,
        child: ListView(padding: orgPad, children: [
          if (projects.isEmpty)
            emptyNote('No projects yet.')
          else
            rowsBox([
              for (final p in projects)
                InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProjectBoardScreen(
                          org: org, number: p.number, github: github),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    child: Row(children: [
                      Icon(Icons.view_kanban_outlined,
                          color: p.closed ? AppColors.faint : AppColors.accent),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.title,
                                style: TextStyle(
                                    color: AppColors.text,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 3),
                            Text(
                                [
                                  '#${p.number}',
                                  if (p.description.isNotEmpty) p.description,
                                  '${p.items} items',
                                  if (p.updatedAt != null)
                                    'updated ${timeAgo(p.updatedAt)}',
                                ].join('  ·  '),
                                style: TextStyle(
                                    color: AppColors.muted, fontSize: 12.5)),
                          ],
                        ),
                      ),
                      if (p.closed) pill('Closed', AppColors.muted),
                    ]),
                  ),
                ),
            ]),
        ]),
      ),
    );
  }
}
