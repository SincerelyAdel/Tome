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
  final String actorLogin;
  final String actorAvatar;
  final int runAttempt;
  final DateTime? runStartedAt;
  final DateTime? updatedAt;

  /// Workflow file, e.g. .github/workflows/build.yml
  final String path;
  final int workflowId;
  final String commitMessage;
  final String commitAuthor;

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
    this.actorLogin = '',
    this.actorAvatar = '',
    this.runAttempt = 1,
    this.runStartedAt,
    this.updatedAt,
    this.path = '',
    this.workflowId = 0,
    this.commitMessage = '',
    this.commitAuthor = '',
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
      actorLogin: json['actor']?['login'] ?? '',
      actorAvatar: json['actor']?['avatar_url'] ?? '',
      runAttempt: json['run_attempt'] ?? 1,
      runStartedAt: DateTime.tryParse(json['run_started_at'] ?? ''),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? ''),
      path: ((json['path'] as String?) ?? '').split('@').first,
      workflowId: json['workflow_id'] ?? 0,
      commitMessage: json['head_commit']?['message'] ?? '',
      commitAuthor: json['head_commit']?['author']?['name'] ?? '',
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

/// Extra run fields the run page shows.
extension WorkflowRunTiming on WorkflowRun {
  /// Wall-clock time from start to finish (or until now while running).
  Duration get duration {
    final start = runStartedAt ?? createdAt;
    final end = isRunning ? DateTime.now() : (updatedAt ?? start);
    final d = end.difference(start);
    return d.isNegative ? Duration.zero : d;
  }
}

/// A workflow defined in the repo (.github/workflows/*.yml).
class Workflow {
  final int id;
  final String name;
  final String path;
  final String state;

  Workflow(
      {required this.id,
      required this.name,
      required this.path,
      required this.state});

  factory Workflow.fromJson(Map<String, dynamic> json) => Workflow(
        id: json['id'] as int,
        name: json['name'] ?? '',
        path: json['path'] ?? '',
        state: json['state'] ?? '',
      );
}

/// One job of a run, with its steps.
class WorkflowJob {
  final int id;
  final String name;
  final String status;
  final String? conclusion;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String runnerName;
  final List<String> labels;
  final List<JobStep> steps;
  final String htmlUrl;

  WorkflowJob({
    required this.id,
    required this.name,
    required this.status,
    required this.conclusion,
    required this.startedAt,
    required this.completedAt,
    required this.runnerName,
    required this.labels,
    required this.steps,
    required this.htmlUrl,
  });

  factory WorkflowJob.fromJson(Map<String, dynamic> json) => WorkflowJob(
        id: json['id'] as int,
        name: json['name'] ?? '',
        status: json['status'] ?? '',
        conclusion: json['conclusion'],
        startedAt: DateTime.tryParse(json['started_at'] ?? ''),
        completedAt: DateTime.tryParse(json['completed_at'] ?? ''),
        runnerName: json['runner_name'] ?? '',
        labels: ((json['labels'] as List?) ?? []).cast<String>(),
        steps: ((json['steps'] as List?) ?? [])
            .map((e) => JobStep.fromJson(e))
            .toList(),
        htmlUrl: json['html_url'] ?? '',
      );

  bool get isRunning => status != 'completed';

  Duration? get duration => _span(startedAt, completedAt, isRunning);
}

class JobStep {
  final int number;
  final String name;
  final String status;
  final String? conclusion;
  final DateTime? startedAt;
  final DateTime? completedAt;

  JobStep({
    required this.number,
    required this.name,
    required this.status,
    required this.conclusion,
    required this.startedAt,
    required this.completedAt,
  });

  factory JobStep.fromJson(Map<String, dynamic> json) => JobStep(
        number: json['number'] ?? 0,
        name: json['name'] ?? '',
        status: json['status'] ?? '',
        conclusion: json['conclusion'],
        startedAt: DateTime.tryParse(json['started_at'] ?? ''),
        completedAt: DateTime.tryParse(json['completed_at'] ?? ''),
      );

  bool get isRunning => status != 'completed';

  Duration? get duration => _span(startedAt, completedAt, isRunning);
}

Duration? _span(DateTime? start, DateTime? end, bool running) {
  if (start == null) return null;
  final d = (running ? DateTime.now() : (end ?? start)).difference(start);
  return d.isNegative ? Duration.zero : d;
}

/// An error, warning or notice a job reported (shown on the run summary).
class CheckAnnotation {
  final String path;
  final int startLine;
  final int endLine;
  final String level; // failure, warning, notice
  final String title;
  final String message;

  CheckAnnotation({
    required this.path,
    required this.startLine,
    required this.endLine,
    required this.level,
    required this.title,
    required this.message,
  });

  factory CheckAnnotation.fromJson(Map<String, dynamic> json) =>
      CheckAnnotation(
        path: json['path'] ?? '',
        startLine: json['start_line'] ?? 0,
        endLine: json['end_line'] ?? 0,
        level: json['annotation_level'] ?? 'notice',
        title: json['title'] ?? '',
        message: json['message'] ?? '',
      );
}

/// Billable time of a run, per runner OS.
class RunTiming {
  final Duration runDuration;
  final Map<String, ({Duration total, int jobs})> billable;

  RunTiming({required this.runDuration, required this.billable});

  factory RunTiming.fromJson(Map<String, dynamic> json) {
    final billable = <String, ({Duration total, int jobs})>{};
    (json['billable'] as Map<String, dynamic>? ?? {}).forEach((os, v) {
      billable[os] = (
        total: Duration(milliseconds: v['total_ms'] ?? 0),
        jobs: v['jobs'] ?? 0,
      );
    });
    return RunTiming(
      runDuration: Duration(milliseconds: json['run_duration_ms'] ?? 0),
      billable: billable,
    );
  }
}
