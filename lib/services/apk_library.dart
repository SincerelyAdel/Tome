import 'dart:io';
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../models/actions.dart';
import '../models/repo_item.dart';
import 'artifact_service.dart';
import 'github_service.dart';

enum ApkSource { release, artifact, repoFile, device }

/// One installable thing: a release asset, an Actions artifact (a zip that
/// may hold several APKs), an .apk committed in a repo, or an APK already
/// downloaded to this device.
class ApkEntry {
  ApkEntry({
    required this.source,
    required this.owner,
    required this.repo,
    required this.name,
    this.size = 0,
    this.date,
    this.detail = '',
    this.assetId,
    this.artifact,
    this.path,
    this.ref,
    this.file,
  });

  final ApkSource source;
  final String owner, repo, name;
  final int size;
  final DateTime? date;

  /// Release tag, workflow branch or file path, shown under the name.
  final String detail;

  final int? assetId; // release asset
  final Artifact? artifact; // Actions artifact
  final String? path, ref; // file in the repo
  final File? file; // already on this device

  String get repoName => '$owner/$repo';

  String get key => switch (source) {
        ApkSource.release => '$repoName/release/$assetId',
        ApkSource.artifact => '$repoName/artifact/${artifact!.id}',
        ApkSource.repoFile => '$repoName/file/$ref/$path',
        ApkSource.device => 'device/${file!.path}',
      };
}

/// Finds and downloads APKs across all the repos an account can see.
class ApkLibrary {
  ApkLibrary(this.github);

  final GitHubService github;
  final _dio = Dio();

  static final _apkArtifact = RegExp(r'apk|android', caseSensitive: false);

  /// Scans every repo, a few at a time, reporting each repo's APKs as it
  /// goes so the list fills in while scanning.
  Future<void> scan({
    required void Function(List<ApkEntry> found) onFound,
    required void Function(int done, int total) onProgress,
  }) async {
    final repos = await github.getMyRepos();
    var done = 0;
    onProgress(0, repos.length);
    for (var i = 0; i < repos.length; i += 6) {
      final batch = repos.skip(i).take(6);
      await Future.wait(batch.map((r) async {
        final found = await _scanRepo(r);
        done++;
        if (found.isNotEmpty) onFound(found);
        onProgress(done, repos.length);
      }));
    }
  }

  Future<List<ApkEntry>> _scanRepo(RepoInfo r) async {
    final out = <ApkEntry>[];
    final base = '/repos/${r.owner}/${r.name}';

    // Release assets.
    try {
      final releases = await github.api('$base/releases?per_page=10') as List;
      for (final rel in releases) {
        for (final a in (rel['assets'] as List? ?? const [])) {
          final name = a['name'] as String? ?? '';
          if (!ArtifactService.isApk(name)) continue;
          out.add(ApkEntry(
            source: ApkSource.release,
            owner: r.owner,
            repo: r.name,
            name: name,
            size: a['size'] ?? 0,
            date: DateTime.tryParse(a['updated_at'] ?? ''),
            detail: [
              rel['name']?.toString().isNotEmpty == true
                  ? rel['name']
                  : rel['tag_name'],
              if (rel['prerelease'] == true) 'pre-release',
              if (rel['draft'] == true) 'draft',
            ].join(' · '),
            assetId: a['id'],
          ));
        }
      }
    } catch (_) {}

    // Actions artifacts with "apk" or "android" in the name, newest of each.
    try {
      final data =
          await github.api('$base/actions/artifacts?per_page=50') as Map;
      final seen = <String>{};
      for (final a in (data['artifacts'] as List? ?? const [])) {
        final art = Artifact.fromJson(a);
        if (art.expired || !_apkArtifact.hasMatch(art.name)) continue;
        if (!seen.add(art.name)) continue;
        final run = a['workflow_run'] as Map?;
        out.add(ApkEntry(
          source: ApkSource.artifact,
          owner: r.owner,
          repo: r.name,
          name: art.name,
          size: art.sizeInBytes,
          date: DateTime.tryParse(a['created_at'] ?? ''),
          detail: run?['head_branch'] == null ? '' : 'on ${run!['head_branch']}',
          artifact: art,
        ));
      }
    } catch (_) {}

    // .apk files committed to the default branch.
    try {
      final tree = await github.api(
          '$base/git/trees/${Uri.encodeComponent(r.defaultBranch)}?recursive=1')
          as Map;
      for (final t in (tree['tree'] as List? ?? const [])) {
        final path = t['path'] as String? ?? '';
        if (t['type'] != 'blob' || !ArtifactService.isApk(path)) continue;
        out.add(ApkEntry(
          source: ApkSource.repoFile,
          owner: r.owner,
          repo: r.name,
          name: path.split('/').last,
          size: t['size'] ?? 0,
          date: r.updatedAt,
          detail: path,
          path: path,
          ref: r.defaultBranch,
        ));
      }
    } catch (_) {}
    return out;
  }

