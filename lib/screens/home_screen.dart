import 'package:flutter/material.dart';
import '../app_nav.dart';
import '../models/repo_item.dart';
import '../models/github_models.dart';
import '../services/github_org.dart';
import '../services/github_service.dart';
import '../services/prefs_service.dart';
import '../theme.dart';
import '../widgets/delete_repo.dart';
import 'profile_screen.dart';
import 'repo_browser_screen.dart';
import 'settings_screen.dart';

const _accountCount = 2;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _inputCtrl = TextEditingController();
  PageController? _pages;
  bool _opening = false;
  String? _inputError;
  List<String> _recentRepos = [];

  /// GitHub token per account page.
  final List<String?> _tokens = List.filled(_accountCount, null);

  /// A username typed into the search box, listed on that page instead.
  final List<String?> _typedOwner = List.filled(_accountCount, null);

  /// Whose public repos account 1 shows when it has no token.
  String _publicOwner = '';
  int _page = 0;

  @override
  void initState() {
    super.initState();
    settingsChanged.addListener(_reloadTokens);
    _init();
  }

  Future<void> _init() async {
    _tokens[0] = await PrefsService.getGithubToken();
    _tokens[1] = await PrefsService.getGithubToken2();
    _publicOwner = await PrefsService.getListOwner();
    _page = (await PrefsService.getActiveAccount()).clamp(0, _accountCount - 1);
    _recentRepos = await PrefsService.getRecentRepos();
    if (!mounted) return;
    _useAccount(_page);
    setState(() => _pages = PageController(initialPage: _page));
  }

  /// Screens opened from anywhere (profiles, mentions) use this account.
  void _useAccount(int i) {
    GitHubService.current = GitHubService(token: _tokens[i]);
  }

  bool _hasToken(int i) => (_tokens[i] ?? '').isNotEmpty;

  Future<void> _loadRecent() async {
    final repos = await PrefsService.getRecentRepos();
    if (mounted) setState(() => _recentRepos = repos);
  }

  void _onPageChanged(int page) {
    setState(() => _page = page);
    _useAccount(page);
    PrefsService.setActiveAccount(page);
  }

  /// Handles the top input: a repo opens it, a username lists their repos.
  Future<void> _submit(String input) async {
    if (input.trim().isEmpty) return;
    final repo = GitHubService.parseRepoUrl(input);
    if (repo != null) {
      await _openTyped(repo['owner']!, repo['repo']!);
      return;
    }
    final user = GitHubService.parseUsername(input);
    if (user != null) {
      setState(() {
        _inputError = null;
        _typedOwner[_page] = user;
      });
      _inputCtrl.clear();
      FocusScope.of(context).unfocus();
      if (_page == 0 && !_hasToken(0)) PrefsService.setListOwner(user);
      return;
    }
    setState(() => _inputError = 'Enter a repo URL, owner/repo, or username');
  }

  /// Checks a typed repo exists before opening it.
  Future<void> _openTyped(String owner, String repo) async {
    setState(() {
      _opening = true;
      _inputError = null;
    });
    try {
      await GitHubService(token: _tokens[_page]).getRepoInfo(owner, repo);
      if (!mounted) return;
      _inputCtrl.clear();
      _openRepo(owner, repo, _page);
    } catch (e) {
      setState(() => _inputError = 'Could not open $owner/$repo');
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  void _openRepo(String owner, String repo, int account) {
    FocusScope.of(context).unfocus();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RepoBrowserScreen(
            owner: owner, repo: repo, token: _tokens[account]),
      ),
    ).then((_) {
      _useAccount(_page);
      _loadRecent();
    });
  }

  void _openProfile(String login, int account) {
    FocusScope.of(context).unfocus();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileScreen(
            login: login, github: GitHubService(token: _tokens[account])),
      ),
    ).then((_) {
      _useAccount(_page);
      _loadRecent();
    });
  }

  Future<void> _openSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
    await _reloadTokens();
  }

  /// Picks up tokens saved in Settings.
  Future<void> _reloadTokens() async {
    final t1 = await PrefsService.getGithubToken();
    final t2 = await PrefsService.getGithubToken2();
    if (!mounted) return;
    setState(() {
      _tokens[0] = t1;
      _tokens[1] = t2;
    });
    _useAccount(_page);
    _loadRecent();
  }

  /// Whose repos page [i] lists: a username, or null for the token
  /// owner's own repos. Returns '' when there's nothing to show.
  String? _listOwnerFor(int i) {
    if (_typedOwner[i] != null) return _typedOwner[i];
    if (_hasToken(i)) return null;
    return i == 0 ? _publicOwner : '';
  }

  double _hPad(double width) {
    const maxContent = 1400.0;
    if (width > maxContent + 48) return (width - maxContent) / 2;
    return width > 700 ? 24 : 16;
  }

  @override
  Widget build(BuildContext context) {
    final hPad = _hPad(MediaQuery.of(context).size.width);

    return Scaffold(
      body: Column(children: [
        Padding(
          padding: EdgeInsets.fromLTRB(hPad, 14, hPad, 0),
          child: _buildInput(),
        ),
        if (_recentRepos.isNotEmpty) _buildRecent(hPad),
        const SizedBox(height: 12),
        _PageDots(controller: _pages, count: _accountCount, page: _page),
        Expanded(
          child: _pages == null
              ? const Center(child: CircularProgressIndicator())
              : PageView.builder(
                  controller: _pages,
                  itemCount: _accountCount,
                  onPageChanged: _onPageChanged,
                  itemBuilder: (context, i) => _SwipeTransition(
                    controller: _pages!,
                    index: i,
                    child: _AccountPage(
                      index: i,
                      token: _tokens[i],
                      owner: _listOwnerFor(i),
                      typed: _typedOwner[i] != null,
                      hPad: hPad,
                      onOpenRepo: (owner, repo) => _openRepo(owner, repo, i),
                      onOpenProfile: (login) => _openProfile(login, i),
                      onClearTyped: () => setState(() => _typedOwner[i] = null),
                      onOpenSettings: _openSettings,
                    ),
                  ),
                ),
        ),
      ]),
    );
  }

  Widget _buildInput() {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: color),
        );
    return TextField(
      controller: _inputCtrl,
      textInputAction: TextInputAction.go,
      autocorrect: false,
      onSubmitted: _submit,
      style: TextStyle(color: AppColors.text, fontSize: 15),
      decoration: InputDecoration(
        hintText: 'Repo URL, owner/repo, or username',
        hintStyle: TextStyle(color: AppColors.faint),
        prefixIcon: Icon(Icons.search, color: AppColors.muted),
        suffixIcon: Padding(
          padding: const EdgeInsets.all(6),
          child: _opening
              ? const Padding(
                  padding: EdgeInsets.all(10),
                  child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.button,
                    foregroundColor: AppColors.onButton,
                  ),
                  icon: Icon(Icons.arrow_upward,
                      size: 20,
                      color: AppColors.isDark ? Colors.black : Colors.white),
                  tooltip: 'Go',
                  onPressed: () => _submit(_inputCtrl.text),
                ),
        ),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: border(AppColors.border),
        enabledBorder: border(AppColors.border),
        focusedBorder: border(AppColors.accent),
        errorText: _inputError,
      ),
    );
  }

  Widget _buildRecent(double hPad) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.fromLTRB(hPad, 10, hPad, 0),
        children: _recentRepos.take(8).map((r) {
          final parts = r.split('/');
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              avatar: Icon(Icons.history, size: 16, color: AppColors.muted),
              label: Text(parts.length == 2 ? parts[1] : r),
              labelStyle: TextStyle(color: AppColors.text, fontSize: 13),
              backgroundColor: AppColors.surface,
              side: BorderSide(color: AppColors.border),
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              onPressed: parts.length == 2
                  ? () => _openRepo(parts[0], parts[1], _page)
                  : null,
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  void dispose() {
    settingsChanged.removeListener(_reloadTokens);
    _inputCtrl.dispose();
    _pages?.dispose();
    super.dispose();
  }
}

/// Small dots showing which account page is open. Not tappable:
/// switching is done by swiping.
class _PageDots extends StatelessWidget {
  const _PageDots(
      {required this.controller, required this.count, required this.page});

  final PageController? controller;
  final int count;
  final int page;

  @override
  Widget build(BuildContext context) {
    Widget dots(double pos) => Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(count, (i) {
            final t = (1 - (pos - i).abs()).clamp(0.0, 1.0);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 8 + 16 * t,
              height: 8,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: Color.lerp(AppColors.border, AppColors.accent, t),
              ),
            );
          }),
        );
    final c = controller;
    if (c == null) return dots(page.toDouble());
    return AnimatedBuilder(
      animation: c,
      builder: (context, _) => dots(c.hasClients && c.position.haveDimensions
          ? c.page ?? page.toDouble()
          : page.toDouble()),
    );
  }
}

