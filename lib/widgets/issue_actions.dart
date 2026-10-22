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
  });

  final String owner;
  final String repo;
  final GitHubService github;
  final GhIssue issue;
  final GhPullDetail? pull;
  final VoidCallback onChanged;

  @override
  State<IssueActions> createState() => _IssueActionsState();
}

class _IssueActionsState extends State<IssueActions> {
  final _text = TextEditingController();
  bool _busy = false;
  String _mergeMethod = 'merge';

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
        if (canMerge) ...[_mergeBox(p), const SizedBox(height: 16)],
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
                        backgroundColor: AppColors.accent,
                        foregroundColor: AppColors.onAccent),
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

  Widget _mergeBox(GhPullDetail? p) {
    final state = p?.mergeableState ?? 'unknown';
    final blocked = state == 'dirty' || state == 'draft';
    final (String title, String sub, Color color) = switch (state) {
      'clean' || 'has_hooks' => (
          'This branch has no conflicts with the base branch',
          'Merging can be performed automatically.',
          ghOpen
        ),
      'dirty' => (
          'This branch has conflicts that must be resolved',
          'Resolve them on github.com or locally first.',
          ghClosed
        ),
      'blocked' => (
          'Merging is blocked',
          'Required reviews or checks are missing. As an admin GitHub may '
              'still let you merge.',
          ghClosed
        ),
      'unstable' => (
          'Some checks were not successful',
          'You can still merge.',
          AppColors.warning
        ),
      'behind' => (
          'This branch is out-of-date with the base branch',
          'It can still be merged.',
          AppColors.warning
        ),
      'draft' => (
          'This pull request is still a draft',
          'Mark it ready for review on github.com before merging.',
          ghDraft
        ),
      _ => (
          'Merge status is still being checked',
          'Refresh in a moment for the latest state.',
          AppColors.muted
        ),
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: color.withOpacity(0.6)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.merge, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: AppColors.text,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600)),
                  Text(sub,
                      style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              DropdownButton<String>(
                value: _mergeMethod,
                dropdownColor: AppColors.surface,
                style: TextStyle(color: AppColors.text, fontSize: 14),
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(
                      value: 'merge', child: Text('Create a merge commit')),
                  DropdownMenuItem(
                      value: 'squash', child: Text('Squash and merge')),
                  DropdownMenuItem(
                      value: 'rebase', child: Text('Rebase and merge')),
                ],
                onChanged: (v) => setState(() => _mergeMethod = v!),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                    backgroundColor: ghOpen, foregroundColor: Colors.white),
                onPressed: _busy || blocked ? null : _merge,
                icon: const Icon(Icons.merge, size: 18),
                label: const Text('Merge pull request'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
