import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import '../models/actions.dart';
import '../services/artifact_service.dart';
import '../services/github_service.dart';
import '../theme.dart';

const _bg = AppColors.bg;
const _surface = AppColors.surface;
const _border = AppColors.border;
const _text = AppColors.text;
const _muted = AppColors.muted;
const _blue = AppColors.accent;
const _green = AppColors.success;
const _red = AppColors.danger;
const _yellow = AppColors.warning;

/// Lists recent GitHub Actions runs for a repo.
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
  List<WorkflowRun> _runs = [];
  bool _loading = true;
  String? _error;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final runs =
          await widget.github.getWorkflowRuns(widget.owner, widget.repo);
      if (!mounted) return;
      setState(() {
        _runs = runs;
        _loading = false;
        _error = null;
      });
      // Keep refreshing while something is still building.
      _poll?.cancel();
      if (runs.any((r) => r.isRunning)) {
        _poll = Timer(const Duration(seconds: 15), _load);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        iconTheme: const IconThemeData(color: _text),
        title: const Text('Actions', style: TextStyle(color: _text)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () {
              setState(() => _loading = true);
              _load();
            },
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading && _runs.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _runs.isEmpty) {
      return _ErrorView(message: _error!, onRetry: _load);
    }
    if (_runs.isEmpty) {
      return const Center(
        child: Text('No workflow runs yet', style: TextStyle(color: _muted)),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        itemCount: _runs.length,
        separatorBuilder: (_, __) =>
            const Divider(height: 1, color: _border),
        itemBuilder: (context, i) {
          final run = _runs[i];
          return ListTile(
            leading: RunStatusIcon(run: run),
            title: Text(
              run.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _text, fontSize: 14),
            ),
            subtitle: Text(
              '${run.name} #${run.runNumber} · ${run.branch} · '
              '${_ago(run.createdAt)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _muted, fontSize: 12),
            ),
            trailing: const Icon(Icons.chevron_right, color: _muted),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => RunDetailScreen(
                  owner: widget.owner,
                  repo: widget.repo,
                  github: widget.github,
                  run: run,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Shows a run's artifacts and lets the user download and install them.
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

class _RunDetailScreenState extends State<RunDetailScreen> {
  late final ArtifactService _service = ArtifactService(widget.github);
  List<Artifact>? _artifacts;
  String? _error;
  final Map<int, _ArtifactState> _state = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final artifacts = await widget.github
          .getRunArtifacts(widget.owner, widget.repo, widget.run.id);
      if (mounted) setState(() => _artifacts = artifacts);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

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
          setState(() {
            s.progress = total > 0 ? received / total : 0;
          });
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
        s.error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _open(File file) async {
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

  @override
  Widget build(BuildContext context) {
    final run = widget.run;
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        iconTheme: const IconThemeData(color: _text),
        title: Text('${run.name} #${run.runNumber}',
            style: const TextStyle(color: _text, fontSize: 16)),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _summaryCard(run),
            const SizedBox(height: 20),
            const Text('Artifacts',
                style: TextStyle(
                    color: _text, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (!widget.github.hasToken)
              _note(
                'GitHub only lets signed-in users download artifacts. Add a '
                'GitHub token in Settings to download them here.',
              ),
            ..._artifactSection(),
          ],
        ),
      ),
    );
  }

  List<Widget> _artifactSection() {
    if (_error != null) {
      return [_ErrorView(message: _error!, onRetry: _load)];
    }
    if (_artifacts == null) {
      return [
        const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        )
      ];
    }
    if (_artifacts!.isEmpty) {
      return [
        Text(
          widget.run.isRunning
              ? 'Still running. Artifacts appear when the run finishes.'
              : 'This run has no artifacts.',
          style: const TextStyle(color: _muted),
        )
      ];
    }
    return _artifacts!.map(_artifactCard).toList();
  }

  Widget _summaryCard(WorkflowRun run) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RunStatusIcon(run: run, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(run.title,
                    style: const TextStyle(color: _text, fontSize: 15)),
                const SizedBox(height: 6),
                Text(
                  '${_statusLabel(run)} · ${run.branch} · ${run.shortSha}\n'
                  '${run.event} · ${_ago(run.createdAt)}',
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _artifactCard(Artifact a) {
    final s = _state[a.id];
    final downloading = s?.progress != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _surface,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            leading: const Icon(Icons.inventory_2_outlined, color: _muted),
            title: Text(a.name,
                style: const TextStyle(color: _text, fontFamily: 'monospace')),
            subtitle: Text(
              a.expired ? 'Expired' : _size(a.sizeInBytes),
              style: const TextStyle(color: _muted, fontSize: 12),
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
                            backgroundColor: AppColors.accent),
                        onPressed: widget.github.hasToken
                            ? () => _download(a)
                            : null,
                        icon: const Icon(Icons.download, size: 18),
                        label: Text(s?.files != null ? 'Again' : 'Get'),
                      ),
          ),
          if (s?.error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(s!.error!, style: const TextStyle(color: _red)),
            ),
          if (s?.files != null) ...[
            const Divider(height: 1, color: _border),
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
          color: apk ? _green : _muted),
      title: Text(name,
          style: const TextStyle(
              color: _text, fontFamily: 'monospace', fontSize: 12)),
      subtitle: Text(
        [
          _size(f.lengthSync()),
          if (recommended) 'for this device',
        ].join(' · '),
        style: TextStyle(
            color: recommended ? _green : _muted, fontSize: 11),
      ),
      trailing: TextButton(
        onPressed: () => _open(f),
        child: Text(apk ? 'Install' : 'Open',
            style: TextStyle(color: apk ? _green : _blue)),
      ),
    );
  }

  Widget _note(String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warningBg,
        border: Border.all(color: _yellow.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: const TextStyle(color: _text, fontSize: 13)),
    );
  }
}

class RunStatusIcon extends StatelessWidget {
  final WorkflowRun run;
  final double size;
  const RunStatusIcon({super.key, required this.run, this.size = 22});

  @override
  Widget build(BuildContext context) {
    if (run.isRunning) {
      return SizedBox(
        width: size,
        height: size,
        child: const Padding(
          padding: EdgeInsets.all(3),
          child: CircularProgressIndicator(strokeWidth: 2.5, color: _yellow),
        ),
      );
    }
    switch (run.conclusion) {
      case 'success':
        return Icon(Icons.check_circle, color: _green, size: size);
      case 'failure':
      case 'timed_out':
        return Icon(Icons.cancel, color: _red, size: size);
      default:
        return Icon(Icons.remove_circle_outline, color: _muted, size: size);
    }
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: _red, size: 40),
            const SizedBox(height: 8),
            Text(message,
                style: const TextStyle(color: _red),
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

String _statusLabel(WorkflowRun run) {
  if (run.isRunning) return run.status.replaceAll('_', ' ');
  return run.conclusion ?? run.status;
}

String _ago(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'just now';
  if (d.inHours < 1) return '${d.inMinutes}m ago';
  if (d.inDays < 1) return '${d.inHours}h ago';
  return '${d.inDays}d ago';
}

String _size(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
