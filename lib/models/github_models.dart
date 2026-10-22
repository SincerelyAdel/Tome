/// Issues, pull requests, commits and branches from the GitHub API.

class GhUser {
  final String login;
  final String avatarUrl;

  const GhUser({required this.login, required this.avatarUrl});

  factory GhUser.fromJson(Map<String, dynamic>? json) => GhUser(
        login: json?['login'] ?? 'ghost',
        avatarUrl: json?['avatar_url'] ?? '',
      );
}

class GhLabel {
  final String name;
  final String color; // hex without '#'

  const GhLabel({required this.name, required this.color});

  factory GhLabel.fromJson(Map<String, dynamic> json) =>
      GhLabel(name: json['name'] ?? '', color: json['color'] ?? '888888');
}

/// An issue or a pull request (GitHub treats both as issues).
class GhIssue {
  final int number;
  final String title;
  final String body;
  final bool isOpen;
  final bool isPullRequest;
  final bool isDraft;
  final bool isMerged;
  final GhUser user;
  final List<GhLabel> labels;
  final int comments;
  final DateTime? createdAt;
  final DateTime? closedAt;
  final String? headRef;
  final String? baseRef;

  const GhIssue({
    required this.number,
    required this.title,
    required this.body,
    required this.isOpen,
    required this.isPullRequest,
    required this.user,
    this.isDraft = false,
    this.isMerged = false,
    this.labels = const [],
    this.comments = 0,
    this.createdAt,
    this.closedAt,
    this.headRef,
    this.baseRef,
  });

  /// From /issues (may also contain PRs) or /pulls.
  factory GhIssue.fromJson(Map<String, dynamic> json) {
    final isPr = json['pull_request'] != null || json['head'] != null;
    return GhIssue(
      number: json['number'] ?? 0,
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      isOpen: json['state'] == 'open',
      isPullRequest: isPr,
      isDraft: json['draft'] == true,
      isMerged: json['merged_at'] != null ||
          json['pull_request']?['merged_at'] != null,
      user: GhUser.fromJson(json['user']),
      labels: ((json['labels'] as List?) ?? [])
          .map((e) => GhLabel.fromJson(e))
          .toList(),
      comments: json['comments'] ?? 0,
      createdAt: DateTime.tryParse(json['created_at'] ?? ''),
      closedAt: DateTime.tryParse(json['closed_at'] ?? ''),
      headRef: json['head']?['ref'],
      baseRef: json['base']?['ref'],
    );
  }
}

class GhComment {
  final GhUser user;
  final String body;
  final DateTime? createdAt;

  const GhComment({required this.user, required this.body, this.createdAt});

  factory GhComment.fromJson(Map<String, dynamic> json) => GhComment(
        user: GhUser.fromJson(json['user']),
        body: json['body'] ?? '',
        createdAt: DateTime.tryParse(json['created_at'] ?? ''),
      );
}

class GhCommit {
  final String sha;
  final String message;
  final String authorName;
  final GhUser? author;
  final DateTime? date;
  final List<GhFileChange> files;
  final int additions;
  final int deletions;

  const GhCommit({
    required this.sha,
    required this.message,
    required this.authorName,
    this.author,
    this.date,
    this.files = const [],
    this.additions = 0,
    this.deletions = 0,
  });

  String get shortSha => sha.length > 7 ? sha.substring(0, 7) : sha;
  String get title => message.split('\n').first;
  String get description =>
      message.contains('\n') ? message.substring(message.indexOf('\n')).trim() : '';

  factory GhCommit.fromJson(Map<String, dynamic> json) {
    final commit = json['commit'] ?? {};
    return GhCommit(
      sha: json['sha'] ?? '',
      message: commit['message'] ?? '',
      authorName: commit['author']?['name'] ?? '',
      author: json['author'] == null ? null : GhUser.fromJson(json['author']),
      date: DateTime.tryParse(commit['author']?['date'] ?? ''),
      files: ((json['files'] as List?) ?? [])
          .map((e) => GhFileChange.fromJson(e))
          .toList(),
      additions: json['stats']?['additions'] ?? 0,
      deletions: json['stats']?['deletions'] ?? 0,
    );
  }
}

class GhFileChange {
  final String filename;
  final String status; // added, removed, modified, renamed
  final int additions;
  final int deletions;
  final String? patch;

  const GhFileChange({
    required this.filename,
    required this.status,
    required this.additions,
    required this.deletions,
    this.patch,
  });

  factory GhFileChange.fromJson(Map<String, dynamic> json) => GhFileChange(
        filename: json['filename'] ?? '',
        status: json['status'] ?? 'modified',
        additions: json['additions'] ?? 0,
        deletions: json['deletions'] ?? 0,
        patch: json['patch'],
      );
}

class GhBranch {
  final String name;
  final bool isProtected;

  const GhBranch({required this.name, required this.isProtected});

  factory GhBranch.fromJson(Map<String, dynamic> json) => GhBranch(
        name: json['name'] ?? '',
        isProtected: json['protected'] == true,
      );
}