/// Scales and fades a page as it slides away during a swipe.
class _SwipeTransition extends StatelessWidget {
  const _SwipeTransition(
      {required this.controller, required this.index, required this.child});

  final PageController controller;
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      child: child,
      builder: (context, child) {
        var pos = index.toDouble();
        if (controller.hasClients && controller.position.haveDimensions) {
          pos = controller.page ?? pos;
        }
        final d = (pos - index).abs().clamp(0.0, 1.0);
        return Opacity(
          opacity: 1 - 0.6 * d,
          child: Transform.scale(scale: 1 - 0.08 * d, child: child),
        );
      },
    );
  }
}

/// One account's repo list. Kept alive so swiping back doesn't reload it.
class _AccountPage extends StatefulWidget {
  const _AccountPage({
    required this.index,
    required this.token,
    required this.owner,
    required this.typed,
    required this.hPad,
    required this.onOpenRepo,
    required this.onOpenProfile,
    required this.onClearTyped,
    required this.onOpenSettings,
  });

  final int index;
  final String? token;

  /// null = token owner's repos, '' = nothing set up, else a username.
  final String? owner;
  final bool typed;
  final double hPad;
  final void Function(String owner, String repo) onOpenRepo;
  final ValueChanged<String> onOpenProfile;
  final VoidCallback onClearTyped;
  final VoidCallback onOpenSettings;

