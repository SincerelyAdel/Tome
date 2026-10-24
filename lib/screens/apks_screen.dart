import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import '../services/apk_library.dart';
import '../services/artifact_service.dart';
import '../services/github_org.dart';
import '../services/prefs_service.dart';
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

  // Repos and builds start collapsed; these hold the ones opened.
  final _openRepos = <String>{};
  final _openBuilds = <String>{};

  /// "owner/name" of the APK builder repo, or '' when not set up.
  String _builder = '';

  /// Whose repos are scanned (the account open on the home screen).
  String? _login;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
    if (widget.github.hasToken) {
      widget.github.getViewer().then((v) {
        if (mounted) setState(() => _login = v.login);
      }).catchError((_) {});
    }
    PrefsService.getBuilderRepo().then((b) {
      if (mounted) setState(() => _builder = b);
    });
    _scan();
  }

  /// Asks the builder repo to build [preset] (or a repo picked here).
  Future<void> _buildApk({String? preset}) async {
    if (_builder.isEmpty) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text('Set up an APK builder',
              style: TextStyle(color: AppColors.text)),
          content: Text(
              'Build APKs on demand from one builder repo, so your app repos '
              'spend no Actions minutes on pushes.\n\n'
              '1. Create a repo and copy tools/apk-builder/.github/workflows/'
              'build-apk.yml from the Tome repo into it.\n'
              '2. Add its secrets (see tools/apk-builder/README.md).\n'
              '3. Enter it in Settings under "APK builder repo".',
              style: TextStyle(color: AppColors.muted, height: 1.45)),
          actions: [
            FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK')),
          ],
        ),
      );
      return;
    }
    final names = _lib.repos.map((r) => r.fullName).toList()..sort();
    var repo = preset ?? '';
    final ref = TextEditingController();
    var abi = 'arm64';
    var runner = await PrefsService.getBuildRunner();
    if (!mounted) return;
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text('Build an APK', style: TextStyle(color: AppColors.text)),
          content: SizedBox(
            width: 460,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Autocomplete<String>(
                initialValue: TextEditingValue(text: repo),
                optionsBuilder: (v) => names.where((n) =>
                    n.toLowerCase().contains(v.text.trim().toLowerCase())),
                onSelected: (v) => setD(() => repo = v),
                fieldViewBuilder: (ctx, ctrl, focus, onDone) => TextField(
                  controller: ctrl,
                  focusNode: focus,
                  autofocus: preset == null,
                  autocorrect: false,
                  onChanged: (v) => setD(() => repo = v.trim()),
                  style: TextStyle(
                      color: AppColors.text, fontFamily: 'monospace'),
                  decoration: const InputDecoration(
                      labelText: 'Repo (owner/name)'),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ref,
                autocorrect: false,
                style: TextStyle(color: AppColors.text, fontFamily: 'monospace'),
                decoration: const InputDecoration(
                    labelText: 'Branch, tag or commit',
                    hintText: 'blank = default branch'),
              ),
              const SizedBox(height: 16),
              Row(children: [
                Text('Build for', style: TextStyle(color: AppColors.muted)),
                const SizedBox(width: 12),
                Expanded(
                  child: segmentChips(
                      ['arm64 (faster)', 'All CPU types'],
                      abi == 'arm64' ? 0 : 1,
                      (i) => setD(() => abi = i == 0 ? 'arm64' : 'all')),
                ),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Text('Run on', style: TextStyle(color: AppColors.muted)),
                const SizedBox(width: 12),
                Expanded(
                  child: segmentChips(
                      ['GitHub', 'My PC'],
                      runner == 'my-pc' ? 1 : 0,
                      (i) => setD(() => runner = i == 0 ? 'github' : 'my-pc')),
                ),
              ]),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                    runner == 'my-pc'
                        ? 'Fastest, no minutes used. Waits in the queue while '
                            'your PC is off or asleep.'
                        : "GitHub's machines. Free for a public builder repo.",
                    style: TextStyle(color: AppColors.faint, fontSize: 12.5)),
              ),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Cancel', style: TextStyle(color: AppColors.muted))),
            FilledButton(
                onPressed: RegExp(r'^[\w.-]+/[\w.-]+$').hasMatch(repo)
                    ? () => Navigator.pop(ctx, true)
                    : null,
                child: const Text('Start build')),
          ],
        ),
      ),
    );
    if (go != true || !mounted) return;
    PrefsService.setBuildRunner(runner);
    await runAction(
        context,
        () => widget.github
            .startApkBuild(_builder, repo, ref.text.trim(), abi, runner),
        done: 'Building $repo ${runner == 'my-pc' ? 'on your PC' : 'on GitHub'}. '
            'It shows up here when it finishes.');
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
          ? 'Allow Tome to install apps: Settings → Apps → Tome → '
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
    // Repo -> build -> APKs, keeping the scan order (most recently pushed
    // repo first, newest build first).
    final groups = <String, Map<String, List<ApkEntry>>>{};
    for (final e in shown) {
      groups
          .putIfAbsent(e.repoName, () => {})
          .putIfAbsent(e.group, () => [])
          .add(e);
    }
    // In "All", an Actions build that was also published as a release with
    // the same number is the same build twice: keep the release.
    if (_filter == 0) {
      for (final builds in groups.values) {
        final released = {
          for (final l in builds.values)
            if (l.first.source == ApkSource.release) l.first.groupTitle
        };
        builds.removeWhere((_, l) =>
            l.first.source == ApkSource.artifact &&
            released.contains(l.first.groupTitle));
      }
    }
    // While searching, open everything that matched.
    final searching = _search.text.trim().isNotEmpty;
    final width = MediaQuery.of(context).size.width;
    final hPad = width > 1340 ? (width - 1240) / 2 : 20.0;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        iconTheme: IconThemeData(color: AppColors.text),
        title: const Text('APKs'),
        actions: [
          TextButton.icon(
            onPressed: _buildApk,
            icon: Icon(Icons.build_outlined, size: 18, color: AppColors.accent),
            label: Text('Build APK', style: TextStyle(color: AppColors.accent)),
          ),
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
                'Every APK across ${_login == null ? 'your' : "$_login's"} '
                'repos: release downloads, Actions builds, and .apk files in '
                'the code. Swipe to the other account on the home screen to '
                'see its APKs.',
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
            const SizedBox(height: 16),
            for (final g in groups.entries)
              _repoSection(g.key, g.value, searching),
          ],
        ),
      ),
    );
  }

  /// A repo: a collapsed header that opens to its builds.
  Widget _repoSection(
      String repo, Map<String, List<ApkEntry>> builds, bool searching) {
    final open = searching || _openRepos.contains(repo);
    final apks = builds.values.fold<int>(0, (n, l) => n + l.length);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() {
              if (!_openRepos.remove(repo)) _openRepos.add(repo);
            }),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
              child: Row(children: [
                Icon(open ? Icons.expand_more : Icons.chevron_right,
                    color: AppColors.muted),
                const SizedBox(width: 8),
                Icon(Icons.book_outlined, size: 19, color: AppColors.accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(repo,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: AppColors.text,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w600)),
                ),
                Text(
                    '${builds.length} build${builds.length == 1 ? '' : 's'}'
                    ' · $apks APK${apks == 1 ? '' : 's'}',
                    style: TextStyle(color: AppColors.muted, fontSize: 13)),
                if (_builder.isNotEmpty && repo.contains('/') &&
                    repo != _builder) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Build a new APK',
                    icon: Icon(Icons.build_outlined,
                        size: 18, color: AppColors.accent),
                    onPressed: () => _buildApk(preset: repo),
                  ),
                ],
              ]),
            ),
          ),
          if (open)
            for (final b in _newestFirst(builds)) ...[
              Divider(height: 1, color: AppColors.border),
              _buildSection('$repo/${b.key}', b.value, searching),
            ],
        ],
      ),
    );
  }

  static List<MapEntry<String, List<ApkEntry>>> _newestFirst(
      Map<String, List<ApkEntry>> builds) {
    DateTime newest(List<ApkEntry> l) => l
        .map((e) => e.date ?? DateTime(0))
        .reduce((x, y) => x.isAfter(y) ? x : y);
    return builds.entries.toList()
      ..sort((x, y) => newest(y.value).compareTo(newest(x.value)));
  }

  /// One build ("Tome:14"): a collapsed row that opens to its APKs.
  Widget _buildSection(String key, List<ApkEntry> apks, bool searching) {
    final open = searching || _openBuilds.contains(key);
    final first = apks.first;
    final (String label, Color color) = switch (first.source) {
      ApkSource.release => ('Release', ghOpen),
      ApkSource.artifact => ('Actions', AppColors.accent),
      ApkSource.repoFile => ('In code', AppColors.muted),
      ApkSource.device => ('Downloaded', AppColors.success),
    };
    final total = apks.fold<int>(0, (n, e) => n + e.size);
    final count = first.source == ApkSource.artifact
        ? 'zip'
        : '${apks.length} APK${apks.length == 1 ? '' : 's'}';
    return Container(
      color: AppColors.bg.withOpacity(0.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() {
              if (!_openBuilds.remove(key)) _openBuilds.add(key);
            }),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(40, 12, 16, 12),
              child: Row(children: [
                Icon(open ? Icons.expand_more : Icons.chevron_right,
                    size: 20, color: AppColors.muted),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(first.groupTitle,
                          style: TextStyle(
                              color: AppColors.text,
                              fontFamily: 'monospace',
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 3),
                      Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          pill(label, color),
                          Text(
                              [
                                if (first.groupDetail.isNotEmpty)
                                  first.groupDetail,
                                count,
                                if (total > 0) _size(total),
                                if (first.date != null) timeAgo(first.date),
                              ].join(' · '),
                              style: TextStyle(
                                  color: AppColors.muted, fontSize: 12.5)),
                        ],
                      ),
                    ],
                  ),
                ),
              ]),
            ),
          ),
          if (open)
            Padding(
              padding: const EdgeInsets.fromLTRB(40, 0, 12, 12),
              child: rowsBox([for (final e in apks) _entry(e)]),
            ),
        ],
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
                      Text(
                          [
                            if (e.source == ApkSource.repoFile) e.detail,
                            if (e.size > 0) _size(e.size),
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
