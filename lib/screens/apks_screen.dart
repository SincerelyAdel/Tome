import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import '../services/apk_library.dart';
import '../services/artifact_service.dart';
import '../services/github_service.dart';
import '../services/share_service.dart';
import '../theme.dart';
import '../widgets/gh_widgets.dart';
import '../widgets/loader.dart';

/// Every APK across your repos in one place: release assets, Actions
/// artifacts, .apk files in the code, and ones already downloaded. Each can
/// be downloaded, installed, or sent to your phone or tablet.
class ApksScreen extends StatefulWidget {
  const ApksScreen({super.key, required this.github});

  final GitHubService github;

  @override
  State<ApksScreen> createState() => _ApksScreenState();
}

class _Download {
  double? progress;
  List<File>? files;
  String? error;
}

const _filters = ['All', 'Releases', 'Actions', 'In code', 'On this device'];

class _ApksScreenState extends State<ApksScreen> {
  late final _lib = ApkLibrary(widget.github);
  final _found = <ApkEntry>[];
  List<ApkEntry> _device = [];
  final _downloads = <String, _Download>{};
  final _search = TextEditingController();
  int _filter = 0;
  int _done = 0, _total = 0;
  bool _scanning = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
    _scan();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    setState(() {
      _found.clear();
      _scanning = true;
      _error = null;
      _done = _total = 0;
    });
    await _loadDevice();
    if (!widget.github.hasToken) {
      setState(() => _scanning = false);
      return;
    }
    try {
      await _lib.scan(
        onFound: (list) async {
          // Mark release assets and repo files that are already saved.
          for (final e in list) {
            if (e.source == ApkSource.release ||
                e.source == ApkSource.repoFile) {
              final f = await _lib.localFile(e);
              if (await f.exists()) {
                _downloads[e.key] = _Download()..files = [f];
              }
            }
          }
          if (mounted) setState(() => _found.addAll(list));
        },
        onProgress: (d, t) {
          if (mounted) {
            setState(() {
              _done = d;
              _total = t;
            });
          }
        },
      );
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
    if (mounted) setState(() => _scanning = false);
  }

  Future<void> _loadDevice() async {
    try {
      final d = await _lib.onDevice();
      if (mounted) setState(() => _device = d);
    } catch (_) {}
  }

  Future<void> _get(ApkEntry e) async {
    final d = _downloads[e.key] = _Download()..progress = 0;
    setState(() {});
    try {
      final files = await _lib.download(e, onProgress: (got, total) {
        if (mounted) setState(() => d.progress = total > 0 ? got / total : 0);
      });
      d.files = files;
      if (files.isEmpty) d.error = 'No APK inside this artifact.';
    } catch (e) {
      d.error = e.toString().replaceFirst('Exception: ', '');
    }
    d.progress = null;
    if (mounted) setState(() {});
    _loadDevice();
  }

