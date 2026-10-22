import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:flutter_highlight/themes/github.dart';
import 'package:open_filex/open_filex.dart';
import '../models/actions.dart';
import '../services/artifact_service.dart';
import '../services/github_service.dart';
import '../theme.dart';
import '../widgets/gh_widgets.dart';
import '../widgets/job_log.dart';
import 'repo_tabs/commit_detail_screen.dart';
import '../models/github_models.dart';

/// GitHub Actions for a repo, like github.com's Actions tab: workflows on
/// the left, runs on the right. More runs load as the list scrolls.
class ActionsScreen extends StatefulWidget {
  final String owner;
  final String repo;
  final GitHubService github;

  const ActionsScreen({
    super.key,
    required this.owner,
    required this.repo,
    required this.github,
  });

  @override
  State<ActionsScreen> createState() => _ActionsScreenState();
}

class _ActionsScreenState extends State<ActionsScreen> {
  static const _pageSize = 30;

  List<Workflow> _workflows = [];
  Workflow? _workflow; // null = all workflows
  List<WorkflowRun>? _runs;
  String? _error;
  int _page = 1;
  bool _hasMore = true;
  bool _loadingMore = false;
  Timer? _poll;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 600) _loadMore();
    });
    widget.github.getWorkflows(widget.owner, widget.repo).then((w) {
      if (mounted) setState(() => _workflows = w);
    }).catchError((_) {});
    _load();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final wf = _workflow;
    setState(() => _error = null);
    try {
      final runs = await widget.github.getWorkflowRuns(
          widget.owner, widget.repo,
          perPage: _pageSize, workflowId: wf?.id);
      if (!mounted || wf != _workflow) return;
      setState(() {
        _runs = runs;
        _page = 1;
        _hasMore = runs.length == _pageSize;
      });
      // Keep refreshing while something is still building.
      _poll?.cancel();
      if (runs.any((r) => r.isRunning)) {
        _poll = Timer(const Duration(seconds: 15), _load);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<void> _loadMore() async {
    final runs = _runs;
    if (runs == null || !_hasMore || _loadingMore) return;
    final wf = _workflow;
    setState(() => _loadingMore = true);
    try {
      final next = await widget.github.getWorkflowRuns(
          widget.owner, widget.repo,
          perPage: _pageSize, page: _page + 1, workflowId: wf?.id);
      if (!mounted || wf != _workflow || runs != _runs) return;
      final seen = runs.map((r) => r.id).toSet();
      setState(() {
        _runs = [...runs, ...next.where((r) => !seen.contains(r.id))];
        _page++;
        _hasMore = next.length == _pageSize;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _pick(Workflow? w) {
    if (w == _workflow) return;
    setState(() {
      _workflow = w;
      _runs = null;
    });
    _load();
  }

  void _open(WorkflowRun run) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RunDetailScreen(
          owner: widget.owner,
          repo: widget.repo,
          github: widget.github,
          run: run,
        ),
      ),
    ).then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width > 900;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        iconTheme: IconThemeData(color: AppColors.text),
        title: Text('Actions · ${widget.repo}'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: AppColors.muted),
            tooltip: 'Refresh',
            onPressed: _load,
          ),
        ],
      ),
      body: wide
          ? Row(children: [
              SizedBox(width: 270, child: _sidebar()),
              VerticalDivider(width: 1, color: AppColors.border),
              Expanded(child: _runList()),
            ])
          : Column(children: [
              if (_workflows.isNotEmpty) _chips(),
              Expanded(child: _runList()),
            ]),
    );
  }

  Widget _sidebar() {
    Widget item(Workflow? w) {
      final active = w == _workflow;
      return _NavItem(
        icon: w == null ? Icons.play_circle_outline : Icons.account_tree_outlined,
        label: w?.name ?? 'All workflows',
        active: active,
        onTap: () => _pick(w),
        trailing: w != null && w.state != 'active'
            ? Icon(Icons.pause_circle_outline, size: 15, color: AppColors.faint)
            : null,
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
      children: [
        item(null),
        if (_workflows.isNotEmpty) _sideHeading('Workflows'),
        ..._workflows.map(item),
      ],
    );
  }

  Widget _chips() {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
        children: [null, ..._workflows].map((w) {
          final active = w == _workflow;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(w?.name ?? 'All workflows'),
              selected: active,
              onSelected: (_) => _pick(w),
              labelStyle: TextStyle(
                  color: active ? AppColors.onAccent : AppColors.text,
                  fontSize: 13),
              selectedColor: AppColors.accent,
              backgroundColor: AppColors.surface,
              side: BorderSide(color: AppColors.border),
              showCheckmark: false,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _runList() {
    final runs = _runs;
    if (runs == null) return tabMessage(error: _error, onRetry: _load);
    final title = _workflow?.name ?? 'All workflows';
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
        itemCount: runs.length + 2,
        itemBuilder: (context, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontFamily: kSerif,
                          color: AppColors.text,
                          fontSize: 24,
                          fontWeight: FontWeight.w500)),
                  if (_workflow != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(_workflow!.path,
                          style: TextStyle(
                              color: AppColors.muted,
                              fontFamily: 'monospace',
                              fontSize: 12.5)),
                    ),
                ],
              ),
            );
          }
          if (i == runs.length + 1) {
            if (runs.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                    child: Text('No workflow runs yet',
                        style: TextStyle(color: AppColors.muted))),
              );
            }
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: _hasMore
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5))
                    : Text('${runs.length} workflow runs',
                        style:
                            TextStyle(color: AppColors.faint, fontSize: 12.5)),
              ),
            );
          }
          return _runRow(runs[i - 1], first: i == 1, last: i == runs.length);
        },
      ),
    );
  }

  Widget _runRow(WorkflowRun r, {required bool first, required bool last}) {
    final radius = BorderRadius.vertical(
      top: first ? const Radius.circular(10) : Radius.zero,
      bottom: last ? const Radius.circular(10) : Radius.zero,
    );
    final muted = TextStyle(color: AppColors.muted, fontSize: 12.5);
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: AppColors.border, width: 0.5),
      ),
      child: InkWell(
        borderRadius: radius,
        onTap: () => _open(r),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: StatusIcon(status: r.status, conclusion: r.conclusion),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: AppColors.text,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 5),
                  Text.rich(
                    TextSpan(children: [
                      TextSpan(
                          text: '${r.name} #${r.runNumber}: ',
                          style: TextStyle(
                              color: AppColors.muted,
                              fontWeight: FontWeight.w600)),
                      ..._trigger(r, muted),
                    ]),
                    style: muted,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              branchChip(r.branch),
              const SizedBox(height: 6),
              Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.calendar_today_outlined,
                    size: 13, color: AppColors.muted),
                const SizedBox(width: 4),
                Text(timeAgo(r.createdAt), style: muted),
                const SizedBox(width: 10),
                Icon(Icons.timer_outlined, size: 14, color: AppColors.muted),
                const SizedBox(width: 3),
                Text(formatDuration(r.duration), style: muted),
              ]),
            ]),
          ]),
        ),
      ),
    );
  }
}

