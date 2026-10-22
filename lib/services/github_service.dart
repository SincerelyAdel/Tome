import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/actions.dart';
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

  Future<List<RepoItem>> getContents(
      String owner, String repo, String path) async {
    final encodedPath = path.isEmpty ? '' : '/$path';
    final response = await http.get(
      Uri.parse('$_baseUrl/repos/$owner/$repo/contents$encodedPath'),
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

  Future<String> getFileContent(String owner, String repo, String path) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/repos/$owner/$repo/contents/$path'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final encoded = data['content'] as String;
      return utf8.decode(base64.decode(encoded.replaceAll('\n', '')));
    }
    throw Exception('Failed to load file: ${response.statusCode}');
  }

  Future<List<RepoItem>> getAllVerilogFiles(
      String owner, String repo) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/repos/$owner/$repo/git/trees/HEAD?recursive=1'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final tree = data['tree'] as List<dynamic>;
      return tree
          .where((e) =>
              e['type'] == 'blob' &&
              (e['path'].toString().endsWith('.v') ||
                  e['path'].toString().endsWith('.sv') ||
                  e['path'].toString().endsWith('.vh')))
          .map((e) => RepoItem(
                name: e['path'].toString().split('/').last,
                path: e['path'],
                type: 'file',
                size: e['size'],
                sha: e['sha'],
              ))
          .toList();
    }
    throw Exception('Failed to fetch tree: ${response.statusCode}');
  }

  bool get hasToken => token != null && token!.isNotEmpty;

  Future<List<WorkflowRun>> getWorkflowRuns(String owner, String repo,
      {int perPage = 30}) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/repos/$owner/$repo/actions/runs?per_page=$perPage'),
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
