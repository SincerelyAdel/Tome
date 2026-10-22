import 'package:flutter/material.dart';
import '../models/repo_item.dart';
import '../services/github_service.dart';
import '../services/prefs_service.dart';
import '../theme.dart';
import 'repo_browser_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _inputCtrl = TextEditingController();
  final _filterCtrl = TextEditingController();
  bool _opening = false;
  String? _inputError;
  List<String> _recentRepos = [];

  String? _token;

  /// Whose repos are listed. null = the token owner's own repos.
  String? _owner;
  List<RepoInfo>? _repos;
  bool _listLoading = false;
  String? _listError;
  int _listRequest = 0;

  bool get _hasToken => _token != null && _token!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _filterCtrl.addListener(() => setState(() {}));
    _init();
  }

  Future<void> _init() async {
    _token = await PrefsService.getGithubToken();
    _owner = _hasToken ? null : await PrefsService.getListOwner();
    await _loadRecent();
    await _loadRepos();
  }

  Future<void> _loadRecent() async {
    final repos = await PrefsService.getRecentRepos();
    if (mounted) setState(() => _recentRepos = repos);
  }

  Future<void> _loadRepos() async {
    final request = ++_listRequest;
    setState(() {
      _listLoading = true;
      _listError = null;
    });
    try {
      final github = GitHubService(token: _token);
      final repos = _owner == null
          ? await github.getMyRepos()
          : await github.getUserRepos(_owner!);
      if (!mounted || request != _listRequest) return;
      setState(() {
        _repos = repos;
        _listLoading = false;
      });
    } catch (e) {
      if (!mounted || request != _listRequest) return;
      setState(() {
        _repos = null;
        _listError = e.toString().replaceFirst('Exception: ', '');
        _listLoading = false;
      });
    }
  }

  void _showOwner(String? owner) {
    _filterCtrl.clear();
    setState(() => _owner = owner);
    if (owner != null) PrefsService.setListOwner(owner);
    _loadRepos();
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
      setState(() => _inputError = null);
      _inputCtrl.clear();
      FocusScope.of(context).unfocus();
      _showOwner(user);
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
      await GitHubService(token: _token).getRepoInfo(owner, repo);
      if (!mounted) return;
      _inputCtrl.clear();
      _openRepo(owner, repo);
    } catch (e) {
      setState(() => _inputError = 'Could not open $owner/$repo');
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  void _openRepo(String owner, String repo) {
    FocusScope.of(context).unfocus();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            RepoBrowserScreen(owner: owner, repo: repo, token: _token),
      ),
    ).then((_) => _loadRecent());
  }

  Future<void> _openSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
    final token = await PrefsService.getGithubToken();
    if (token != _token) {
      // Token added or removed: switch between "your repos" and public list.
      _token = token;
      _owner = _hasToken ? null : await PrefsService.getListOwner();
      _loadRepos();
    }
    _loadRecent();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final hPad = width > 680 ? (width - 640) / 2 : 16.0;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: const Row(children: [
          Icon(Icons.auto_awesome, color: AppColors.accent, size: 22),
          SizedBox(width: 10),
          Text('RepoViewer'),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: AppColors.muted),
            tooltip: 'Settings',
            onPressed: _openSettings,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadRepos,
        child: ListView(
          padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 32),
          children: [
            _buildInput(),
            if (_recentRepos.isNotEmpty) ...[
              const SizedBox(height: 20),
              _sectionLabel('Recent'),
              const SizedBox(height: 8),
              _buildRecent(),
            ],
            const SizedBox(height: 28),
            _buildListHeader(),
            const SizedBox(height: 10),
            ..._buildList(),
          ],
        ),
      ),
    );
  }

  Widget _buildInput() {
    return TextField(
      controller: _inputCtrl,
      textInputAction: TextInputAction.go,
      autocorrect: false,
      onSubmitted: _submit,
      style: const TextStyle(color: AppColors.text, fontSize: 15),
      decoration: InputDecoration(
        hintText: 'Repo URL, owner/repo, or username',
        hintStyle: const TextStyle(color: AppColors.faint),
        prefixIcon: const Icon(Icons.search, color: AppColors.muted),
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
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.onAccent,
                  ),
                  icon: const Icon(Icons.arrow_upward, size: 20),
                  tooltip: 'Go',
                  onPressed: () => _submit(_inputCtrl.text),
                ),
        ),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: _inputBorder(AppColors.border),
        enabledBorder: _inputBorder(AppColors.border),
        focusedBorder: _inputBorder(AppColors.accent),
        errorText: _inputError,
      ),
    );
  }

  OutlineInputBorder _inputBorder(Color color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: color),
      );

  Widget _buildRecent() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _recentRepos.take(6).map((r) {
        final parts = r.split('/');
        return ActionChip(
          avatar: const Icon(Icons.history, size: 16, color: AppColors.muted),
          label: Text(parts.length == 2 ? parts[1] : r),
          labelStyle: const TextStyle(color: AppColors.text, fontSize: 13),
          backgroundColor: AppColors.surface,
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          onPressed: parts.length == 2
              ? () => _openRepo(parts[0], parts[1])
              : null,
        );
      }).toList(),
    );
  }

  Widget _buildListHeader() {
    final title =
        _owner == null ? 'Your repositories' : '$_owner\'s repositories';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(
            child: Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontFamily: kSerif,
                    color: AppColors.text,
                    fontSize: 22,
                    fontWeight: FontWeight.w500)),
          ),
          if (_owner != null && _hasToken)
            TextButton(
              onPressed: () => _showOwner(null),
              child: const Text('Mine',
                  style: TextStyle(color: AppColors.accent)),
            ),
        ]),
        if (!_hasToken) ...[
          const SizedBox(height: 4),
          const Text(
            'Type a username above to list someone else\'s repos. '
            'Add a GitHub token in Settings to see your private repos.',
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          ),
        ],
        if ((_repos?.length ?? 0) > 6) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _filterCtrl,
            style: const TextStyle(color: AppColors.text, fontSize: 14),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Filter repositories',
              hintStyle: const TextStyle(color: AppColors.faint),
              prefixIcon: const Icon(Icons.filter_list,
                  size: 20, color: AppColors.muted),
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

  List<Widget> _buildList() {
    if (_listLoading && _repos == null) {
      return const [
        Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        )
      ];
    }
    if (_listError != null) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(children: [
            Text(_listError!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.danger)),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _loadRepos, child: const Text('Retry')),
          ]),
        )
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
        Padding(
          padding: const EdgeInsets.all(24),
          child: Text(q.isEmpty ? 'No repositories' : 'No matches',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted)),
        )
      ];
    }
    return repos.map(_repoCard).toList();
  }

  Widget _repoCard(RepoInfo r) {
    final showOwner = _owner == null && r.owner.isNotEmpty;
    final meta = <String>[
      if (r.language.isNotEmpty) r.language,
      if (r.stars > 0) '★ ${r.stars}',
      if (r.updatedAt != null) 'Updated ${_ago(r.updatedAt!)}',
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _openRepo(r.owner, r.name),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Flexible(
                        child: Text.rich(
                          TextSpan(children: [
                            if (showOwner)
                              TextSpan(
                                  text: '${r.owner} / ',
                                  style: const TextStyle(
                                      color: AppColors.muted,
                                      fontWeight: FontWeight.w400)),
                            TextSpan(text: r.name),
                          ]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AppColors.text,
                              fontSize: 15,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (r.isPrivate) _badge(Icons.lock_outline, 'Private'),
                      if (r.isFork) _badge(Icons.call_split, 'Fork'),
                    ]),
                    if (r.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(r.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 13,
                              height: 1.35)),
                    ],
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(meta.join('  ·  '),
                          style: const TextStyle(
                              color: AppColors.faint, fontSize: 12)),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.faint),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _badge(IconData icon, String label) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: AppColors.muted),
        const SizedBox(width: 3),
        Text(label,
            style: const TextStyle(color: AppColors.muted, fontSize: 11)),
      ]),
    );
  }

  Widget _sectionLabel(String text) => Text(text,
      style: const TextStyle(
          color: AppColors.muted, fontSize: 13, fontWeight: FontWeight.w600));

  @override
  void dispose() {
    _inputCtrl.dispose();
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
