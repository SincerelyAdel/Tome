import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/repo_item.dart';
import '../services/uvm_runs.dart';
import '../services/uvm_vip.dart';
import '../services/github_service.dart';
import '../services/download_service.dart';
import '../services/prefs_service.dart';
import '../widgets/file_icon.dart';
import 'actions_screen.dart';
import 'file_viewer_screen.dart';
import 'repo_tabs/branches_tab.dart';
import 'repo_tabs/commits_tab.dart';
import 'repo_tabs/issues_tab.dart';
import '../theme.dart';
import '../widgets/delete_repo.dart';
import '../app_nav.dart';

class RepoBrowserScreen extends StatefulWidget {
  final String owner;
  final String repo;
  final String? token;

  const RepoBrowserScreen({
    super.key,
    required this.owner,
    required this.repo,
    this.token,
  });

  @override
  State<RepoBrowserScreen> createState() => _RepoBrowserScreenState();
}

class _RepoBrowserScreenState extends State<RepoBrowserScreen> {
  late GitHubService _github;
  final Map<String, List<RepoItem>> _cache = {};
  final List<String> _pathStack = [];
  List<RepoItem> _currentItems = [];
  bool _loading = true;
  String? _error;
  RepoItem? _selectedItem;
  double _downloadProgress = 0;
  bool _downloading = false;

  /// Selected tab: 0 Code, 1 Issues, 2 Pull requests, 3 Commit graph, 4 Branches.
  int _tab = 0;

  /// Branch shown in Code and Commits; null until the repo info loads.
  String? _branch;
  String? _defaultBranch;
  final Map<int, int> _counts = {};

  String get _currentPath => _pathStack.join('/');

  @override
  void initState() {
    super.initState();
    _github = GitHubService(token: widget.token);
    GitHubService.current = _github;
    // The APK builder repo only shows its Actions.
    if (isBuilderRepo(widget.owner, widget.repo)) return;
    _loadPath('');
    _github.getRepoInfo(widget.owner, widget.repo).then((info) {
      if (!mounted) return;
      setState(() {
        _defaultBranch = info.defaultBranch;
        _branch ??= info.defaultBranch;
      });
    }).catchError((_) {});
    PrefsService.addRecentRepo('${widget.owner}/${widget.repo}');
  }

  Future<void> _loadPath(String path) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = _cache[path] ??
          await _github.getContents(widget.owner, widget.repo, path,
              ref: _branch);
      _cache[path] = items;
      setState(() {
        _currentItems = items;
        _loading = false;
        _runSummary = null;
        _vip = null;
        _vipWorkflow = null;
      });
      if (UvmRuns.isRunFolder(items)) _loadRunSummary(path);
      if (UvmVip.isVipFolder(items)) _loadVip(path);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  // ------------------------------------------------------- uvm-debugger run

  /// run.json's test · seed · status for the folder on screen, if it's a run.
  String? _runSummary;
  bool _openingRun = false;

  Future<void> _loadRunSummary(String path) async {
    try {
      final bytes = await _github.getRawFile(widget.owner, widget.repo,
          path.isEmpty ? 'run.json' : '$path/run.json',
          ref: _branch);
      final s = UvmRuns.summaryOfText(utf8.decode(bytes, allowMalformed: true));
      if (mounted && _currentPath == path) setState(() => _runSummary = s);
    } catch (_) {
      // The banner still works without a summary.
    }
  }

  Future<void> _openRun() async {
    final path = _currentPath;
    setState(() => _openingRun = true);
    try {
      final dir = await UvmRuns.fetchFromRepo(
          _github, widget.owner, widget.repo, path, _currentItems,
          ref: _branch);
      await UvmRuns.open(dir, {
        'repo': '${widget.owner}/${widget.repo}',
        'branch': _branch ?? _defaultBranch ?? '',
        'path': path,
      });
    } catch (e) {
      _showSnack(e is UvmViewerMissing ? '$e' : 'Could not open the run: $e');
    } finally {
      if (mounted) setState(() => _openingRun = false);
    }
  }

