import 'package:flutter/material.dart';
import '../models/github_models.dart';
import '../models/repo_item.dart';
import '../services/github_org.dart';
import '../services/github_service.dart';
import '../theme.dart';
import '../widgets/gh_markdown.dart';
import '../widgets/gh_widgets.dart';
import 'org/org_screen.dart';
import 'repo_browser_screen.dart';

/// A GitHub profile laid out like github.com: avatar and details on the
/// left; Overview (README, pinned repos, contributions), Repositories,
/// Followers and Following on the right.
class ProfileScreen extends StatefulWidget {
  ProfileScreen({super.key, required this.login, GitHubService? github})
      : github = github ?? GitHubService.current;

  final String login;
  final GitHubService github;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _tab = 0; // 0 Overview, 1 Repositories, 2 Followers, 3 Following

  GhProfile? _profile;
  String? _error;
  String? _readme;
  bool _readmeLoaded = false;
  GhProfileExtras? _extras;
  List<RepoInfo>? _repos;
  List<GhUser> _orgs = [];
  String? _reposError;
  final _people = <int, List<GhUser>>{};
  final _peopleErrors = <int, String>{};
  final _filter = TextEditingController();

  GitHubService get _gh => widget.github;

  @override
  void initState() {
    super.initState();
    _filter.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  String _msg(Object e) => e.toString().replaceFirst('Exception: ', '');

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final p = await _gh.getProfile(widget.login);
      if (!mounted) return;
      setState(() => _profile = p);
      _gh.getProfileReadme(p.login, isOrg: p.isOrg).then((r) {
        if (mounted) {
          setState(() {
            _readme = r;
            _readmeLoaded = true;
          });
        }
      });
      _gh.getProfileExtras(p.login, isOrg: p.isOrg).then((x) {
        if (mounted) setState(() => _extras = x);
      }).catchError((_) {});
      if (!p.isOrg) {
        _loadRepos();
        _loadOrgs(p.login);
      }
    } catch (e) {
      if (mounted) setState(() => _error = _msg(e));
    }
  }

  /// Your own profile also lists private org memberships.
  Future<void> _loadOrgs(String login) async {
    try {
      var own = false;
      if (_gh.hasToken) {
        try {
          own = (await _gh.getViewer()).login.toLowerCase() ==
              login.toLowerCase();
        } catch (_) {}
      }
      final orgs = own ? await _gh.getMyOrgs() : await _gh.getUserOrgs(login);
      if (mounted) setState(() => _orgs = orgs);
    } catch (_) {}
  }

  Future<void> _loadRepos() async {
    setState(() => _reposError = null);
    try {
      final r = await _gh.getUserRepos(widget.login);
      if (mounted) setState(() => _repos = r);
    } catch (e) {
      if (mounted) setState(() => _reposError = _msg(e));
    }
  }

  Future<void> _loadPeople(int tab) async {
    if (_people.containsKey(tab)) return;
    _peopleErrors.remove(tab);
    try {
      final list =
          await _gh.getFollowers(widget.login, following: tab == 3);
      if (mounted) setState(() => _people[tab] = list);
    } catch (e) {
      if (mounted) setState(() => _peopleErrors[tab] = _msg(e));
    }
  }

  void _select(int tab) {
    setState(() => _tab = tab);
    if (tab >= 2) _loadPeople(tab);
  }

  void _openRepo(String owner, String name) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            RepoBrowserScreen(owner: owner, repo: name, token: _gh.token),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = _profile;
    if (p != null && p.isOrg) return OrgScreen(profile: p, github: _gh);
    final wide = MediaQuery.of(context).size.width > 900;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        iconTheme: IconThemeData(color: AppColors.text),
        title: Text(widget.login),
      ),
      body: p == null
          ? tabMessage(error: _error, onRetry: _load)
          : RefreshIndicator(
              onRefresh: () async {
                _people.clear();
                await _load();
              },
              child: wide ? _wide(p) : _narrow(p),
            ),
    );
  }

  Widget _wide(GhProfile p) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 320,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(28, 28, 20, 40),
            children: [_details(p, avatarSize: 260)],
          ),
        ),
        Expanded(
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _tabBar(p)),
              ..._tabBody(p),
              const SliverToBoxAdapter(child: SizedBox(height: 48)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _narrow(GhProfile p) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          sliver: SliverToBoxAdapter(child: _details(p, avatarSize: 96)),
        ),
        SliverToBoxAdapter(child: _tabBar(p)),
        ..._tabBody(p),
        const SliverToBoxAdapter(child: SizedBox(height: 48)),
      ],
    );
  }

  // ----------------------------------------------------------- left column

  Widget _details(GhProfile p, {required double avatarSize}) {
    final muted = TextStyle(color: AppColors.muted, fontSize: 14);
    Widget line(IconData icon, String text) => Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 16, color: AppColors.muted),
            const SizedBox(width: 8),
            Expanded(
                child: SelectableText(text,
                    style: TextStyle(color: AppColors.text, fontSize: 13.5))),
          ]),
        );
    final avatar = Container(
      decoration: BoxDecoration(
        shape: p.isOrg ? BoxShape.rectangle : BoxShape.circle,
        borderRadius: p.isOrg ? BorderRadius.circular(16) : null,
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(p.isOrg ? 15 : avatarSize),
        child: Image.network(
          p.avatarUrl,
          width: avatarSize,
          height: avatarSize,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => SizedBox(
              width: avatarSize,
              height: avatarSize,
              child: Icon(Icons.person, color: AppColors.faint)),
        ),
      ),
    );
    final names = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (p.name.isNotEmpty)
          Text(p.name,
              style: TextStyle(
                  fontFamily: kSerif,
                  color: AppColors.text,
                  fontSize: 26,
                  fontWeight: FontWeight.w600,
                  height: 1.2)),
        Text(p.login,
            style: TextStyle(
                color: AppColors.muted, fontSize: 19, fontWeight: FontWeight.w300)),
      ],
    );
    final narrow = avatarSize < 200;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (narrow)
          Row(children: [
            avatar,
            const SizedBox(width: 18),
            Expanded(child: names),
          ])
        else ...[
          avatar,
          const SizedBox(height: 16),
          names,
        ],
        if (p.bio.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(p.bio,
              style: TextStyle(color: AppColors.text, fontSize: 15, height: 1.45)),
        ],
        if (!p.isOrg) ...[
          const SizedBox(height: 14),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Icon(Icons.people_outline, size: 16, color: AppColors.muted),
              const SizedBox(width: 6),
              _countLink(p.followers, 'followers', 2),
              Text('  ·  ', style: muted),
              _countLink(p.following, 'following', 3),
            ],
          ),
        ],
        const SizedBox(height: 6),
        if (p.company.isNotEmpty) line(Icons.business_outlined, p.company),
        if (p.location.isNotEmpty) line(Icons.location_on_outlined, p.location),
        if (p.email.isNotEmpty) line(Icons.mail_outline, p.email),
        if (p.blog.isNotEmpty) line(Icons.link, p.blog),
        if (p.twitter.isNotEmpty) line(Icons.alternate_email, '@${p.twitter}'),
        if (p.createdAt != null)
          line(Icons.calendar_today_outlined,
              'Joined ${_monthYear(p.createdAt!)}'),
        if (_orgs.isNotEmpty) ...[
          const SizedBox(height: 18),
          Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 14),
          Text('Organizations',
              style: TextStyle(
                  color: AppColors.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          for (final o in _orgs)
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => ProfileScreen(login: o.login, github: _gh)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(o.avatarUrl,
                        width: 32,
                        height: 32,
                        errorBuilder: (_, __, ___) =>
                            const SizedBox(width: 32, height: 32)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(o.login,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: AppColors.accent,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                  ),
                  Icon(Icons.chevron_right, size: 18, color: AppColors.faint),
                ]),
              ),
            ),
        ],
      ],
    );
  }

  Widget _countLink(int n, String label, int tab) {
    return InkWell(
      onTap: () => _select(tab),
      child: Text.rich(TextSpan(children: [
        TextSpan(
            text: _compact(n),
            style: TextStyle(
                color: AppColors.text, fontWeight: FontWeight.w600)),
        TextSpan(text: ' $label', style: TextStyle(color: AppColors.muted)),
      ]), style: const TextStyle(fontSize: 14)),
    );
  }

  // --------------------------------------------------------------- tabs

  Widget _tabBar(GhProfile p) {
    final tabs = [
      (Icons.menu_book_outlined, 'Overview', null),
      (Icons.book_outlined, 'Repositories', _repos?.length ?? p.publicRepos),
      if (!p.isOrg) (Icons.people_outline, 'Followers', p.followers),
      if (!p.isOrg) (Icons.person_add_alt, 'Following', p.following),
    ];
    return Container(
      height: 48,
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: [
          for (var i = 0; i < tabs.length; i++)
            InkWell(
              onTap: () => _select(i),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                        color: i == _tab
                            ? AppColors.accent
                            : Colors.transparent,
                        width: 2),
                  ),
                ),
                child: Row(children: [
                  Icon(tabs[i].$1,
                      size: 17,
                      color: i == _tab ? AppColors.text : AppColors.muted),
                  const SizedBox(width: 8),
                  Text(tabs[i].$2,
                      style: TextStyle(
                          color: AppColors.text,
                          fontSize: 14,
                          fontWeight:
                              i == _tab ? FontWeight.w600 : FontWeight.w400)),
                  if (tabs[i].$3 != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(_compact(tabs[i].$3!),
                          style: TextStyle(
                              color: AppColors.text, fontSize: 12)),
                    ),
                  ],
                ]),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _tabBody(GhProfile p) {
    const pad = EdgeInsets.fromLTRB(20, 20, 20, 0);
    Widget box(Widget w) =>
        SliverPadding(padding: pad, sliver: SliverToBoxAdapter(child: w));
    switch (_tab) {
      case 0:
        return _overview(p).map(box).toList();
      case 1:
        return _repoList(pad);
      default:
        return [box(_peopleList(_tab))];
    }
  }

  List<Widget> _overview(GhProfile p) {
    final x = _extras;
    final readme = _readme;
    final out = <Widget>[];
    if (readme != null) {
      final base = p.isOrg
          ? 'https://raw.githubusercontent.com/${p.login}/.github/HEAD/profile/'
          : 'https://raw.githubusercontent.com/${p.login}/${p.login}/HEAD/';
      out.add(_card(
        header: Text.rich(TextSpan(children: [
          TextSpan(text: p.login, style: TextStyle(color: AppColors.muted)),
          TextSpan(
              text: ' / README.md',
              style: TextStyle(color: AppColors.muted)),
        ]), style: const TextStyle(fontSize: 12.5, fontFamily: 'monospace')),
        child: GhMarkdown(readme, imageBase: base, fontSize: 15),
      ));
    }
    // Pinned repos (token only), else the most recently pushed ones.
    final pinned = x?.pinned ?? const <GhPinnedRepo>[];
    final popular = pinned.isNotEmpty
        ? pinned
        : (_repos ?? [])
            .where((r) => !r.isFork)
            .take(6)
            .map((r) => GhPinnedRepo(
                owner: r.owner,
                name: r.name,
                description: r.description,
                language: r.language,
                stars: r.stars))
            .toList();
    if (popular.isNotEmpty) {
      out.add(Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(pinned.isNotEmpty ? 'Pinned' : 'Recent repositories',
              style: TextStyle(color: AppColors.text, fontSize: 16)),
          const SizedBox(height: 10),
          LayoutBuilder(builder: (context, box) {
            final cols = box.maxWidth > 560 ? 2 : 1;
            final w = (box.maxWidth - 14 * (cols - 1)) / cols;
            return Wrap(
              spacing: 14,
              runSpacing: 14,
              children: popular
                  .map((r) => SizedBox(width: w, child: _pinnedCard(r)))
                  .toList(),
            );
          }),
        ],
      ));
    }
    if (x != null && x.weeks.isNotEmpty) {
      out.add(_contributions(x));
    }
    if (out.isEmpty) {
      out.add(_readmeLoaded && _repos != null
          ? Text('Nothing to show yet.',
              style: TextStyle(color: AppColors.muted))
          : const Center(child: CircularProgressIndicator()));
    }
    return out;
  }

  Widget _card({required Widget header, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: header,
          ),
          Padding(padding: const EdgeInsets.all(22), child: child),
        ],
      ),
    );
  }

  Widget _pinnedCard(GhPinnedRepo r) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openRepo(r.owner, r.name),
        child: Container(
          height: 128,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.book_outlined, size: 16, color: AppColors.muted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                      r.owner.toLowerCase() == widget.login.toLowerCase()
                          ? r.name
                          : '${r.owner}/${r.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: AppColors.accent,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                ),
              ]),
              const SizedBox(height: 8),
              Expanded(
                child: Text(r.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: AppColors.muted, fontSize: 13, height: 1.4)),
              ),
              _repoMeta(r.language, r.languageColor, r.stars, r.forks, null),
            ],
          ),
        ),
      ),
    );
  }

  Widget _repoMeta(
      String lang, String langColor, int stars, int forks, DateTime? updated) {
    final style = TextStyle(color: AppColors.muted, fontSize: 12.5);
    return Wrap(
      spacing: 16,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (lang.isNotEmpty)
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 11,
              height: 11,
              decoration: BoxDecoration(
                  color: _langColor(lang, langColor), shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
            Text(lang, style: style),
          ]),
        if (stars > 0)
          Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.star_border, size: 15, color: AppColors.muted),
            const SizedBox(width: 3),
            Text(_compact(stars), style: style),
          ]),
        if (forks > 0)
          Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.call_split, size: 14, color: AppColors.muted),
            const SizedBox(width: 3),
            Text(_compact(forks), style: style),
          ]),
        if (updated != null) Text('Updated ${timeAgo(updated)}', style: style),
      ],
    );
  }

  /// The contribution calendar, in gold instead of GitHub's green.
  Widget _contributions(GhProfileExtras x) {
    const cell = 12.0, gap = 3.0;
    final weeks = x.weeks;
    Color shade(int level) => level == 0
        ? AppColors.surfaceAlt
        : Color.lerp(AppColors.accent.withOpacity(0.25), AppColors.accentLight,
            (level - 1) / 3)!;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final monthLabels = <Widget>[];
    for (var w = 0; w < weeks.length; w++) {
      final first = weeks[w].first.date;
      final show = w == 0
          ? first.day <= 7
          : first.month != weeks[w - 1].first.date.month;
      monthLabels.add(SizedBox(
        width: cell + gap,
        child: show
            // Wider than its week column; paints past it on purpose.
            ? Text(months[first.month - 1],
                softWrap: false,
                overflow: TextOverflow.visible,
                style: TextStyle(color: AppColors.muted, fontSize: 11))
            : null,
      ));
    }
    final grid = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: monthLabels),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final week in weeks)
              Padding(
                padding: const EdgeInsets.only(right: gap),
                child: Column(children: [
                  // The first week may start mid-week.
                  for (var pad = 0; pad < 7 - week.length && week == weeks.first; pad++)
                    const SizedBox(width: cell, height: cell + gap),
                  for (final d in week)
                    Tooltip(
                      message: '${d.count} contribution'
                          '${d.count == 1 ? '' : 's'} on ${_day(d.date)}',
                      child: Container(
                        width: cell,
                        height: cell,
                        margin: const EdgeInsets.only(bottom: gap),
                        decoration: BoxDecoration(
                          color: shade(d.level),
                          borderRadius: BorderRadius.circular(2.5),
                        ),
                      ),
                    ),
                ]),
              ),
          ],
        ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
            '${_compact(x.totalContributions)} contribution'
            '${x.totalContributions == 1 ? '' : 's'} in the last year',
            style: TextStyle(color: AppColors.text, fontSize: 16)),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                reverse: true, // newest weeks visible first
                child: grid,
              ),
              const SizedBox(height: 8),
              Row(mainAxisSize: MainAxisSize.min, children: [
                Text('Less ',
                    style: TextStyle(color: AppColors.muted, fontSize: 11.5)),
                for (var l = 0; l <= 4; l++)
                  Container(
                    width: cell,
                    height: cell,
                    margin: const EdgeInsets.only(left: 3),
                    decoration: BoxDecoration(
                        color: shade(l),
                        borderRadius: BorderRadius.circular(2.5)),
                  ),
                Text('  More',
                    style: TextStyle(color: AppColors.muted, fontSize: 11.5)),
              ]),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _repoList(EdgeInsets pad) {
    final repos = _repos;
    if (repos == null) {
      return [
        SliverPadding(
          padding: pad,
          sliver: SliverToBoxAdapter(
              child: tabMessage(error: _reposError, onRetry: _loadRepos)),
        )
      ];
    }
    final q = _filter.text.trim().toLowerCase();
    final shown = repos
        .where((r) =>
            q.isEmpty ||
            r.name.toLowerCase().contains(q) ||
            r.description.toLowerCase().contains(q))
        .toList();
    return [
      SliverPadding(
        padding: pad,
        sliver: SliverToBoxAdapter(
          child: TextField(
            controller: _filter,
            style: TextStyle(color: AppColors.text, fontSize: 14),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Find a repository…',
              hintStyle: TextStyle(color: AppColors.faint),
              prefixIcon: Icon(Icons.search, size: 20, color: AppColors.muted),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppColors.border),
              ),
            ),
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        sliver: shown.isEmpty
            ? SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                        q.isEmpty
                            ? '${widget.login} has no public repositories.'
                            : 'No matches',
                        style: TextStyle(color: AppColors.muted)),
                  ),
                ),
              )
            : SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _repoRow(shown[i]),
                  childCount: shown.length,
                ),
              ),
      ),
    ];
  }

  Widget _repoRow(RepoInfo r) {
    return InkWell(
      onTap: () => _openRepo(r.owner, r.name),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 4),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Flexible(
                child: Text(r.name,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: AppColors.accent,
                        fontSize: 17,
                        fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 8),
              outlineBadge(r.isPrivate ? 'Private' : 'Public'),
              if (r.isFork) ...[
                const SizedBox(width: 6),
                outlineBadge('Fork'),
              ],
            ]),
            if (r.description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(r.description,
                  style: TextStyle(
                      color: AppColors.muted, fontSize: 13.5, height: 1.4)),
            ],
            const SizedBox(height: 10),
            _repoMeta(r.language, '', r.stars, 0, r.updatedAt),
          ],
        ),
      ),
    );
  }

  Widget _peopleList(int tab) {
    final people = _people[tab];
    if (people == null) {
      return tabMessage(
          error: _peopleErrors[tab],
          onRetry: () {
            setState(() => _peopleErrors.remove(tab));
            _loadPeople(tab);
          });
    }
    if (people.isEmpty) {
      return tabMessage(
          empty: tab == 2
              ? '${widget.login} has no followers yet.'
              : '${widget.login} isn’t following anyone.');
    }
    return Column(
      children: people
          .map((u) => InkWell(
                onTap: () => openProfile(context, u.login),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
                  decoration: BoxDecoration(
                    border:
                        Border(bottom: BorderSide(color: AppColors.border)),
                  ),
                  child: Row(children: [
                    Avatar(u.avatarUrl, size: 44),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(u.login,
                          style: TextStyle(
                              color: AppColors.text,
                              fontSize: 15.5,
                              fontWeight: FontWeight.w600)),
                    ),
                    Icon(Icons.chevron_right, color: AppColors.faint),
                  ]),
                ),
              ))
          .toList(),
    );
  }
}

