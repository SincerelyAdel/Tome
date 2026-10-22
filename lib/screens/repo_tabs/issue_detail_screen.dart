import 'package:flutter/material.dart';
import '../../models/github_models.dart';
import '../../services/github_org.dart';
import '../../services/github_service.dart';
import '../../theme.dart';
import '../../widgets/diff_view.dart';
import '../../widgets/file_tree.dart';
import '../../widgets/gh_markdown.dart';
import '../../widgets/gh_widgets.dart';
import '../../widgets/issue_actions.dart';
import 'commit_detail_screen.dart';

/// An issue or pull request laid out like GitHub: header, (for PRs) the
/// Conversation / Commits / Checks / Files changed tabs, a timeline of
/// comments, reviews and events, and a sidebar with people and labels.
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
  int _tab = 0; // 0 Conversation, 1 Commits, 2 Checks, 3 Files changed

  List<GhEvent>? _timeline;
  String? _timelineError;
  GhPullDetail? _pull;
  List<GhCommit>? _commits;
  List<GhFileChange>? _files;
  List<GhCheckRun>? _checks;
  final Map<int, String> _tabErrors = {};

  // Files changed: the page scroll, the file tree that stays in view while
  // the diffs scroll past, and a key per diff card to jump to it.
  final _scroll = ScrollController();
  final _bodyKey = GlobalKey();
  final _filesKey = GlobalKey();
  final _treeOffset = ValueNotifier<double>(0);
  final Map<String, GlobalKey> _fileKeys = {};
  String? _selectedFile;
  double _viewportH = 800;

  GhIssue get _i => widget.issue;
  bool get _isPr => _i.isPullRequest;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_placeTree);
    _loadTimeline();
    if (_isPr) _loadPull();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _treeOffset.dispose();
    super.dispose();
  }

  static const _treeGap = 12.0;

  double get _treeH => _viewportH - 2 * _treeGap;

  /// Slides the file tree down so it stays on screen while the diffs next
  /// to it scroll, without running past the last diff.
  void _placeTree() {
    final row = _filesKey.currentContext?.findRenderObject() as RenderBox?;
    final body = _bodyKey.currentContext?.findRenderObject() as RenderBox?;
    if (row == null || body == null || !row.attached) return;
    final top = row.localToGlobal(Offset.zero, ancestor: body).dy;
    final max = row.size.height - _treeH;
    _treeOffset.value = max <= 0 ? 0 : (_treeGap - top).clamp(0.0, max);
  }

  void _jumpToFile(GhFileChange f) {
    setState(() => _selectedFile = f.filename);
    final ctx = _fileKeys[f.filename]?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          alignment: 0.02);
    }
  }

  String _msg(Object e) => e.toString().replaceFirst('Exception: ', '');

  Future<void> _loadTimeline() async {
    setState(() => _timelineError = null);
    try {
      final t =
          await widget.github.getTimeline(widget.owner, widget.repo, _i.number);
      if (mounted) setState(() => _timeline = t);
    } catch (e) {
      if (mounted) setState(() => _timelineError = _msg(e));
    }
  }

  Future<void> _loadPull() async {
    try {
      final p = await widget.github.getPull(widget.owner, widget.repo, _i.number);
      if (!mounted) return;
      setState(() => _pull = p);
      _loadChecks();
    } catch (_) {/* header falls back to list data */}
  }

  Future<void> _loadChecks() async {
    final sha = _pull?.headSha;
    if (sha == null || sha.isEmpty) return;
    try {
      final c = await widget.github.getCheckRuns(widget.owner, widget.repo, sha);
      if (mounted) setState(() => _checks = c);
    } catch (e) {
      if (mounted) setState(() => _tabErrors[2] = _msg(e));
    }
  }

  Future<void> _loadCommits() async {
    setState(() => _tabErrors.remove(1));
    try {
      final c = await widget.github
          .getPullCommits(widget.owner, widget.repo, _i.number);
      if (mounted) setState(() => _commits = c);
    } catch (e) {
      if (mounted) setState(() => _tabErrors[1] = _msg(e));
    }
  }

  Future<void> _loadFiles() async {
    setState(() => _tabErrors.remove(3));
    try {
      final f =
          await widget.github.getPullFiles(widget.owner, widget.repo, _i.number);
      if (mounted) setState(() => _files = f);
    } catch (e) {
      if (mounted) setState(() => _tabErrors[3] = _msg(e));
    }
  }

  void _selectTab(int t) {
    setState(() => _tab = t);
    if (t == 1 && _commits == null) _loadCommits();
    if (t == 3 && _files == null) _loadFiles();
    if (t == 2 && _checks == null) _loadChecks();
  }

  // ---------------------------------------------------------------- layout

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final wide = width > 1000;
    final hPad = width > 1340 ? (width - 1280) / 2 : (wide ? 32.0 : 16.0);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(
            '${widget.repo} · ${_isPr ? 'Pull request' : 'Issue'} #${_i.number}',
            style: TextStyle(color: AppColors.text, fontSize: 16)),
        iconTheme: IconThemeData(color: AppColors.text),
      ),
      body: LayoutBuilder(
        key: _bodyKey,
        builder: (context, box) {
          _viewportH = box.maxHeight;
          return _page(wide, hPad);
        },
      ),
    );
  }

  Widget _page(bool wide, double hPad) {
    return ListView(
        controller: _scroll,
        padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 48),
        children: [
          _header(wide),
          const SizedBox(height: 18),
          if (_isPr) ...[_tabBar(), const SizedBox(height: 20)],
          if (!_isPr || _tab == 0)
            wide
                ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                        child: Column(children: [
                      _conversation(),
                      const SizedBox(height: 8),
                      _actions(),
                    ])),
                    const SizedBox(width: 28),
                    SizedBox(width: 280, child: _sidebar()),
                  ])
                : Column(children: [
                    _conversation(),
                    const SizedBox(height: 8),
                    _actions(),
                    const SizedBox(height: 24),
                    _sidebar(),
                  ])
          else if (_tab == 1)
            _commitsTab()
          else if (_tab == 2)
            _checksTab()
          else
            _filesTab(wide),
        ],
    );
  }

  /// Comment / close / review / merge, then reload with fresh data.
  Widget _actions() => IssueActions(
        owner: widget.owner,
        repo: widget.repo,
        github: widget.github,
        issue: _i,
        pull: _pull,
        onChanged: _reloadPage,
      );

  Future<void> _reloadPage() async {
    GhIssue fresh = _i;
    try {
      fresh = await widget.github
          .getIssue(widget.owner, widget.repo, _i.number);
    } catch (_) {}
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: Duration.zero,
        pageBuilder: (_, __, ___) => IssueDetailScreen(
            owner: widget.owner,
            repo: widget.repo,
            github: widget.github,
            issue: fresh),
      ),
    );
  }

  // ---------------------------------------------------------------- header

  Widget _header(bool wide) {
    final title = Text.rich(
      TextSpan(children: [
        TextSpan(text: _i.title),
        TextSpan(
            text: '  #${_i.number}',
            style: TextStyle(color: AppColors.faint, fontWeight: FontWeight.w300)),
      ]),
      style: TextStyle(
          color: AppColors.text, fontSize: wide ? 30 : 24, height: 1.25),
    );
    final status = _mergeStatus();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: title),
          if (status != null && wide) ...[const SizedBox(width: 16), status],
        ]),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _statePill(),
            ..._summary(),
            if (status != null && !wide) status,
          ],
        ),
      ],
    );
  }

  List<Widget> _summary() {
    final muted = TextStyle(color: AppColors.muted, fontSize: 14);
    final strong = TextStyle(
        color: AppColors.text, fontSize: 14, fontWeight: FontWeight.w600);
    if (_isPr) {
      final p = _pull;
      final n = p?.commits;
      final head = p?.headRef ?? _i.headRef ?? '';
      final base = p?.baseRef ?? _i.baseRef ?? '';
      final merged = p?.merged ?? _i.isMerged;
      return [
        Text.rich(TextSpan(children: [
          userSpan(_i.user.login, style: strong),
          TextSpan(
              text: merged ? ' merged ' : ' wants to merge ', style: muted),
          if (n != null)
            TextSpan(text: '$n commit${n == 1 ? '' : 's'} ', style: muted),
          TextSpan(text: 'into', style: muted),
        ])),
        _branchChip(base),
        Text('from', style: muted),
        _branchChip(head),
      ];
    }
    final n = _i.comments;
    return [
      Text.rich(TextSpan(children: [
        userSpan(_i.user.login, style: strong),
        TextSpan(
            text: ' opened this issue ${timeAgo(_i.createdAt)}'
                ' · $n comment${n == 1 ? '' : 's'}',
            style: muted),
      ])),
    ];
  }

  Widget _branchChip(String name) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.accent.withOpacity(AppColors.isDark ? 0.16 : 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(name,
            style: TextStyle(
                color: AppColors.isDark ? AppColors.accentLight : AppColors.accent,
                fontFamily: 'monospace',
                fontSize: 12.5)),
      );

  Widget _statePill() {
    late final String text;
    late final Color color;
    late final IconData icon;
    final merged = _pull?.merged ?? _i.isMerged;
    if (_isPr) {
      if (merged) {
        (text, color, icon) = ('Merged', ghMerged, Icons.merge);
      } else if (_i.isOpen) {
        (text, color, icon) = _i.isDraft
            ? ('Draft', ghDraft, Icons.call_split)
            : ('Open', ghOpen, Icons.call_split);
      } else {
        (text, color, icon) = ('Closed', ghClosed, Icons.call_split);
      }
    } else {
      (text, color, icon) = _i.isOpen
          ? ('Open', ghOpen, Icons.radio_button_checked)
          : ('Closed', ghMerged, Icons.check_circle_outline);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: Colors.white),
        const SizedBox(width: 6),
        Text(text,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
      ]),
    );
  }

  /// "Ready to merge" / "Merge conflicts" ... for open PRs.
  Widget? _mergeStatus() {
    final p = _pull;
    if (!_isPr || p == null || p.merged || !_i.isOpen) return null;
    final (String text, Color color, IconData icon) = switch (p.mergeableState) {
      'clean' => ('Ready to merge', ghOpen, Icons.check_circle),
      'has_hooks' => ('Ready to merge', ghOpen, Icons.check_circle),
      'dirty' => ('Merge conflicts', ghClosed, Icons.cancel),
      'blocked' => ('Merging blocked', ghClosed, Icons.block),
      'unstable' => ('Checks failing', AppColors.warning, Icons.error),
      'behind' => ('Behind base branch', AppColors.warning, Icons.history),
      'draft' => ('Draft', ghDraft, Icons.edit_note),
      _ => ('Merge status unknown', AppColors.muted, Icons.help_outline),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(text,
            style: TextStyle(
                color: AppColors.text, fontSize: 13.5, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  // ----------------------------------------------------------------- tabs

  Widget _tabBar() {
    final p = _pull;
    final tabs = [
      (Icons.forum_outlined, 'Conversation', _i.comments),
      (Icons.commit, 'Commits', p?.commits),
      (Icons.checklist, 'Checks', _checks?.length),
      (Icons.difference_outlined, 'Files changed', p?.changedFiles),
    ];
    return Container(
      decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border))),
      child: Row(children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (var i = 0; i < tabs.length; i++)
                _tabItem(i, tabs[i].$1, tabs[i].$2, tabs[i].$3),
            ]),
          ),
        ),
        if (p != null) ...[
          const SizedBox(width: 12),
          diffStat(p.additions, p.deletions),
          const SizedBox(width: 6),
          diffBar(p.additions, p.deletions),
        ],
      ]),
    );
  }

  Widget _tabItem(int i, IconData icon, String label, int? count) {
    final active = _tab == i;
    return InkWell(
      onTap: () => _selectTab(i),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: active ? AppColors.surface : Colors.transparent,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          border: active
              ? Border(
                  top: BorderSide(color: AppColors.accent, width: 2),
                  left: BorderSide(color: AppColors.border),
                  right: BorderSide(color: AppColors.border),
                )
              : null,
        ),
        child: Row(children: [
          Icon(icon, size: 17, color: active ? AppColors.text : AppColors.muted),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                  color: AppColors.text,
                  fontSize: 14,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400)),
          if (count != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
              decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(10)),
              child: Text('$count',
                  style: TextStyle(color: AppColors.text, fontSize: 12)),
            ),
          ],
        ]),
      ),
    );
  }

  // --------------------------------------------------------- conversation

  static const _gutter = 56.0; // avatar column
  static const _lineX = _gutter + 19; // timeline line position

  Widget _conversation() {
    final items = <Widget>[
      _commentCard(_i.user, _i.createdAt, _i.body, isAuthor: true),
    ];
    final t = _timeline;
    if (t == null) {
      items.add(Padding(
        padding: const EdgeInsets.all(24),
        child: tabMessage(error: _timelineError, onRetry: _loadTimeline),
      ));
    } else {
      var i = 0;
      while (i < t.length) {
        final e = t[i];
        if (e.event == 'committed') {
          final group = <GhEvent>[];
          while (i < t.length && t[i].event == 'committed') {
            group.add(t[i++]);
          }
          items.add(_commitGroup(group));
          continue;
        }
        final w = _eventWidget(e);
        if (w != null) items.add(w);
        i++;
      }
    }
    return Stack(children: [
      // The vertical line that threads the timeline together.
      Positioned(
        left: _lineX,
        top: 0,
        bottom: 0,
        child: Container(width: 2, color: AppColors.border),
      ),
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: items),
    ]);
  }

  Widget? _eventWidget(GhEvent e) {
    final who = e.actor?.login ?? 'someone';
    final subj = e.subject?.login ?? '';
    switch (e.event) {
      case 'commented':
        return _commentCard(e.actor ?? const GhUser(login: '?', avatarUrl: ''),
            e.at, e.body,
            isAuthor: e.actor?.login == _i.user.login);
      case 'reviewed':
        return _review(e);
      case 'review_requested':
        return _eventRow(Icons.visibility_outlined, e, [
          _u(who), _t(' requested a review from '), _u(subj)]);
      case 'review_request_removed':
        return _eventRow(Icons.visibility_off_outlined, e, [
          _u(who), _t(' removed the request for review from '), _u(subj)]);
      case 'assigned':
        return _eventRow(Icons.person_outline, e, subj == who
            ? [_u(who), _t(' self-assigned this')]
            : [_u(who), _t(' assigned '), _u(subj)]);
      case 'unassigned':
        return _eventRow(Icons.person_remove_outlined, e,
            [_u(who), _t(' unassigned '), _u(subj)]);
      case 'labeled':
      case 'unlabeled':
        return _eventRow(Icons.label_outline, e, [
          _u(who),
          _t(e.event == 'labeled' ? ' added the ' : ' removed the '),
          WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: e.label == null ? const SizedBox() : LabelChip(e.label!)),
          _t(' label'),
        ]);
      case 'renamed':
        return _eventRow(Icons.edit_outlined, e, [
          _u(who), _t(' changed the title '),
          TextSpan(
              text: e.renameFrom ?? '',
              style: TextStyle(
                  decoration: TextDecoration.lineThrough,
                  color: AppColors.muted)),
          _t(' '), _b(e.renameTo ?? ''),
        ]);
      case 'merged':
        return _eventRow(Icons.merge, e, [
          _u(who), _t(' merged commit '),
          _mono((e.sha ?? '').padRight(7).substring(0, 7)),
          _t(' into '), _b(_pull?.baseRef ?? _i.baseRef ?? ''),
        ], color: ghMerged);
      case 'closed':
        return _eventRow(Icons.block, e, [_u(who), _t(' closed this')],
            color: _isPr ? ghClosed : ghMerged);
      case 'reopened':
        return _eventRow(Icons.radio_button_checked, e,
            [_u(who), _t(' reopened this')], color: ghOpen);
      case 'head_ref_force_pushed':
        return _eventRow(Icons.upload_outlined, e,
            [_u(who), _t(' force-pushed the head branch')]);
      case 'head_ref_deleted':
        return _eventRow(Icons.delete_outline, e,
            [_u(who), _t(' deleted the head branch')]);
      case 'head_ref_restored':
        return _eventRow(Icons.restore, e,
            [_u(who), _t(' restored the head branch')]);
      case 'ready_for_review':
        return _eventRow(Icons.visibility_outlined, e,
            [_u(who), _t(' marked this pull request as ready for review')]);
      case 'convert_to_draft':
        return _eventRow(Icons.edit_note, e,
            [_u(who), _t(' marked this pull request as draft')]);
      case 'cross-referenced':
        return _eventRow(Icons.link, e, [_u(who), _t(' mentioned this')]);
      case 'referenced':
        return _eventRow(Icons.commit, e, [
          _u(who), _t(' added a commit that referenced this'),
          if (e.sha != null) ...[_t(' '), _mono(e.sha!.substring(0, 7))],
        ]);
      case 'milestoned':
      case 'demilestoned':
        return _eventRow(Icons.flag_outlined, e, [
          _u(who),
          _t(e.event == 'milestoned'
              ? ' added this to a milestone'
              : ' removed this from a milestone'),
        ]);
      default:
        return null; // subscribed, mentioned, comment_deleted ...
    }
  }

  InlineSpan _t(String s) => TextSpan(text: s);

  /// A username that opens the profile.
  InlineSpan _u(String login) => userSpan(login,
      style: TextStyle(
          color: AppColors.text, fontWeight: FontWeight.w600, fontSize: 13.5));
  InlineSpan _b(String s) => TextSpan(
      text: s,
      style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w600));
  InlineSpan _mono(String s) => TextSpan(
      text: s,
      style: TextStyle(fontFamily: 'monospace', color: AppColors.text));

  /// A small event line on the timeline: icon badge, text, time.
  Widget _eventRow(IconData icon, GhEvent e, List<InlineSpan> spans,
      {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(left: _lineX - 15, top: 6, bottom: 6),
      child: Row(children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color ?? AppColors.surfaceAlt,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.bg, width: 2),
          ),
          child: Icon(icon,
              size: 16, color: color == null ? AppColors.muted : Colors.white),
        ),
        const SizedBox(width: 10),
        if (e.actor != null) ...[
          Avatar(e.actor!.avatarUrl, size: 20, login: e.actor!.login),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text.rich(
            TextSpan(children: [
              ...spans,
              TextSpan(
                  text: '  ${timeAgo(e.at)}',
                  style: TextStyle(color: AppColors.faint)),
            ]),
            style: TextStyle(color: AppColors.muted, fontSize: 13.5),
          ),
        ),
      ]),
    );
  }

  /// "X added N commits" followed by the commits, like GitHub.
  Widget _commitGroup(List<GhEvent> commits) {
    final who = commits.first.authorName ?? 'someone';
    InlineSpan Function(String) name = _b;
    return Padding(
      padding: const EdgeInsets.only(left: _lineX - 15, top: 6, bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.bg, width: 2),
              ),
              child: Icon(Icons.upload_outlined, size: 16, color: AppColors.muted),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text.rich(
                TextSpan(children: [
                  name(who),
                  _t(' added ${commits.length} commit'
                      '${commits.length == 1 ? '' : 's'}'),
                  TextSpan(
                      text: '  ${timeAgo(commits.last.at)}',
                      style: TextStyle(color: AppColors.faint)),
                ]),
                style: TextStyle(color: AppColors.muted, fontSize: 13.5),
              ),
            ),
          ]),
          const SizedBox(height: 4),
          ...commits.map((c) => InkWell(
                onTap: c.sha == null
                    ? null
                    : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CommitDetailScreen(
                              owner: widget.owner,
                              repo: widget.repo,
                              github: widget.github,
                              summary: GhCommit(
                                sha: c.sha!,
                                message: c.message ?? '',
                                authorName: c.authorName ?? '',
                                date: c.at,
                              ),
                            ),
                          ),
                        ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(children: [
                    SizedBox(
                      width: 32,
                      child: Center(
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: AppColors.bg,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.faint, width: 2),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text((c.message ?? '').split('\n').first,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: AppColors.muted,
                              fontFamily: 'monospace',
                              fontSize: 12.5,
                              decoration: TextDecoration.underline,
                              decorationColor: AppColors.border)),
                    ),
                    const SizedBox(width: 12),
                    Text((c.sha ?? '').padRight(7).substring(0, 7),
                        style: TextStyle(
                            color: AppColors.faint,
                            fontFamily: 'monospace',
                            fontSize: 12.5)),
                  ]),
                ),
              )),
        ],
      ),
    );
  }

  Widget _review(GhEvent e) {
    final who = e.actor?.login ?? 'someone';
    final (String verb, IconData icon, Color? color) = switch (e.reviewState) {
      'approved' => (' approved these changes', Icons.check, ghOpen),
      'changes_requested' =>
        (' requested changes', Icons.difference_outlined, ghClosed),
      'dismissed' => ('\'s review was dismissed', Icons.block, null),
      _ => (' reviewed', Icons.visibility_outlined, null),
    };
    final row = _eventRow(icon, e, [_u(who), _t(verb)], color: color);
    if (e.body.trim().isEmpty) return row;
    return Column(children: [
      row,
      _commentCard(e.actor ?? const GhUser(login: '?', avatarUrl: ''), e.at,
          e.body,
          verb: 'left a review'),
    ]);
  }

  Widget _commentCard(GhUser user, DateTime? at, String body,
      {bool isAuthor = false, String verb = 'commented'}) {
    final highlight = isAuthor;
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: _gutter,
          child: Align(
              alignment: Alignment.topLeft, child: Avatar(user.avatarUrl, size: 40, login: user.login)),
        ),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(
                  color: highlight
                      ? AppColors.accent.withOpacity(0.55)
                      : AppColors.border),
              borderRadius: BorderRadius.circular(8),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: highlight
                        ? AppColors.accent.withOpacity(AppColors.isDark ? 0.10 : 0.08)
                        : AppColors.surfaceAlt,
                    border: Border(
                        bottom: BorderSide(
                            color: highlight
                                ? AppColors.accent.withOpacity(0.35)
                                : AppColors.border)),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  child: Row(children: [
                    Expanded(
                      child: Text.rich(TextSpan(children: [
                        _u(user.login),
                        TextSpan(
                            text: ' $verb ${timeAgo(at)}',
                            style: TextStyle(color: AppColors.muted)),
                      ]), style: const TextStyle(fontSize: 13.5)),
                    ),
                    if (user.login == _i.user.login)
                      outlineBadge('Author'),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: body.trim().isEmpty
                      ? Text('No description provided.',
                          style: TextStyle(
                              color: AppColors.faint,
                              fontStyle: FontStyle.italic,
                              fontSize: 14))
                      : GhMarkdown(body),
                ),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  // --------------------------------------------------------------- sidebar

  Widget _sidebar() {
    final t = _timeline ?? const <GhEvent>[];
    // Latest review state per reviewer.
    final reviews = <String, (GhUser, String)>{};
    for (final e in t.where((e) => e.event == 'reviewed' && e.actor != null)) {
      if (e.reviewState == 'commented' &&
          reviews.containsKey(e.actor!.login)) {
        continue; // a plain comment doesn't override approve/changes
      }
      reviews[e.actor!.login] = (e.actor!, e.reviewState ?? 'commented');
    }
    final pending = (_pull?.requestedReviewers ?? const <GhUser>[])
        .where((u) => !reviews.containsKey(u.login))
        .toList();

    final participants = <String, GhUser>{_i.user.login: _i.user};
    for (final e in t) {
      if ((e.event == 'commented' || e.event == 'reviewed') && e.actor != null) {
        participants[e.actor!.login] = e.actor!;
      }
    }

    final none = TextStyle(color: AppColors.muted, fontSize: 13);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_isPr)
          _section('Reviewers', [
            if (reviews.isEmpty && pending.isEmpty)
              Text('No reviews', style: none),
            ...reviews.values.map((r) => _person(r.$1, trailing: _reviewIcon(r.$2))),
            ...pending.map((u) => _person(u,
                trailing: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                      color: AppColors.warning, shape: BoxShape.circle),
                ))),
          ]),
        _section('Assignees', [
          if (_i.assignees.isEmpty) Text('No one assigned', style: none),
          ..._i.assignees.map(_person),
        ]),
        _section('Labels', [
          if (_i.labels.isEmpty)
            Text('None yet', style: none)
          else
            Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _i.labels.map((l) => LabelChip(l)).toList()),
        ]),
        _section('Milestone', [
          Text(_i.milestone ?? 'No milestone',
              style: _i.milestone == null
                  ? none
                  : TextStyle(color: AppColors.text, fontSize: 13.5)),
        ]),
        _section('${participants.length} participant'
            '${participants.length == 1 ? '' : 's'}', [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: participants.values
                .map((u) => Tooltip(
                    message: u.login, child: Avatar(u.avatarUrl, size: 28, login: u.login)))
                .toList(),
          ),
        ], last: true),
      ],
    );
  }

  Widget _section(String title, List<Widget> children, {bool last = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: last
            ? null
            : Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _person(GhUser u, {Widget? trailing}) => InkWell(
        onTap: () => openProfile(context, u.login),
        child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Avatar(u.avatarUrl, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Text(u.login,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: AppColors.text,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600)),
          ),
          if (trailing != null) trailing,
        ]),
      ));

  Widget _reviewIcon(String state) => switch (state) {
        'approved' => Icon(Icons.check, size: 18, color: ghOpen),
        'changes_requested' =>
          Icon(Icons.difference_outlined, size: 18, color: ghClosed),
        _ => Icon(Icons.chat_bubble_outline, size: 16, color: AppColors.muted),
      };

  // ------------------------------------------------------- other PR tabs

  Widget _commitsTab() {
    final c = _commits;
    if (c == null) {
      return tabMessage(error: _tabErrors[1], onRetry: _loadCommits);
    }
    if (c.isEmpty) return tabMessage(empty: 'No commits');
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        for (var i = 0; i < c.length; i++)
          InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CommitDetailScreen(
                  owner: widget.owner,
                  repo: widget.repo,
                  github: widget.github,
                  summary: c[i],
                ),
              ),
            ),
            child: Container(
              color: AppColors.surface,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: null,
              child: Row(children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c[i].title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: AppColors.text,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Row(children: [
                        Avatar(c[i].author?.avatarUrl ?? '', size: 18, login: c[i].author?.login),
                        const SizedBox(width: 6),
                        Text(
                            '${c[i].author?.login ?? c[i].authorName} committed '
                            '${timeAgo(c[i].date)}',
                            style: TextStyle(
                                color: AppColors.muted, fontSize: 12.5)),
                      ]),
                    ],
                  ),
                ),
                Text(c[i].shortSha,
                    style: TextStyle(
                        fontFamily: 'monospace',
                        color: AppColors.muted,
                        fontSize: 12.5)),
              ]),
            ),
          ),
      ].expand((w) => [w, Divider(height: 1, color: AppColors.border)]).toList()
        ..removeLast()),
    );
  }

  Widget _checksTab() {
    final runs = _checks;
    if (runs == null) {
      return tabMessage(error: _tabErrors[2], onRetry: _loadChecks);
    }
    if (runs.isEmpty) return tabMessage(empty: 'No checks ran on this branch');
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
        color: AppColors.surface,
      ),
      child: Column(
        children: runs.map((r) {
          final (IconData icon, Color color, String state) =
              r.status != 'completed'
                  ? (Icons.timelapse, AppColors.warning, 'In progress')
                  : switch (r.conclusion) {
                      'success' => (Icons.check_circle, ghOpen, 'Successful'),
                      'failure' || 'timed_out' =>
                        (Icons.cancel, ghClosed, 'Failing'),
                      'cancelled' => (Icons.block, AppColors.muted, 'Cancelled'),
                      'skipped' => (Icons.skip_next, AppColors.muted, 'Skipped'),
                      _ => (Icons.help_outline, AppColors.muted,
                          r.conclusion ?? 'Unknown'),
                    };
          final took = r.startedAt != null && r.completedAt != null
              ? r.completedAt!.difference(r.startedAt!)
              : null;
          return ListTile(
            leading: Icon(icon, color: color),
            title: Text(r.name,
                style: TextStyle(
                    color: AppColors.text, fontWeight: FontWeight.w600)),
            subtitle: Text(
                took == null
                    ? state
                    : '$state in ${took.inMinutes}m ${took.inSeconds % 60}s',
                style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
          );
        }).toList(),
      ),
    );
  }

  Widget _filesTab(bool wide) {
    final f = _files;
    if (f == null) return tabMessage(error: _tabErrors[3], onRetry: _loadFiles);
    if (f.isEmpty) return tabMessage(empty: 'No files changed');
    final adds = f.fold<int>(0, (a, x) => a + x.additions);
    final dels = f.fold<int>(0, (a, x) => a + x.deletions);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Text('${f.length} file${f.length == 1 ? '' : 's'} changed  ',
              style: TextStyle(color: AppColors.text, fontSize: 14)),
          diffStat(adds, dels, fontSize: 14),
          const SizedBox(width: 6),
          diffBar(adds, dels),
        ]),
        const SizedBox(height: 12),
        if (!wide) ...[
          Container(
            height: 320,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: FileTree(
                files: f, selected: _selectedFile, onTap: _jumpToFile),
          ),
          const SizedBox(height: 14),
          ..._cards(f),
        ] else
          Row(
            key: _filesKey,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 300,
                child: ValueListenableBuilder<double>(
                  valueListenable: _treeOffset,
                  builder: (_, off, child) => Transform.translate(
                      offset: Offset(0, off), child: child),
                  child: SizedBox(
                    height: _treeH,
                    child: FileTree(
                        files: f, selected: _selectedFile, onTap: _jumpToFile),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: _cards(f),
                ),
              ),
            ],
          ),
      ],
    );
  }

  List<Widget> _cards(List<GhFileChange> f) => [
        for (final x in f)
          DiffFileCard(x,
              key: _fileKeys.putIfAbsent(x.filename, () => GlobalKey())),
      ];
}