/// "Commit abc1234 pushed by octocat", "Manually run by octocat" ...
List<InlineSpan> _trigger(WorkflowRun r, TextStyle style) {
  final who = r.actorLogin.isEmpty
      ? <InlineSpan>[]
      : [
          const TextSpan(text: ' by '),
          userSpan(r.actorLogin,
              style: style.copyWith(fontWeight: FontWeight.w600)),
        ];
  final mono = TextStyle(fontFamily: 'monospace', color: AppColors.muted);
  switch (r.event) {
    case 'push':
      return [
        const TextSpan(text: 'Commit '),
        TextSpan(text: r.shortSha, style: mono),
        const TextSpan(text: ' pushed'),
        ...who,
      ];
    case 'pull_request':
    case 'pull_request_target':
      return [const TextSpan(text: 'Pull request run'), ...who];
    case 'workflow_dispatch':
      return [const TextSpan(text: 'Manually run'), ...who];
    case 'schedule':
      return [const TextSpan(text: 'Scheduled')];
    case 'release':
      return [const TextSpan(text: 'Release'), ...who];
    default:
      return [TextSpan(text: r.event.replaceAll('_', ' ')), ...who];
  }
}

// ===================================================================== run

/// One workflow run, like its page on github.com: a summary with the jobs,
/// annotations and artifacts; each job's steps with their full logs; the
/// run's usage; and the workflow file it ran.
class RunDetailScreen extends StatefulWidget {
  final String owner;
  final String repo;
  final GitHubService github;
  final WorkflowRun run;

  const RunDetailScreen({
    super.key,
    required this.owner,
    required this.repo,
    required this.github,
    required this.run,
  });

  @override
  State<RunDetailScreen> createState() => _RunDetailScreenState();
}

class _ArtifactState {
  double? progress; // null when not downloading
  List<File>? files;
  String? error;
}

/// What the run page is showing.
const _summary = -1, _usage = -2, _workflowFile = -3;

class _RunDetailScreenState extends State<RunDetailScreen> {
  late final ArtifactService _service = ArtifactService(widget.github);
  late WorkflowRun _run = widget.run;
  int _view = _summary; // or a job index

  List<WorkflowJob>? _jobs;
  String? _jobsError;
  List<Artifact>? _artifacts;
  String? _artifactsError;
  final Map<int, _ArtifactState> _state = {};
  final Map<int, List<CheckAnnotation>> _annotations = {};
  RunTiming? _timing;
  String? _workflowSource;
  String? _workflowError;
  Timer? _poll;

  // Logs per job id.
  final Map<int, List<List<LogLine>>> _logs = {};
  final Map<int, String> _rawLogs = {};
  final Map<int, String> _logErrors = {};
  final Set<int> _logLoading = {};
  final Map<int, Set<int>> _openSteps = {};
  final Set<String> _openGroups = {};
  final _search = TextEditingController();

