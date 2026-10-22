import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/github_branches.dart';
import '../../services/github_org.dart';
import '../../services/github_service.dart';
import '../../theme.dart';
import '../../widgets/gh_widgets.dart';
import '../../widgets/loader.dart';
import 'issue_detail_screen.dart';

/// The Branches page, laid out like github.com's: Overview / Yours /
/// Active / Stale / All, a search box, and tables with when each branch
/// was updated, its checks, how far it is behind and ahead of the default
/// branch, and its pull request.
class BranchesTab extends StatefulWidget {
  const BranchesTab({
    super.key,
    required this.owner,
    required this.repo,
    required this.github,
    required this.defaultBranch,
    required this.current,
    required this.onSelect,
    this.onCount,
  });

  final String owner;
  final String repo;
  final GitHubService github;
  final String? defaultBranch;
  final String? current;

  /// Shows a branch in another tab (0 Code, 3 Commit graph).
  final void Function(String name, int tab) onSelect;
  final ValueChanged<int>? onCount;

  @override
  State<BranchesTab> createState() => _BranchesTabState();
}

enum _View { overview, yours, active, stale, all }

class _BranchesTabState extends State<BranchesTab> {
  BranchList? _list;
  Object? _error;
  var _view = _View.overview;
  final _search = TextEditingController();

