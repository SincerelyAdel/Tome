import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/actions.dart';
import '../models/github_models.dart';
import '../models/repo_item.dart';

class GitHubService {
  static const String _baseUrl = 'https://api.github.com';
  final String? token;

  GitHubService({this.token});

  Map<String, String> get _headers => {
        'Accept': 'application/vnd.github.v3+json',
        if (token != null && token!.isNotEmpty)
          'Authorization': 'token $token',
      };

  Future<RepoInfo> getRepoInfo(String owner, String repo) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/repos/$owner/$repo'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      return RepoInfo.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to load repo: ${response.statusCode}');
  }

  /// [ref] is a branch name; null means the default branch.
  Future<List<RepoItem>> getContents(String owner, String repo, String path,
      {String? ref}) async {
    final encodedPath = path.isEmpty ? '' : '/$path';
    final response = await http.get(
      Uri.parse('$_baseUrl/repos/$owner/$repo/contents$encodedPath'
          '${_refQuery(ref)}'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      final items = data.map((e) => RepoItem.fromJson(e)).toList();
      // Sort: directories first, then files, both alphabetically
      items.sort((a, b) {
        if (a.isDirectory && b.isFile) return -1;
        if (a.isFile && b.isDirectory) return 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      return items;
    }
    throw Exception('Failed to load contents: ${response.statusCode}');
  }

  Future<String> getFileContent(String owner, String repo, String path,
      {String? ref}) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/repos/$owner/$repo/contents/$path${_refQuery(ref)}'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final encoded = data['content'] as String;
      return utf8.decode(base64.decode(encoded.replaceAll('\n', '')));
    }
    throw Exception('Failed to load file: ${response.statusCode}');
  }

  /// Repos the token's owner can access (own, collaborator, org),
  /// most recently pushed first. Includes private repos.
  Future<List<RepoInfo>> getMyRepos() async {
    return _getRepoList('$_baseUrl/user/repos?per_page=100&sort=pushed'
        '&affiliation=owner,collaborator,organization_member');
  }

  static String _refQuery(String? ref) =>
      ref == null ? '' : '?ref=${Uri.encodeQueryComponent(ref)}';

  Future<List<dynamic>> _getList(String url, String what) async {
    final response = await http.get(Uri.parse(url), headers: _headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    }
    if (response.statusCode == 403) {
      throw Exception('GitHub rate limit hit or access denied.');
    }
    throw Exception('Failed to load $what: ${response.statusCode}');
  }

  /// Issues only (GitHub's /issues also returns PRs; those are dropped).
  Future<List<GhIssue>> getIssues(String owner, String repo,
      {bool open = true}) async {
    final list = await _getList(
        '$_baseUrl/repos/$owner/$repo/issues'
        '?state=${open ? 'open' : 'closed'}&per_page=100',
        'issues');
    return list
        .where((e) => e['pull_request'] == null)
        .map((e) => GhIssue.fromJson(e))
        .toList();
  }

  Future<List<GhIssue>> getPulls(String owner, String repo,
      {bool open = true}) async {
    final list = await _getList(
        '$_baseUrl/repos/$owner/$repo/pulls'
        '?state=${open ? 'open' : 'closed'}&per_page=100',
        'pull requests');
    return list.map((e) => GhIssue.fromJson(e)).toList();
  }

  /// Comments on an issue or a pull request.
  Future<List<GhComment>> getComments(
      String owner, String repo, int number) async {
    final list = await _getList(
        '$_baseUrl/repos/$owner/$repo/issues/$number/comments?per_page=100',
        'comments');
    return list.map((e) => GhComment.fromJson(e)).toList();
  }

  Future<GhPullDetail> getPull(String owner, String repo, int number) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/repos/$owner/$repo/pulls/$number'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      return GhPullDetail.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to load pull request: ${response.statusCode}');
  }

  /// Everything that happened on an issue or PR, oldest first: comments,
  /// reviews, pushed commits, assignments, labels, merges...
  Future<List<GhEvent>> getTimeline(
      String owner, String repo, int number) async {
    final events = <GhEvent>[];
    for (var page = 1; page <= 5; page++) {
      final list = await _getList(
          '$_baseUrl/repos/$owner/$repo/issues/$number/timeline'
          '?per_page=100&page=$page',
          'timeline');
      events.addAll(list.map((e) => GhEvent.fromJson(e)));
      if (list.length < 100) break;
    }
    return events;
  }

  Future<List<GhCommit>> getPullCommits(
      String owner, String repo, int number) async {
    final list = await _getList(
        '$_baseUrl/repos/$owner/$repo/pulls/$number/commits?per_page=100',
        'commits');
    return list.map((e) => GhCommit.fromJson(e)).toList();
  }

  Future<List<GhFileChange>> getPullFiles(
      String owner, String repo, int number) async {
    final files = <GhFileChange>[];
    for (var page = 1; page <= 5; page++) {
      final list = await _getList(
          '$_baseUrl/repos/$owner/$repo/pulls/$number/files'
          '?per_page=100&page=$page',
          'files');
      files.addAll(list.map((e) => GhFileChange.fromJson(e)));
      if (list.length < 100) break;
    }
    return files;
  }

  Future<List<GhCheckRun>> getCheckRuns(
      String owner, String repo, String sha) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/repos/$owner/$repo/commits/$sha/check-runs'
          '?per_page=100'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      return ((jsonDecode(response.body)['check_runs'] as List?) ?? [])
          .map((e) => GhCheckRun.fromJson(e))
          .toList();
    }
    throw Exception('Failed to load checks: ${response.statusCode}');
  }

  /// One page of history; pages start at 1.
  Future<List<GhCommit>> getCommits(String owner, String repo,
      {String? branch, int page = 1, int perPage = 100}) async {
    final sha = branch == null ? '' : '&sha=${Uri.encodeQueryComponent(branch)}';
    final list = await _getList(
        '$_baseUrl/repos/$owner/$repo/commits?per_page=$perPage&page=$page$sha',
        'commits');
    return list.map((e) => GhCommit.fromJson(e)).toList();
  }

  /// One commit with its changed files and diffs.
  Future<GhCommit> getCommit(String owner, String repo, String sha) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/repos/$owner/$repo/commits/$sha'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      return GhCommit.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to load commit: ${response.statusCode}');
  }

  Future<List<GhBranch>> getBranches(String owner, String repo) async {
    final list = await _getList(
        '$_baseUrl/repos/$owner/$repo/branches?per_page=100', 'branches');
    return list.map((e) => GhBranch.fromJson(e)).toList();
  }

  /// The token owner's login and avatar URL.
  Future<({String login, String avatarUrl})> getViewer() async {
    final response =
        await http.get(Uri.parse('$_baseUrl/user'), headers: _headers);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (
        login: data['login'] as String,
        avatarUrl: (data['avatar_url'] as String?) ?? '',
      );
    }
    if (response.statusCode == 401) {
      throw Exception('GitHub token was rejected. Check it in Settings.');
    }
    throw Exception('Could not load account: ${response.statusCode}');
  }

  /// Public repos of any user or organization.
  Future<List<RepoInfo>> getUserRepos(String user) async {
    return _getRepoList(
        '$_baseUrl/users/${Uri.encodeComponent(user)}/repos?per_page=100&sort=pushed');
  }

  Future<List<RepoInfo>> _getRepoList(String url) async {
    final response = await http.get(Uri.parse(url), headers: _headers);
    if (response.statusCode == 200) {
      return (jsonDecode(response.body) as List<dynamic>)
          .map((e) => RepoInfo.fromJson(e))
          .toList();
    }
    if (response.statusCode == 404) throw Exception('User not found');
    if (response.statusCode == 401) {
      throw Exception('GitHub token was rejected. Check it in Settings.');
    }
    if (response.statusCode == 403) {
      throw Exception('GitHub rate limit hit. Add a token in Settings.');
    }
    throw Exception('Failed to load repos: ${response.statusCode}');
  }

  /// "SincerelyAdel", "github.com/SincerelyAdel" or "@SincerelyAdel"
  /// -> "SincerelyAdel". Returns null for anything else.
  static String? parseUsername(String input) {
    input = input.trim();
    final url = RegExp(r'github\.com/([A-Za-z0-9-]+)/?$').firstMatch(input);
    if (url != null) return url.group(1);
    final bare = RegExp(r'^@?([A-Za-z0-9-]+)$').firstMatch(input);
    return bare?.group(1);
  }

  bool get hasToken => token != null && token!.isNotEmpty;

  /// Calls any REST endpoint ([path] starts with '/') and returns the
  /// decoded JSON, or null for an empty reply. Failures throw an
  /// [ApiException] carrying GitHub's own message.
  Future<dynamic> api(String path,
      {String method = 'GET', Object? body}) async {
    final request = http.Request(method, Uri.parse('$_baseUrl$path'))
      ..headers.addAll(_headers);
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    final response = await http.Response.fromStream(await request.send());
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final text = utf8.decode(response.bodyBytes, allowMalformed: true);
      return text.trim().isEmpty ? null : jsonDecode(text);
    }
    throw ApiException.from(response.statusCode, response.body, hasToken);
  }

  /// Runs a GraphQL query; returns `data`. Needs a token.
  Future<Map<String, dynamic>> graphql(
      String query, Map<String, dynamic> variables) async {
    if (!hasToken) {
      throw const ApiException(401, 'This needs a GitHub token. Add one in Settings.');
    }
    final response = await http.post(Uri.parse('$_baseUrl/graphql'),
        headers: _headers,
        body: jsonEncode({'query': query, 'variables': variables}));
    if (response.statusCode != 200) {
      throw ApiException.from(response.statusCode, response.body, hasToken);
    }
    final json = jsonDecode(utf8.decode(response.bodyBytes));
    final errors = json['errors'] as List?;
    if (json['data'] == null && errors != null && errors.isNotEmpty) {
      throw ApiException(200, errors.first['message']?.toString() ?? 'GraphQL error');
    }
    return (json['data'] as Map<String, dynamic>?) ?? {};
  }

  /// The app-wide service for the account in use, so screens opened from
  /// anywhere (like a profile from an @mention) use the right token.
  static GitHubService current = GitHubService();

  Future<Map<String, dynamic>> _getJson(String url, String what) async {
    final response = await http.get(Uri.parse(url), headers: _headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    if (response.statusCode == 404) throw Exception('$what not found');
    if (response.statusCode == 403) {
      throw Exception('GitHub rate limit hit or no access (403).');
    }
    throw Exception('Failed to load $what: ${response.statusCode}');
  }

  // ------------------------------------------------------------ profiles

  Future<GhProfile> getProfile(String login) async => GhProfile.fromJson(
      await _getJson('$_baseUrl/users/${Uri.encodeComponent(login)}', 'User'));

  Future<List<GhUser>> getFollowers(String login,
      {bool following = false}) async {
    final list = await _getList(
        '$_baseUrl/users/${Uri.encodeComponent(login)}/'
        '${following ? 'following' : 'followers'}?per_page=100',
        following ? 'following' : 'followers');
    return list.map((e) => GhUser.fromJson(e)).toList();
  }

  /// The profile README (login/login, or .github/profile for orgs), or null.
  Future<String?> getProfileReadme(String login, {bool isOrg = false}) async {
    final url = isOrg
        ? '$_baseUrl/repos/$login/.github/contents/profile/README.md'
        : '$_baseUrl/repos/$login/$login/readme';
    final response = await http.get(Uri.parse(url),
        headers: {..._headers, 'Accept': 'application/vnd.github.raw'});
    return response.statusCode == 200
        ? utf8.decode(response.bodyBytes, allowMalformed: true)
        : null;
  }

  /// Pinned repos and the contribution calendar. GitHub only serves these
  /// over GraphQL, which needs a token; returns null without one.
  Future<GhProfileExtras?> getProfileExtras(String login,
      {bool isOrg = false}) async {
    if (!hasToken) return null;
    final owner = isOrg ? 'organization' : 'user';
    final calendar = isOrg
        ? ''
        : 'contributionsCollection { contributionCalendar { totalContributions '
            'weeks { contributionDays { date contributionCount contributionLevel } } } }';
    final query = 'query(\$l: String!) { $owner(login: \$l) { '
        'pinnedItems(first: 6, types: REPOSITORY) { nodes { ... on Repository { '
        'name owner { login } description stargazerCount forkCount '
        'primaryLanguage { name color } } } } $calendar } }';
    final response = await http.post(Uri.parse('$_baseUrl/graphql'),
        headers: _headers,
        body: jsonEncode({
          'query': query,
          'variables': {'l': login}
        }));
    if (response.statusCode != 200) return null;
    final data = (jsonDecode(response.body)['data'] ?? {})[owner];
    if (data == null) return null;
    final pinned = ((data['pinnedItems']?['nodes'] as List?) ?? [])
        .where((n) => n is Map && n['name'] != null)
        .map((n) => GhPinnedRepo(
              owner: n['owner']?['login'] ?? login,
              name: n['name'],
              description: n['description'] ?? '',
              language: n['primaryLanguage']?['name'] ?? '',
              languageColor: n['primaryLanguage']?['color'] ?? '',
              stars: n['stargazerCount'] ?? 0,
              forks: n['forkCount'] ?? 0,
            ))
        .toList();
    final cal = data['contributionsCollection']?['contributionCalendar'];
    const levels = {
      'FIRST_QUARTILE': 1,
      'SECOND_QUARTILE': 2,
      'THIRD_QUARTILE': 3,
      'FOURTH_QUARTILE': 4,
    };
    final weeks = ((cal?['weeks'] as List?) ?? [])
        .map((w) => ((w['contributionDays'] as List?) ?? [])
            .map((d) => GhContributionDay(
                  DateTime.parse(d['date']),
                  d['contributionCount'] ?? 0,
                  levels[d['contributionLevel']] ?? 0,
                ))
            .toList())
        .toList();
    return GhProfileExtras(
      pinned: pinned,
      totalContributions: cal?['totalContributions'] ?? 0,
      weeks: weeks,
    );
  }

  // ------------------------------------------------------------- actions

  Future<List<Workflow>> getWorkflows(String owner, String repo) async {
    final data = await _getJson(
        '$_baseUrl/repos/$owner/$repo/actions/workflows?per_page=100',
        'workflows');
    return ((data['workflows'] as List?) ?? [])
        .map((e) => Workflow.fromJson(e))
        .toList();
  }

  Future<WorkflowRun> getRun(String owner, String repo, int runId) async =>
      WorkflowRun.fromJson(await _getJson(
          '$_baseUrl/repos/$owner/$repo/actions/runs/$runId', 'Run'));

  Future<List<WorkflowJob>> getRunJobs(
      String owner, String repo, int runId) async {
    final data = await _getJson(
        '$_baseUrl/repos/$owner/$repo/actions/runs/$runId/jobs?per_page=100',
        'jobs');
    return ((data['jobs'] as List?) ?? [])
        .map((e) => WorkflowJob.fromJson(e))
        .toList();
  }

  Future<RunTiming> getRunTiming(String owner, String repo, int runId) async =>
      RunTiming.fromJson(await _getJson(
          '$_baseUrl/repos/$owner/$repo/actions/runs/$runId/timing',
          'timing'));

  /// A job's check-run annotations (errors and warnings).
  Future<List<CheckAnnotation>> getAnnotations(
      String owner, String repo, int jobId) async {
    final list = await _getList(
        '$_baseUrl/repos/$owner/$repo/check-runs/$jobId/annotations?per_page=100',
        'annotations');
    return list.map((e) => CheckAnnotation.fromJson(e)).toList();
  }

  /// A job's full plain-text log. GitHub redirects to a signed URL that
  /// must be fetched without the token.
  Future<String> getJobLog(String owner, String repo, int jobId) async {
    if (!hasToken) {
      throw Exception('GitHub only shows logs to signed-in users. '
          'Add a token in Settings.');
    }
    final client = http.Client();
    try {
      final request = http.Request('GET',
          Uri.parse('$_baseUrl/repos/$owner/$repo/actions/jobs/$jobId/logs'))
        ..followRedirects = false
        ..headers.addAll(_headers);
      final response =
          await http.Response.fromStream(await client.send(request));
      final location = response.headers['location'];
      if (response.statusCode >= 300 &&
          response.statusCode < 400 &&
          location != null) {
        final log = await client.get(Uri.parse(location));
        if (log.statusCode == 200) {
          return utf8.decode(log.bodyBytes, allowMalformed: true);
        }
        throw Exception('Could not download the log (${log.statusCode}).');
      }
      if (response.statusCode == 200) {
        return utf8.decode(response.bodyBytes, allowMalformed: true);
      }
      if (response.statusCode == 404 || response.statusCode == 410) {
        throw Exception('The log is not available yet, or it has expired.');
      }
      throw Exception('Could not load the log (${response.statusCode}).');
    } finally {
      client.close();
    }
  }

  Future<List<WorkflowRun>> getWorkflowRuns(String owner, String repo,
      {int perPage = 30, int page = 1, int? workflowId}) async {
    final base = workflowId == null
        ? '$_baseUrl/repos/$owner/$repo/actions/runs'
        : '$_baseUrl/repos/$owner/$repo/actions/workflows/$workflowId/runs';
    final response = await http.get(
      Uri.parse('$base?per_page=$perPage&page=$page'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['workflow_runs'] as List<dynamic>)
          .map((e) => WorkflowRun.fromJson(e))
          .toList();
    }
    throw Exception('Failed to load workflow runs: ${response.statusCode}');
  }

  Future<List<Artifact>> getRunArtifacts(
      String owner, String repo, int runId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/repos/$owner/$repo/actions/runs/$runId/artifacts'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['artifacts'] as List<dynamic>)
          .map((e) => Artifact.fromJson(e))
          .toList();
    }
    throw Exception('Failed to load artifacts: ${response.statusCode}');
  }

  /// GitHub answers an artifact download with a redirect to a short-lived
  /// signed URL. We grab that URL ourselves so the GitHub token is never
  /// forwarded to the storage host (which rejects it).
  Future<String> getArtifactDownloadUrl(
      String owner, String repo, int artifactId) async {
    if (!hasToken) {
      throw Exception(
          'GitHub requires a token to download artifacts, even for public '
          'repos. Add one in Settings.');
    }
    final client = http.Client();
    try {
      final request = http.Request(
        'GET',
        Uri.parse(
            '$_baseUrl/repos/$owner/$repo/actions/artifacts/$artifactId/zip'),
      )
        ..followRedirects = false
        ..headers.addAll(_headers);
      final response = await client.send(request);
      await response.stream.drain<void>();
      final location = response.headers['location'];
      if (response.statusCode >= 300 &&
          response.statusCode < 400 &&
          location != null) {
        return location;
      }
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw Exception('GitHub refused the download '
            '(${response.statusCode}). Check that your token has access to '
            'this repo (Actions: read).');
      }
      if (response.statusCode == 410) {
        throw Exception('This artifact has expired.');
      }
      throw Exception('Artifact download failed: ${response.statusCode}');
    } finally {
      client.close();
    }
  }

  /// Parses "https://github.com/owner/repo" or "owner/repo"
  static Map<String, String>? parseRepoUrl(String input) {
    input = input.trim();
    final githubRegex =
        RegExp(r'github\.com[/:]([^/]+)/([^/\s]+?)(?:\.git)?(?:/.*)?$');
    final match = githubRegex.firstMatch(input);
    if (match != null) {
      return {'owner': match.group(1)!, 'repo': match.group(2)!};
    }
    final shortRegex = RegExp(r'^([^/]+)/([^/]+)$');
    final shortMatch = shortRegex.firstMatch(input);
    if (shortMatch != null) {
      return {'owner': shortMatch.group(1)!, 'repo': shortMatch.group(2)!};
    }
    return null;
  }
}