  GitHubService get _gh => widget.github;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
    _refresh();
    _loadArtifacts();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _search.dispose();
    super.dispose();
  }

  String _msg(Object e) => e.toString().replaceFirst('Exception: ', '');

  Future<void> _refresh() async {
    _poll?.cancel();
    try {
      final run = await _gh.getRun(widget.owner, widget.repo, _run.id);
      if (mounted) setState(() => _run = run);
    } catch (_) {/* keep what we have */}
    await _loadJobs();
    if (!mounted) return;
    if (_run.isRunning) {
      _poll = Timer(const Duration(seconds: 10), _refresh);
    } else {
      _gh.getRunTiming(widget.owner, widget.repo, _run.id).then((t) {
        if (mounted) setState(() => _timing = t);
      }).catchError((_) {});
    }
  }

  Future<void> _loadJobs() async {
    try {
      final jobs = await _gh.getRunJobs(widget.owner, widget.repo, _run.id);
      if (!mounted) return;
      setState(() {
        _jobs = jobs;
        _jobsError = null;
      });
      for (final j in jobs) {
        if (!j.isRunning && !_annotations.containsKey(j.id)) {
          _gh.getAnnotations(widget.owner, widget.repo, j.id).then((a) {
            if (mounted) setState(() => _annotations[j.id] = a);
          }).catchError((_) {});
        }
      }
      // A finished job that was open while running: fetch its log now.
      if (_view >= 0 && _view < jobs.length) _loadLog(jobs[_view]);
    } catch (e) {
      if (mounted) setState(() => _jobsError = _msg(e));
    }
  }

  Future<void> _loadArtifacts() async {
    setState(() => _artifactsError = null);
    try {
      final a = await _gh.getRunArtifacts(widget.owner, widget.repo, _run.id);
      if (mounted) setState(() => _artifacts = a);
    } catch (e) {
      if (mounted) setState(() => _artifactsError = _msg(e));
    }
  }

  Future<void> _loadLog(WorkflowJob job, {bool force = false}) async {
    if (job.isRunning || _logLoading.contains(job.id)) return;
    if (!force && _logs.containsKey(job.id)) return;
    setState(() {
      _logLoading.add(job.id);
      _logErrors.remove(job.id);
    });
    try {
      final raw = await _gh.getJobLog(widget.owner, widget.repo, job.id);
      final parsed = splitLogBySteps(raw, job.steps);
      if (!mounted) return;
      setState(() {
        _rawLogs[job.id] = raw;
        _logs[job.id] = parsed;
        // Open failed steps, like GitHub does.
        _openSteps.putIfAbsent(job.id, () => {
              for (var i = 0; i < job.steps.length; i++)
                if (job.steps[i].conclusion == 'failure') i
            });
      });
    } catch (e) {
      if (mounted) setState(() => _logErrors[job.id] = _msg(e));
    } finally {
      if (mounted) setState(() => _logLoading.remove(job.id));
    }
  }

  Future<void> _loadWorkflowFile() async {
    if (_workflowSource != null || _run.path.isEmpty) return;
    setState(() => _workflowError = null);
    try {
      final src = await _gh.getFileContent(widget.owner, widget.repo, _run.path,
          ref: _run.headSha);
      if (mounted) setState(() => _workflowSource = src);
    } catch (e) {
      if (mounted) setState(() => _workflowError = _msg(e));
    }
  }

  void _show(int view) {
    setState(() => _view = view);
    final jobs = _jobs;
    if (view >= 0 && jobs != null && view < jobs.length) _loadLog(jobs[view]);
    if (view == _workflowFile) _loadWorkflowFile();
  }

  // ------------------------------------------------------------ artifacts

  Future<void> _download(Artifact artifact) async {
    final s = _state.putIfAbsent(artifact.id, () => _ArtifactState());
    setState(() {
      s.progress = 0;
      s.error = null;
      s.files = null;
    });
    try {
      final files = await _service.downloadAndExtract(
        widget.owner,
        widget.repo,
        artifact,
        onProgress: (received, total) {
          if (!mounted) return;
          setState(() => s.progress = total > 0 ? received / total : 0);
        },
      );
      if (!mounted) return;
      setState(() {
        s.progress = null;
        s.files = files;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        s.progress = null;
        s.error = _msg(e);
      });
    }
  }

  Future<void> _openFile(File file) async {
    final result = await _service.open(file);
    if (!mounted || result.type == ResultType.done) return;
    final msg = result.type == ResultType.permissionDenied
        ? 'Allow RepoViewer to install apps: Settings → Apps → RepoViewer → '
            'Install unknown apps'
        : 'Could not open file: ${result.message}';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 6)),
    );
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width > 900;
    final run = _run;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        iconTheme: IconThemeData(color: AppColors.text),
        titleSpacing: 0,
        title: Row(children: [
          StatusIcon(status: run.status, conclusion: run.conclusion, size: 22),
          const SizedBox(width: 10),
          Flexible(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: run.title),
                TextSpan(
                    text: '  #${run.runNumber}',
                    style: TextStyle(color: AppColors.muted)),
              ]),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ]),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: AppColors.muted),
            tooltip: 'Refresh',
            onPressed: () {
              _refresh();
              _loadArtifacts();
              final jobs = _jobs;
              if (_view >= 0 && jobs != null && _view < jobs.length) {
                _loadLog(jobs[_view], force: true);
              }
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: wide
          ? Row(children: [
              SizedBox(width: 280, child: _sidebar()),
              VerticalDivider(width: 1, color: AppColors.border),
              Expanded(child: _content()),
            ])
          : Column(children: [
              _chips(),
              Expanded(child: _content()),
            ]),
    );
  }

  Widget _sidebar() {
    final jobs = _jobs ?? [];
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
      children: [
        _NavItem(
          icon: Icons.home_outlined,
          label: 'Summary',
          active: _view == _summary,
          onTap: () => _show(_summary),
        ),
        _sideHeading('Jobs'),
        if (_jobs == null && _jobsError == null)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Center(
                child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))),
          ),
        if (_jobsError != null)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(_jobsError!,
                style: TextStyle(color: AppColors.danger, fontSize: 12.5)),
          ),
        for (var i = 0; i < jobs.length; i++)
          _NavItem(
            leading: StatusIcon(
                status: jobs[i].status,
                conclusion: jobs[i].conclusion,
                size: 17),
            label: jobs[i].name,
            active: _view == i,
            onTap: () => _show(i),
            trailing: Text(formatDuration(jobs[i].duration),
                style: TextStyle(color: AppColors.faint, fontSize: 12)),
          ),
        _sideHeading('Run details'),
        _NavItem(
          icon: Icons.timer_outlined,
          label: 'Usage',
          active: _view == _usage,
          onTap: () => _show(_usage),
        ),
        _NavItem(
          icon: Icons.description_outlined,
          label: 'Workflow file',
          active: _view == _workflowFile,
          onTap: () => _show(_workflowFile),
        ),
      ],
    );
  }

  Widget _chips() {
    final jobs = _jobs ?? [];
    final items = <(int, String)>[
      (_summary, 'Summary'),
      for (var i = 0; i < jobs.length; i++) (i, jobs[i].name),
      (_usage, 'Usage'),
      (_workflowFile, 'Workflow file'),
    ];
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
        children: items.map((it) {
          final active = it.$1 == _view;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(it.$2),
              selected: active,
              onSelected: (_) => _show(it.$1),
              labelStyle: TextStyle(
                  color: active ? AppColors.onAccent : AppColors.text,
                  fontSize: 13),
              selectedColor: AppColors.accent,
              backgroundColor: AppColors.surface,
              side: BorderSide(color: AppColors.border),
              showCheckmark: false,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _content() {
    final jobs = _jobs;
    if (_view >= 0) {
      if (jobs == null || _view >= jobs.length) {
        return tabMessage(error: _jobsError, onRetry: _refresh);
      }
      return _jobView(jobs[_view]);
    }
    final children = switch (_view) {
      _usage => _usageView(),
      _workflowFile => _workflowView(),
      _ => _summaryView(),
    };
    return RefreshIndicator(
      onRefresh: () async {
        await _refresh();
        await _loadArtifacts();
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 48),
        children: children,
      ),
    );
  }

  // -------------------------------------------------------------- summary

  List<Widget> _summaryView() {
    final run = _run;
    final label = TextStyle(color: AppColors.muted, fontSize: 12.5);
    final big = TextStyle(
        color: AppColors.text, fontSize: 18, fontWeight: FontWeight.w600);
    Widget cell(String title, Widget value) => Padding(
          padding: const EdgeInsets.only(right: 40, bottom: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: label),
              const SizedBox(height: 6),
              value,
            ],
          ),
        );
    final artifacts = _artifacts;
    final annotations = [
      for (final j in _jobs ?? <WorkflowJob>[])
        for (final a in _annotations[j.id] ?? <CheckAnnotation>[]) (j, a)
    ];
    final errors = annotations.where((a) => a.$2.level == 'failure').length;
    final warnings = annotations.where((a) => a.$2.level == 'warning').length;

    return [
      // Trigger, status, duration, artifacts.
      _box(
        padding: const EdgeInsets.all(20),
        child: Wrap(
          runSpacing: 16,
          children: [
            cell(
              'Triggered via ${run.event.replaceAll('_', ' ')} '
                  '${timeAgo(run.createdAt)}',
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (run.actorLogin.isNotEmpty) ...[
                    Avatar(run.actorAvatar, size: 20, login: run.actorLogin),
                    UserName(run.actorLogin,
                        style: TextStyle(
                            color: AppColors.text,
                            fontWeight: FontWeight.w600,
                            fontSize: 14)),
                  ],
                  Text(run.event == 'push' ? 'pushed' : 'ran',
                      style: TextStyle(color: AppColors.muted, fontSize: 14)),
                  InkWell(
                    onTap: _openCommit,
                    child: Text(run.shortSha,
                        style: TextStyle(
                            fontFamily: 'monospace',
                            color: AppColors.accent,
                            fontSize: 14)),
                  ),
                  branchChip(run.branch),
                ],
              ),
            ),
            cell('Status', Text(statusLabel(run.status, run.conclusion), style: big)),
            cell('Total duration', Text(formatDuration(run.duration), style: big)),
            cell('Artifacts',
                Text(artifacts == null ? '–' : '${artifacts.length}', style: big)),
            if (run.runAttempt > 1)
              cell('Attempt', Text('#${run.runAttempt}', style: big)),
          ],
        ),
      ),
      if (run.commitMessage.isNotEmpty) ...[
        const SizedBox(height: 16),
        _box(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.commit, size: 18, color: AppColors.muted),
            const SizedBox(width: 10),
            Expanded(
              child: SelectableText(run.commitMessage,
                  style: TextStyle(
                      color: AppColors.text, fontSize: 13.5, height: 1.45)),
            ),
          ]),
        ),
      ],
      const SizedBox(height: 24),
      // The jobs, as boxes like GitHub's workflow graph.
      _box(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(run.path.isEmpty ? run.name : run.path.split('/').last,
                style: TextStyle(
                    color: AppColors.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
            Text('on: ${run.event}', style: label),
            const SizedBox(height: 16),
            if (_jobs == null)
              tabMessage(error: _jobsError, onRetry: _refresh)
            else if (_jobs!.isEmpty)
              Text('No jobs', style: label)
            else
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (var i = 0; i < _jobs!.length; i++) _jobBox(i, _jobs![i]),
                ],
              ),
          ],
        ),
      ),
      if (annotations.isNotEmpty) ...[
        const SizedBox(height: 24),
        _sectionTitle('Annotations',
            '${errors > 0 ? '$errors error${errors == 1 ? '' : 's'}' : ''}'
            '${errors > 0 && warnings > 0 ? ' and ' : ''}'
            '${warnings > 0 ? '$warnings warning${warnings == 1 ? '' : 's'}' : ''}'),
        _box(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < annotations.length; i++)
                _annotation(annotations[i].$1, annotations[i].$2,
                    last: i == annotations.length - 1),
            ],
          ),
        ),
      ],
      const SizedBox(height: 24),
      _sectionTitle('Artifacts', 'Produced during runtime'),
      if (!_gh.hasToken)
        _note('GitHub only lets signed-in users download artifacts. Add a '
            'GitHub token in Settings to download them here.'),
      ..._artifactSection(),
    ];
  }

  void _openCommit() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CommitDetailScreen(
          owner: widget.owner,
          repo: widget.repo,
          github: _gh,
          summary: GhCommit(
            sha: _run.headSha,
            message: _run.commitMessage,
            authorName: _run.commitAuthor,
          ),
        ),
      ),
    );
  }

  Widget _jobBox(int i, WorkflowJob j) {
    return Material(
      color: AppColors.surfaceAlt,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _show(i),
        child: Container(
          width: 250,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(children: [
            StatusIcon(status: j.status, conclusion: j.conclusion, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(j.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppColors.text, fontSize: 13.5)),
            ),
            const SizedBox(width: 8),
            Text(formatDuration(j.duration),
                style: TextStyle(color: AppColors.muted, fontSize: 12)),
          ]),
        ),
      ),
    );
  }

  Widget _annotation(WorkflowJob job, CheckAnnotation a, {required bool last}) {
    final (IconData icon, Color color) = switch (a.level) {
      'failure' => (Icons.cancel_outlined, AppColors.danger),
      'warning' => (Icons.warning_amber_rounded, AppColors.warning),
      _ => (Icons.info_outline, AppColors.accent),
    };
    final where = a.path.isEmpty || a.path == '.github'
        ? ''
        : '${a.path}${a.startLine > 0 ? '#L${a.startLine}' : ''}';
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        border: last
            ? null
            : Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () => _show(_jobs!.indexOf(job)),
                child: Text(
                    a.title.isEmpty ? job.name : '${job.name}: ${a.title}',
                    style: TextStyle(
                        color: AppColors.text,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 4),
              SelectableText(a.message,
                  style: TextStyle(
                      color: AppColors.muted,
                      fontFamily: 'monospace',
                      fontSize: 12.5,
                      height: 1.45)),
              if (where.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(where,
                    style: TextStyle(
                        color: AppColors.faint,
                        fontFamily: 'monospace',
                        fontSize: 12)),
              ],
            ],
          ),
        ),
      ]),
    );
  }

  List<Widget> _artifactSection() {
    if (_artifactsError != null) {
      return [tabMessage(error: _artifactsError, onRetry: _loadArtifacts)];
    }
    final artifacts = _artifacts;
    if (artifacts == null) {
      return [
        const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        )
      ];
    }
    if (artifacts.isEmpty) {
      return [
        Text(
          _run.isRunning
              ? 'Still running. Artifacts appear when the run finishes.'
              : 'This run has no artifacts.',
          style: TextStyle(color: AppColors.muted),
        )
      ];
    }
    return artifacts.map(_artifactCard).toList();
  }

  Widget _artifactCard(Artifact a) {
    final s = _state[a.id];
    final downloading = s?.progress != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            leading: Icon(Icons.inventory_2_outlined, color: AppColors.muted),
            title: Text(a.name,
                style: TextStyle(color: AppColors.text, fontFamily: 'monospace')),
            subtitle: Text(
              [
                a.expired ? 'Expired' : _size(a.sizeInBytes),
                if (!a.expired && a.expiresAt != null)
                  'expires ${_inDays(a.expiresAt!)}',
              ].join(' · '),
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            trailing: a.expired
                ? null
                : downloading
                    ? SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          value: (s!.progress ?? 0) > 0 ? s.progress : null,
                          strokeWidth: 3,
                        ),
                      )
                    : FilledButton.icon(
                        style: FilledButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            foregroundColor: AppColors.onAccent),
                        onPressed: _gh.hasToken ? () => _download(a) : null,
                        icon: const Icon(Icons.download, size: 18),
                        label: Text(s?.files != null ? 'Again' : 'Get'),
                      ),
          ),
          if (s?.error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(s!.error!, style: TextStyle(color: AppColors.danger)),
            ),
          if (s?.files != null) ...[
            Divider(height: 1, color: AppColors.border),
            ...s!.files!.map(_fileRow),
          ],
        ],
      ),
    );
  }

  Widget _fileRow(File f) {
    final name = f.uri.pathSegments.last;
    final apk = ArtifactService.isApk(name);
    final recommended = apk && ArtifactService.matchesDevice(name);
    return ListTile(
      dense: true,
      leading: Icon(apk ? Icons.android : Icons.insert_drive_file,
          color: apk ? AppColors.success : AppColors.muted),
      title: Text(name,
          style: TextStyle(
              color: AppColors.text, fontFamily: 'monospace', fontSize: 12)),
      subtitle: Text(
        [_size(f.lengthSync()), if (recommended) 'for this device'].join(' · '),
        style: TextStyle(
            color: recommended ? AppColors.success : AppColors.muted,
            fontSize: 11),
      ),
      trailing: TextButton(
        onPressed: () => _openFile(f),
        child: Text(apk ? 'Install' : 'Open',
            style: TextStyle(
                color: apk ? AppColors.success : AppColors.accent)),
      ),
    );
  }

  // ------------------------------------------------------------------ job

  Widget _jobView(WorkflowJob job) {
    final logs = _logs[job.id];
    final q = _search.text.trim().toLowerCase();
    final open = _openSteps.putIfAbsent(job.id, () => {});

    // Flatten steps and their visible lines into one lazy list.
    final rows = <Widget Function()>[];
    for (var s = 0; s < job.steps.length; s++) {
      final step = job.steps[s];
      final lines = logs == null || s >= logs.length ? <LogLine>[] : logs[s];
      final matches = q.isEmpty
          ? lines
          : lines.where((l) => l.text.toLowerCase().contains(q)).toList();
      if (q.isNotEmpty && matches.isEmpty) continue;
      final expanded = q.isNotEmpty || open.contains(s);
      rows.add(() => _stepHeader(job, s, step, expanded, lines.isNotEmpty));
      if (!expanded) continue;
      if (logs == null) {
        rows.add(() => _logNote(job));
        continue;
      }
      if (lines.isEmpty) {
        rows.add(() => _plainNote(step.conclusion == 'skipped'
            ? 'This step was skipped.'
            : 'No output.'));
        continue;
      }
      for (final l in matches) {
        if (q.isEmpty &&
            l.group != null &&
            !_openGroups.contains('${job.id}:$s:${l.group}')) {
          continue; // folded inside a closed group
        }
        rows.add(() => _logLine(job, s, l));
      }
    }

    return Column(children: [
      _jobHeader(job),
      Expanded(
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          decoration: BoxDecoration(
            color: AppColors.isDark
                ? const Color(0xFF0A0A0A)
                : const Color(0xFFF6F8FA),
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(10),
          ),
          clipBehavior: Clip.antiAlias,
          child: RefreshIndicator(
            onRefresh: () async {
              await _refresh();
              await _loadLog(job, force: true);
            },
            child: Scrollbar(
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: rows.length,
                itemBuilder: (_, i) => rows[i](),
              ),
            ),
          ),
        ),
      ),
    ]);
  }

  Widget _jobHeader(WorkflowJob job) {
    final raw = _rawLogs[job.id];
    final when = job.isRunning
        ? 'started ${timeAgo(job.startedAt)}'
        : '${statusLabel(job.status, job.conclusion)} '
            '${timeAgo(job.completedAt)} in ${formatDuration(job.duration)}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(job.name,
                  style: TextStyle(
                      fontFamily: kSerif,
                      color: AppColors.text,
                      fontSize: 21,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 3),
              Text(
                  [
                    when,
                    if (job.runnerName.isNotEmpty) 'runner ${job.runnerName}',
                    if (job.labels.isNotEmpty) job.labels.join(', '),
                  ].join('  ·  '),
                  style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
            ],
          ),
        ),
        SizedBox(
          width: 220,
          child: TextField(
            controller: _search,
            style: TextStyle(color: AppColors.text, fontSize: 13.5),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Search logs',
              hintStyle: TextStyle(color: AppColors.faint),
              prefixIcon: Icon(Icons.search, size: 18, color: AppColors.muted),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.border),
              ),
            ),
          ),
        ),
        IconButton(
          icon: Icon(Icons.unfold_more, color: AppColors.muted),
          tooltip: 'Expand all steps',
          onPressed: () => setState(() => _openSteps[job.id] = {
                for (var i = 0; i < job.steps.length; i++) i
              }),
        ),
        IconButton(
          icon: Icon(Icons.unfold_less, color: AppColors.muted),
          tooltip: 'Collapse all steps',
          onPressed: () => setState(() => _openSteps[job.id] = {}),
        ),
        IconButton(
          icon: Icon(Icons.copy, color: AppColors.muted),
          tooltip: 'Copy full log',
          onPressed: raw == null
              ? null
              : () {
                  Clipboard.setData(ClipboardData(text: raw));
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Log copied')));
                },
        ),
      ]),
    );
  }

  Widget _stepHeader(
      WorkflowJob job, int s, JobStep step, bool expanded, bool hasLines) {
    return InkWell(
      onTap: () => setState(() {
        final open = _openSteps.putIfAbsent(job.id, () => {});
        if (!open.remove(s)) open.add(s);
      }),
      child: Container(
        color: expanded ? AppColors.surface.withOpacity(0.6) : null,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(children: [
          Icon(expanded ? Icons.expand_more : Icons.chevron_right,
              size: 20, color: AppColors.muted),
          const SizedBox(width: 6),
          StatusIcon(status: step.status, conclusion: step.conclusion, size: 17),
          const SizedBox(width: 10),
          Expanded(
            child: Text(step.name,
                style: TextStyle(
                    color: step.conclusion == 'skipped'
                        ? AppColors.faint
                        : AppColors.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w500)),
          ),
          Text(formatDuration(step.duration),
              style: TextStyle(color: AppColors.faint, fontSize: 12.5)),
        ]),
      ),
    );
  }

  Widget _logLine(WorkflowJob job, int s, LogLine l) {
    final dark = AppColors.isDark;
    final isGroup = l.kind == LogKind.group;
    final groupKey = '${job.id}:$s:${l.number}';
    final groupOpen = _openGroups.contains(groupKey);
    final color = logKindColor(l.kind);
    final text = Text.rich(
      TextSpan(children: [
        if (isGroup)
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Icon(groupOpen ? Icons.arrow_drop_down : Icons.arrow_right,
                size: 18, color: AppColors.muted),
          ),
        ...ansiSpans(l.text, dark: dark),
      ]),
      style: TextStyle(
        fontFamily: 'monospace',
        fontSize: 12.5,
        height: 1.5,
        color: color ?? AppColors.text,
        fontWeight: isGroup ? FontWeight.w600 : null,
      ),
    );
    final row = Container(
      color: switch (l.kind) {
        LogKind.error => AppColors.danger.withOpacity(dark ? 0.12 : 0.08),
        LogKind.warning => AppColors.warning.withOpacity(dark ? 0.10 : 0.08),
        _ => null,
      },
      padding: EdgeInsets.only(left: l.group != null ? 18 : 0, right: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 58,
          child: Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Text('${l.number}',
                textAlign: TextAlign.right,
                style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    height: 1.56,
                    color: AppColors.faint)),
          ),
        ),
        Expanded(child: text),
      ]),
    );
    if (!isGroup) return row;
    return InkWell(
      onTap: () => setState(() {
        if (!_openGroups.remove(groupKey)) _openGroups.add(groupKey);
      }),
      child: row,
    );
  }

  Widget _logNote(WorkflowJob job) {
    if (job.isRunning) {
      return _plainNote('This job is still running. Its log appears when '
          'it finishes; the page refreshes on its own.');
    }
    if (_logLoading.contains(job.id)) {
      return const Padding(
        padding: EdgeInsets.all(14),
        child: Center(
            child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }
    final err = _logErrors[job.id];
    if (err != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(46, 6, 16, 10),
        child: Row(children: [
          Expanded(
              child: Text(err,
                  style: TextStyle(color: AppColors.danger, fontSize: 13))),
          TextButton(
              onPressed: () => _loadLog(job, force: true),
              child: const Text('Retry')),
        ]),
      );
    }
    return _plainNote('No output.');
  }

  Widget _plainNote(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(46, 6, 16, 10),
        child: Text(text,
            style: TextStyle(color: AppColors.muted, fontSize: 13)),
      );

  // ---------------------------------------------------------------- usage

  List<Widget> _usageView() {
    final run = _run;
    final t = _timing;
    final jobs = _jobs ?? [];
    final big = TextStyle(
        color: AppColors.text, fontSize: 18, fontWeight: FontWeight.w600);
    final label = TextStyle(color: AppColors.muted, fontSize: 12.5);
    return [
      Text('Usage',
          style: TextStyle(
              fontFamily: kSerif, color: AppColors.text, fontSize: 24)),
      const SizedBox(height: 16),
      _box(
        padding: const EdgeInsets.all(20),
        child: Wrap(spacing: 48, runSpacing: 16, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Run time', style: label),
            const SizedBox(height: 6),
            Text(formatDuration(t?.runDuration ?? run.duration), style: big),
          ]),
          if (t != null)
            for (final e in t.billable.entries)
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Billable · ${e.key}', style: label),
                const SizedBox(height: 6),
                Text(
                    '${formatDuration(e.value.total)}  '
                    '(${e.value.jobs} job${e.value.jobs == 1 ? '' : 's'})',
                    style: big),
              ]),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Started', style: label),
            const SizedBox(height: 6),
            Text(_stamp(run.runStartedAt ?? run.createdAt), style: big),
          ]),
        ]),
      ),
      const SizedBox(height: 24),
      _sectionTitle('Jobs', ''),
      _box(
        child: Column(children: [
          for (var i = 0; i < jobs.length; i++)
            InkWell(
              onTap: () => _show(i),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  border: i == jobs.length - 1
                      ? null
                      : Border(bottom: BorderSide(color: AppColors.border)),
                ),
                child: Row(children: [
                  StatusIcon(
                      status: jobs[i].status,
                      conclusion: jobs[i].conclusion,
                      size: 17),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(jobs[i].name,
                          style: TextStyle(
                              color: AppColors.text, fontSize: 14))),
                  Text(
                      jobs[i].labels.isEmpty ? '' : jobs[i].labels.first,
                      style: label),
                  const SizedBox(width: 20),
                  SizedBox(
                    width: 80,
                    child: Text(formatDuration(jobs[i].duration),
                        textAlign: TextAlign.right,
                        style: TextStyle(color: AppColors.text, fontSize: 13.5)),
                  ),
                ]),
              ),
            ),
        ]),
      ),
    ];
  }

  // -------------------------------------------------------- workflow file

  List<Widget> _workflowView() {
    final src = _workflowSource;
    return [
      Text(_run.path.isEmpty ? 'Workflow file' : _run.path,
          style: TextStyle(
              color: AppColors.text, fontFamily: 'monospace', fontSize: 15)),
      const SizedBox(height: 4),
      Text('at ${_run.shortSha}',
          style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
      const SizedBox(height: 14),
      if (_run.path.isEmpty)
        Text('GitHub didn’t say which file this run used.',
            style: TextStyle(color: AppColors.muted))
      else if (src == null)
        tabMessage(error: _workflowError, onRetry: _loadWorkflowFile)
      else
        _box(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: HighlightView(
              src,
              language: 'yaml',
              theme: {
                ..._codeTheme,
                'root': _codeTheme['root']!.copyWith(
                    backgroundColor: Colors.transparent,
                    color: AppColors.text),
              },
              padding: const EdgeInsets.all(18),
              textStyle: const TextStyle(
                  fontFamily: 'monospace', fontSize: 13.5, height: 1.5),
            ),
          ),
        ),
    ];
  }

  // -------------------------------------------------------------- helpers

  Widget _box({required Widget child, EdgeInsets? padding}) => Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(10),
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      );

  Widget _sectionTitle(String title, String sub) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(title,
              style: TextStyle(
                  color: AppColors.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          const SizedBox(width: 10),
          Text(sub, style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
        ]),
      );

  Widget _note(String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warningBg,
        border: Border.all(color: AppColors.warning.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: TextStyle(color: AppColors.text, fontSize: 13)),
    );
  }
}

