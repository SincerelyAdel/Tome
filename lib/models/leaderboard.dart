/// One contributor's weekly activity in one repo, from GitHub's
/// /repos/{owner}/{repo}/stats/contributors.
class RepoContributor {
  final String repo;
  final String login;
  final String avatarUrl;
  final List<ContributorWeek> weeks;

  const RepoContributor({
    required this.repo,
    required this.login,
    required this.avatarUrl,
    required this.weeks,
  });

  /// Null for entries GitHub can't tie to an account.
  static RepoContributor? fromJson(String repo, Map<String, dynamic> json) {
    final author = json['author'];
    if (author is! Map || (author['login'] ?? '') == '') return null;
    return RepoContributor(
      repo: repo,
      login: author['login'] as String,
      avatarUrl: author['avatar_url'] as String? ?? '',
      weeks: ((json['weeks'] as List?) ?? [])
          .map((w) => ContributorWeek(
                start: DateTime.fromMillisecondsSinceEpoch(
                    ((w['w'] as num?) ?? 0).toInt() * 1000,
                    isUtc: true),
                additions: ((w['a'] as num?) ?? 0).toInt(),
                deletions: ((w['d'] as num?) ?? 0).toInt(),
                commits: ((w['c'] as num?) ?? 0).toInt(),
              ))
          .toList(),
    );
  }
}

class ContributorWeek {
  final DateTime start;
  final int additions, deletions, commits;

  const ContributorWeek({
    required this.start,
    required this.additions,
    required this.deletions,
    required this.commits,
  });
}

/// Commit stats for an org: per-repo contributors, plus repos GitHub was
/// still computing when we asked.
class OrgCommitStats {
  final List<RepoContributor> contributors;
  final int repoCount;
  final List<String> pendingRepos;

  const OrgCommitStats({
    required this.contributors,
    required this.repoCount,
    required this.pendingRepos,
  });
}

/// A person's totals on the leaderboard.
class LeaderEntry {
  final String login;
  final String avatarUrl;
  final int commits, additions, deletions;
  final Set<String> repos;

  const LeaderEntry({
    required this.login,
    required this.avatarUrl,
    required this.commits,
    required this.additions,
    required this.deletions,
    required this.repos,
  });
}

/// Time windows the leaderboard can show. GitHub reports activity per week,
/// so windows are counted in whole weeks.
enum LeaderPeriod {
  week('This week', Duration(days: 7)),
  month('4 weeks', Duration(days: 28)),
  year('12 months', Duration(days: 365)),
  all('All time', null);

  const LeaderPeriod(this.label, this.window);

  final String label;
  final Duration? window;
}

/// Adds up everyone's activity across repos within [period] and ranks by
/// commits (then lines added). Bots and people with no commits in the
/// window are left out.
List<LeaderEntry> rankContributors(
  List<RepoContributor> contributors,
  LeaderPeriod period, {
  DateTime? now,
}) {
  final window = period.window;
  final cutoff =
      window == null ? null : (now ?? DateTime.now()).toUtc().subtract(window);

  final totals = <String, _Tally>{};
  for (final c in contributors) {
    if (c.login.endsWith('[bot]')) continue;
    var commits = 0, adds = 0, dels = 0;
    for (final w in c.weeks) {
      if (cutoff != null && w.start.isBefore(cutoff)) continue;
      commits += w.commits;
      adds += w.additions;
      dels += w.deletions;
    }
    if (commits == 0) continue;
    final t = totals.putIfAbsent(
        c.login.toLowerCase(), () => _Tally(c.login, c.avatarUrl));
    t.commits += commits;
    t.additions += adds;
    t.deletions += dels;
    t.repos.add(c.repo);
  }

  final ranked = totals.values
      .map((t) => LeaderEntry(
            login: t.login,
            avatarUrl: t.avatarUrl,
            commits: t.commits,
            additions: t.additions,
            deletions: t.deletions,
            repos: t.repos,
          ))
      .toList()
    ..sort((a, b) {
      final byCommits = b.commits.compareTo(a.commits);
      if (byCommits != 0) return byCommits;
      final byAdds = b.additions.compareTo(a.additions);
      if (byAdds != 0) return byAdds;
      return a.login.toLowerCase().compareTo(b.login.toLowerCase());
    });
  return ranked;
}

class _Tally {
  _Tally(this.login, this.avatarUrl);

  final String login;
  final String avatarUrl;
  int commits = 0, additions = 0, deletions = 0;
  final Set<String> repos = {};
}
