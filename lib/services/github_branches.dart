import 'github_service.dart';

/// One row of the Branches page.
class BranchInfo {
  BranchInfo({
    required this.name,
    this.sha,
    this.updatedAt,
    this.authorLogin,
    this.authorAvatar,
    this.checkState,
    this.checksPassed = 0,
    this.checksTotal = 0,
    this.ahead,
    this.behind,
    this.prNumber,
    this.prState,
    this.prDraft = false,
  });

  final String name;
  final String? sha;
  final DateTime? updatedAt;
  final String? authorLogin;
  final String? authorAvatar;

  /// SUCCESS, FAILURE, ERROR, PENDING, EXPECTED, or null when no checks ran.
  final String? checkState;
  final int checksPassed;
  final int checksTotal;

  /// Commits this branch has that the default branch doesn't, and the
  /// other way round.
  final int? ahead;
  final int? behind;

  /// The newest pull request opened from this branch.
  final int? prNumber;
  final String? prState; // OPEN, MERGED, CLOSED
  final bool prDraft;

  /// GitHub calls a branch stale after three months without commits.
  bool get isStale =>
      updatedAt != null &&
      DateTime.now().difference(updatedAt!) > const Duration(days: 90);
}

class BranchList {
  BranchList(this.defaultBranch, this.viewer, this.branches, {this.full = true});

  final String? defaultBranch;
  final String? viewer;
  final List<BranchInfo> branches;

  /// False when only names could be loaded (no token).
  final bool full;
}

const _query = r'''
query($owner: String!, $name: String!, $base: String!, $after: String) {
  viewer { login }
  repository(owner: $owner, name: $name) {
    refs(refPrefix: "refs/heads/", first: 50, after: $after,
         orderBy: {field: TAG_COMMIT_DATE, direction: DESC}) {
      pageInfo { hasNextPage endCursor }
      nodes {
        name
        compare(headRef: $base) { aheadBy behindBy }
        associatedPullRequests(first: 1,
            orderBy: {field: CREATED_AT, direction: DESC}) {
          nodes { number state isDraft }
        }
        target {
          ... on Commit {
            oid
            committedDate
            author { avatarUrl user { login avatarUrl } }
            statusCheckRollup {
              state
              contexts(first: 100) {
                totalCount
                nodes {
                  __typename
                  ... on CheckRun { conclusion }
                  ... on StatusContext { state }
                }
              }
            }
          }
        }
      }
    }
  }
}
''';

/// Branches with their last commit, checks, ahead/behind counts and pull
/// request, like github.com's Branches page.
extension GitHubBranches on GitHubService {
  Future<BranchList> getBranchList(
      String owner, String repo, String defaultBranch) async {
    if (!hasToken) {
      final names = await getBranches(owner, repo);
      return BranchList(defaultBranch, null,
          [for (final b in names) BranchInfo(name: b.name)],
          full: false);
    }
    final out = <BranchInfo>[];
    String? viewer;
    String? after;
    for (var page = 0; page < 6; page++) {
      final data = await graphql(_query, {
        'owner': owner,
        'name': repo,
        'base': defaultBranch,
        'after': after,
      });
      viewer = data['viewer']?['login'];
      final refs = data['repository']?['refs'];
      if (refs == null) break;
      for (final n in (refs['nodes'] as List)) {
        out.add(_parse(n as Map<String, dynamic>));
      }
      if (refs['pageInfo']?['hasNextPage'] != true) break;
      after = refs['pageInfo']['endCursor'];
    }
    return BranchList(defaultBranch, viewer, out);
  }

  BranchInfo _parse(Map<String, dynamic> n) {
    final c = (n['target'] as Map?) ?? {};
    final author = c['author'] as Map?;
    final user = author?['user'] as Map?;
    final rollup = c['statusCheckRollup'] as Map?;
    var passed = 0, total = 0;
    if (rollup != null) {
      final ctx = rollup['contexts'] as Map;
      total = ctx['totalCount'] ?? 0;
      for (final x in (ctx['nodes'] as List)) {
        final ok = x['__typename'] == 'CheckRun'
            ? const {'SUCCESS', 'NEUTRAL', 'SKIPPED'}.contains(x['conclusion'])
            : x['state'] == 'SUCCESS';
        if (ok) passed++;
      }
    }
    final cmp = n['compare'] as Map?;
    final prs = (n['associatedPullRequests']?['nodes'] as List?) ?? const [];
    final pr = prs.isEmpty ? null : prs.first as Map;
    return BranchInfo(
      name: n['name'] ?? '',
      sha: c['oid'],
      updatedAt: DateTime.tryParse(c['committedDate'] ?? '')?.toLocal(),
      authorLogin: user?['login'],
      authorAvatar: user?['avatarUrl'] ?? author?['avatarUrl'],
      checkState: rollup?['state'],
      checksPassed: passed,
      checksTotal: total,
      // compare() runs from this branch to the default branch, so its
      // "ahead" is how far this branch is behind.
      behind: cmp?['aheadBy'],
      ahead: cmp?['behindBy'],
      prNumber: pr?['number'],
      prState: pr?['state'],
      prDraft: pr?['isDraft'] == true,
    );
  }

  static String _refPath(String name) =>
      name.split('/').map(Uri.encodeComponent).join('/');

  Future<void> deleteBranch(String owner, String repo, String name) =>
      api('/repos/$owner/$repo/git/refs/heads/${_refPath(name)}',
          method: 'DELETE');

  Future<void> createBranch(
          String owner, String repo, String name, String sha) =>
      api('/repos/$owner/$repo/git/refs',
          method: 'POST', body: {'ref': 'refs/heads/$name', 'sha': sha});
}