Map<String, TextStyle> get _codeTheme =>
    AppColors.isDark ? atomOneDarkTheme : githubTheme;

// ================================================================ shared

/// A row in the Actions sidebars.
class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.active,
    required this.onTap,
    this.icon,
    this.leading,
    this.trailing,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;
  final IconData? icon;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: active ? AppColors.surfaceAlt : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border(
                left: BorderSide(
                    color: active ? AppColors.accent : Colors.transparent,
                    width: 3),
              ),
            ),
            child: Row(children: [
              leading ??
                  Icon(icon, size: 18,
                      color: active ? AppColors.text : AppColors.muted),
              const SizedBox(width: 10),
              Expanded(
                child: Text(label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: AppColors.text,
                        fontSize: 13.5,
                        fontWeight: active ? FontWeight.w600 : FontWeight.w400)),
              ),
              if (trailing != null) ...[const SizedBox(width: 6), trailing!],
            ]),
          ),
        ),
      ),
    );
  }
}

Widget _sideHeading(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(10, 18, 10, 8),
      child: Text(text,
          style: TextStyle(
              color: AppColors.muted,
              fontSize: 12.5,
              fontWeight: FontWeight.w600)),
    );

/// A branch name in a small rounded chip.
Widget branchChip(String name) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.accent.withOpacity(AppColors.isDark ? 0.14 : 0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(name,
          style: TextStyle(
              color: AppColors.accent, fontFamily: 'monospace', fontSize: 12)),
    );

