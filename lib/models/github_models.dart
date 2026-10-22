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
  final List<GhUser> assignees;
  final String? milestone;

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
    this.assignees = const [],
    this.milestone,
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
      assignees: ((json['assignees'] as List?) ?? [])
          .map((e) => GhUser.fromJson(e))
          .toList(),
      milestone: json['milestone']?['title'],
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
  final List<String> parents;

  const GhCommit({
    required this.sha,
    required this.message,
    required this.authorName,
    this.author,
    this.date,
    this.files = const [],
    this.additions = 0,
    this.deletions = 0,
    this.parents = const [],
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
      parents: ((json['parents'] as List?) ?? [])
          .map((p) => p['sha'] as String)
          .toList(),
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

/// Extra fields of a pull request that only /pulls/{n} returns.
class GhPullDetail {
  final int commits;
  final int additions;
  final int deletions;
  final int changedFiles;
  final String headSha;
  final String headRef;
  final String baseRef;
  final bool merged;
  final String mergeableState; // clean, dirty, blocked, unstable, unknown
  final List<GhUser> requestedReviewers;

  const GhPullDetail({
    required this.commits,
    required this.additions,
    required this.deletions,
    required this.changedFiles,
    required this.headSha,
    required this.headRef,
    required this.baseRef,
    required this.merged,
    required this.mergeableState,
    required this.requestedReviewers,
  });

  factory GhPullDetail.fromJson(Map<String, dynamic> json) => GhPullDetail(
        commits: json['commits'] ?? 0,
        additions: json['additions'] ?? 0,
        deletions: json['deletions'] ?? 0,
        changedFiles: json['changed_files'] ?? 0,
        headSha: json['head']?['sha'] ?? '',
        headRef: json['head']?['ref'] ?? '',
        baseRef: json['base']?['ref'] ?? '',
        merged: json['merged'] == true,
        mergeableState: json['mergeable_state'] ?? 'unknown',
        requestedReviewers: ((json['requested_reviewers'] as List?) ?? [])
            .map((e) => GhUser.fromJson(e))
            .toList(),
      );
}

/// One entry of an issue/PR timeline (comment, review, commit, event).
class GhEvent {
  final String event; // commented, reviewed, committed, assigned, ...
  final GhUser? actor;
  final DateTime? at;
  final String body;

  /// Review state: approved, changes_requested, commented, dismissed.
  final String? reviewState;

  /// For committed events.
  final String? sha;
  final String? message;
  final String? authorName;

  /// Who was assigned / requested / mentioned, or the label.
  final GhUser? subject;
  final GhLabel? label;
  final String? renameFrom;
  final String? renameTo;

  const GhEvent({
    required this.event,
    this.actor,
    this.at,
    this.body = '',
    this.reviewState,
    this.sha,
    this.message,
    this.authorName,
    this.subject,
    this.label,
    this.renameFrom,
    this.renameTo,
  });

  factory GhEvent.fromJson(Map<String, dynamic> json) {
    final event = json['event'] ?? '';
    final who = json['actor'] ?? json['user'];
    final subject = json['assignee'] ?? json['requested_reviewer'];
    DateTime? at = DateTime.tryParse(
        json['created_at'] ?? json['submitted_at'] ?? '');
    if (event == 'committed') {
      at = DateTime.tryParse(json['author']?['date'] ?? '');
    }
    return GhEvent(
      event: event,
      actor: who == null ? null : GhUser.fromJson(who),
      at: at,
      body: json['body'] ?? '',
      reviewState: (json['state'] as String?)?.toLowerCase(),
      sha: json['sha'] ?? json['commit_id'],
      message: json['message'],
      authorName: json['author']?['name'],
      subject: subject == null ? null : GhUser.fromJson(subject),
      label: json['label'] == null ? null : GhLabel.fromJson(json['label']),
      renameFrom: json['rename']?['from'],
      renameTo: json['rename']?['to'],
    );
  }
}

/// A CI check run on a commit.
class GhCheckRun {
  final String name;
  final String status; // queued, in_progress, completed
  final String? conclusion; // success, failure, cancelled, skipped, ...
  final DateTime? startedAt;
  final DateTime? completedAt;

  const GhCheckRun({
    required this.name,
    required this.status,
    this.conclusion,
    this.startedAt,
    this.completedAt,
  });

  factory GhCheckRun.fromJson(Map<String, dynamic> json) => GhCheckRun(
        name: json['name'] ?? '',
        status: json['status'] ?? '',
        conclusion: json['conclusion'],
        startedAt: DateTime.tryParse(json['started_at'] ?? ''),
        completedAt: DateTime.tryParse(json['completed_at'] ?? ''),
      );
}

/// A user or organization profile.
class GhProfile {
  final String login;
  final String name;
  final String avatarUrl;
  final String bio;
  final String company;
  final String location;
  final String blog;
  final String twitter;
  final String email;
  final int followers;
  final int following;
  final int publicRepos;
  final DateTime? createdAt;
  final bool isOrg;

  const GhProfile({
    required this.login,
    this.name = '',
    this.avatarUrl = '',
    this.bio = '',
    this.company = '',
    this.location = '',
    this.blog = '',
    this.twitter = '',
    this.email = '',
    this.followers = 0,
    this.following = 0,
    this.publicRepos = 0,
    this.createdAt,
    this.isOrg = false,
  });

  factory GhProfile.fromJson(Map<String, dynamic> j) => GhProfile(
        login: j['login'] ?? '',
        name: j['name'] ?? '',
        avatarUrl: j['avatar_url'] ?? '',
        bio: j['bio'] ?? j['description'] ?? '',
        company: j['company'] ?? '',
        location: j['location'] ?? '',
        blog: j['blog'] ?? '',
        twitter: j['twitter_username'] ?? '',
        email: j['email'] ?? '',
        followers: j['followers'] ?? 0,
        following: j['following'] ?? 0,
        publicRepos: j['public_repos'] ?? 0,
        createdAt: DateTime.tryParse(j['created_at'] ?? ''),
        isOrg: j['type'] == 'Organization',
      );
}

/// A pinned repository on a profile.
class GhPinnedRepo {
  final String owner;
  final String name;
  final String description;
  final String language;
  final String languageColor;
  final int stars;
  final int forks;

  const GhPinnedRepo({
    required this.owner,
    required this.name,
    this.description = '',
    this.language = '',
    this.languageColor = '',
    this.stars = 0,
    this.forks = 0,
  });
}

/// One day on the contribution calendar. [level] is 0 (none) to 4 (most).
class GhContributionDay {
  final DateTime date;
  final int count;
  final int level;

  const GhContributionDay(this.date, this.count, this.level);
}

/// Profile extras that only GitHub's GraphQL API gives (needs a token).
class GhProfileExtras {
  final List<GhPinnedRepo> pinned;
  final int totalContributions;

  /// Weeks of 7 days, oldest first.
  final List<List<GhContributionDay>> weeks;

  const GhProfileExtras(
      {this.pinned = const [],
      this.totalContributions = 0,
      this.weeks = const []});
}
