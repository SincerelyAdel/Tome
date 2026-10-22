import 'package:flutter/material.dart';
import '../models/github_models.dart';
import '../services/github_org.dart';
import '../services/github_service.dart';
import '../theme.dart';
import 'gh_widgets.dart';
import 'loader.dart';

/// The bottom of an issue or PR page: write a comment, close or reopen,
/// and for open pull requests review (approve / request changes) and
/// merge. Everything asks before changing GitHub. [onChanged] reloads the
/// page afterwards.
class IssueActions extends StatefulWidget {
  const IssueActions({
    super.key,
    required this.owner,
    required this.repo,
    required this.github,
    required this.issue,
    required this.onChanged,
    this.pull,
    this.checks,
    this.timeline,
  });

  final String owner;
  final String repo;
  final GitHubService github;
  final GhIssue issue;
  final GhPullDetail? pull;
  final List<GhCheckRun>? checks;
  final List<GhEvent>? timeline;
  final VoidCallback onChanged;

  @override
  State<IssueActions> createState() => _IssueActionsState();
}

class _IssueActionsState extends State<IssueActions> {
  final _text = TextEditingController();
  bool _busy = false;
  String _mergeMethod = 'merge';
  bool _showReviewers = false;
  bool _showChecks = false;

  GhIssue get _i => widget.issue;
  bool get _isPr => _i.isPullRequest;
  bool get _merged => widget.pull?.merged ?? _i.isMerged;
  String get _kind => _isPr ? 'pull request' : 'issue';

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _do(Future<void> Function() action, String done) async {
    setState(() => _busy = true);
    final ok = await runAction(context, action, done: done);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      _text.clear();
      widget.onChanged();
    }
  }

  Future<void> _comment() async {
    final body = _text.text.trim();
    if (body.isEmpty) return;
    await _do(
        () => widget.github.addComment(widget.owner, widget.repo, _i.number, body),
        'Comment posted');
  }

  Future<void> _toggleState() async {
    final open = !_i.isOpen;
    final hasText = _text.text.trim().isNotEmpty;
    if (!await confirmAction(context,
        title: open ? 'Reopen this $_kind?' : 'Close this $_kind?',
        message: '${widget.repo} #${_i.number} will be '
            '${open ? 'reopened' : 'closed'}'
            '${hasText ? ', and your comment posted first' : ''}.',
        action: open ? 'Reopen' : 'Close',
        danger: !open)) {
      return;
    }
    await _do(() async {
      if (hasText) {
        await widget.github.addComment(
            widget.owner, widget.repo, _i.number, _text.text.trim());
      }
      await widget.github
          .setIssueOpen(widget.owner, widget.repo, _i.number, open);
    }, open ? 'Reopened' : 'Closed');
  }

  Future<void> _review(String event) async {
    final label = switch (event) {
      'APPROVE' => 'Approve',
      'REQUEST_CHANGES' => 'Request changes',
      _ => 'Comment',
    };
    if (event == 'REQUEST_CHANGES' && _text.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Write what needs to change in the box first.')));
      return;
    }
    if (!await confirmAction(context,
        title: '$label this pull request?',
        message: 'Submits your review on ${widget.repo} #${_i.number}'
            '${_text.text.trim().isEmpty ? '' : ' with your comment'}.',
        action: label)) {
      return;
    }
    await _do(
        () => widget.github.reviewPull(
            widget.owner, widget.repo, _i.number, event, _text.text),
        'Review submitted');
  }

  Future<void> _merge() async {
    final how = switch (_mergeMethod) {
      'squash' => 'squash and merge',
      'rebase' => 'rebase and merge',
      _ => 'merge',
    };
    final p = widget.pull;
    if (!await confirmAction(context,
        title: 'Merge pull request?',
        message: 'This will $how #${_i.number}'
            '${p == null ? '' : ' (${p.headRef} into ${p.baseRef})'}. '
            'This can\'t be undone from the app.',
        action: 'Merge')) {
      return;
    }
    await _do(
        () => widget.github
            .mergePull(widget.owner, widget.repo, _i.number, _mergeMethod),
        'Pull request merged');
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.github.hasToken) {
      return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Text('Add a GitHub token in Settings to comment, review or merge.',
            style: TextStyle(color: AppColors.muted, fontSize: 13)),
      );
    }
    final p = widget.pull;
    final canMerge = _isPr && _i.isOpen && !_merged;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (canMerge && p != null) ...[_mergeBox(p), const SizedBox(height: 16)],
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Add a comment',
                  style: TextStyle(
                      color: AppColors.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              TextField(
                controller: _text,
                minLines: 3,
                maxLines: 12,
                style: TextStyle(color: AppColors.text, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Leave a comment (Markdown works)',
                  hintStyle: TextStyle(color: AppColors.faint),
                  filled: true,
                  fillColor: AppColors.bg,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppColors.border)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppColors.border)),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 10,
                runSpacing: 8,
                children: [
                  if (canMerge) ...[
                    OutlinedButton.icon(
                      onPressed: _busy ? null : () => _review('REQUEST_CHANGES'),
                      icon: Icon(Icons.difference_outlined,
                          size: 18, color: ghClosed),
                      label: const Text('Request changes'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : () => _review('APPROVE'),
                      icon: Icon(Icons.check, size: 18, color: ghOpen),
                      label: const Text('Approve'),
                    ),
                  ],
                  if (!_merged)
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _toggleState,
                      icon: Icon(
                          _i.isOpen
                              ? Icons.check_circle_outline
                              : Icons.radio_button_checked,
                          size: 18,
                          color: _i.isOpen ? ghMerged : ghOpen),
                      label: Text(_i.isOpen
                          ? (_text.text.trim().isEmpty
                              ? 'Close $_kind'
                              : 'Close with comment')
                          : 'Reopen $_kind'),
                    ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: AppColors.button,
                        foregroundColor: AppColors.onButton),
                    onPressed: _busy || _text.text.trim().isEmpty
                        ? null
                        : _comment,
                    child: _busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Comment'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ----------------------------------------------------------- merge box

  Future<void> _setDraft(bool draft) async {
    final p = widget.pull!;
    if (!await confirmAction(context,
        title: draft ? 'Convert to draft?' : 'Ready for review?',
        message: draft
            ? 'Marks #${_i.number} as a draft. It can\'t be merged until it\'s '
                'marked ready for review again.'
            : 'Marks #${_i.number} as ready for review and notifies reviewers.',
        action: draft ? 'Convert to draft' : 'Ready for review')) {
      return;
    }
    await _do(() => widget.github.setPullDraft(p.nodeId, draft),
        draft ? 'Converted to draft' : 'Marked ready for review');
  }

  Future<void> _updateBranch() async {
    final p = widget.pull!;
    if (!await confirmAction(context,
        title: 'Update branch?',
        message: 'Merges the latest changes from ${p.baseRef} into '
            '${p.headRef}.',
        action: 'Update branch')) {
      return;
    }
    await _do(
        () => widget.github
            .updatePullBranch(widget.owner, widget.repo, _i.number),
        'Branch update started');
  }

  /// Each reviewer's latest decision (approved / changes_requested), plus
  /// everyone still asked to review ("pending").
  Map<String, (GhUser, String)> _reviewers(GhPullDetail p) {
    final out = <String, (GhUser, String)>{};
    for (final e in widget.timeline ?? const <GhEvent>[]) {
      if (e.event != 'reviewed' || e.actor == null) continue;
      final s = e.reviewState;
      if (s == 'approved' || s == 'changes_requested') {
        out[e.actor!.login] = (e.actor!, s!);
      } else if (s == 'dismissed') {
        out.remove(e.actor!.login);
      }
    }
    for (final u in p.requestedReviewers) {
      out[u.login] = (u, 'pending');
    }
    return out;
  }

  Widget _mergeBox(GhPullDetail p) {
    final state = p.mergeableState;
    final checking = p.mergeable == null || state == 'unknown';
    final conflicts = p.mergeable == false || state == 'dirty';
    final draft = p.draft || state == 'draft' || _i.isDraft;

    // Reviews.
    final reviewers = _reviewers(p);
    final approved =
        reviewers.values.where((r) => r.$2 == 'approved').length;
    final changes =
        reviewers.values.where((r) => r.$2 == 'changes_requested').length;
    final pending = reviewers.values.where((r) => r.$2 == 'pending').length;
    final reviewRequired = state == 'blocked' && approved == 0;

    // Checks.
    final checks = widget.checks;
    const bad = {
      'failure', 'timed_out', 'cancelled', 'action_required', 'startup_failure'
    };
    final failing = checks?.where((c) => bad.contains(c.conclusion)).length ?? 0;
    final running =
        checks?.where((c) => c.status != 'completed').length ?? 0;
    final passed = (checks?.length ?? 0) - failing - running;

    final rows = <Widget>[];

    // ---- reviews
    if (changes > 0) {
      rows.add(_statusRow(_Mark.fail, 'Changes requested',
          '$changes review${changes == 1 ? '' : 's'} requesting changes'));
    } else if (approved > 0) {
      rows.add(_statusRow(_Mark.ok, 'Changes approved',
          '$approved approving review${approved == 1 ? '' : 's'}'));
    } else if (reviewRequired) {
      rows.add(_statusRow(_Mark.fail, 'Review required',
          'At least one approving review is required by reviewers with '
              'write access.'));
    } else if (pending > 0) {
      rows.add(_statusRow(_Mark.ok, 'Review requested',
          'Review has been requested on this pull request. It is not '
              'required to merge.'));
    }
    if (reviewers.isNotEmpty) {
      rows.add(_expander(
        icon: Icons.person_outline,
        label: [
          if (pending > 0) '$pending pending review${pending == 1 ? '' : 's'}',
          if (approved > 0) '$approved approved',
          if (changes > 0) '$changes requested changes',
        ].join(', '),
        open: _showReviewers,
        toggle: () => setState(() => _showReviewers = !_showReviewers),
        children: [
          for (final (u, s) in reviewers.values)
            _detailLine(
              switch (s) {
                'approved' => Icon(Icons.check, size: 16, color: ghOpen),
                'changes_requested' =>
                  Icon(Icons.difference_outlined, size: 16, color: ghClosed),
                _ => Icon(Icons.circle, size: 9, color: AppColors.warning),
              },
              Row(children: [
                Avatar(u.avatarUrl, size: 20, login: u.login),
                const SizedBox(width: 8),
                Text(u.login,
                    style: TextStyle(
                        color: AppColors.text, fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                Text(
                    switch (s) {
                      'approved' => 'approved these changes',
                      'changes_requested' => 'requested changes',
                      _ => 'review pending',
                    },
                    style: TextStyle(color: AppColors.muted)),
              ]),
            ),
        ],
      ));
    }

    // ---- checks
    if (checks == null) {
      rows.add(_statusRow(_Mark.pending, 'Checking status',
          'Loading the checks on the latest commit...'));
    } else if (checks.isNotEmpty) {
      final summary = [
        if (failing > 0) '$failing failing',
        if (running > 0) '$running in progress',
        if (passed > 0) '$passed successful',
      ].join(', ');
      rows.add(_statusRow(
        failing > 0
            ? _Mark.fail
            : running > 0
                ? _Mark.pending
                : _Mark.ok,
        failing > 0
            ? 'Some checks were not successful'
            : running > 0
                ? 'Some checks haven\'t completed yet'
                : 'All checks have passed',
        failing == 0 && running == 0
            ? '$passed successful check${passed == 1 ? '' : 's'}'
            : '$summary check${checks.length == 1 ? '' : 's'}',
        open: _showChecks,
        toggle: () => setState(() => _showChecks = !_showChecks),
      ));
      if (_showChecks) {
        rows.add(Container(
          color: AppColors.bg,
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(children: [
            for (final c in checks)
              _detailLine(
                c.status != 'completed'
                    ? Icon(Icons.circle, size: 9, color: AppColors.warning)
                    : bad.contains(c.conclusion)
                        ? Icon(Icons.close, size: 16, color: ghClosed)
                        : Icon(
                            c.conclusion == 'skipped'
                                ? Icons.block
                                : Icons.check,
                            size: 16,
                            color: c.conclusion == 'skipped'
                                ? AppColors.muted
                                : ghOpen),
                Text.rich(TextSpan(children: [
                  TextSpan(
                      text: c.name,
                      style: TextStyle(
                          color: AppColors.text, fontWeight: FontWeight.w600)),
                  TextSpan(
                      text: '  ${c.status != 'completed' ? 'In progress' : _checkWord(c.conclusion)}',
                      style: TextStyle(color: AppColors.muted)),
                ])),
              ),
          ]),
        ));
      }
    }

    // ---- conflicts / draft / up to date
    if (draft) {
      rows.add(_statusRow(_Mark.neutral,
          'This pull request is still a work in progress',
          'Draft pull requests cannot be merged.',
          action: TextButton(
              onPressed: _busy ? null : () => _setDraft(false),
              child: const Text('Ready for review'))));
    } else if (checking) {
      rows.add(_statusRow(_Mark.pending,
          'Checking for the ability to merge automatically...',
          'Hang tight while GitHub checks this branch.'));
    } else if (conflicts) {
      rows.add(_statusRow(_Mark.fail,
          'This branch has conflicts that must be resolved',
          'Resolve them on github.com or locally, then push.'));
    } else {
      rows.add(_statusRow(_Mark.ok, 'No conflicts with base branch',
          'Merging can be performed automatically.'));
      if (state == 'behind') {
        rows.add(_statusRow(_Mark.neutral,
            'This branch is out-of-date with the base branch',
            'Merge the latest changes from ${p.baseRef} into this branch.',
            action: OutlinedButton(
                onPressed: _busy ? null : _updateBranch,
                child: const Text('Update branch'))));
      }
    }

    final mergeable = !draft && !checking && !conflicts;
    final allGood = mergeable && failing == 0 && changes == 0 && !reviewRequired;
    final tileColor = draft || !mergeable
        ? AppColors.muted
        : allGood
            ? ghOpen
            : AppColors.warning;

    rows.add(Container(
      color: AppColors.surfaceAlt.withOpacity(0.5),
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 14,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _mergeButton(enabled: mergeable && !_busy),
          if (state == 'blocked' && mergeable)
            Text('Requirements aren\'t met yet. As an admin GitHub may still '
                'let you merge.',
                style: TextStyle(color: AppColors.muted, fontSize: 13)),
        ],
      ),
    ));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: tileColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.merge, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: tileColor.withOpacity(0.7)),
                borderRadius: BorderRadius.circular(10),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < rows.length; i++) ...[
                    if (i > 0) Divider(height: 1, color: AppColors.border),
                    rows[i],
                  ],
                ],
              ),
            ),
          ),
        ]),
        if (!draft && p.nodeId.isNotEmpty)
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text('Still in progress?',
                    style: TextStyle(color: AppColors.muted, fontSize: 13)),
                TextButton(
                    onPressed: _busy ? null : () => _setDraft(true),
                    child: const Text('Convert to draft')),
              ]),
            ),
          ),
      ],
    );
  }

  static String _checkWord(String? c) => switch (c) {
        'success' => 'Successful',
        'failure' => 'Failing',
        'cancelled' => 'Cancelled',
        'skipped' => 'Skipped',
        'timed_out' => 'Timed out',
        'neutral' => 'Neutral',
        'action_required' => 'Action required',
        _ => c ?? '',
      };

  Widget _statusRow(_Mark mark, String title, String sub,
      {bool? open, VoidCallback? toggle, Widget? action}) {
    final (IconData icon, Color color) = switch (mark) {
      _Mark.ok => (Icons.check, ghOpen),
      _Mark.fail => (Icons.close, ghClosed),
      _Mark.pending => (Icons.more_horiz, AppColors.warning),
      _Mark.neutral => (Icons.priority_high, AppColors.muted),
    };
    return InkWell(
      onTap: toggle,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
        child: Row(children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: AppColors.text,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(sub,
                    style: TextStyle(color: AppColors.muted, fontSize: 13.5)),
              ],
            ),
          ),
          if (action != null) action,
          if (open != null)
            Icon(open ? Icons.expand_more : Icons.chevron_right,
                color: AppColors.muted),
        ]),
      ),
    );
  }

  /// A darker strip like GitHub's "1 pending review >", opening a list.
  Widget _expander(
      {required IconData icon,
      required String label,
      required bool open,
      required VoidCallback toggle,
      required List<Widget> children}) {
    return Container(
      color: AppColors.bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: toggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(children: [
                Icon(icon, size: 18, color: AppColors.muted),
                const SizedBox(width: 10),
                Text(label,
                    style: TextStyle(color: AppColors.text, fontSize: 13.5)),
                Icon(open ? Icons.expand_more : Icons.chevron_right,
                    size: 18, color: AppColors.muted),
              ]),
            ),
          ),
          if (open) ...[
            ...children,
            const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }

  Widget _detailLine(Widget icon, Widget body) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 6, 16, 6),
        child: Row(children: [
          SizedBox(width: 20, child: Center(child: icon)),
          const SizedBox(width: 12),
          Expanded(child: body),
        ]),
      );

  /// GitHub's green split button: merge, plus an arrow to pick the method.
  Widget _mergeButton({required bool enabled}) {
    final label = switch (_mergeMethod) {
      'squash' => 'Squash and merge',
      'rebase' => 'Rebase and merge',
      _ => 'Merge pull request',
    };
    final bg = enabled ? ghOpen : ghOpen.withOpacity(0.4);
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        InkWell(
          onTap: enabled ? _merge : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
            child: Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
          ),
        ),
        Container(width: 1, height: 40, color: Colors.black26),
        PopupMenuButton<String>(
          tooltip: 'Merge method',
          enabled: !_busy,
          onSelected: (v) => setState(() => _mergeMethod = v),
          itemBuilder: (_) => [
            for (final (v, t, d) in const [
              ('merge', 'Create a merge commit',
                  'All commits from this branch will be added to the base branch via a merge commit.'),
              ('squash', 'Squash and merge',
                  'The commits from this branch will be combined into one commit in the base branch.'),
              ('rebase', 'Rebase and merge',
                  'The commits from this branch will be rebased and added to the base branch.'),
            ])
              CheckedPopupMenuItem(
                value: v,
                checked: _mergeMethod == v,
                child: SizedBox(
                  width: 300,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(t,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text(d,
                          style: TextStyle(
                              color: AppColors.muted, fontSize: 12.5)),
                    ],
                  ),
                ),
              ),
          ],
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 9),
            child: Icon(Icons.arrow_drop_down, color: Colors.white),
          ),
        ),
      ]),
    );
  }
}

enum _Mark { ok, fail, pending, neutral }
