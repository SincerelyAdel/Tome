import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter/services.dart';

/// Hands uvm-debugger runs from Actions artifacts to the UVM viewer app.
///
/// Tome does the GitHub side (token, download, unzip). The viewer only
/// receives a zipped run folder. The handoff goes by file type, not by the
/// viewer's package name, so renaming the viewer doesn't break it. The full
/// contract is docs/GITHUB_HANDOFF.md in the uvm-debugger repo.
class UvmRuns {
  UvmRuns._();

  /// What the button calls the viewer. The only place its name appears.
  static const viewerName = 'Cauldron';

  /// The file type the viewer accepts (ACTION_VIEW).
  static const mime = 'application/vnd.uvmdbg.run+zip';

  /// Artifact names that hold runs start with this.
  static const artifactPrefix = 'uvmdbg';

  static const _channel = MethodChannel('tome/share');

  static bool isRunArtifact(String name) =>
      name.toLowerCase().startsWith(artifactPrefix);

  /// Every run folder in an extracted artifact: each folder holding a
  /// run.json. One artifact may carry several runs.
  static List<Directory> findRuns(List<File> files) {
    final dirs = <String, Directory>{};
    for (final f in files) {
      if (f.uri.pathSegments.last == 'run.json') {
        dirs[f.parent.path] = f.parent;
      }
    }
    final list = dirs.values.toList()..sort((a, b) => a.path.compareTo(b.path));
    return list;
  }

  /// The run's id: run.json's `run_id`, else its folder name.
  static String runId(Directory dir) =>
      _manifest(dir)['run_id']?.toString() ??
      dir.uri.pathSegments.where((s) => s.isNotEmpty).last;

  /// A one-line summary from run.json: test, seed and how it ended.
  static String summary(Directory dir) {
    final m = _manifest(dir);
    return [
      if (m['test'] != null) '${m['test']}',
      if (m['seed'] != null) 'seed ${m['seed']}',
      if (m['elab_only'] == true) 'elaboration only',
      if (m['status'] != null) '${m['status']}',
    ].join(' · ');
  }

  /// run.json, or empty when it's missing or not valid JSON.
  static Map<String, dynamic> _manifest(Directory dir) {
    try {
      final j = jsonDecode(File('${dir.path}/run.json').readAsStringSync());
      return j is Map<String, dynamic> ? j : const {};
    } catch (_) {
      return const {};
    }
  }

  /// Zips one run folder (its files at the zip root) next to it.
  static Future<File> pack(Directory dir) async {
    final safe = runId(dir).replaceAll(RegExp(r'[^\w.-]'), '_');
    final zip = File('${dir.parent.path}/$safe.uvmdbg.zip');
    if (await zip.exists()) await zip.delete();
    final enc = ZipFileEncoder()..create(zip.path);
    await enc.addDirectory(dir, includeDirName: false);
    await enc.close();
    return zip;
  }

  /// Packs [dir] and opens it in the viewer. [source] says where the run
  /// came from (repo, Actions run, commit) for the viewer to show. Throws
  /// [UvmViewerMissing] when no installed app accepts runs.
  static Future<void> open(Directory dir, Map<String, String> source) async {
    final zip = await pack(dir);
    try {
      await _channel.invokeMethod('openRun', {
        'path': zip.path,
        'mime': mime,
        'extras': source,
      });
    } on PlatformException catch (e) {
      if (e.code == 'no_viewer') throw const UvmViewerMissing();
      rethrow;
    }
  }
}

class UvmViewerMissing implements Exception {
  const UvmViewerMissing();

  @override
  String toString() =>
      '${UvmRuns.viewerName} isn\'t installed, or it is too old to accept runs. '
      'Install it from the APKs page.';
}
