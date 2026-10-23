import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import '../models/actions.dart';
import 'github_service.dart';

/// Downloads a workflow artifact, unzips it and opens files from it
/// (for an .apk that launches the Android installer).
class ArtifactService {
  final GitHubService github;
  final Dio _dio = Dio();

  ArtifactService(this.github);

  /// Downloads and extracts [artifact]. Returns the extracted files,
  /// APKs first.
  Future<List<File>> downloadAndExtract(
    String owner,
    String repo,
    Artifact artifact, {
    void Function(int received, int total)? onProgress,
  }) async {
    final url =
        await github.getArtifactDownloadUrl(owner, repo, artifact.id);

    final base = Platform.isAndroid
        ? (await getExternalStorageDirectory() ??
            await getApplicationDocumentsDirectory())
        : await getApplicationDocumentsDirectory();
    final outDir = Directory('${base.path}/artifacts/${artifact.id}');
    if (await outDir.exists()) await outDir.delete(recursive: true);
    await outDir.create(recursive: true);

    final zipPath = '${outDir.path}/${artifact.name}.zip';
    // The signed URL carries its own auth, so no headers are sent here.
    await _dio.download(url, zipPath, onReceiveProgress: onProgress);

    final filesDir = '${outDir.path}/files';
    await extractFileToDisk(zipPath, filesDir);
    await File(zipPath).delete();

    final files = Directory(filesDir)
        .listSync(recursive: true)
        .whereType<File>()
        .toList();
    files.sort((a, b) {
      final aApk = isApk(a.path), bApk = isApk(b.path);
      if (aApk != bApk) return aApk ? -1 : 1;
      return a.path.compareTo(b.path);
    });
    return files;
  }

  Future<OpenResult> open(File file) {
    return OpenFilex.open(
      file.path,
      type: isApk(file.path) ? 'application/vnd.android.package-archive' : null,
    );
  }

  static bool isApk(String path) => path.toLowerCase().endsWith('.apk');

  /// The CPU type of this device, e.g. "arm64", read from the Dart VM.
  static String? get deviceAbi {
    final match = RegExp(r'android_(\w+)').firstMatch(Platform.version);
    return match?.group(1);
  }

  /// True if [apkName] is a split APK built for this device's CPU,
  /// or a universal APK.
  static bool matchesDevice(String apkName) {
    final name = apkName.toLowerCase();
    final abi = deviceAbi;
    const splits = ['arm64-v8a', 'armeabi-v7a', 'x86_64'];
    if (!splits.any(name.contains)) return true; // universal APK
    switch (abi) {
      case 'arm64':
        return name.contains('arm64-v8a');
      case 'arm':
        return name.contains('armeabi-v7a');
      case 'x64':
        return name.contains('x86_64');
      default:
        return false;
    }
  }
}