  @override
  State<_AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<_AccountPage>
    with AutomaticKeepAliveClientMixin {
  final _filterCtrl = TextEditingController();
  List<RepoInfo>? _repos;
  bool _loading = false;
  String? _error;
  int _request = 0;
  String? _login;
  String? _avatarUrl;

  /// Organizations the token's account belongs to.
  List<GhUser> _orgs = [];

  bool get _hasToken => (widget.token ?? '').isNotEmpty;
  bool get _notSetUp => widget.owner == '';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _filterCtrl.addListener(() => setState(() {}));
    reposChanged.addListener(_reload);
    builderRepo.addListener(_redraw);
    _reload();
  }

  /// Long-press a repo: open it, or delete it in one step.
  Future<void> _repoMenu(RepoInfo r) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            title: Text('${r.owner}/${r.name}',
                style: TextStyle(
                    color: AppColors.text, fontWeight: FontWeight.w600)),
          ),
          ListTile(
            leading: const Icon(Icons.open_in_new),
            title: const Text('Open'),
            onTap: () => Navigator.pop(ctx, 'open'),
          ),
          if (_hasToken)
            ListTile(
              leading: Icon(Icons.delete_outline, color: AppColors.danger),
              title: Text('Delete repository',
                  style: TextStyle(color: AppColors.danger)),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (!mounted) return;
    if (choice == 'open') widget.onOpenRepo(r.owner, r.name);
    if (choice == 'delete') {
      final gone = await deleteRepoFlow(
          context, GitHubService(token: widget.token), r.owner, r.name);
      if (gone && mounted) setState(() => _repos?.remove(r));
    }
  }

  @override
  void didUpdateWidget(covariant _AccountPage old) {
    super.didUpdateWidget(old);
    if (old.token != widget.token || old.owner != widget.owner) {
      _filterCtrl.clear();
      _reload();
    }
  }

  Future<void> _reload() async {
    final request = ++_request;
    if (old(request)) return;
    setState(() {
      _error = null;
      _repos = null;
      if (!_hasToken) {
        _login = null;
        _avatarUrl = null;
        _orgs = [];
      }
    });
    if (_notSetUp) return;
    setState(() => _loading = true);

    final github = GitHubService(token: widget.token);
    if (_hasToken) {
      github.getViewer().then((v) {
        if (old(request)) return;
        setState(() {
          _login = v.login;
          _avatarUrl = v.avatarUrl;
        });
      }).catchError((_) {});
      github.getMyOrgs().then((o) {
        if (!old(request)) setState(() => _orgs = o);
      }).catchError((_) {});
    }
    try {
      final repos = widget.owner == null
          ? await github.getMyRepos()
          : await github.getUserRepos(widget.owner!);
      if (old(request)) return;
      // No builder chosen yet: adopt the user's own "apk-builder" repo.
      if (builderRepo.value.isEmpty && widget.owner == null) {
        for (final r in repos) {
          if (r.name.toLowerCase() == kApkBuilderRepoName) {
            PrefsService.setBuilderRepo('${r.owner}/${r.name}');
            break;
          }
        }
      }
      setState(() {
        _repos = repos;
        _loading = false;
      });
    } catch (e) {
      if (old(request)) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  /// True if the page is gone or a newer load has started.
  bool old(int request) => !mounted || request != _request;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final hPad = widget.hPad;
    final width = MediaQuery.of(context).size.width;
    final wide = width > 700;

    if (_notSetUp) return _buildSetUp(hPad);

    return RefreshIndicator(
      onRefresh: _reload,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 16),
            sliver: SliverToBoxAdapter(child: _buildHeader()),
          ),
          ..._buildBody(hPad, wide),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final title = widget.owner == null
        ? (_login ?? 'Account ${widget.index + 1}')
        : widget.owner!;
    final subtitle = widget.typed
        ? 'Public repositories'
        : _hasToken
            ? 'Account ${widget.index + 1} · your repositories'
            : 'Account ${widget.index + 1} · public repositories';
    final login = widget.owner ?? _login;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: login == null ? null : () => widget.onOpenProfile(login),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.surfaceAlt,
                    foregroundImage: (_avatarUrl ?? '').isNotEmpty &&
                            widget.owner == null
                        ? NetworkImage(_avatarUrl!)
                        : widget.owner != null && widget.owner!.isNotEmpty
                            ? NetworkImage(
                                'https://github.com/${widget.owner}.png?size=96')
                            : null,
                    child: Icon(Icons.person_outline, color: AppColors.muted),
                  ),
                  const SizedBox(width: 14),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontFamily: kSerif,
                                color: AppColors.text,
                                fontSize: 24,
                                fontWeight: FontWeight.w500)),
                        const SizedBox(height: 2),
                        Text(subtitle,
                            style: TextStyle(
                                color: AppColors.muted, fontSize: 13)),
                      ],
                    ),
                  ),
                  if (login != null) ...[
                    const SizedBox(width: 8),
                    Icon(Icons.chevron_right, color: AppColors.faint),
                  ],
                ]),
              ),
            ),
          ),
          if (widget.typed)
            TextButton(
              onPressed: widget.onClearTyped,
              child: Text('Back to account',
                  style: TextStyle(color: AppColors.accent)),
            ),
        ]),
        if (_orgs.isNotEmpty && widget.owner == null) ...[
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final o in _orgs)
              ActionChip(
                avatar: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.network(o.avatarUrl,
                      width: 20,
                      height: 20,
                      errorBuilder: (_, __, ___) => Icon(Icons.corporate_fare,
                          size: 16, color: AppColors.muted)),
                ),
                label: Text(o.login),
                labelStyle: TextStyle(
                    color: AppColors.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
                backgroundColor: AppColors.surface,
                side: BorderSide(color: AppColors.accent.withOpacity(0.45)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                onPressed: () => widget.onOpenProfile(o.login),
              ),
          ]),
        ],
        if ((_repos?.length ?? 0) > 6) ...[
          const SizedBox(height: 16),
          TextField(
            controller: _filterCtrl,
            style: TextStyle(color: AppColors.text, fontSize: 14),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Filter repositories',
              hintStyle: TextStyle(color: AppColors.faint),
              prefixIcon:
                  Icon(Icons.filter_list, size: 20, color: AppColors.muted),
              filled: true,
              fillColor: AppColors.surfaceAlt,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ],
    );
  }

  List<Widget> _buildBody(double hPad, bool wide) {
    Widget boxed(Widget child) => SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 24),
          sliver: SliverToBoxAdapter(child: Center(child: child)),
        );

    if (_loading && _repos == null) {
      return [boxed(const CircularProgressIndicator())];
    }
    if (_error != null) {
      return [
        boxed(Column(children: [
          Text(_error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.danger)),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: _reload, child: const Text('Retry')),
        ]))
      ];
    }
    final q = _filterCtrl.text.trim().toLowerCase();
    final repos = (_repos ?? [])
        .where((r) =>
            q.isEmpty ||
            r.fullName.toLowerCase().contains(q) ||
            r.description.toLowerCase().contains(q))
        .toList();
    if (repos.isEmpty) {
      return [
        boxed(Text(q.isEmpty ? 'No repositories' : 'No matches',
            style: TextStyle(color: AppColors.muted)))
      ];
    }
    return [
      SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: hPad),
        sliver: SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: wide ? 16 : 10,
            crossAxisSpacing: wide ? 16 : 10,
            mainAxisExtent: wide ? 142 : 158,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, i) => _repoCard(repos[i], wide),
            childCount: repos.length,
          ),
        ),
      ),
    ];
  }

  Widget _repoCard(RepoInfo r, bool wide) {
    final showOwner = widget.owner == null &&
        r.owner.isNotEmpty &&
        _login != null &&
        r.owner.toLowerCase() != _login!.toLowerCase();
    final meta = <String>[
      if (r.language.isNotEmpty) r.language,
      if (r.stars > 0) '★ ${r.stars}',
      if (r.updatedAt != null) 'Updated ${_ago(r.updatedAt!)}',
    ];
    final pad = wide ? 20.0 : 14.0;
    final gold = isBuilderRepo(r.owner, r.name);
    final fg = gold ? AppColors.onButton : AppColors.text;
    final sub = gold ? AppColors.onButton.withOpacity(0.75) : AppColors.muted;
    final faint = gold ? AppColors.onButton.withOpacity(0.6) : AppColors.faint;
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: gold ? AppColors.accent : AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => widget.onOpenRepo(r.owner, r.name),
        onLongPress: () => _repoMenu(r),
        child: Ink(
          decoration: gold
              ? BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.accentLight,
                      AppColors.button,
                      AppColors.accent,
                    ],
                  ),
                )
              : null,
          child: Padding(
            padding: EdgeInsets.all(pad),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(
                      gold
                          ? Icons.precision_manufacturing_outlined
                          : Icons.book_outlined,
                      size: 18,
                      color: gold ? fg : AppColors.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text.rich(
                      TextSpan(children: [
                        if (showOwner)
                          TextSpan(
                              text: '${r.owner} / ',
                              style: TextStyle(
                                  color: sub, fontWeight: FontWeight.w400)),
                        TextSpan(text: r.name),
                      ]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: fg,
                          fontSize: wide ? 18 : 16,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (r.isPrivate) _badge(Icons.lock_outline, 'Private', wide),
                  if (r.isFork) _badge(Icons.call_split, 'Fork', wide),
                ]),
                const SizedBox(height: 8),
                // Loose fit: the meta line follows the text directly and any
                // spare height goes to the bottom of the card.
                Flexible(
                  child: Text(
                      r.description.isEmpty ? 'No description' : r.description,
                      maxLines: wide ? 2 : 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: r.description.isEmpty ? faint : sub,
                          fontSize: wide ? 14.5 : 13,
                          height: 1.4)),
                ),
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(meta.join('  ·  '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: faint, fontSize: wide ? 13 : 12)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _badge(IconData icon, String label, bool wide) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: AppColors.muted),
        if (wide) ...[
          const SizedBox(width: 3),
          Text(label, style: TextStyle(color: AppColors.muted, fontSize: 11)),
        ],
      ]),
    );
  }

  Widget _buildSetUp(double hPad) {
    return ListView(
      padding: EdgeInsets.fromLTRB(hPad, 48, hPad, 32),
      children: [
        Icon(Icons.person_add_alt_1_outlined, size: 56, color: AppColors.faint),
        const SizedBox(height: 16),
        Text(widget.index == 0 ? 'Welcome to RepoViewer' : 'Account 2',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: kSerif,
                color: AppColors.text,
                fontSize: 24,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Text(
          widget.index == 0
              ? 'Add a GitHub token in Settings to see your own repos, '
                  'private ones included.\n'
                  'Or type any username or owner/repo above to browse '
                  'public code.'
              : 'Add a GitHub token for your second account in Settings.\n'
                  'Then swipe left and right here to switch accounts.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted, fontSize: 14, height: 1.5),
        ),
        const SizedBox(height: 20),
        Center(
          child: OutlinedButton.icon(
            onPressed: widget.onOpenSettings,
            icon: const Icon(Icons.settings_outlined, size: 18),
            label: const Text('Open Settings'),
          ),
        ),
      ],
    );
  }

  void _redraw() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    reposChanged.removeListener(_reload);
    builderRepo.removeListener(_redraw);
    _filterCtrl.dispose();
    super.dispose();
  }
}

String _ago(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inDays >= 365) return '${d.inDays ~/ 365}y ago';
  if (d.inDays >= 30) return '${d.inDays ~/ 30}mo ago';
  if (d.inDays >= 1) return '${d.inDays}d ago';
  if (d.inHours >= 1) return '${d.inHours}h ago';
  return 'just now';
}