  // ------------------------------------------------------------ on device

  static Future<Directory> _root() async {
    final base = Platform.isAndroid
        ? (await getExternalStorageDirectory() ??
            await getApplicationDocumentsDirectory())
        : await getApplicationDocumentsDirectory();
    return base;
  }

  /// Where a release asset or repo file is saved. Artifacts keep using the
  /// Actions screen's folder so both screens see the same downloads.
  Future<File> localFile(ApkEntry e) async {
    final root = await _root();
    final folder = switch (e.source) {
      ApkSource.release => 'release-${e.assetId}',
      _ => 'file-${e.ref}-${e.path.hashCode.toUnsigned(32)}',
    };
    return File('${root.path}/apks/${e.owner}_${e.repo}/$folder/${e.name}');
  }

  /// Every APK this app has downloaded before, newest first.
  Future<List<ApkEntry>> onDevice() async {
    final root = await _root();
    final files = <File>[];
    for (final dir in ['apks', 'artifacts']) {
      final d = Directory('${root.path}/$dir');
      if (!await d.exists()) continue;
      await for (final f in d.list(recursive: true)) {
        if (f is File && ArtifactService.isApk(f.path)) files.add(f);
      }
    }
    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    return [
      for (final f in files)
        ApkEntry(
          source: ApkSource.device,
          owner: '',
          repo: '',
          name: f.uri.pathSegments.last,
          size: f.lengthSync(),
          date: f.lastModifiedSync(),
          detail: f.parent.path.split('/apks/').last.split('/artifacts/').last,
          file: f,
        ),
    ];
  }

  // ------------------------------------------------------------ downloads

  /// Downloads [e] and returns the APK files it holds (an artifact zip can
  /// hold several).
  Future<List<File>> download(ApkEntry e,
      {void Function(int received, int total)? onProgress}) async {
    switch (e.source) {
      case ApkSource.artifact:
        final files = await ArtifactService(github).downloadAndExtract(
            e.owner, e.repo, e.artifact!,
            onProgress: onProgress);
        return files.where((f) => ArtifactService.isApk(f.path)).toList();
      case ApkSource.release:
        return [
          await _fetch(
              '/repos/${e.owner}/${e.repo}/releases/assets/${e.assetId}',
              'application/octet-stream',
              await localFile(e),
              onProgress)
        ];
      case ApkSource.repoFile:
        final path = e.path!.split('/').map(Uri.encodeComponent).join('/');
        return [
          await _fetch(
              '/repos/${e.owner}/${e.repo}/contents/$path'
              '?ref=${Uri.encodeQueryComponent(e.ref!)}',
              'application/vnd.github.raw',
              await localFile(e),
              onProgress)
        ];
      case ApkSource.device:
        return [e.file!];
    }
  }

  /// GitHub often answers a download with a redirect to a signed storage
  /// URL; follow it without the token, which the storage host rejects.
  Future<File> _fetch(String apiPath, String accept, File out,
      void Function(int, int)? onProgress) async {
    await out.parent.create(recursive: true);
    final client = http.Client();
    try {
      final req = http.Request('GET', Uri.parse('https://api.github.com$apiPath'))
        ..followRedirects = false
        ..headers.addAll({
          'Accept': accept,
          if (github.hasToken) 'Authorization': 'token ${github.token}',
        });
      final res = await client.send(req);
      if (res.statusCode >= 300 && res.statusCode < 400) {
        final location = res.headers['location'];
        await res.stream.drain();
        if (location == null) throw Exception('GitHub gave no download link.');
        await _dio.download(location, out.path, onReceiveProgress: onProgress);
        return out;
      }
      if (res.statusCode != 200) {
        await res.stream.drain();
        throw Exception(res.statusCode == 404
            ? 'Not found, or this token can\'t read it.'
            : 'Download failed (${res.statusCode}).');
      }
      final total = res.contentLength ?? 0;
      var got = 0;
      final sink = out.openWrite();
      await for (final chunk in res.stream) {
        sink.add(chunk);
        got += chunk.length;
        onProgress?.call(got, total);
      }
      await sink.close();
      return out;
    } finally {
      client.close();
    }
  }
}