  GitHubService get _gh => widget.github;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
    if (widget.defaultBranch != null) _load();
  }

  @override
  void didUpdateWidget(BranchesTab old) {
    super.didUpdateWidget(old);
    if (old.defaultBranch == null && widget.defaultBranch != null) _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final l = await _gh.getBranchList(
          widget.owner, widget.repo, widget.defaultBranch!);
      if (!mounted) return;
      setState(() => _list = l);
      widget.onCount?.call(l.branches.length);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  // ------------------------------------------------------------- actions

  void _copy(String name) {
    Clipboard.setData(ClipboardData(text: name));
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Copied $name')));
  }

  Future<void> _delete(BranchInfo b) async {
    final pr = b.prNumber != null && b.prState == 'OPEN'
        ? ' Pull request #${b.prNumber} will be closed.'
        : '';
    if (!await confirmAction(context,
        title: 'Delete ${b.name}?',
        message: 'Deletes the branch from ${widget.repo} on GitHub.$pr '
            'You can restore it on github.com from the pull request or '
            'the branches page.',
        action: 'Delete branch',
        danger: true)) {
      return;
    }
    if (!mounted) return;
    final ok = await runAction(
        context, () => _gh.deleteBranch(widget.owner, widget.repo, b.name),
        done: 'Deleted ${b.name}');
    if (ok && mounted) {
      setState(() => _list!.branches.remove(b));
      widget.onCount?.call(_list!.branches.length);
    }
  }

  Future<void> _newBranch({String? from}) async {
    final list = _list;
    if (list == null) return;
    final withSha = list.branches.where((b) => b.sha != null).toList();
    if (withSha.isEmpty) return;
    var source = from ?? widget.current ?? list.defaultBranch ?? withSha.first.name;
    if (!withSha.any((b) => b.name == source)) source = withSha.first.name;
    final name = TextEditingController();
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text('Create a branch', style: TextStyle(color: AppColors.text)),
          content: SizedBox(
            width: 420,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: name,
                autofocus: true,
                autocorrect: false,
                style: TextStyle(color: AppColors.text, fontFamily: 'monospace'),
                decoration: const InputDecoration(labelText: 'New branch name'),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: source,
                isExpanded: true,
                dropdownColor: AppColors.surface,
                decoration: const InputDecoration(labelText: 'Source'),
                style: TextStyle(color: AppColors.text, fontFamily: 'monospace'),
                items: [
                  for (final b in withSha)
                    DropdownMenuItem(
                        value: b.name,
                        child: Text(b.name, overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (v) => setD(() => source = v!),
              ),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Cancel', style: TextStyle(color: AppColors.muted))),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Create new branch')),
          ],
        ),
      ),
    );
    final n = name.text.trim();
    if (go != true || n.isEmpty || !mounted) return;
    final sha = withSha.firstWhere((b) => b.name == source).sha!;
    final ok = await runAction(
        context, () => _gh.createBranch(widget.owner, widget.repo, n, sha),
        done: 'Created $n from $source');
    if (ok) _load();
  }

  Future<void> _openPr(int number) async {
    try {
      final issue = await _gh.getIssue(widget.owner, widget.repo, number);
      if (!mounted) return;
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => IssueDetailScreen(
                  owner: widget.owner,
                  repo: widget.repo,
                  github: _gh,
                  issue: issue)));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e is ApiException ? e.message : '$e')));
      }
    }
  }

  // --------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final list = _list;
    if (list == null) {
      return _error == null
          ? const Center(child: CircularProgressIndicator())
          : errorPanel(_error!, onRetry: _load);
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: LayoutBuilder(builder: (context, box) {
        final compact = box.maxWidth < 820;
        return ListView(
          padding: EdgeInsets.fromLTRB(compact ? 14 : 28, 20, compact ? 14 : 28, 40),
          children: [
            Row(children: [
              Text('Branches',
                  style: TextStyle(
                      fontFamily: kSerif, color: AppColors.text, fontSize: 24)),
              const Spacer(),
              if (_gh.hasToken && list.full)
                FilledButton(
                    onPressed: _newBranch, child: const Text('New branch')),
            ]),
            const SizedBox(height: 14),
            _tabs(),
            const SizedBox(height: 14),
            _searchBox(),
            if (!list.full)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                    'Add a GitHub token in Settings to see updates, checks, '
                    'ahead/behind counts and pull requests.',
                    style: TextStyle(color: AppColors.muted, fontSize: 13)),
              ),
            ..._sections(list, compact),
          ],
        );
      }),
    );
  }

  Widget _tabs() {
    const names = {
      _View.overview: 'Overview',
      _View.yours: 'Yours',
      _View.active: 'Active',
      _View.stale: 'Stale',
      _View.all: 'All',
    };
    return Container(
      decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border))),
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final v in _View.values)
            InkWell(
              onTap: () => setState(() {
                _view = v;
                _search.clear();
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                        color: _view == v ? AppColors.accent : Colors.transparent,
                        width: 2),
                  ),
                ),
                child: Text(names[v]!,
                    style: TextStyle(
                        color: _view == v ? AppColors.text : AppColors.muted,
                        fontSize: 14.5,
                        fontWeight:
                            _view == v ? FontWeight.w600 : FontWeight.w400)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _searchBox() {
    return TextField(
      controller: _search,
      autocorrect: false,
      style: TextStyle(color: AppColors.text, fontSize: 14),
      decoration: InputDecoration(
        isDense: true,
        hintText: 'Search branches...',
        hintStyle: TextStyle(color: AppColors.faint),
        prefixIcon: Icon(Icons.search, color: AppColors.muted, size: 20),
        suffixIcon: _search.text.isEmpty
            ? null
            : IconButton(
                icon: Icon(Icons.close, color: AppColors.muted, size: 18),
                onPressed: _search.clear),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: AppColors.border)),
      ),
    );
  }

  List<Widget> _sections(BranchList list, bool compact) {
    final def = list.defaultBranch;
    final all = list.branches;
    final others = all.where((b) => b.name != def).toList();
    final defRow = all.where((b) => b.name == def).toList();
    final yours = others
        .where((b) => list.viewer != null && b.authorLogin == list.viewer)
        .toList();
    final active = others.where((b) => !b.isStale).toList();
    final stale = others.where((b) => b.isStale).toList();

    final q = _search.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      final hits = all.where((b) => b.name.toLowerCase().contains(q)).toList();
      return [
        _section('Search results', hits, compact,
            empty: 'No branches match "${_search.text.trim()}".'),
      ];
    }

    switch (_view) {
      case _View.overview:
        return [
          if (defRow.isNotEmpty) _section('Default', defRow, compact),
          if (yours.isNotEmpty)
            _section('Your branches', yours, compact,
                limit: 5, more: _View.yours),
          if (active.isNotEmpty)
            _section('Active branches', active, compact,
                limit: 5, more: _View.active),
          if (stale.isNotEmpty)
            _section('Stale branches', stale, compact,
                limit: 5, more: _View.stale),
          if (!list.full) _section('All branches', others, compact),
        ];
      case _View.yours:
        return [
          _section('Your branches', yours, compact,
              empty: list.viewer == null
                  ? 'Add a GitHub token to see your branches.'
                  : 'You haven\'t pushed any branches here.'),
        ];
      case _View.active:
        return [
          _section('Active branches', active, compact,
              empty: 'No branches with commits in the last 3 months.'),
        ];
      case _View.stale:
        return [
          _section('Stale branches', stale, compact,
              empty: 'No stale branches. Stale means no commits in 3 months.'),
        ];
      case _View.all:
        return [
          if (defRow.isNotEmpty) _section('Default', defRow, compact),
          _section('All branches', others, compact,
              empty: 'There are no other branches.'),
        ];
    }
  }

  Widget _section(String title, List<BranchInfo> rows, bool compact,
      {int? limit, _View? more, String? empty}) {
    final shown = limit == null ? rows : rows.take(limit).toList();
    final maxCount = shown.fold<int>(
        1,
        (m, b) => [m, b.ahead ?? 0, b.behind ?? 0]
            .reduce((a, c) => a > c ? a : c));
    final full = _list!.full;
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title,
              style: TextStyle(
                  color: AppColors.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          rowsBox([
            _headerRow(compact, full),
            if (shown.isEmpty && empty != null)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(empty,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted)),
              ),
            for (final b in shown) _row(b, compact, full, maxCount),
            if (more != null && rows.length > shown.length)
              InkWell(
                onTap: () => setState(() => _view = more),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('View more branches',
                          style: TextStyle(
                              color: AppColors.accent, fontSize: 14)),
                      const SizedBox(width: 4),
                      Icon(Icons.chevron_right,
                          color: AppColors.accent, size: 18),
                    ],
                  ),
                ),
              ),
          ]),
        ],
      ),
    );
  }

  // Column widths.
  static const _wUpdated = 150.0;
  static const _wChecks = 100.0;
  static const _wAheadBehind = 130.0;
  static const _wPr = 96.0;
  static const _wActions = 92.0;

  Widget _headerRow(bool compact, bool full) {
    Text label(String t, {TextAlign align = TextAlign.start}) => Text(t,
        textAlign: align,
        style: TextStyle(
            color: AppColors.muted,
            fontSize: 12.5,
            fontWeight: FontWeight.w500));
    Widget h(String t, {double? w}) => w == null
        ? Expanded(child: label(t))
        : SizedBox(width: w, child: label(t));

    return Container(
      color: AppColors.surfaceAlt.withOpacity(0.5),
      padding: const EdgeInsets.fromLTRB(16, 11, 8, 11),
      child: Row(children: [
        h('Branch'),
        if (full) ...[
          h('Updated', w: _wUpdated),
          if (!compact) h('Check status', w: _wChecks),
          if (!compact)
            SizedBox(
              width: _wAheadBehind,
              child: Row(children: [
                Expanded(child: label('Behind', align: TextAlign.end)),
                Container(
                    width: 1,
                    height: 14,
                    margin: const EdgeInsets.symmetric(horizontal: 5),
                    color: AppColors.border),
                Expanded(child: label('Ahead')),
              ]),
            ),
          h('Pull request', w: _wPr),
        ],
        const SizedBox(width: _wActions),
      ]),
    );
  }

  Widget _row(BranchInfo b, bool compact, bool full, int maxCount) {
    final isDefault = b.name == _list!.defaultBranch;
    final isCurrent = b.name == (widget.current ?? _list!.defaultBranch);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(children: [
        Expanded(
          child: Row(children: [
            Flexible(child: _nameChip(b.name, isCurrent)),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.copy_outlined, size: 17, color: AppColors.muted),
              tooltip: 'Copy branch name',
              onPressed: () => _copy(b.name),
            ),
          ]),
        ),
        if (full) ...[
          SizedBox(
            width: _wUpdated,
            child: Row(children: [
              if (b.authorAvatar != null) ...[
                Avatar(b.authorAvatar!, size: 18, login: b.authorLogin),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(timeAgo(b.updatedAt),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppColors.text, fontSize: 13)),
              ),
            ]),
          ),
          if (!compact) SizedBox(width: _wChecks, child: _checks(b)),
          if (!compact)
            SizedBox(
              width: _wAheadBehind,
              child: isDefault
                  ? Center(child: outlineBadge('Default', color: AppColors.text))
                  : _aheadBehind(b, maxCount),
            ),
          SizedBox(width: _wPr, child: _prPill(b)),
        ],
        SizedBox(
          width: _wActions,
          child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            if (_gh.hasToken)
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.delete_outline,
                    size: 20,
                    color: isDefault ? AppColors.faint : AppColors.muted),
                tooltip: isDefault
                    ? 'The default branch can\'t be deleted'
                    : 'Delete branch',
                onPressed: isDefault ? null : () => _delete(b),
              ),
            _menu(b),
          ]),
        ),
      ]),
    );
  }

  Widget _nameChip(String name, bool current) {
    final c = AppColors.accent;
    return Material(
      color: c.withOpacity(current ? 0.22 : 0.10),
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => widget.onSelect(name, 0),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
          child: Text(name,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: AppColors.isDark ? AppColors.accentLight : c,
                  fontFamily: 'monospace',
                  fontSize: 13,
                  fontWeight: current ? FontWeight.w700 : FontWeight.w400)),
        ),
      ),
    );
  }

  Widget _checks(BranchInfo b) {
    if (b.checkState == null || b.checksTotal == 0) return const SizedBox();
    final (IconData icon, Color color) = switch (b.checkState) {
      'SUCCESS' => (Icons.check, ghOpen),
      'FAILURE' || 'ERROR' => (Icons.close, ghClosed),
      _ => (Icons.circle, AppColors.warning),
    };
    return Row(children: [
      Icon(icon, size: icon == Icons.circle ? 10 : 17, color: color),
      const SizedBox(width: 7),
      Text('${b.checksPassed} / ${b.checksTotal}',
          style: TextStyle(color: AppColors.text, fontSize: 13)),
    ]);
  }

  /// "10 | 1" with grey bars under each number, growing out from the
  /// middle line, scaled to the biggest number in the table.
  Widget _aheadBehind(BranchInfo b, int maxCount) {
    if (b.ahead == null || b.behind == null) return const SizedBox();
    const barMax = 54.0;
    double w(int n) => n == 0 ? 0 : (barMax * n / maxCount).clamp(3, barMax);
    Widget side(int n, bool left) => Expanded(
          child: Column(
            crossAxisAlignment:
                left ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$n',
                  style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
              const SizedBox(height: 3),
              Container(
                width: w(n),
                height: 3,
                decoration: BoxDecoration(
                  color: AppColors.faint.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        );
    return Row(children: [
      side(b.behind!, true),
      Container(
          width: 1,
          height: 24,
          margin: const EdgeInsets.symmetric(horizontal: 5),
          color: AppColors.border),
      side(b.ahead!, false),
    ]);
  }

  Widget _prPill(BranchInfo b) {
    final n = b.prNumber;
    if (n == null) return const SizedBox();
    final (IconData icon, Color color) = switch (b.prState) {
      'MERGED' => (Icons.merge, ghMerged),
      'CLOSED' => (Icons.call_split, ghClosed),
      _ => (Icons.call_split, b.prDraft ? ghDraft : ghOpen),
    };
    return Align(
      alignment: Alignment.centerLeft,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openPr(n),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text('#$n', style: TextStyle(color: AppColors.text, fontSize: 12.5)),
          ]),
        ),
      ),
    );
  }

  Widget _menu(BranchInfo b) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_horiz, color: AppColors.muted, size: 20),
      tooltip: 'More',
      onSelected: (v) {
        switch (v) {
          case 'code':
            widget.onSelect(b.name, 0);
          case 'graph':
            widget.onSelect(b.name, 3);
          case 'copy':
            _copy(b.name);
          case 'new':
            _newBranch(from: b.name);
          case 'pr':
            _openPr(b.prNumber!);
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'code', child: Text('Browse code')),
        const PopupMenuItem(value: 'graph', child: Text('View commit graph')),
        if (b.prNumber != null)
          PopupMenuItem(
              value: 'pr', child: Text('Open pull request #${b.prNumber}')),
        const PopupMenuItem(value: 'copy', child: Text('Copy branch name')),
        if (_gh.hasToken && b.sha != null)
          const PopupMenuItem(
              value: 'new', child: Text('New branch from here')),
      ],
    );
  }
}
