class RepoItem {
  final String name;
  final String path;
  final String type; // 'file' or 'dir'
  final String? downloadUrl;
  final int? size;
  final String sha;

  RepoItem({
    required this.name,
    required this.path,
    required this.type,
    this.downloadUrl,
    this.size,
    required this.sha,
  });

  factory RepoItem.fromJson(Map<String, dynamic> json) {
    return RepoItem(
      name: json['name'] ?? '',
      path: json['path'] ?? '',
      type: json['type'] ?? 'file',
      downloadUrl: json['download_url'],
      size: json['size'],
      sha: json['sha'] ?? '',
    );
  }

  bool get isDirectory => type == 'dir';
  bool get isFile => type == 'file';

  String get extension {
    final parts = name.split('.');
    return parts.length > 1 ? parts.last.toLowerCase() : '';
  }
}

/// The repo that builds APKs for your other repos (see
/// github.com/SincerelyAdel/apk-builder). It's tooling rather than an app,
/// so repo lists always show it last.
const kApkBuilderRepoName = 'apk-builder';

extension AppRepoLast on List<RepoInfo> {
  /// The same repos with the APK builder repo (any owner, forks too) moved
  /// to the end. Everything else keeps its order.
  List<RepoInfo> withAppRepoLast() => [
        ...where((r) => !r.isAppRepo),
        ...where((r) => r.isAppRepo),
      ];
}

class RepoInfo {
  final String owner;
  final String name;
  final String fullName;
  final String description;
  final String defaultBranch;
  final int stars;
  final String language;
  final bool isPrivate;
  final bool isFork;
  final DateTime? updatedAt;

  RepoInfo({
    required this.owner,
    required this.name,
    required this.fullName,
    required this.description,
    required this.defaultBranch,
    required this.stars,
    required this.language,
    this.isPrivate = false,
    this.isFork = false,
    this.updatedAt,
  });

  factory RepoInfo.fromJson(Map<String, dynamic> json) {
    return RepoInfo(
      owner: json['owner']?['login'] ?? '',
      name: json['name'] ?? '',
      fullName: json['full_name'] ?? '',
      description: json['description'] ?? '',
      defaultBranch: json['default_branch'] ?? 'main',
      stars: json['stargazers_count'] ?? 0,
      language: json['language'] ?? '',
      isPrivate: json['private'] ?? false,
      isFork: json['fork'] ?? false,
      updatedAt: DateTime.tryParse(json['pushed_at'] ?? json['updated_at'] ?? ''),
    );
  }

  bool get isAppRepo => name.toLowerCase() == kApkBuilderRepoName;

  String get zipUrl =>
      'https://github.com/$fullName/archive/refs/heads/$defaultBranch.zip';
}
