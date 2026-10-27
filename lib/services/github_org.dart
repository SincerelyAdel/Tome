import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/actions.dart';
import '../models/github_models.dart';
import '../models/leaderboard.dart';
import '../models/org_models.dart';
import '../models/repo_item.dart';
import 'github_service.dart';

/// Organization pages (people, teams, runners, security, settings,
/// billing, audit log, projects), search, and the actions that change
/// things on GitHub (comment, close, review, merge, re-run, invite).
extension GitHubOrg on GitHubService {
  /// Reads up to [maxPages] pages of a list endpoint ([path] has a '?').
  Future<List<dynamic>> _pages(String path, {int maxPages = 5}) async {
    final out = <dynamic>[];
    for (var page = 1; page <= maxPages; page++) {
      final list = await api('$path&per_page=100&page=$page') as List;
      out.addAll(list);
      if (list.length < 100) break;
    }
    return out;
  }

  String _e(String s) => Uri.encodeComponent(s);

  // ---------------------------------------------------------------- orgs

  /// Orgs the token's owner belongs to, including private memberships.
  Future<List<GhUser>> getMyOrgs() async {
    if (!hasToken) return [];
    final list = await api('/user/orgs?per_page=100') as List;
    return list.map((e) => GhUser.fromJson(e)).toList();
  }

  /// A user's public org memberships.
  Future<List<GhUser>> getUserOrgs(String login) async {
    final list = await api('/users/${_e(login)}/orgs?per_page=100') as List;
    return list.map((e) => GhUser.fromJson(e)).toList();
  }