/// A failed GitHub API call, with a message a person can act on.
class ApiException implements Exception {
  final int status;
  final String message;

  const ApiException(this.status, this.message);

  factory ApiException.from(int status, String body, bool hasToken) {
    var gh = '';
    try {
      gh = (jsonDecode(body)['message'] ?? '').toString().replaceAll(RegExp(r'\.+$'), '');
    } catch (_) {}
    final text = switch (status) {
      401 => 'GitHub rejected the token. Check it in Settings.',
      403 when gh.toLowerCase().contains('rate limit') =>
        'GitHub rate limit hit. Try again in a few minutes.',
      403 => hasToken
          ? 'Your token isn\'t allowed to do this${gh.isEmpty ? '' : ' ($gh)'}. '
              'It may need more scopes, such as read:org or admin:org.'
          : 'This needs a GitHub token. Add one in Settings.',
      404 => hasToken
          ? 'Not found, or your token can\'t see it. Owner-only pages need '
              'scopes such as read:org or admin:org.'
          : 'Not found. Private and owner-only data needs a token.',
      409 || 405 || 422 => gh.isEmpty ? 'GitHub refused ($status).' : gh,
      _ => gh.isEmpty ? 'GitHub error $status.' : '$gh ($status)',
    };
    return ApiException(status, text);
  }

  @override
  String toString() => message;
}