  Future<void> _install(File f) async {
    final result = await ArtifactService(widget.github).open(f);
    if (!mounted || result.type == ResultType.done) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      duration: const Duration(seconds: 6),
      content: Text(result.type == ResultType.permissionDenied
          ? 'Allow RepoViewer to install apps: Settings → Apps → RepoViewer → '
              'Install unknown apps'
          : 'Could not open file: ${result.message}'),
    ));
  }

  Future<void> _send(File f) async {
    try {
      await ShareService.send(context, f);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not share: $e')));
      }
    }
  }

  // --------------------------------------------------------------- build

  List<ApkEntry> get _shown {
    final q = _search.text.trim().toLowerCase();
    final list = switch (_filter) {
      1 => _found.where((e) => e.source == ApkSource.release),
      2 => _found.where((e) => e.source == ApkSource.artifact),
      3 => _found.where((e) => e.source == ApkSource.repoFile),
      4 => _device,
      _ => _found,
    };
    return list
        .where((e) =>
            q.isEmpty ||
            e.name.toLowerCase().contains(q) ||
            e.repoName.toLowerCase().contains(q) ||
            e.detail.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final shown = _shown;
    // Group by repo, keeping the scan order (most recently pushed first).
    final groups = <String, List<ApkEntry>>{};
    for (final e in shown) {
      groups.putIfAbsent(_filter == 4 ? 'Downloaded' : e.repoName, () => []).add(e);
    }
    final width = MediaQuery.of(context).size.width;
    final hPad = width > 1340 ? (width - 1240) / 2 : 20.0;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        iconTheme: IconThemeData(color: AppColors.text),
        title: const Text('APKs'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: AppColors.muted),
            tooltip: 'Scan again',
            onPressed: _scanning ? null : _scan,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _scan,
        child: ListView(
          padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 40),
          children: [
            Text(
                'Every APK across your repos: release downloads, Actions '
                'builds, and .apk files in the code.',
                style: TextStyle(color: AppColors.muted, fontSize: 13.5)),
            const SizedBox(height: 14),
            TextField(
              controller: _search,
              style: TextStyle(color: AppColors.text, fontSize: 14),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Search APKs or repos...',
                hintStyle: TextStyle(color: AppColors.faint),
                prefixIcon: Icon(Icons.search, color: AppColors.muted, size: 20),
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
            ),
            const SizedBox(height: 12),
            segmentChips([
              for (var i = 0; i < _filters.length; i++)
                '${_filters[i]} ${_count(i)}',
            ], _filter, (i) => setState(() => _filter = i)),
            if (_scanning) ...[
              const SizedBox(height: 10),
              LinearProgressIndicator(
                  value: _total == 0 ? null : _done / _total,
                  minHeight: 3,
                  backgroundColor: AppColors.surfaceAlt),
              const SizedBox(height: 6),
              Text(
                  _total == 0
                      ? 'Finding your repos...'
                      : 'Checked $_done of $_total repos',
                  style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              errorPanel(_error!, onRetry: _scan),
            ],
            if (!widget.github.hasToken && _filter != 4)
              emptyNote('Add a GitHub token in Settings to find APKs in your '
                  'repos. Downloaded APKs are under "On this device".'),
            if (shown.isEmpty && !_scanning && widget.github.hasToken)
              emptyNote(_filter == 4
                  ? 'Nothing downloaded yet.'
                  : 'No APKs found. Actions artifacts count when their name '
                      'has "apk" or "android" in it.'),
            for (final g in groups.entries) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(2, 22, 0, 8),
                child: Text(g.key,
                    style: TextStyle(
                        color: AppColors.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
              ),
              rowsBox([for (final e in g.value) _entry(e)]),
            ],
          ],
        ),
      ),
    );
  }

  int _count(int filter) => switch (filter) {
        1 => _found.where((e) => e.source == ApkSource.release).length,
        2 => _found.where((e) => e.source == ApkSource.artifact).length,
        3 => _found.where((e) => e.source == ApkSource.repoFile).length,
        4 => _device.length,
        _ => _found.length,
      };

  Widget _entry(ApkEntry e) {
    final d = _downloads[e.key];
    final files = e.source == ApkSource.device ? [e.file!] : d?.files;
    final (String label, Color color) = switch (e.source) {
      ApkSource.release => ('Release', ghOpen),
      ApkSource.artifact => ('Actions', AppColors.accent),
      ApkSource.repoFile => ('In code', AppColors.muted),
      ApkSource.device => ('Downloaded', AppColors.success),
    };
    final single = files != null && files.length == 1 &&
        e.source != ApkSource.artifact;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: Row(children: [
            Icon(e.source == ApkSource.artifact
                    ? Icons.inventory_2_outlined
                    : Icons.android,
                color: e.source == ApkSource.artifact
                    ? AppColors.muted
                    : AppColors.success),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.name,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: AppColors.text,
                          fontFamily: 'monospace',
                          fontSize: 13.5)),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      pill(label, color),
                      Text(
                          [
                            if (e.detail.isNotEmpty) e.detail,
                            if (e.size > 0) _size(e.size),
                            if (e.date != null) timeAgo(e.date),
                            if (single &&
                                ArtifactService.matchesDevice(e.name))
                              'for this device',
                          ].join(' · '),
                          style: TextStyle(
                              color: AppColors.muted, fontSize: 12.5)),
                    ],
                  ),
                ],
              ),
            ),
            if (d?.progress != null)
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                    value: (d!.progress ?? 0) > 0 ? d.progress : null,
                    strokeWidth: 3),
              )
            else if (single)
              ..._fileActions(files.first)
            else if (e.source != ApkSource.device)
              FilledButton.icon(
                onPressed: () => _get(e),
                icon: const Icon(Icons.download, size: 18),
                label: Text(files == null ? 'Get' : 'Again'),
              ),
          ]),
        ),
        if (d?.error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(54, 0, 16, 12),
            child: Text(d!.error!, style: TextStyle(color: AppColors.danger)),
          ),
        // An artifact can hold several APKs (one per CPU type).
        if (!single && files != null && files.isNotEmpty)
          for (final f in files)
            Padding(
              padding: const EdgeInsets.fromLTRB(54, 0, 12, 8),
              child: Row(children: [
                Icon(Icons.android, size: 18, color: AppColors.success),
                const SizedBox(width: 10),
                Expanded(
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(
                          text: f.uri.pathSegments.last,
                          style: TextStyle(
                              color: AppColors.text,
                              fontFamily: 'monospace',
                              fontSize: 12.5)),
                      TextSpan(
                          text: '  ${_size(f.lengthSync())}'
                              '${ArtifactService.matchesDevice(f.path) ? ' · for this device' : ''}',
                          style: TextStyle(
                              color: AppColors.muted, fontSize: 12)),
                    ]),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                ..._fileActions(f),
              ]),
            ),
      ],
    );
  }

  List<Widget> _fileActions(File f) => [
        TextButton.icon(
          onPressed: () => _send(f),
          icon: Icon(
              ShareService.isTablet(context)
                  ? Icons.phone_android
                  : Icons.tablet_android,
              size: 17,
              color: AppColors.accent),
          label: Text(ShareService.sendLabel(context),
              style: TextStyle(color: AppColors.accent)),
        ),
        TextButton(
          onPressed: () => _install(f),
          child: Text('Install', style: TextStyle(color: AppColors.success)),
        ),
      ];

  static String _size(int bytes) {
    if (bytes >= 1 << 20) return '${(bytes / (1 << 20)).toStringAsFixed(1)} MB';
    if (bytes >= 1 << 10) return '${(bytes / (1 << 10)).toStringAsFixed(0)} KB';
    return '$bytes B';
  }
}