  /// Shown above a folder that holds a run.json.
  Widget _runBanner() {
    final name = _pathStack.isEmpty ? widget.repo : _pathStack.last;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.6)),
      ),
      child: Row(children: [
        Icon(Icons.auto_awesome, color: AppColors.accent, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: AppColors.text,
                    fontFamily: 'monospace',
                    fontSize: 13)),
            Text(
                (_runSummary ?? '').isEmpty
                    ? 'UVM run'
                    : 'UVM run · $_runSummary',
                style: TextStyle(color: AppColors.muted, fontSize: 11.5)),
          ]),
        ),
        const SizedBox(width: 8),
        _openingRun
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 3))
            : FilledButton.icon(
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.button,
                    foregroundColor: AppColors.onButton),
                onPressed: _openRun,
                icon: const Icon(Icons.play_arrow, size: 18),
                label: const Text('Open in ${UvmRuns.viewerName}'),
              ),
      ]),
    );
  }

  // ------------------------------------------------------------- VIP runs

  /// The VIP on screen (a folder holding vip.json), once vip.json is read.
  UvmVip? _vip;

  /// Whether the branch has the uvmdbg workflow; null while checking.
  bool? _vipWorkflow;
  bool _startingVip = false;

  Future<void> _loadVip(String path) async {
    final ref = _branch;
    try {
      final bytes = await _github.getRawFile(widget.owner, widget.repo,
          path.isEmpty ? 'vip.json' : '$path/vip.json',
          ref: ref);
      final vip = UvmVip.parse(utf8.decode(bytes, allowMalformed: true),
          folder: _pathStack.isEmpty ? widget.repo : _pathStack.last);
      if (mounted && _currentPath == path) setState(() => _vip = vip);
    } catch (_) {}
    final has =
        await UvmVip.hasWorkflow(_github, widget.owner, widget.repo, ref);
    if (mounted && _currentPath == path) setState(() => _vipWorkflow = has);
  }

  /// Asks for the test and seed, starts the run and opens it in Actions.
  Future<void> _runVip() async {
    final vip = _vip;
    if (vip == null) return;
    final ref = _branch ?? _defaultBranch ?? 'main';
    final choices = vip.testChoices;
    var test = choices.isEmpty ? '' : choices.first;
    final seed = TextEditingController(text: '1');

    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text('Run ${vip.name}',
              style: TextStyle(color: AppColors.text)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('On $ref, with ${UvmVip.workflowFile}',
                    style: TextStyle(
                        color: AppColors.muted,
                        fontFamily: 'monospace',
                        fontSize: 12.5)),
                const SizedBox(height: 14),
                if (choices.isEmpty)
                  InputDecorator(
                    decoration: const InputDecoration(labelText: 'Test'),
                    child: Text('Default test',
                        style: TextStyle(color: AppColors.text)),
                  )
                else
                  DropdownButtonFormField<String>(
                    initialValue: test,
                    dropdownColor: AppColors.surface,
                    style: TextStyle(
                        color: AppColors.text, fontFamily: 'monospace'),
                    decoration: const InputDecoration(labelText: 'Test'),
                    items: [
                      for (final t in choices)
                        DropdownMenuItem(
                          value: t,
                          child: Text(
                              t == vip.defaultTest ? '$t  (default)' : t),
                        ),
                    ],
                    onChanged: (v) => setD(() => test = v ?? ''),
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: seed,
                  autocorrect: false,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: TextStyle(
                      color: AppColors.text, fontFamily: 'monospace'),
                  decoration: InputDecoration(
                    labelText: 'Seed',
                    suffixIcon: IconButton(
                      tooltip: 'Random seed',
                      icon: const Icon(Icons.casino_outlined),
                      onPressed: () => seed.text =
                          '${1 + Random().nextInt(999999999)}',
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton.icon(
                onPressed: () => Navigator.pop(ctx, true),
                icon: const Icon(Icons.play_arrow, size: 18),
                label: const Text('Run')),
          ],
        ),
      ),
    );
    final seedText = seed.text;
    if (go != true || !mounted) return;

    setState(() => _startingVip = true);
    try {
      final run = await vip.start(_github, widget.owner, widget.repo, ref,
          test: test, seed: seedText);
      if (!mounted) return;
      if (run == null) {
        _showSnack('Run started. It will show up in Actions shortly.');
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RunDetailScreen(
            owner: widget.owner,
            repo: widget.repo,
            github: _github,
            run: run,
          ),
        ),
      );
    } catch (e) {
      _showSnack('Could not start the run: $e');
    } finally {
      if (mounted) setState(() => _startingVip = false);
    }
  }

  /// Shown above a VIP folder (one holding vip.json).
  Widget _vipBanner() {
    final vip = _vip;
    final name =
        vip?.name ?? (_pathStack.isEmpty ? widget.repo : _pathStack.last);
    final String sub;
    if (_vipWorkflow == false) {
      sub = "${UvmVip.workflowPath} isn't on ${_branch ?? 'this branch'}";
    } else if (vip == null) {
      sub = 'VIP';
    } else {
      final n = vip.tests.length;
      sub = [
        'VIP',
        n == 1 ? '1 test' : '$n tests',
        if (vip.defaultTest.isNotEmpty) 'default ${vip.defaultTest}',
      ].join(' · ');
    }
    final ready = vip != null && _vipWorkflow == true;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.6)),
      ),
      child: Row(children: [
        Icon(Icons.memory, color: AppColors.accent, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: AppColors.text,
                    fontFamily: 'monospace',
                    fontSize: 13)),
            Text(sub,
                style: TextStyle(
                    color: _vipWorkflow == false
                        ? AppColors.danger
                        : AppColors.muted,
                    fontSize: 11.5)),
          ]),
        ),
        const SizedBox(width: 8),
        _startingVip || (vip != null && _vipWorkflow == null)
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 3))
            : FilledButton.icon(
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.button,
                    foregroundColor: AppColors.onButton),
                onPressed: ready ? _runVip : null,
                icon: const Icon(Icons.play_arrow, size: 18),
                label: const Text('Run'),
              ),
      ]),
    );
  }

  void _navigateTo(RepoItem item) {
    if (item.isDirectory) {
      setState(() {
        _pathStack.add(item.name);
        _selectedItem = null;
      });
      _loadPath(_currentPath);
    } else if (item.isFile) {
      setState(() => _selectedItem = item);
      if (MediaQuery.of(context).size.width < 800) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FileViewerScreen(
              item: item,
              owner: widget.owner,
              repo: widget.repo,
              github: _github,
              branch: _branch,
            ),
          ),
        );
      }
    }
  }

  void _navigateBack() {
    if (_pathStack.isNotEmpty) {
      setState(() {
        _pathStack.removeLast();
        _selectedItem = null;
      });
      _loadPath(_currentPath);
    }
  }

  void _navigateToBreadcrumb(int index) {
    setState(() {
      _pathStack.removeRange(index + 1, _pathStack.length);
      _selectedItem = null;
    });
    _loadPath(_currentPath);
  }

  Future<void> _downloadZip() async {
    setState(() {
      _downloading = true;
      _downloadProgress = 0;
    });
    try {
      final service = DownloadService();
      final zipUrl =
          'https://github.com/${widget.owner}/${widget.repo}/archive/refs/heads/'
          '${_branch ?? _defaultBranch ?? 'main'}.zip';
      final path = await service.downloadZip(
        zipUrl,
        '${widget.owner}_${widget.repo}',
        onProgress: (received, total) {
          if (total > 0) {
            setState(() => _downloadProgress = received / total);
          }
        },
      );
      setState(() => _downloading = false);
      _showSnack('Saved to: $path');
    } catch (e) {
      setState(() => _downloading = false);
      _showSnack('Download failed: $e');
    }
  }

  void _openActions() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ActionsScreen(
          owner: widget.owner,
          repo: widget.repo,
          github: _github,
        ),
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 4)));
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 800;
    if (isBuilderRepo(widget.owner, widget.repo)) {
      return ActionsScreen(
          owner: widget.owner,
          repo: widget.repo,
          github: _github,
          golden: true);
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Row(children: [
          Icon(Icons.code, color: AppColors.accent, size: 20),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              isWide ? '${widget.owner} / ${widget.repo}' : widget.repo,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: AppColors.text, fontFamily: 'monospace', fontSize: 15),
            ),
          ),
        ]),
        iconTheme: IconThemeData(color: AppColors.text),
        actions: [
          // GitHub Actions runs and artifacts
          if (isWide)
            TextButton.icon(
              icon: Icon(Icons.play_circle_outline,
                  color: AppColors.warning, size: 18),
              label:
                  Text('Actions', style: TextStyle(color: AppColors.warning)),
              onPressed: _openActions,
            )
          else
            IconButton(
              icon: Icon(Icons.play_circle_outline, color: AppColors.warning),
              tooltip: 'Actions',
              onPressed: _openActions,
            ),
          // Download ZIP button
          if (_downloading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                width: 120,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    LinearProgressIndicator(
                      value: _downloadProgress,
                      backgroundColor: AppColors.border,
                      valueColor: AlwaysStoppedAnimation(AppColors.accent),
                    ),
                    Text(
                      '${(_downloadProgress * 100).toInt()}%',
                      style: TextStyle(color: AppColors.muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
            )
          else if (isWide)
            TextButton.icon(
              icon: Icon(Icons.download, color: AppColors.success, size: 18),
              label: Text('Download ZIP',
                  style: TextStyle(color: AppColors.success)),
              onPressed: _downloadZip,
            )
          else
            IconButton(
              icon: Icon(Icons.download, color: AppColors.success),
              tooltip: 'Download ZIP',
              onPressed: _downloadZip,
            ),
          if (_github.hasToken)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: AppColors.muted),
              tooltip: 'More',
              onSelected: (v) async {
                if (v != 'delete') return;
                final gone = await deleteRepoFlow(
                    context, _github, widget.owner, widget.repo);
                if (gone && context.mounted) Navigator.pop(context);
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'delete',
                  child: Row(children: [
                    Icon(Icons.delete_outline, color: AppColors.danger),
                    const SizedBox(width: 12),
                    Text('Delete repository',
                        style: TextStyle(color: AppColors.danger)),
                  ]),
                ),
              ],
            ),
          const SizedBox(width: 8),
        ],
        bottom: _RepoTabBar(
          selected: _tab,
          counts: _counts,
          onSelect: (i) => setState(() => _tab = i),
        ),
      ),
      body: IndexedStack(
        index: _tab,
        children: [
          Column(
            children: [
              _buildBreadcrumb(),
              Expanded(
                child: isWide
                    ? Row(children: [
                        SizedBox(width: 320, child: _buildFileTree()),
                        VerticalDivider(width: 1, color: AppColors.border),
                        Expanded(child: _buildFilePane()),
                      ])
                    : _buildFileTree(),
              ),
            ],
          ),
          IssuesTab(
            owner: widget.owner,
            repo: widget.repo,
            github: _github,
            pulls: false,
            onOpenCount: (n) => setState(() => _counts[1] = n),
          ),
          IssuesTab(
            owner: widget.owner,
            repo: widget.repo,
            github: _github,
            pulls: true,
            onOpenCount: (n) => setState(() => _counts[2] = n),
          ),
          if (_branch == null)
            const Center(child: CircularProgressIndicator())
          else
            CommitsTab(
              owner: widget.owner,
              repo: widget.repo,
              github: _github,
              branch: _branch,
            ),
          BranchesTab(
            owner: widget.owner,
            repo: widget.repo,
            github: _github,
            defaultBranch: _defaultBranch,
            current: _branch,
            onSelect: _selectBranch,
            onCount: (n) => setState(() => _counts[4] = n),
          ),
        ],
      ),
    );
  }

  /// Shows [name] in Code and the commit graph, and jumps to [tab].
  void _selectBranch(String name, [int tab = 0]) {
    final changed = name != _branch;
    setState(() {
      _tab = tab;
      if (!changed) return;
      _branch = name;
      _cache.clear();
      _pathStack.clear();
      _selectedItem = null;
    });
    if (changed) _loadPath('');
  }

  Widget _buildBreadcrumb() {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          if (_branch != null) ...[
            InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () => setState(() => _tab = 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.account_tree_outlined,
                      size: 14, color: AppColors.muted),
                  const SizedBox(width: 6),
                  Text(_branch!,
                      style: TextStyle(
                          color: AppColors.text,
                          fontFamily: 'monospace',
                          fontSize: 12.5)),
                  Icon(Icons.arrow_drop_down, size: 16, color: AppColors.muted),
                ]),
              ),
            ),
            const SizedBox(width: 12),
          ],
          InkWell(
            onTap: _pathStack.isNotEmpty
                ? () {
                    setState(() {
                      _pathStack.clear();
                      _selectedItem = null;
                    });
                    _loadPath('');
                  }
                : null,
            child: Text(
              widget.repo,
              style: TextStyle(
                color: _pathStack.isEmpty ? AppColors.text : AppColors.accent,
                fontFamily: 'monospace',
                fontSize: 13,
              ),
            ),
          ),
          ..._pathStack.asMap().entries.map((e) => Row(children: [
                Text(' / ',
                    style: TextStyle(color: AppColors.faint, fontSize: 13)),
                InkWell(
                  onTap: e.key < _pathStack.length - 1
                      ? () => _navigateToBreadcrumb(e.key)
                      : null,
                  child: Text(
                    e.value,
                    style: TextStyle(
                      color: e.key < _pathStack.length - 1
                          ? AppColors.accent
                          : AppColors.text,
                      fontFamily: 'monospace',
                      fontSize: 13,
                    ),
                  ),
                ),
              ])),
        ],
      ),
    );
  }

  Widget _buildFileTree() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: AppColors.danger, size: 40),
              const SizedBox(height: 8),
              Text(_error!,
                  style: TextStyle(color: AppColors.danger),
                  textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => _loadPath(_currentPath),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final list = _fileList();
    final banners = [
      if (UvmRuns.isRunFolder(_currentItems)) _runBanner(),
      if (UvmVip.isVipFolder(_currentItems)) _vipBanner(),
    ];
    if (banners.isEmpty) return list;
    return Column(children: [...banners, Expanded(child: list)]);
  }

  Widget _fileList() {
    return ListView.builder(
      itemCount: _currentItems.length + (_pathStack.isNotEmpty ? 1 : 0),
      itemBuilder: (context, i) {
        if (_pathStack.isNotEmpty && i == 0) {
          return ListTile(
            leading: Icon(Icons.arrow_upward, color: AppColors.muted, size: 20),
            title: Text('..',
                style:
                    TextStyle(color: AppColors.muted, fontFamily: 'monospace')),
            dense: true,
            onTap: _navigateBack,
          );
        }
        final item = _currentItems[i - (_pathStack.isNotEmpty ? 1 : 0)];
        final isSelected = _selectedItem?.path == item.path;
        return Material(
          color: isSelected ? AppColors.surfaceAlt : Colors.transparent,
          child: ListTile(
            leading: FileIcon(
                name: item.name, isDirectory: item.isDirectory, size: 20),
            title: Text(
              item.name,
              style: TextStyle(
                color: isSelected ? AppColors.accent : AppColors.text,
                fontFamily: 'monospace',
                fontSize: 13,
              ),
            ),
            trailing: item.isFile && item.size != null
                ? Text(
                    _formatSize(item.size!),
                    style: TextStyle(color: AppColors.faint, fontSize: 11),
                  )
                : item.isDirectory
                    ? Icon(Icons.chevron_right,
                        color: AppColors.faint, size: 16)
                    : null,
            dense: true,
            onTap: () => _navigateTo(item),
          ),
        );
      },
    );
  }

  Widget _buildFilePane() {
    if (_selectedItem == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.touch_app, color: AppColors.border, size: 56),
            const SizedBox(height: 12),
            Text(
              'Select a file to view',
              style: TextStyle(color: AppColors.muted, fontSize: 14),
            ),
          ],
        ),
      );
    }
    return FileViewerScreen(
      // New key per file so switching files reloads the viewer.
      key: ValueKey('$_branch:${_selectedItem!.path}'),
      item: _selectedItem!,
      owner: widget.owner,
      repo: widget.repo,
      github: _github,
      branch: _branch,
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}