  /// 'admin' (owner), 'member', or null if unknown.
  Future<String?> getMyOrgRole(String org) async {
    try {
      final m = await api('/user/memberships/orgs/${_e(org)}');
      return m['role'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Every repo in the org the token can see, private ones included.
  Future<List<RepoInfo>> getOrgRepos(String org) async {
    final list = await _pages('/orgs/${_e(org)}/repos?type=all&sort=pushed');
    final repos = list.map((e) => RepoInfo.fromJson(e)).toList();
    repos.sort((a, b) => (b.updatedAt ?? DateTime(0))
        .compareTo(a.updatedAt ?? DateTime(0)));
    return repos.withAppRepoLast();
  }

  Future<List<GhMember>> getOrgMembers(String org) async {
    final all = await _pages('/orgs/${_e(org)}/members?role=all');
    Set<String> owners = {};
    try {
      owners = (await _pages('/orgs/${_e(org)}/members?role=admin'))
          .map((e) => (e['login'] ?? '').toString())
          .toSet();
    } catch (_) {}
    final members = all
        .map((e) => GhMember(GhUser.fromJson(e),
            isOwner: owners.contains(e['login'])))
        .toList();
    members.sort((a, b) {
      if (a.isOwner != b.isOwner) return a.isOwner ? -1 : 1;
      return a.user.login.toLowerCase().compareTo(b.user.login.toLowerCase());
    });
    return members;
  }

  Future<List<GhInvite>> getInvitations(String org) async =>
      (await _pages('/orgs/${_e(org)}/invitations?'))
          .map((e) => GhInvite.fromJson(e))
          .toList();

  Future<List<GhUser>> getOutsideCollaborators(String org) async =>
      (await _pages('/orgs/${_e(org)}/outside_collaborators?'))
          .map((e) => GhUser.fromJson(e))
          .toList();

  Future<List<GhTeam>> getTeams(String org) async =>
      (await _pages('/orgs/${_e(org)}/teams?'))
          .map((e) => GhTeam.fromJson(e))
          .toList();

  Future<List<GhUser>> getTeamMembers(String org, String slug) async =>
      (await _pages('/orgs/${_e(org)}/teams/${_e(slug)}/members?'))
          .map((e) => GhUser.fromJson(e))
          .toList();

  /// The team's repos with its permission on each (admin, push, pull ...).
  Future<List<(RepoInfo, String)>> getTeamRepos(String org, String slug) async {
    final list = await _pages('/orgs/${_e(org)}/teams/${_e(slug)}/repos?');
    return list.map((e) {
      final p = (e['permissions'] as Map?) ?? {};
      final perm = p['admin'] == true
          ? 'Admin'
          : p['maintain'] == true
              ? 'Maintain'
              : p['push'] == true
                  ? 'Write'
                  : p['triage'] == true
                      ? 'Triage'
                      : 'Read';
      return (RepoInfo.fromJson(e), perm);
    }).toList();
  }

  // ------------------------------------------------------------- actions

  Future<List<GhRunner>> getOrgRunners(String org) async {
    final data = await api('/orgs/${_e(org)}/actions/runners?per_page=100');
    return ((data['runners'] as List?) ?? [])
        .map((e) => GhRunner.fromJson(e))
        .toList();
  }

  /// Recent runs across the org's most recently pushed repos, newest first.
  Future<List<(String, WorkflowRun)>> getOrgRuns(String org,
      {int repoCount = 15, int perRepo = 10}) async {
    final repos = (await getOrgRepos(org)).take(repoCount).toList();
    final results = await Future.wait(repos.map((r) async {
      try {
        final runs =
            await getWorkflowRuns(r.owner, r.name, perPage: perRepo);
        return runs.map((run) => (r.name, run)).toList();
      } catch (_) {
        return <(String, WorkflowRun)>[];
      }
    }));
    final all = results.expand((x) => x).toList();
    all.sort((a, b) => b.$2.createdAt.compareTo(a.$2.createdAt));
    return all.take(80).toList();
  }

  // --------------------------------------------------------- leaderboard

  /// Weekly commit stats for the org's most recently pushed repos (forks
  /// left out, since their history is mostly upstream's). GitHub computes
  /// these on demand and answers 202 until they're ready, so each repo is
  /// asked a few times; any still not ready are listed in pendingRepos.
  Future<OrgCommitStats> getOrgCommitStats(String org,
      {int repoCount = 30}) async {
    final repos = (await getOrgRepos(org))
        .where((r) => !r.isFork)
        .take(repoCount)
        .toList();
    final pending = <String>[];
    final results = await Future.wait(repos.map((r) async {
      for (var attempt = 0; attempt < 4; attempt++) {
        if (attempt > 0) await Future.delayed(const Duration(seconds: 2));
        final data = await api(
            '/repos/${_e(r.owner)}/${_e(r.name)}/stats/contributors');
        if (data is List) {
          return data
              .whereType<Map<String, dynamic>>()
              .map((e) => RepoContributor.fromJson(r.name, e))
              .whereType<RepoContributor>()
              .toList();
        }
        // 204 (no body): an empty repo, nothing to count. Anything else is
        // GitHub's 202 "still counting", so ask again.
        if (data == null) return <RepoContributor>[];
      }
      pending.add(r.name);
      return <RepoContributor>[];
    }).map((f) => f.catchError((_) => <RepoContributor>[])));
    return OrgCommitStats(
      contributors: results.expand((x) => x).toList(),
      repoCount: repos.length,
      pendingRepos: pending,
    );
  }

  // ------------------------------------------------------------ security

  Future<List<GhAlert>> getDependabotAlerts(String org) async =>
      (await _pages('/orgs/${_e(org)}/dependabot/alerts?state=open',
              maxPages: 3))
          .map((e) => GhAlert.dependabot(e))
          .toList();

  Future<List<GhAlert>> getCodeScanningAlerts(String org) async =>
      (await _pages('/orgs/${_e(org)}/code-scanning/alerts?state=open',
              maxPages: 3))
          .map((e) => GhAlert.codeScanning(e))
          .toList();

  Future<List<GhAlert>> getSecretScanningAlerts(String org) async =>
      (await _pages('/orgs/${_e(org)}/secret-scanning/alerts?state=open',
              maxPages: 3))
          .map((e) => GhAlert.secret(e))
          .toList();

  // ------------------------------------------------------------ settings

  Future<List<GhSetting>> getOrgSecrets(String org) async {
    final data = await api('/orgs/${_e(org)}/actions/secrets?per_page=100');
    return ((data['secrets'] as List?) ?? [])
        .map((e) => GhSetting.fromJson(e))
        .toList();
  }

  Future<List<GhSetting>> getOrgVariables(String org) async {
    final data = await api('/orgs/${_e(org)}/actions/variables?per_page=30');
    return ((data['variables'] as List?) ?? [])
        .map((e) => GhSetting.fromJson(e))
        .toList();
  }

  /// This month's usage per product. Tries GitHub's current billing API,
  /// then the older Actions-only one.
  Future<List<GhBillingLine>> getBilling(String org) async {
    final now = DateTime.now();
    try {
      final data = await api('/organizations/${_e(org)}/settings/billing/usage'
          '?year=${now.year}&month=${now.month}');
      final byKey = <String, GhBillingLine>{};
      for (final u in (data['usageItems'] as List?) ?? []) {
        final key = '${u['product']}|${u['sku']}';
        final old = byKey[key];
        num n(Object? x) => x is num ? x : 0;
        byKey[key] = GhBillingLine(
          product: (u['product'] ?? '').toString(),
          sku: (u['sku'] ?? '').toString(),
          unit: (u['unitType'] ?? '').toString(),
          quantity: (old?.quantity ?? 0) + n(u['quantity']).toDouble(),
          gross: (old?.gross ?? 0) + n(u['grossAmount']).toDouble(),
          net: (old?.net ?? 0) + n(u['netAmount']).toDouble(),
        );
      }
      final lines = byKey.values.toList()
        ..sort((a, b) => b.gross.compareTo(a.gross));
      return lines;
    } on ApiException catch (first) {
      try {
        final d = await api('/orgs/${_e(org)}/settings/billing/actions');
        final lines = <GhBillingLine>[
          GhBillingLine(
              product: 'Actions',
              sku: 'Minutes used',
              quantity: (d['total_minutes_used'] ?? 0).toDouble(),
              unit: 'minutes'),
          GhBillingLine(
              product: 'Actions',
              sku: 'Included minutes',
              quantity: (d['included_minutes'] ?? 0).toDouble(),
              unit: 'minutes'),
          GhBillingLine(
              product: 'Actions',
              sku: 'Paid minutes',
              quantity: (d['total_paid_minutes_used'] ?? 0).toDouble(),
              unit: 'minutes'),
        ];
        ((d['minutes_used_breakdown'] as Map?) ?? {}).forEach((os, m) {
          lines.add(GhBillingLine(
              product: 'Actions',
              sku: os.toString(),
              quantity: (m as num).toDouble(),
              unit: 'minutes'));
        });
        return lines;
      } catch (_) {
        throw first;
      }
    }
  }

  /// Needs GitHub Enterprise Cloud; other plans answer 404.
  Future<List<GhAuditEntry>> getAuditLog(String org) async {
    final list =
        await api('/orgs/${_e(org)}/audit-log?per_page=100&include=all')
            as List;
    return list.map((e) => GhAuditEntry.fromJson(e)).toList();
  }

  // ------------------------------------------------------------ projects

  Future<List<GhProject>> getProjects(String org) async {
    final data = await graphql(
        r'query($l: String!) { organization(login: $l) { '
        'projectsV2(first: 50, orderBy: {field: UPDATED_AT, direction: DESC}) '
        '{ nodes { number title shortDescription closed updatedAt '
        'items { totalCount } } } } }',
        {'l': org});
    final nodes =
        (data['organization']?['projectsV2']?['nodes'] as List?) ?? [];
    return nodes
        .where((n) => n != null)
        .map((n) => GhProject(
              number: n['number'] ?? 0,
              title: n['title'] ?? '',
              description: n['shortDescription'] ?? '',
              closed: n['closed'] == true,
              updatedAt: DateTime.tryParse(n['updatedAt'] ?? ''),
              items: n['items']?['totalCount'] ?? 0,
            ))
        .toList();
  }

  Future<GhProjectBoard> getProjectBoard(String org, int number) async {
    const content = 'number title body state createdAt '
        'author { login avatarUrl } repository { name owner { login } }';
    final data = await graphql(
        r'query($l: String!, $n: Int!) { organization(login: $l) { '
        r'projectV2(number: $n) { title '
        'field(name: "Status") { ... on ProjectV2SingleSelectField { options { name } } } '
        'items(first: 100) { nodes { type '
        'fieldValueByName(name: "Status") { ... on ProjectV2ItemFieldSingleSelectValue { name } } '
        'content { ... on DraftIssue { title } '
        '... on Issue { $content } '
        '... on PullRequest { $content merged isDraft headRefName baseRefName } '
        '} } } } } }',
        {'l': org, 'n': number});
    final p = data['organization']?['projectV2'];
    if (p == null) throw const ApiException(404, 'Project not found.');
    final columns = ((p['field']?['options'] as List?) ?? [])
        .map((o) => (o['name'] ?? '').toString())
        .toList();
    final items = <GhProjectItem>[];
    for (final n in (p['items']?['nodes'] as List?) ?? []) {
      if (n == null) continue;
      final c = n['content'] ?? {};
      final type = (n['type'] ?? '').toString();
      final status = (n['fieldValueByName']?['name'] ?? '').toString();
      GhIssue? issue;
      if (type == 'ISSUE' || type == 'PULL_REQUEST') {
        issue = GhIssue(
          number: c['number'] ?? 0,
          title: c['title'] ?? '',
          body: c['body'] ?? '',
          isOpen: c['state'] == 'OPEN',
          isPullRequest: type == 'PULL_REQUEST',
          isMerged: c['merged'] == true,
          isDraft: c['isDraft'] == true,
          user: GhUser(
              login: c['author']?['login'] ?? 'ghost',
              avatarUrl: c['author']?['avatarUrl'] ?? ''),
          createdAt: DateTime.tryParse(c['createdAt'] ?? ''),
          headRef: c['headRefName'],
          baseRef: c['baseRefName'],
        );
      }
      items.add(GhProjectItem(
        status: status,
        type: type,
        title: (c['title'] ?? '(no title)').toString(),
        owner: c['repository']?['owner']?['login'] ?? '',
        repo: c['repository']?['name'] ?? '',
        issue: issue,
      ));
    }
    return GhProjectBoard(
        title: p['title'] ?? '', columns: columns, items: items);
  }

  // -------------------------------------------------------------- search

  Future<List<GhSearchItem>> searchIssues(String query) async {
    final data = await api('/search/issues?q=${Uri.encodeQueryComponent(query)}'
        '&sort=updated&order=desc&per_page=100');
    return ((data['items'] as List?) ?? []).map((e) {
      final parts = (e['repository_url'] ?? '').toString().split('/');
      final n = parts.length;
      return GhSearchItem(
        n >= 2 ? parts[n - 2] : '',
        n >= 1 ? parts[n - 1] : '',
        GhIssue.fromJson(e),
        updatedAt: DateTime.tryParse(e['updated_at'] ?? ''),
      );
    }).toList();
  }

  Future<GhIssue> getIssue(String owner, String repo, int number) async =>
      GhIssue.fromJson(await api('/repos/$owner/$repo/issues/$number'));

  // -------------------------------------------- changes (write actions)

  Future<void> addComment(
          String owner, String repo, int number, String body) =>
      api('/repos/$owner/$repo/issues/$number/comments',
          method: 'POST', body: {'body': body});

  Future<void> setIssueOpen(
          String owner, String repo, int number, bool open) =>
      api('/repos/$owner/$repo/issues/$number',
          method: 'PATCH', body: {'state': open ? 'open' : 'closed'});

  /// [event] is APPROVE, REQUEST_CHANGES or COMMENT.
  Future<void> reviewPull(String owner, String repo, int number, String event,
          String body) =>
      api('/repos/$owner/$repo/pulls/$number/reviews',
          method: 'POST',
          body: {'event': event, if (body.trim().isNotEmpty) 'body': body});

  /// Marks a pull request as a draft, or ready for review.
  Future<void> setPullDraft(String nodeId, bool draft) => graphql(
      draft
          ? r'mutation($id: ID!) { convertPullRequestToDraft(input: {pullRequestId: $id}) { clientMutationId } }'
          : r'mutation($id: ID!) { markPullRequestReadyForReview(input: {pullRequestId: $id}) { clientMutationId } }',
      {'id': nodeId});

  /// Merges the base branch into the pull request's branch.
  Future<void> updatePullBranch(String owner, String repo, int number) =>
      api('/repos/$owner/$repo/pulls/$number/update-branch', method: 'PUT');

  /// [method] is merge, squash or rebase.
  Future<void> mergePull(
          String owner, String repo, int number, String method) =>
      api('/repos/$owner/$repo/pulls/$number/merge',
          method: 'PUT', body: {'merge_method': method});

  Future<void> rerunRun(String owner, String repo, int runId) =>
      api('/repos/$owner/$repo/actions/runs/$runId/rerun', method: 'POST');

  Future<void> rerunFailedJobs(String owner, String repo, int runId) => api(
      '/repos/$owner/$repo/actions/runs/$runId/rerun-failed-jobs',
      method: 'POST');

  Future<void> cancelRun(String owner, String repo, int runId) =>
      api('/repos/$owner/$repo/actions/runs/$runId/cancel', method: 'POST');

  Future<void> rerunJob(String owner, String repo, int jobId) =>
      api('/repos/$owner/$repo/actions/jobs/$jobId/rerun', method: 'POST');

  /// Starts a workflow that has a `workflow_dispatch` trigger. [inputs] are
  /// the trigger's inputs; ones left out use their defaults.
  Future<void> dispatchWorkflow(
          String owner, String repo, int workflowId, String ref,
          {Map<String, String> inputs = const {}}) =>
      api('/repos/$owner/$repo/actions/workflows/$workflowId/dispatches',
          method: 'POST',
          body: {'ref': ref, if (inputs.isNotEmpty) 'inputs': inputs});

  /// Deletes a repository for good (GitHub keeps it restorable for a while
  /// under Settings → Repositories → Deleted repositories).
  ///
  /// When GitHub refuses, the error says why in plain words: what GitHub
  /// said, which scopes a classic token has, and which permission a
  /// fine-grained token is missing.
  Future<void> deleteRepo(String owner, String repo) async {
    final res = await http.delete(
      Uri.parse('https://api.github.com/repos/${_e(owner)}/${_e(repo)}'),
      headers: {
        'Accept': 'application/vnd.github+json',
        if (hasToken) 'Authorization': 'token $token',
      },
    );
    if (res.statusCode == 204) return;

    var said = '';
    try {
      said = (jsonDecode(res.body)['message'] ?? '').toString();
    } catch (_) {}
    final scopes = res.headers['x-oauth-scopes'];
    final wants = res.headers['x-accepted-github-permissions'];
    final classic = scopes != null;
    final lines = <String>[
      'GitHub said: ${said.isEmpty ? 'error ${res.statusCode}' : said} '
          '(${res.statusCode}).',
    ];
    if (classic) {
      final list = scopes.split(',').map((x) => x.trim()).where((x) => x.isNotEmpty);
      lines.add('This is a classic token with: '
          '${list.isEmpty ? 'no scopes' : list.join(', ')}.');
      if (!list.contains('delete_repo')) {
        lines.add('Add the delete_repo scope to it on github.com → Settings → '
            'Developer settings → Tokens (classic), then save it again here.');
      } else if (res.statusCode == 403) {
        lines.add('The token is fine; this account is not an admin of '
            '$owner/$repo, or $owner does not let members delete repos.');
      }
    } else {
      lines.add('This is a fine-grained token.');
      if (res.statusCode == 404) {
        lines.add('It cannot see $owner/$repo. On github.com, check that its '
            'Resource owner is $owner and its Repository access includes '
            'this repo. For an organization, the token may also be waiting '
            'for approval under the org Settings → Personal access tokens.');
      } else {
        lines.add('It needs Repository permissions → Administration: Read and '
            'write${wants != null && wants.isNotEmpty ? ' (GitHub asks for $wants)' : ''}. '
            'Edit the token on github.com, then save it again here.');
      }
    }
    throw ApiException(res.statusCode, lines.join('\n'));
  }

  /// Starts the APK builder workflow in [builder] ("owner/name") for
  /// [source] ("owner/name"). [ref] blank means the default branch.
  /// [runner] is "github" (GitHub's machines) or "my-pc" (your own PC's
  /// self-hosted runner).
  Future<void> startApkBuild(String builder, String source, String ref,
      String abi, String runner) async {
    final info = await api('/repos/$builder') as Map;
    await api('/repos/$builder/actions/workflows/build-apk.yml/dispatches',
        method: 'POST',
        body: {
          'ref': info['default_branch'] ?? 'main',
          'inputs': {
            'repo': source,
            'ref': ref,
            'abi': abi,
            'runner': runner,
          },
        });
  }

  /// [role] is direct_member or admin.
  Future<void> inviteMember(String org, String login, String role) async {
    final user = await api('/users/${_e(login)}');
    await api('/orgs/${_e(org)}/invitations',
        method: 'POST', body: {'invitee_id': user['id'], 'role': role});
  }

  Future<void> cancelInvitation(String org, int id) =>
      api('/orgs/${_e(org)}/invitations/$id', method: 'DELETE');
}
