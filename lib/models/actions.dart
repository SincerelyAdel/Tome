/// A single GitHub Actions workflow run.
class WorkflowRun {
  final int id;
  final String name;
  final String title;
  final int runNumber;
  final String branch;
  final String event;
  final String status; // queued, in_progress, completed
  final String? conclusion; // success, failure, cancelled, ...
  final String headSha;
  final DateTime createdAt;
  final String htmlUrl;

  WorkflowRun({
    required this.id,
    required this.name,
    required this.title,
    required this.runNumber,
    required this.branch,
    required this.event,
    required this.status,
    required this.conclusion,
    required this.headSha,
    required this.createdAt,
    required this.htmlUrl,
  });

  factory WorkflowRun.fromJson(Map<String, dynamic> json) {
    return WorkflowRun(
      id: json['id'] as int,
      name: json['name'] ?? '',
      title: json['display_title'] ?? '',
      runNumber: json['run_number'] ?? 0,
      branch: json['head_branch'] ?? '',
      event: json['event'] ?? '',
      status: json['status'] ?? '',
      conclusion: json['conclusion'],
      headSha: json['head_sha'] ?? '',
      createdAt:
          DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      htmlUrl: json['html_url'] ?? '',
    );
  }

  bool get isRunning => status != 'completed';
  String get shortSha => headSha.length > 7 ? headSha.substring(0, 7) : headSha;
}

/// A file bundle uploaded by a workflow run.
class Artifact {
  final int id;
  final String name;
  final int sizeInBytes;
  final bool expired;
  final DateTime? expiresAt;

  Artifact({
    required this.id,
    required this.name,
    required this.sizeInBytes,
    required this.expired,
    required this.expiresAt,
  });

  factory Artifact.fromJson(Map<String, dynamic> json) {
    return Artifact(
      id: json['id'] as int,
      name: json['name'] ?? '',
      sizeInBytes: json['size_in_bytes'] ?? 0,
      expired: json['expired'] ?? false,
      expiresAt: DateTime.tryParse(json['expires_at'] ?? ''),
    );
  }
}