/// GitHub-style repo tabs: icon, label, count, gold underline when active.
class _RepoTabBar extends StatelessWidget implements PreferredSizeWidget {
  const _RepoTabBar(
      {required this.selected, required this.counts, required this.onSelect});

  final int selected;
  final Map<int, int> counts;
  final ValueChanged<int> onSelect;

  static const _tabs = [
    (Icons.code, 'Code'),
    (Icons.radio_button_checked, 'Issues'),
    (Icons.call_split, 'Pull requests'),
    (Icons.commit, 'Commit graph'),
    (Icons.account_tree_outlined, 'Branches'),
  ];

  @override
  Size get preferredSize => const Size.fromHeight(48);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < _tabs.length; i++) _tab(i),
          ],
        ),
      ),
    );
  }

  Widget _tab(int i) {
    final (icon, label) = _tabs[i];
    final active = i == selected;
    final count = counts[i];
    return InkWell(
      onTap: () => onSelect(i),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? AppColors.accent : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(children: [
          Icon(icon,
              size: 17, color: active ? AppColors.text : AppColors.muted),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                  color: AppColors.text,
                  fontSize: 14,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400)),
          if (count != null && count > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(count >= 100 ? '99+' : '$count',
                  style: TextStyle(
                      color: AppColors.text,
                      fontSize: 12,
                      fontWeight: FontWeight.w500)),
            ),
          ],
        ]),
      ),
    );
  }
}