/// The status icon GitHub uses for runs, jobs and steps.
class StatusIcon extends StatelessWidget {
  const StatusIcon(
      {super.key, required this.status, this.conclusion, this.size = 20});

  final String status;
  final String? conclusion;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (status == 'in_progress') {
      return SizedBox(
        width: size,
        height: size,
        child: Padding(
          padding: EdgeInsets.all(size * 0.12),
          child: CircularProgressIndicator(
              strokeWidth: size / 8, color: AppColors.warning),
        ),
      );
    }
    if (status != 'completed') {
      return Icon(Icons.schedule, color: AppColors.warning, size: size);
    }
    return switch (conclusion) {
      'success' => Icon(Icons.check_circle, color: ghOpen, size: size),
      'failure' || 'timed_out' || 'startup_failure' =>
        Icon(Icons.cancel, color: ghClosed, size: size),
      'cancelled' => Icon(Icons.block, color: AppColors.muted, size: size),
      'skipped' =>
        Icon(Icons.do_not_disturb_on_outlined, color: AppColors.faint, size: size),
      'action_required' =>
        Icon(Icons.error_outline, color: AppColors.warning, size: size),
      _ => Icon(Icons.remove_circle_outline, color: AppColors.muted, size: size),
    };
  }
}

/// "succeeded", "failed", "in progress" ...
String statusLabel(String status, String? conclusion) {
  if (status != 'completed') return status.replaceAll('_', ' ');
  return switch (conclusion) {
    'success' => 'Success',
    'failure' => 'Failure',
    'cancelled' => 'Cancelled',
    'skipped' => 'Skipped',
    'timed_out' => 'Timed out',
    'startup_failure' => 'Startup failure',
    'action_required' => 'Action required',
    null => 'Completed',
    final c => c.replaceAll('_', ' '),
  };
}

/// "1h 3m", "2m 5s", "41s".
String formatDuration(Duration? d) {
  if (d == null) return '';
  if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes % 60}m';
  if (d.inMinutes > 0) return '${d.inMinutes}m ${d.inSeconds % 60}s';
  return '${d.inSeconds}s';
}

String _stamp(DateTime t) {
  final l = t.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${l.year}-${two(l.month)}-${two(l.day)} ${two(l.hour)}:${two(l.minute)}';
}

String _inDays(DateTime t) {
  final d = t.difference(DateTime.now());
  if (d.isNegative) return 'soon';
  if (d.inDays >= 1) return 'in ${d.inDays} day${d.inDays == 1 ? '' : 's'}';
  return 'in ${d.inHours}h';
}

String _size(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