String _compact(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}m';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(n >= 10000 ? 0 : 1)}k';
  return '$n';
}

const _monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December'
];

String _monthYear(DateTime d) => '${_monthNames[d.month - 1]} ${d.year}';
String _day(DateTime d) =>
    '${_monthNames[d.month - 1].substring(0, 3)} ${d.day}, ${d.year}';

/// GitHub's language colors for the common ones; gold otherwise.
Color _langColor(String lang, String hex) {
  if (hex.startsWith('#') && hex.length == 7) {
    return Color(int.parse('FF${hex.substring(1)}', radix: 16));
  }
  const known = {
    'Dart': 0xFF00B4AB,
    'Python': 0xFF3572A5,
    'JavaScript': 0xFFF1E05A,
    'TypeScript': 0xFF3178C6,
    'Java': 0xFFB07219,
    'Kotlin': 0xFFA97BFF,
    'C': 0xFF555555,
    'C++': 0xFFF34B7D,
    'C#': 0xFF178600,
    'Go': 0xFF00ADD8,
    'Rust': 0xFFDEA584,
    'Swift': 0xFFF05138,
    'HTML': 0xFFE34C26,
    'CSS': 0xFF563D7C,
    'Shell': 0xFF89E051,
    'Verilog': 0xFFB2B7F8,
    'SystemVerilog': 0xFFDAE1C2,
    'VHDL': 0xFFADB2CB,
    'Tcl': 0xFFE4CC98,
    'Makefile': 0xFF427819,
    'Jupyter Notebook': 0xFFDA5B0B,
    'Ruby': 0xFF701516,
    'PHP': 0xFF4F5D95,
    'Assembly': 0xFF6E4C13,
    'CMake': 0xFFDA3434,
    'Vue': 0xFF41B883,
    'Astro': 0xFFFF5A03,
  };
  final c = known[lang];
  return c == null ? AppColors.accent : Color(c);
}
